from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from enum import Enum


class Domain(str, Enum):
    hiring = "hiring"
    lending = "lending"
    healthcare = "healthcare"
    other = "other"


class BiasMetrics(BaseModel):
    demographic_parity_difference: float
    disparate_impact_ratio: float
    equalized_odds_difference: float
    selection_rate_by_group: Dict[str, float]
    false_positive_rate_by_group: Dict[str, float]


class AuditRequest(BaseModel):
    file_url: str           # Cloud Storage URL of uploaded CSV
    domain: Domain
    target_column: str      # e.g. "approved", "hired", "diagnosed"
    sensitive_columns: List[str]  # e.g. ["gender", "caste", "income_group"]
    user_id: str


class RemediationStep(BaseModel):
    priority: int
    action: str
    description: str
    technique: str          # e.g. "resampling", "reweighting", "threshold_adjustment"
    expected_impact: str


class AuditResult(BaseModel):
    audit_id: str
    user_id: str
    domain: Domain
    overall_fairness_score: float   # 0-100
    bias_detected: bool
    affected_groups: List[str]
    metrics: BiasMetrics
    gemini_report: str              # plain-language Gemini report
    remediation_steps: List[RemediationStep]
    legal_references: List[str]
    created_at: str
    pdf_url: Optional[str] = None


class AuditSummary(BaseModel):
    audit_id: str
    domain: Domain
    overall_fairness_score: float
    bias_detected: bool
    created_at: str
