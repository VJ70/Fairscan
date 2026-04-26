"""
FairScan API routes.
POST /audit        — run full bias analysis on uploaded CSV
GET  /audit/{id}   — get audit result
GET  /audits       — list user's audit history
POST /audit/{id}/pdf — generate PDF report
"""
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends
from fastapi.responses import JSONResponse
from typing import Optional, List
import uuid
import datetime
import pandas as pd
from io import BytesIO

from app.models.schemas import (
    AuditRequest, AuditResult, AuditSummary, Domain, BiasMetrics
)
from app.services.bias_detector import (
    load_csv_from_bytes, auto_detect_sensitive_columns, run_bias_analysis
)
from app.services.gemini_service import generate_fairness_report
from app.core.firebase import get_firestore

router = APIRouter()


@router.post("/audit", response_model=AuditResult)
async def run_audit(
    file: UploadFile = File(...),
    domain: Domain = Form(...),
    target_column: str = Form(...),
    sensitive_column: str = Form(...),
    user_id: str = Form(...),
):
    """
    Main endpoint: accept CSV upload, run bias analysis, call Gemini, return result.
    """
    # Validate file type
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are supported")

    # Read file
    contents = await file.read()
    if len(contents) > 50 * 1024 * 1024:  # 50MB limit
        raise HTTPException(status_code=400, detail="File exceeds 50MB limit")

    try:
        df = load_csv_from_bytes(contents)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not parse CSV: {str(e)}")

    # Validate columns exist
    if target_column not in df.columns:
        raise HTTPException(
            status_code=400,
            detail=f"Target column '{target_column}' not found. Available: {list(df.columns)}"
        )
    if sensitive_column not in df.columns:
        # Auto-detect if not found
        detected = auto_detect_sensitive_columns(df)
        if not detected:
            raise HTTPException(
                status_code=400,
                detail=f"Sensitive column '{sensitive_column}' not found and no demographic columns auto-detected."
            )
        sensitive_column = detected[0]

    # Run bias analysis
    try:
        metrics, fairness_score, bias_detected, affected_groups = run_bias_analysis(
            df, target_column, sensitive_column
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Bias analysis failed: {str(e)}")

    # Generate Gemini report
    try:
        report_text, remediation_steps, legal_refs = generate_fairness_report(
            metrics, domain, affected_groups, fairness_score
        )
    except Exception as e:
        # Fallback report if Gemini fails (e.g. no API key in dev)
        report_text = (
            f"Fairness analysis complete. Overall fairness score: {fairness_score}/100. "
            f"Disparate impact ratio: {metrics.disparate_impact_ratio} "
            f"({'below' if metrics.disparate_impact_ratio < 0.8 else 'above'} the 0.8 threshold). "
            f"Affected groups: {', '.join(affected_groups)}."
        )
        remediation_steps = []
        legal_refs = ["India DPDPA 2023"]

    # Build result
    audit_id = str(uuid.uuid4())
    result = AuditResult(
        audit_id=audit_id,
        user_id=user_id,
        domain=domain,
        overall_fairness_score=fairness_score,
        bias_detected=bias_detected,
        affected_groups=affected_groups,
        metrics=metrics,
        gemini_report=report_text,
        remediation_steps=remediation_steps,
        legal_references=legal_refs,
        created_at=datetime.datetime.utcnow().isoformat(),
    )

    # Persist to Firestore
    try:
        db = get_firestore()
        db.collection("audits").document(audit_id).set(result.model_dump())
    except Exception:
        pass  # Don't fail if Firestore unavailable in dev

    return result


@router.get("/audit/{audit_id}", response_model=AuditResult)
async def get_audit(audit_id: str, user_id: str):
    """Retrieve a previously saved audit result."""
    try:
        db = get_firestore()
        doc = db.collection("audits").document(audit_id).get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Audit not found")
        data = doc.to_dict()
        if data.get("user_id") != user_id:
            raise HTTPException(status_code=403, detail="Not authorised")
        return AuditResult(**data)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/audits", response_model=List[AuditSummary])
async def list_audits(user_id: str, limit: int = 20):
    """List all audits for a user."""
    try:
        db = get_firestore()
        docs = (
            db.collection("audits")
            .where("user_id", "==", user_id)
            .order_by("created_at", direction="DESCENDING")
            .limit(limit)
            .stream()
        )
        results = []
        for doc in docs:
            d = doc.to_dict()
            results.append(AuditSummary(
                audit_id=d["audit_id"],
                domain=d["domain"],
                overall_fairness_score=d["overall_fairness_score"],
                bias_detected=d["bias_detected"],
                created_at=d["created_at"],
            ))
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/detect-columns")
async def detect_columns(file: UploadFile = File(...)):
    """Auto-detect sensitive and target columns in a CSV."""
    contents = await file.read()
    try:
        df = load_csv_from_bytes(contents)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Cannot parse CSV: {e}")

    sensitive = auto_detect_sensitive_columns(df)
    all_cols = list(df.columns)
    sample = df.head(3).to_dict(orient="records")

    return {
        "all_columns": all_cols,
        "suggested_sensitive_columns": sensitive,
        "sample_rows": sample,
        "row_count": len(df),
    }
