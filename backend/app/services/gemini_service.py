"""
Gemini 1.5 Pro integration for plain-language fairness reports.
"""
import google.generativeai as genai
from app.core.config import settings
from app.models.schemas import BiasMetrics, Domain, RemediationStep
from typing import List
import json
import re

LEGAL_REFERENCES = {
    Domain.hiring: [
        "Equal Remuneration Act, 1976 — prohibits gender-based pay/selection discrimination",
        "SC/ST (Prevention of Atrocities) Act, 1989 — protects against caste discrimination",
        "India DPDPA 2023 — requires transparent automated decision-making",
    ],
    Domain.lending: [
        "Reserve Bank of India Fair Practice Code — requires non-discriminatory lending",
        "India DPDPA 2023 — automated credit decisions must be explainable",
        "Consumer Protection Act, 2019 — unfair trade practices include discriminatory terms",
    ],
    Domain.healthcare: [
        "Clinical Establishments Act, 2010 — non-discrimination in patient care",
        "India DPDPA 2023 — health data processing must be fair and transparent",
        "Rights of Persons with Disabilities Act, 2016 — equal access to healthcare",
    ],
    Domain.other: [
        "India DPDPA 2023 — Digital Personal Data Protection Act",
        "IT Act, 2000 (amended) — accountability for automated decisions",
    ],
}

REMEDIATION_MAP = {
    "resampling": RemediationStep(
        priority=1,
        action="Resample training data",
        description="Increase representation of underrepresented groups in training data using oversampling (SMOTE) or undersampling.",
        technique="resampling",
        expected_impact="Reduces demographic parity difference by 30–50%",
    ),
    "reweighting": RemediationStep(
        priority=2,
        action="Apply sample reweighting",
        description="Assign higher weights to samples from disadvantaged groups during model training to compensate for historical bias.",
        technique="reweighting",
        expected_impact="Improves disparate impact ratio toward 0.8+ threshold",
    ),
    "threshold_adjustment": RemediationStep(
        priority=3,
        action="Adjust decision thresholds per group",
        description="Set different classification thresholds for different demographic groups to equalise false positive/negative rates.",
        technique="threshold_adjustment",
        expected_impact="Directly improves equalized odds score",
    ),
    "feature_removal": RemediationStep(
        priority=2,
        action="Remove proxy features",
        description="Identify and remove features that correlate with protected attributes (e.g. postal code as proxy for caste/religion).",
        technique="feature_removal",
        expected_impact="Addresses root cause of indirect discrimination",
    ),
    "audit_trail": RemediationStep(
        priority=3,
        action="Implement human review for borderline cases",
        description="Flag decisions near the threshold for human review. Ensures automated decisions are contestable under DPDPA 2023.",
        technique="audit_trail",
        expected_impact="Reduces legal risk, improves trust",
    ),
}


def _get_remediation_steps(
    di_ratio: float, dp_diff: float, domain: Domain
) -> List[RemediationStep]:
    steps = []
    if di_ratio < 0.8:
        steps.append(REMEDIATION_MAP["resampling"])
        steps.append(REMEDIATION_MAP["reweighting"])
    if dp_diff > 0.15:
        steps.append(REMEDIATION_MAP["threshold_adjustment"])
    steps.append(REMEDIATION_MAP["feature_removal"])
    steps.append(REMEDIATION_MAP["audit_trail"])
    return sorted(steps, key=lambda s: s.priority)


def generate_fairness_report(
    metrics: BiasMetrics,
    domain: Domain,
    affected_groups: List[str],
    fairness_score: float,
) -> tuple[str, List[RemediationStep], List[str]]:
    """
    Call Gemini 1.5 Pro to generate a plain-language fairness audit report.
    Returns (report_text, remediation_steps, legal_references).
    """
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-1.5-pro")

    domain_context = {
        Domain.hiring: "employee hiring and recruitment",
        Domain.lending: "loan and credit approval",
        Domain.healthcare: "patient triage and healthcare access",
        Domain.other: "automated decision-making",
    }

    prompt = f"""You are an AI fairness auditor preparing a report for an Indian organisation.
Analyse these fairness metrics for their {domain_context[domain]} AI system:

METRICS:
- Overall fairness score: {fairness_score}/100
- Demographic parity difference: {metrics.demographic_parity_difference} (ideal = 0, >0.1 is concerning)
- Disparate impact ratio: {metrics.disparate_impact_ratio} (ideal = 1.0, <0.8 indicates potential discrimination)
- Equalized odds difference: {metrics.equalized_odds_difference} (ideal = 0)
- Selection rates by group: {json.dumps(metrics.selection_rate_by_group, indent=2)}
- Most disadvantaged groups: {', '.join(affected_groups)}

Write a 3-paragraph plain-language audit report:

PARAGRAPH 1 — What was found:
State clearly whether bias was detected. Name which groups are most disadvantaged and by how much.
Use specific numbers. Write for a non-technical HR manager or loan officer.

PARAGRAPH 2 — Why this matters legally in India:
Explain the legal implications under relevant Indian law.
Be specific about which laws apply to this domain. Explain what "disparate impact" means practically.

PARAGRAPH 3 — Urgency and next steps:
Give 2-3 specific actions they must take. Be direct. Include a recommended timeline.

Keep each paragraph to 3-4 sentences. Avoid jargon. Do not use bullet points."""

    response = model.generate_content(prompt)
    report_text = response.text

    remediation = _get_remediation_steps(
        metrics.disparate_impact_ratio,
        metrics.demographic_parity_difference,
        domain,
    )
    legal_refs = LEGAL_REFERENCES.get(domain, LEGAL_REFERENCES[Domain.other])

    return report_text, remediation, legal_refs
