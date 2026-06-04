# extraction/validators.py
"""Automated quality checks for extraction results."""

from __future__ import annotations

VALID_EVIDENCE_LEVELS = {"high", "medium", "low"}


def validate_performance_data(data: dict) -> list[str]:
    errors = []
    if "qmax" in data and data["qmax"] is not None:
        try:
            val = float(data["qmax"])
            if val < 0:
                errors.append(f"qmax must be non-negative, got {val}")
            if val > 10000:
                errors.append(f"qmax suspiciously high: {val} mg/g")
        except (TypeError, ValueError):
            errors.append(f"qmax must be numeric, got {data['qmax']}")
    if "removal_rate" in data and data["removal_rate"] is not None:
        try:
            val = float(data["removal_rate"])
            if val < 0 or val > 100:
                errors.append(f"removal_rate must be 0-100%, got {val}")
        except (TypeError, ValueError):
            errors.append(f"removal_rate must be numeric, got {data['removal_rate']}")
    if "evidence_level" in data and data["evidence_level"] is not None:
        if data["evidence_level"] not in VALID_EVIDENCE_LEVELS:
            errors.append(f"evidence_level must be one of {VALID_EVIDENCE_LEVELS}, got '{data['evidence_level']}'")
    return errors


def validate_applicability(data: dict) -> list[str]:
    errors = []
    for ph_field in ["ph_optimal", "ph_min", "ph_max"]:
        if ph_field in data and data[ph_field] is not None:
            try:
                val = float(data[ph_field])
                if val < 0 or val > 14:
                    errors.append(f"{ph_field} must be 0-14, got {val}")
            except (TypeError, ValueError):
                errors.append(f"{ph_field} must be numeric, got {data[ph_field]}")
    return errors


def validate_weights(weights: list[dict]) -> list[str]:
    errors = []
    for i, w in enumerate(weights):
        prefix = f"weight[{i}]"
        if "weight" in w:
            val = w["weight"]
            if not isinstance(val, (int, float)) or val < 0 or val > 1:
                errors.append(f"{prefix}.weight must be 0-1, got {val}")
        for score_field in ["reasoning_score", "literature_score", "evidence_score"]:
            if score_field in w:
                val = w[score_field]
                if not isinstance(val, (int, float)) or val < 0 or val > 1:
                    errors.append(f"{prefix}.{score_field} must be 0-1, got {val}")
    return errors
