"""
FairScan — Firebase Functions (Python)
All backend logic lives here as HTTPS callable functions.

Functions:
  - previewCsv      : detect columns before full analysis
  - runAudit        : full bias analysis + Gemini report
  - getAudit        : fetch a saved audit by ID
  - listAudits      : list user's audit history
"""
import os
import uuid
import datetime
import json

import firebase_admin
from firebase_admin import credentials, firestore, storage
from firebase_functions import https_fn, options
from firebase_functions.params import SecretParam

import bias_detector
import gemini_service

# ── Init ──────────────────────────────────────────────────────────────────────

firebase_admin.initialize_app()
db  = firestore.client()
bkt = storage.bucket()

GEMINI_KEY = SecretParam("GEMINI_API_KEY")

# Allow cross-origin calls from Flutter web + localhost
CORS = options.CorsOptions(
    cors_origins=["*"],
    cors_methods=["GET", "POST"],
)


# ── Helper ────────────────────────────────────────────────────────────────────

def _uid(req: https_fn.CallableRequest) -> str:
    """Extract and validate Firebase Auth UID."""
    if req.auth is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="You must be signed in to use FairScan.",
        )
    return req.auth.uid


def _err(msg: str):
    raise https_fn.HttpsError(
        code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
        message=msg,
    )


# ── Function 1: Preview CSV columns ──────────────────────────────────────────

@https_fn.on_call(cors=CORS)
def previewCsv(req: https_fn.CallableRequest) -> dict:
    """
    Input:  { storage_path: "uploads/uid/filename.csv" }
    Output: { all_columns, suggested_sensitive, suggested_target, row_count, sample }
    """
    uid  = _uid(req)
    path = req.data.get("storage_path", "")

    if not path.startswith(f"uploads/{uid}/"):
        _err("Invalid file path.")

    blob = bkt.blob(path)
    if not blob.exists():
        _err("File not found in storage.")

    csv_bytes = blob.download_as_bytes()
    return bias_detector.preview_csv(csv_bytes)


# ── Function 2: Run full audit ────────────────────────────────────────────────

@https_fn.on_call(
    cors=CORS,
    secrets=[GEMINI_KEY],
    timeout_sec=300,
    memory=options.MemoryOption.MB_512,
)
def runAudit(req: https_fn.CallableRequest) -> dict:
    """
    Input: {
      storage_path: "uploads/uid/file.csv",
      domain: "hiring"|"lending"|"healthcare"|"other",
      target_column: str,
      sensitive_column: str
    }
    Output: full AuditResult dict (also saved to Firestore)
    """
    uid = _uid(req)

    path      = req.data.get("storage_path", "")
    domain    = req.data.get("domain", "other")
    target    = req.data.get("target_column", "")
    sensitive = req.data.get("sensitive_column", "")

    if not all([path, domain, target, sensitive]):
        _err("Missing required fields: storage_path, domain, target_column, sensitive_column")

    if not path.startswith(f"uploads/{uid}/"):
        _err("Invalid file path.")

    # Download CSV from Storage
    blob = bkt.blob(path)
    if not blob.exists():
        _err("File not found. Please re-upload.")
    csv_bytes = blob.download_as_bytes()

    # Run bias analysis
    try:
        analysis = bias_detector.run_analysis(csv_bytes, target, sensitive)
    except KeyError as e:
        _err(f"Column not found in CSV: {e}. Check your column names.")
    except Exception as e:
        _err(f"Analysis failed: {str(e)}")

    # Generate Gemini report
    api_key = GEMINI_KEY.value
    report  = gemini_service.generate_report(
        metrics       = analysis["metrics"],
        domain        = domain,
        affected_groups = analysis["affected_groups"],
        fairness_score  = analysis["overall_fairness_score"],
        api_key         = api_key,
    )

    remediation = gemini_service.get_remediation(domain)
    legal_refs  = gemini_service.get_legal_refs(domain)

    # Build full result
    audit_id = str(uuid.uuid4())
    result = {
        "audit_id":              audit_id,
        "user_id":               uid,
        "domain":                domain,
        "target_column":         target,
        "sensitive_column":      sensitive,
        "overall_fairness_score": analysis["overall_fairness_score"],
        "bias_detected":         analysis["bias_detected"],
        "affected_groups":       analysis["affected_groups"],
        "metrics":               analysis["metrics"],
        "gemini_report":         report,
        "remediation_steps":     remediation,
        "legal_references":      legal_refs,
        "row_count":             analysis["row_count"],
        "created_at":            datetime.datetime.utcnow().isoformat(),
    }

    # Save to Firestore
    db.collection("audits").document(audit_id).set(result)

    return result


# ── Function 3: Get single audit ──────────────────────────────────────────────

@https_fn.on_call(cors=CORS)
def getAudit(req: https_fn.CallableRequest) -> dict:
    """Input: { audit_id: str }"""
    uid      = _uid(req)
    audit_id = req.data.get("audit_id", "")

    doc = db.collection("audits").document(audit_id).get()
    if not doc.exists:
        _err("Audit not found.")

    data = doc.to_dict()
    if data.get("user_id") != uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="Not authorised.",
        )
    return data


# ── Function 4: List audits ───────────────────────────────────────────────────

@https_fn.on_call(cors=CORS)
def listAudits(req: https_fn.CallableRequest) -> dict:
    """Returns last 20 audits for the authenticated user."""
    uid   = _uid(req)
    limit = int(req.data.get("limit", 20))

    docs = (
        db.collection("audits")
        .where("user_id", "==", uid)
        .order_by("created_at", direction=firestore.Query.DESCENDING)
        .limit(limit)
        .stream()
    )

    audits = []
    for doc in docs:
        d = doc.to_dict()
        audits.append({
            "audit_id":              d.get("audit_id"),
            "domain":                d.get("domain"),
            "overall_fairness_score": d.get("overall_fairness_score"),
            "bias_detected":         d.get("bias_detected"),
            "affected_groups":       d.get("affected_groups", []),
            "created_at":            d.get("created_at"),
        })

    return {"audits": audits}
