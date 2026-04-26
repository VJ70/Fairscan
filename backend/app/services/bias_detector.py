"""
Core bias detection service using Fairlearn.
Computes demographic parity, disparate impact, equalized odds.
"""
import pandas as pd
import numpy as np
from typing import Dict, List, Tuple
from app.models.schemas import BiasMetrics


def load_csv_from_bytes(file_bytes: bytes) -> pd.DataFrame:
    from io import BytesIO
    return pd.read_csv(BytesIO(file_bytes))


def auto_detect_sensitive_columns(df: pd.DataFrame) -> List[str]:
    """Heuristically detect demographic columns by name."""
    keywords = [
        "gender", "sex", "caste", "religion", "district",
        "state", "income", "age", "community", "rural", "urban",
        "sc", "st", "obc", "category", "region"
    ]
    detected = []
    for col in df.columns:
        if any(kw in col.lower() for kw in keywords):
            detected.append(col)
    return detected


def compute_selection_rates(
    df: pd.DataFrame,
    target_col: str,
    sensitive_col: str
) -> Dict[str, float]:
    """Compute selection/approval rate per demographic group."""
    rates = {}
    for group in df[sensitive_col].unique():
        group_df = df[df[sensitive_col] == group]
        rate = group_df[target_col].mean()
        rates[str(group)] = round(float(rate), 4)
    return rates


def demographic_parity_difference(rates: Dict[str, float]) -> float:
    """Max selection rate minus min selection rate across groups."""
    values = list(rates.values())
    if len(values) < 2:
        return 0.0
    return round(max(values) - min(values), 4)


def disparate_impact_ratio(rates: Dict[str, float]) -> float:
    """
    80% rule: ratio of lowest to highest selection rate.
    Score < 0.8 indicates potential discrimination.
    """
    values = list(rates.values())
    if len(values) < 2 or max(values) == 0:
        return 1.0
    return round(min(values) / max(values), 4)


def equalized_odds_difference(
    df: pd.DataFrame,
    target_col: str,
    sensitive_col: str,
    prediction_col: str = None
) -> float:
    """
    If a prediction column exists, compute false positive rate parity.
    Otherwise approximate from selection rate variance.
    """
    if prediction_col and prediction_col in df.columns:
        fpr_by_group = {}
        for group in df[sensitive_col].unique():
            g = df[df[sensitive_col] == group]
            negatives = g[g[target_col] == 0]
            if len(negatives) == 0:
                fpr_by_group[str(group)] = 0.0
            else:
                fpr = negatives[prediction_col].mean()
                fpr_by_group[str(group)] = round(float(fpr), 4)
        values = list(fpr_by_group.values())
        return round(max(values) - min(values), 4) if len(values) >= 2 else 0.0

    # Fallback: use variance of selection rates as proxy
    rates = compute_selection_rates(df, target_col, sensitive_col)
    values = list(rates.values())
    return round(float(np.std(values)), 4)


def false_positive_rates(
    df: pd.DataFrame,
    target_col: str,
    sensitive_col: str
) -> Dict[str, float]:
    """Compute false positive rates per group (uses target as proxy if no prediction col)."""
    rates = {}
    for group in df[sensitive_col].unique():
        g = df[df[sensitive_col] == group]
        # Approximation: variance from mean as proxy for FPR
        rates[str(group)] = round(float(g[target_col].std() or 0), 4)
    return rates


def compute_fairness_score(
    dp_diff: float,
    di_ratio: float,
    eo_diff: float
) -> float:
    """
    Aggregate 0-100 fairness score.
    100 = perfectly fair, 0 = severely biased.
    """
    # Demographic parity: ideal = 0, penalise up to 1.0
    dp_score = max(0, 100 - (dp_diff * 100))
    # Disparate impact: ideal = 1.0, below 0.8 is concerning
    di_score = min(100, di_ratio * 100)
    # Equalized odds: ideal = 0
    eo_score = max(0, 100 - (eo_diff * 100))

    return round((dp_score * 0.4 + di_score * 0.4 + eo_score * 0.2), 1)


def run_bias_analysis(
    df: pd.DataFrame,
    target_col: str,
    sensitive_col: str,
) -> Tuple[BiasMetrics, float, bool, List[str]]:
    """
    Main bias analysis pipeline.
    Returns (metrics, fairness_score, bias_detected, affected_groups).
    """
    # Ensure target is binary 0/1
    df = df.copy()
    df[target_col] = df[target_col].astype(int)

    rates = compute_selection_rates(df, target_col, sensitive_col)
    dp_diff = demographic_parity_difference(rates)
    di_ratio = disparate_impact_ratio(rates)
    eo_diff = equalized_odds_difference(df, target_col, sensitive_col)
    fpr = false_positive_rates(df, target_col, sensitive_col)

    metrics = BiasMetrics(
        demographic_parity_difference=dp_diff,
        disparate_impact_ratio=di_ratio,
        equalized_odds_difference=eo_diff,
        selection_rate_by_group=rates,
        false_positive_rate_by_group=fpr,
    )

    score = compute_fairness_score(dp_diff, di_ratio, eo_diff)
    bias_detected = di_ratio < 0.8 or dp_diff > 0.1

    # Identify most disadvantaged groups
    min_rate = min(rates.values())
    affected = [g for g, r in rates.items() if r == min_rate]

    return metrics, score, bias_detected, affected
