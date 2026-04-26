"""
Gemini 1.5 Pro integration.
Generates plain-language fairness audit reports citing Indian law.
"""
import google.generativeai as genai
import os

# ── Legal references by domain ────────────────────────────────────────────────

LEGAL_REFS = {
    "hiring": [
        "Equal Remuneration Act, 1976 — prohibits wage/selection discrimination by gender",
        "SC/ST (Prevention of Atrocities) Act, 1989 — protects against caste discrimination",
        "India DPDPA 2023 — automated hiring decisions must be transparent & contestable",
    ],
    "lending": [
        "RBI Fair Practice Code — mandates non-discriminatory lending criteria",
        "India DPDPA 2023 — automated credit decisions must be explainable",
        "Consumer Protection Act, 2019 — unfair/discriminatory terms are prohibited",
    ],
    "healthcare": [
        "Clinical Establishments Act, 2010 — non-discrimination in patient care",
        "India DPDPA 2023 — health data processing must be fair & transparent",
        "Rights of Persons with Disabilities Act, 2016 — equal healthcare access",
    ],
    "other": [
        "India DPDPA 2023 — Digital Personal Data Protection Act",
        "IT Act 2000 (amended) — accountability for automated decisions",
    ],
}

REMEDIATION = {
    "hiring": [
        {"priority": 1, "action": "Audit job requirement proxies",
         "description": "Check if 'experience' or 'location' columns act as caste/gender proxies. Remove or reweight them.",
         "expected_impact": "Reduces indirect discrimination by 30–50%"},
        {"priority": 2, "action": "Apply sample reweighting",
         "description": "Assign higher training weights to underrepresented demographic groups.",
         "expected_impact": "Improves disparate impact ratio toward 0.8+ threshold"},
        {"priority": 3, "action": "Add human review for borderline cases",
         "description": "Flag applications near the decision threshold for manual review. Required under DPDPA 2023.",
         "expected_impact": "Reduces legal risk, improves trust"},
    ],
    "lending": [
        {"priority": 1, "action": "Remove postal code as feature",
         "description": "Postal codes are strong proxies for caste and income group. Remove from model inputs.",
         "expected_impact": "Directly addresses root cause of geographic discrimination"},
        {"priority": 2, "action": "Separate thresholds per income group",
         "description": "Apply calibrated thresholds so approval rates are equitable across income brackets.",
         "expected_impact": "Brings disparate impact ratio above 0.8"},
        {"priority": 3, "action": "Document decision factors per application",
         "description": "Log which features drove each decision. Required for RBI Fair Practice compliance.",
         "expected_impact": "Enables audit trail and contestability"},
    ],
    "healthcare": [
        {"priority": 1, "action": "Audit training data representation",
         "description": "Ensure training data includes proportional representation of all demographic groups.",
         "expected_impact": "Reduces model accuracy disparities across groups"},
        {"priority": 2, "action": "Equalise false negative rates",
         "description": "Ensure the model does not under-diagnose for specific groups (high-stakes error).",
         "expected_impact": "Reduces harm from missed diagnoses"},
        {"priority": 3, "action": "Add clinician override mechanism",
         "description": "Allow clinicians to override AI recommendations. Log all overrides for bias auditing.",
         "expected_impact": "Required under Clinical Establishments Act"},
    ],
    "other": [
        {"priority": 1, "action": "Identify and remove proxy features",
         "description": "Find features correlated with protected attributes and remove or decorrelate them.",
         "expected_impact": "Addresses indirect discrimination"},
        {"priority": 2, "action": "Implement decision logging",
         "description": "Log every automated decision with the features that drove it for future auditing.",
         "expected_impact": "DPDPA 2023 compliance, enables contestability"},
    ],
}


def generate_report(
    metrics: dict,
    domain: str,
    affected_groups: list,
    fairness_score: float,
    api_key: str,
) -> str:
    """
    Call Gemini 1.5 Pro to generate a 3-paragraph plain-language report.
    Falls back to a template report if Gemini is unavailable.
    """
    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-1.5-pro")

        domain_label = {
            "hiring": "employee hiring and recruitment",
            "lending": "loan and credit approval",
            "healthcare": "patient triage and healthcare access",
            "other": "automated decision-making",
        }.get(domain, "automated decision-making")

        prompt = f"""You are an AI fairness auditor preparing a report for an Indian organisation.
Analyse these fairness metrics for their {domain_label} AI system:

- Overall fairness score: {fairness_score}/100
- Demographic parity difference: {metrics['demographic_parity_difference']} (ideal = 0, above 0.1 is concerning)
- Disparate impact ratio: {metrics['disparate_impact_ratio']} (ideal = 1.0, below 0.8 indicates likely discrimination)
- Equalized odds difference: {metrics['equalized_odds_difference']} (ideal = 0)
- Selection rates by group: {metrics['selection_rate_by_group']}
- Most disadvantaged groups: {', '.join(affected_groups)}

Write exactly 3 paragraphs. No bullet points. No headers.

Paragraph 1 — What was found: State clearly whether bias was detected.
Name the disadvantaged groups and by exactly how much they are affected.
Write for a non-technical HR manager.

Paragraph 2 — Why this matters legally in India: Name the specific Indian
laws that apply to this domain. Explain what "disparate impact" means
in plain terms. Be concrete about the legal risk.

Paragraph 3 — What to do next: Give 2 specific actions with a timeline.
Be direct. End with one sentence on urgency."""

        response = model.generate_content(prompt)
        return response.text

    except Exception as e:
        # Fallback: template report (still useful without Gemini)
        di = metrics['disparate_impact_ratio']
        dp = metrics['demographic_parity_difference']
        bias_word = "significant bias" if di < 0.8 else "moderate disparity"
        groups_str = ', '.join(affected_groups)

        return (
            f"FairScan detected {bias_word} in this {domain} dataset. "
            f"The most disadvantaged group(s) — {groups_str} — received approval at a rate "
            f"{round((1 - di) * 100, 1)}% lower than the most favoured group. "
            f"The disparate impact ratio of {di} {'falls below' if di < 0.8 else 'approaches'} "
            f"the internationally recognised 80% rule threshold.\n\n"
            f"Under India's DPDPA 2023, organisations using automated decision-making systems "
            f"must ensure those systems do not produce discriminatory outcomes. "
            f"A disparate impact ratio below 0.8 constitutes indirect discrimination under "
            f"the Equal Remuneration Act (for hiring) and RBI Fair Practice Code (for lending). "
            f"Continuing to use this model without remediation exposes your organisation to "
            f"regulatory and reputational risk.\n\n"
            f"Immediate actions: (1) Audit your training data for demographic imbalances "
            f"and apply reweighting to underrepresented groups within 2 weeks. "
            f"(2) Add a human review step for borderline decisions within 30 days. "
            f"Do not deploy new versions of this model until the disparate impact ratio "
            f"exceeds 0.8."
        )


def get_remediation(domain: str) -> list:
    return REMEDIATION.get(domain, REMEDIATION["other"])


def get_legal_refs(domain: str) -> list:
    return LEGAL_REFS.get(domain, LEGAL_REFS["other"])
