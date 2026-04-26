"""
/audit endpoints — core of FairScan.
Accepts CSV upload → computes fairness metrics → calls Gemini → returns full audit.
"""
import io
import uuid
from datetime import datetime, timezone

import pandas as pd
from fastapi import APIRouter, File, Form, UploadFile, HTTPException

from app.core.config import settings
from app.core.fairness import compute_fairness_metrics
from app.models.schemas import AuditResult, DomainEnum
from app.services.gemini import generate_fairness_report

router = APIRouter(prefix="/audit", tags=["audit"])


@router.post("/", response_model=AuditResult)
async def run_audit(
    file: UploadFile = File(..., description="CSV file of AI decisions"),
    domain: DomainEnum = Form(DomainEnum.general),
    org_name: str = Form("Organisation"),
    user_id: str = Form(""),
):
    # ── Validate file ──────────────────────────────────────────────────────
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are supported.")

    content = await file.read()
    if len(content) > 50 * 1024 * 1024:  # 50 MB limit
        raise HTTPException(status_code=413, detail="File too large. Max 50 MB.")

    # ── Parse CSV ──────────────────────────────────────────────────────────
    try:
        df = pd.read_csv(io.BytesIO(content))
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Could not parse CSV: {e}")

    if len(df) < 10:
        raise HTTPException(status_code=422, detail="Dataset too small — need at least 10 rows.")

    if len(df.columns) < 2:
        raise HTTPException(status_code=422, detail="Dataset needs at least 2 columns.")

    # ── Route large datasets to BigQuery ──────────────────────────────────
    if len(df) > settings.max_csv_rows_direct:
        # For large files: upload to GCS → BigQuery async job
        # For now, sample for direct processing (production would use BigQuery)
        df = df.sample(n=settings.max_csv_rows_direct, random_state=42)

    # ── Compute fairness metrics ───────────────────────────────────────────
    try:
        fairness = compute_fairness_metrics(df)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Fairness computation failed: {e}")

    if not fairness.sensitive_columns_detected:
        raise HTTPException(
            status_code=422,
            detail=(
                "No sensitive demographic columns detected. "
                "Ensure your CSV has columns like 'gender', 'age', 'caste', 'income', etc."
            ),
        )

    # ── Generate Gemini report ─────────────────────────────────────────────
    try:
        gemini_result = await generate_fairness_report(fairness, domain.value, org_name)
    except Exception as e:
        # Gemini failure shouldn't block the whole audit
        gemini_result = {
            "narrative": "Gemini report generation failed. Raw metrics are still available above.",
            "metadata": {},
        }

    # ── Build response ─────────────────────────────────────────────────────
    audit_id = str(uuid.uuid4())

    return AuditResult(
        audit_id=audit_id,
        overall_score=fairness.overall_score,
        severity=fairness.severity,
        demographic_parity_difference=fairness.demographic_parity_difference,
        disparate_impact_ratio=fairness.disparate_impact_ratio,
        equalized_odds_difference=fairness.equalized_odds_difference,
        equal_opportunity_difference=fairness.equal_opportunity_difference,
        group_metrics=[
            {
                "group_name": gm.group_name,
                "group_value": gm.group_value,
                "positive_rate": gm.positive_rate,
                "sample_size": gm.sample_size,
            }
            for gm in fairness.group_metrics
        ],
        sensitive_columns=fairness.sensitive_columns_detected,
        outcome_column=fairness.outcome_column,
        total_rows=fairness.total_rows,
        domain=domain.value,
        gemini_report=gemini_result["narrative"],
        gemini_metadata=gemini_result.get("metadata", {}),
        created_at=datetime.now(timezone.utc).isoformat(),
    )


@router.get("/sample-data")
async def get_sample_data():
    """Returns info about the sample dataset for demo purposes."""
    return {
        "message": "Download sample_data/hiring_sample.csv from the repo to test FairScan.",
        "columns": [
            "applicant_id", "gender", "age", "caste", "education",
            "experience_years", "income_bracket", "district", "hired"
        ],
        "rows": 500,
        "known_bias": "Gender disparity: male approval rate ~68%, female ~41%",
    }
