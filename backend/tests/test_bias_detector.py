"""
Tests for the core bias detection logic.
Run: pytest tests/
"""
import pytest
import pandas as pd
from app.services.bias_detector import (
    compute_selection_rates,
    demographic_parity_difference,
    disparate_impact_ratio,
    compute_fairness_score,
    run_bias_analysis,
    auto_detect_sensitive_columns,
)


@pytest.fixture
def biased_hiring_df():
    """Synthetic hiring dataset with gender bias."""
    return pd.DataFrame({
        "gender": ["male"] * 60 + ["female"] * 40,
        "experience_years": [5] * 100,
        "hired": [1] * 50 + [0] * 10 + [1] * 16 + [0] * 24,
    })


@pytest.fixture
def fair_df():
    """Synthetic dataset with no bias."""
    return pd.DataFrame({
        "gender": ["male"] * 50 + ["female"] * 50,
        "score": [0.7] * 100,
        "approved": [1] * 40 + [0] * 10 + [1] * 40 + [0] * 10,
    })


def test_selection_rates_biased(biased_hiring_df):
    rates = compute_selection_rates(biased_hiring_df, "hired", "gender")
    assert "male" in rates
    assert "female" in rates
    assert rates["male"] > rates["female"]


def test_demographic_parity_difference(biased_hiring_df):
    rates = compute_selection_rates(biased_hiring_df, "hired", "gender")
    dp = demographic_parity_difference(rates)
    assert dp > 0.1, "Expected significant parity difference in biased dataset"


def test_disparate_impact_biased(biased_hiring_df):
    rates = compute_selection_rates(biased_hiring_df, "hired", "gender")
    di = disparate_impact_ratio(rates)
    assert di < 0.8, "Biased dataset should fall below 80% rule threshold"


def test_fair_dataset_high_score(fair_df):
    metrics, score, bias_detected, affected = run_bias_analysis(fair_df, "approved", "gender")
    assert score > 80, "Fair dataset should score >80"
    assert not bias_detected


def test_biased_dataset_low_score(biased_hiring_df):
    metrics, score, bias_detected, affected = run_bias_analysis(biased_hiring_df, "hired", "gender")
    assert score < 80, "Biased dataset should score <80"
    assert bias_detected
    assert "female" in affected


def test_auto_detect_columns():
    df = pd.DataFrame({
        "gender": [], "income_group": [], "experience": [], "hired": []
    })
    detected = auto_detect_sensitive_columns(df)
    assert "gender" in detected
    assert "income_group" in detected
    assert "experience" not in detected


def test_fairness_score_perfect():
    score = compute_fairness_score(0.0, 1.0, 0.0)
    assert score == 100.0


def test_fairness_score_worst():
    score = compute_fairness_score(1.0, 0.0, 1.0)
    assert score == 0.0
