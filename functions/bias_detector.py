"""
Core bias detection engine.
Pure Python + Pandas — no external ML libraries needed.
Works in Firebase Functions free tier.
"""
import pandas as pd
import numpy as np
from io import BytesIO
from typing import Dict, List, Tuple


# ── Column detection ─────────────────────────────────────────────────────────

SENSITIVE_KEYWORDS = [
    "gender", "sex", "caste", "religion", "community",
    "district", "state", "income", "age", "category",
    "rural", "urban", "sc", "st", "obc", "region", "class"
]

def detect_sensitive_columns(df: pd.DataFrame) -> List[str]:
    return [
        col for col in df.columns
        if any(kw in col.lower() for kw in SENSITIVE_KEYWORDS)
    ]

def detect_target_columns(df: pd.DataFrame) -> List[str]:
    """Guess which columns are binary outcome columns."""
    target_kws = ["hired", "approved", "selected", "accepted",
                  "outcome", "result", "decision", "granted", "passed"]
    candidates = []
    for col in df.columns:
        if any(kw in col.lower() for kw in target_kws):
            candidates.append(col)
        # Also check: binary columns with 0/1 values
        elif df[col].dropna().isin([0, 1]).all() and col not in candidates:
            candidates.append(col)
    return candidates


# ── Fairness metrics ──────────────────────────────────────────────────────────

def selection_rates(df: pd.DataFrame, target: str, sensitive: str) -> Dict[str, float]:
    """Approval/selection rate per demographic group."""
    result = {}
    for grp in df[sensitive].dropna().unique():
        subset = df[df[sensitive] == grp]
        result[str(grp)] = round(float(subset[target].mean()), 4)
    return result


def demographic_parity_diff(rates: Dict[str, float]) -> float:
    """Max rate - min rate. Ideal = 0. >0.1 is concerning."""
    vals = list(rates.values())
    return round(max(vals) - min(vals), 4) if len(vals) >= 2 else 0.0


def disparate_impact(rates: Dict[str, float]) -> float:
    """Min/max ratio. Ideal = 1.0. <0.8 = potential discrimination (80% rule)."""
    vals = list(rates.values())
    if len(vals) < 2 or max(vals) == 0:
        return 1.0
    return round(min(vals) / max(vals), 4)


def equalized_odds_diff(df: pd.DataFrame, target: str, sensitive: str) -> float:
    """Standard deviation of selection rates across groups (proxy)."""
    rates = selection_rates(df, target, sensitive)
    return round(float(np.std(list(rates.values()))), 4)


def fairness_score(dp: float, di: float, eo: float) -> float:
    """
    Aggregate 0–100 score.
    100 = perfectly fair, 0 = maximally biased.
    """
    dp_score = max(0.0, 100.0 - dp * 100)
    di_score = min(100.0, di * 100)
    eo_score = max(0.0, 100.0 - eo * 200)
    return round(dp_score * 0.4 + di_score * 0.4 + eo_score * 0.2, 1)


# ── Main pipeline ─────────────────────────────────────────────────────────────

def run_analysis(
    csv_bytes: bytes,
    target_col: str,
    sensitive_col: str,
) -> dict:
    """
    Full bias analysis pipeline.
    Returns a dict ready to store in Firestore.
    """
    df = pd.read_csv(BytesIO(csv_bytes))

    # Ensure target is binary int
    df[target_col] = df[target_col].astype(int)

    rates   = selection_rates(df, target_col, sensitive_col)
    dp      = demographic_parity_diff(rates)
    di      = disparate_impact(rates)
    eo      = equalized_odds_diff(df, target_col, sensitive_col)
    score   = fairness_score(dp, di, eo)
    biased  = di < 0.8 or dp > 0.1

    # Most disadvantaged group
    min_rate = min(rates.values())
    affected = [g for g, r in rates.items() if r == min_rate]

    return {
        "metrics": {
            "demographic_parity_difference": dp,
            "disparate_impact_ratio": di,
            "equalized_odds_difference": eo,
            "selection_rate_by_group": rates,
        },
        "overall_fairness_score": score,
        "bias_detected": biased,
        "affected_groups": affected,
        "row_count": len(df),
        "group_count": len(rates),
    }


def preview_csv(csv_bytes: bytes) -> dict:
    """Return column info for the upload screen column-picker."""
    df = pd.read_csv(BytesIO(csv_bytes), nrows=5)
    return {
        "all_columns": list(df.columns),
        "suggested_sensitive": detect_sensitive_columns(df),
        "suggested_target": detect_target_columns(df),
        "row_count": sum(1 for _ in BytesIO(csv_bytes)) - 1,
        "sample": df.head(3).to_dict(orient="records"),
    }
