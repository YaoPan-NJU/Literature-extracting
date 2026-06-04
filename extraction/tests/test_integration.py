# extraction/tests/test_integration.py
"""Integration smoke test."""

import json
from pathlib import Path
import pytest

from filename_parser import parse_filename
from prototype_mapper import PrototypeMapper
from validators import validate_performance_data, validate_weights
from writer import generate_prototype_md


class TestIntegration:
    def test_end_to_end_filename_to_prototype(self):
        meta = parse_filename("2022-Eltaweil-alginate-bone-magnetic-adsorption-review.pdf")
        mapper = PrototypeMapper()
        results = mapper.map_paper(meta, group="coordination_chelation")
        assert len(results) > 0
        proto_ids = [r["prototype_id"] for r in results]
        assert "alginate-adsorbent" in proto_ids

    def test_generate_prototype_md_produces_valid_output(self):
        content = generate_prototype_md(
            prototype_id="mussel-foot-adhesion",
            performance={
                "qmax": {"value": 250, "pollutant": "Pb2+"},
                "removal_rate": {"value": 98},
                "mechanisms_identified": ["coordination chelation", "electrostatic adsorption"],
                "evidence_level": "high",
                "material_characterization": {"surface_area": "45 m2/g", "pore_size": "3.5 nm"},
            },
            narrative={
                "problem_definition": {"nature_challenge": "Mussels adhere to wet surfaces", "water_treatment_mapping": "Wet adhesion enables coating"},
                "biological_solution": {"evolutionary_strategy": "Catechol-rich adhesive proteins"},
                "key_feature_extraction": {"must_keep_features": ["catechol groups"], "adjustable_features": ["polymer backbone"]},
                "design_mapping": {"bio_to_material": "Dopamine as catechol analogue"},
                "explainability_anchors": {"one_line_story": "Inspired by mussel foot proteins"},
            },
            applicability={"ph_range": "4-9", "temperature_range": "20-40°C"},
        )
        assert "---" in content
        assert "mussel-foot-adhesion" in content
        assert "Biomimetic Design Narrative" in content

    def test_validators_catch_bad_data(self):
        perf_errors = validate_performance_data({"qmax": -5, "removal_rate": 150})
        assert len(perf_errors) == 2
        weight_errors = validate_weights([{"weight": 2.0}])
        assert len(weight_errors) == 1
