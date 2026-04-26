"""
Gemini 1.5 Pro integration.
Converts raw fairness numbers → plain-language audit report with India-specific legal references.
"""
import google.generativeai as genai
import json
from app.core.config import settings
from app.core.fairness import FairnessReport

genai.configure(api_key=settings.gemini_api_key)

DOMAIN_LAWS = {
    "hiring": [
        "Equal Remuneration Act, 1976",
        "The Constitution of India — Article 15 (non-discrimination)",
        "India DPDPA 2023 — automated decision-making provisions",
    ],
    "lending": [
        "Reserve Bank of India Fair Practices Code",
        "India DPDPA 2023",
        "The Constitution of India — Article 14 (equality before law)",
    ],
    "healthcare": [
        "Clinical Establishments Act, 2010",
        "India DPDPA 2023",
        "The Rights of Persons with Disabilities Act, 2016",
    ],
    "general": [
        "India DPDPA 2023",
        "The Constitution of India — Article 14 & 15",
        "NITI Aayog Responsible AI Principles (2021)",
    ],
}


def build_prompt(report: FairnessReport, domain: str, org_name: str = "your organisation") -> str:
    laws = DOMAIN_LAWS.get(domain, DOMAIN_LAWS["general"])
    laws_str = "\n".join(f"  - {l}" for l in laws)

    group_summary = []
    for gm in report.group_metrics[:8]:
        group_summary.append(
            f"  {gm.group_name}={gm.group_value}: {gm.positive_rate*100:.1f}% positive outcomes (n={gm.sample_size})"
        )
    groups_str = "\n".join(group_summary)

    return f"""You are an AI fairness auditor preparing a report for an Indian organisation.
Analyze the following bias metrics and write a structured audit report.

CONTEXT:
- Organisation: {org_name}
- Domain: {domain} (the AI makes {domain} decisions)
- Dataset size: {report.total_rows} records
- Sensitive attributes analyzed: {", ".join(report.sensitive_columns_detected) or "auto-detected"}
- Outcome column: {report.outcome_column}

FAIRNESS METRICS:
- Overall Fairness Score: {report.overall_score}/100 (severity: {report.severity})
- Demographic Parity Difference: {report.demographic_parity_difference:.4f}
  (0 = perfectly fair, >0.1 = concerning, >0.2 = serious violation)
- Disparate Impact Ratio: {report.disparate_impact_ratio:.4f}
  (1.0 = perfectly fair, <0.8 = fails the 4/5ths rule used in US/EU law)
- Equalized Odds Difference: {report.equalized_odds_difference:.4f}
- Equal Opportunity Difference: {report.equal_opportunity_difference:.4f}

GROUP BREAKDOWN:
{groups_str}

RELEVANT INDIAN LAWS:
{laws_str}

Write a professional audit report with EXACTLY these four sections:

**1. What Was Found**
Explain in plain language (no jargon) which groups are being treated unequally and by how much. Use the actual numbers. Be specific about who is disadvantaged.

**2. Why This Matters**
Explain the real-world impact on people. Then state which specific laws apply and what the legal risk is for the organisation. Be direct about severity.

**3. Top 3 Actions to Fix This**
Give three concrete, actionable steps the organisation can take immediately. Number them. Make them specific to {domain} decisions. No vague advice like "improve your data" — tell them exactly what to do.

**4. Fairness Score Summary**
One paragraph summarising the score ({report.overall_score}/100) and what it means in simple terms.

Tone: Professional but accessible. Write as if explaining to an HR director or loan manager who does not have a data science background. Do not use technical ML terms without explaining them."""


async def generate_fairness_report(
    report: FairnessReport,
    domain: str,
    org_name: str = "your organisation"
) -> dict:
    """Call Gemini and return structured report + JSON metadata."""
    model = genai.GenerativeModel("gemini-1.5-pro")

    # Main narrative report
    prompt = build_prompt(report, domain, org_name)
    response = await model.generate_content_async(prompt)
    narrative = response.text

    # Structured metadata (separate call for JSON)
    json_prompt = f"""Based on this fairness analysis:
- Fairness score: {report.overall_score}/100
- Severity: {report.severity}
- Demographic parity difference: {report.demographic_parity_difference}
- Disparate impact ratio: {report.disparate_impact_ratio}
- Groups affected: {[gm.group_value for gm in report.group_metrics]}

Return ONLY valid JSON (no markdown, no explanation) with this exact structure:
{{
  "severity_label": "Low|Medium|High|Critical",
  "primary_bias_type": "string describing main bias found",
  "most_affected_group": "string",
  "recommended_action_priority": ["action1", "action2", "action3"],
  "compliance_risk": "Low|Medium|High",
  "immediate_action_required": true/false
}}"""

    json_response = await model.generate_content_async(json_prompt)
    try:
        metadata = json.loads(json_response.text.strip())
    except json.JSONDecodeError:
        # Fallback if Gemini adds markdown
        import re
        match = re.search(r'\{.*\}', json_response.text, re.DOTALL)
        metadata = json.loads(match.group()) if match else {}

    return {
        "narrative": narrative,
        "metadata": metadata,
    }
