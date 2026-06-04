# extraction/tests/test_validators.py
import pytest
from validators import validate_performance_data, validate_applicability, validate_weights


class TestValidators:
    def test_valid_performance_data(self):
        data = {"qmax": 120.5, "removal_rate": 95.2, "evidence_level": "high"}
        errors = validate_performance_data(data)
        assert errors == []

    def test_negative_qmax_fails(self):
        data = {"qmax": -10, "removal_rate": 95.2}
        errors = validate_performance_data(data)
        assert any("qmax" in e for e in errors)

    def test_removal_rate_over_100_fails(self):
        data = {"removal_rate": 105}
        errors = validate_performance_data(data)
        assert any("removal_rate" in e for e in errors)

    def test_invalid_evidence_level(self):
        data = {"evidence_level": "super_high"}
        errors = validate_performance_data(data)
        assert any("evidence_level" in e for e in errors)

    def test_valid_applicability(self):
        data = {"ph_range": "3-8", "temperature_range": "25-45°C"}
        errors = validate_applicability(data)
        assert errors == []

    def test_ph_out_of_range(self):
        data = {"ph_optimal": 15}
        errors = validate_applicability(data)
        assert any("ph" in e.lower() for e in errors)

    def test_valid_weights(self):
        weights = [{"weight": 0.85, "reasoning_score": 0.9, "literature_score": 0.7, "evidence_score": 0.8}]
        errors = validate_weights(weights)
        assert errors == []

    def test_weight_out_of_range(self):
        weights = [{"weight": 1.5}]
        errors = validate_weights(weights)
        assert len(errors) > 0
