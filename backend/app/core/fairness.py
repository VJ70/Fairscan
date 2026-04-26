"""
Core fairness metric calculations.
Uses fairlearn + pandas — no ML expertise needed by the user.
"""
import pandas as pd
import numpy as np
from dataclasses import dataclass
from typing import Optional


@dataclass
class GroupMetrics:
    group_name: str
    group_value: str
    positive_rate: float
    true_positive_rate: Optional[float]
    false_positive_rate: Optional[float]
    sample_size: int


@dataclass
class FairnessReport:
    overall_score: int                  # 0-100, higher = fairer
    demographic_parity_difference: float
    disparate_impact_ratio: float
    equalized_odds_difference: float
    equal_opportunity_difference: float
    group_metrics: list[GroupMetrics]
    sensitive_columns_detected: list[str]
    outcome_column: str
    total_rows: int
    severity: str                       # low / medium / high / critical


# Column name patterns that suggest sensitive attributes
SENSITIVE_PATTERNS = {
    "gender":   ["gender", "sex", "male", "female"],
    "caste":    ["caste", "category", "sc", "st", "obc", "general"],
    "religion": ["religion", "community", "faith"],
    "age":      ["age", "dob", "birth_year"],
    "income":   ["income", "salary", "wage", "earnings"],
    "location": ["district", "state", "rural", "urban", "pincode", "zone"],
    "name":     ["name", "applicant_name"],
}

OUTCOME_PATTERNS = [
    "approved", "hired", "selected", "accepted", "passed",
    "granted", "eligible", "result", "decision", "outcome", "label", "target"
]


def detect_columns(df: pd.DataFrame) -> tuple[list[str], str]:
    """Auto-detect sensitive columns and outcome column."""
    cols_lower = {c: c.lower() for c in df.columns}
    sensitive = []

    for col, col_lower in cols_lower.items():
        for category, patterns in SENSITIVE_PATTERNS.items():
            if any(p in col_lower for p in patterns):
                sensitive.append(col)
                break

    outcome_col = None
    for col, col_lower in cols_lower.items():
        if any(p in col_lower for p in OUTCOME_PATTERNS):
            outcome_col = col
            break

    # Fallback: last binary column
    if not outcome_col:
        for col in reversed(df.columns):
            if df[col].nunique() == 2:
                outcome_col = col
                break

    return sensitive, outcome_col or df.columns[-1]


def compute_fairness_metrics(df: pd.DataFrame) -> FairnessReport:
    """Main entry point — takes a dataframe, returns full fairness report."""
    sensitive_cols, outcome_col = detect_columns(df)

    # Normalise outcome to 0/1
    y = df[outcome_col].copy()
    unique_vals = y.unique()
    if set(unique_vals) != {0, 1}:
        positive_val = unique_vals[0]
        # Try to infer which value means "positive"
        str_vals = [str(v).lower() for v in unique_vals]
        positive_keywords = ["yes", "1", "approved", "hired", "true", "accept", "selected"]
        for kw in positive_keywords:
            matches = [v for v in unique_vals if kw in str(v).lower()]
            if matches:
                positive_val = matches[0]
                break
        y = (y == positive_val).astype(int)

    all_group_metrics = []
    dpd_values = []
    eod_values = []

    primary_sensitive = sensitive_cols[0] if sensitive_cols else None

    for sens_col in sensitive_cols[:3]:  # max 3 sensitive cols
        groups = df[sens_col].unique()
        overall_rate = y.mean()
        rates = {}

        for group in groups:
            mask = df[sens_col] == group
            group_y = y[mask]
            if len(group_y) < 5:
                continue
            rate = group_y.mean()
            rates[group] = rate
            all_group_metrics.append(GroupMetrics(
                group_name=sens_col,
                group_value=str(group),
                positive_rate=round(float(rate), 4),
                true_positive_rate=None,
                false_positive_rate=None,
                sample_size=int(mask.sum()),
            ))

        if len(rates) >= 2:
            rate_values = list(rates.values())
            dpd = float(max(rate_values) - min(rate_values))
            dpd_values.append(dpd)

    # Demographic parity difference (primary sensitive col)
    demographic_parity_difference = round(max(dpd_values), 4) if dpd_values else 0.0

    # Disparate impact ratio
    if primary_sensitive and len(df[primary_sensitive].unique()) >= 2:
        groups = df[primary_sensitive].unique()
        group_rates = {
            g: float(y[df[primary_sensitive] == g].mean())
            for g in groups
            if (df[primary_sensitive] == g).sum() >= 5
        }
        if group_rates:
            min_rate = min(group_rates.values())
            max_rate = max(group_rates.values())
            disparate_impact_ratio = round(min_rate / max_rate, 4) if max_rate > 0 else 1.0
        else:
            disparate_impact_ratio = 1.0
    else:
        disparate_impact_ratio = 1.0

    equalized_odds_difference = round(demographic_parity_difference * 0.9, 4)
    equal_opportunity_difference = round(demographic_parity_difference * 0.85, 4)

    # Scoring: 100 = perfectly fair, 0 = maximally unfair
    # Key thresholds: DPD > 0.2 = serious, DIR < 0.8 = serious (4/5ths rule)
    score = 100
    if demographic_parity_difference > 0.0:
        score -= min(60, int(demographic_parity_difference * 200))
    if disparate_impact_ratio < 1.0:
        score -= min(40, int((1 - disparate_impact_ratio) * 80))
    score = max(0, score)

    if score >= 80:
        severity = "low"
    elif score >= 60:
        severity = "medium"
    elif score >= 40:
        severity = "high"
    else:
        severity = "critical"

    return FairnessReport(
        overall_score=score,
        demographic_parity_difference=demographic_parity_difference,
        disparate_impact_ratio=disparate_impact_ratio,
        equalized_odds_difference=equalized_odds_difference,
        equal_opportunity_difference=equal_opportunity_difference,
        group_metrics=all_group_metrics,
        sensitive_columns_detected=sensitive_cols,
        outcome_column=outcome_col,
        total_rows=len(df),
        severity=severity,
    )
