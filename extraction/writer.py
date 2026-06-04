# extraction/writer.py
"""Write extraction results to prototype.md and feature-mapping.json."""

import json
from pathlib import Path
from datetime import date

from config import PROJECT_DIR


def generate_prototype_md(prototype_id: str, performance: dict, narrative: dict, applicability: dict) -> str:
    fm_fields = {
        "id": prototype_id,
        "name": prototype_id.replace("-", " ").title(),
        "category": "biomimetic_adsorbent",
        "features": performance.get("mechanisms_identified", []),
        "pollutants": performance.get("target_pollutants", []),
        "adsorption_mechanisms": performance.get("mechanisms_identified", []),
        "qmax_range": performance.get("qmax", {}).get("value") if isinstance(performance.get("qmax"), dict) else performance.get("qmax"),
        "removal_rate": performance.get("removal_rate", {}).get("value") if isinstance(performance.get("removal_rate"), dict) else performance.get("removal_rate"),
        "applicability": {
            "ph": applicability.get("ph_range"),
            "temperature": applicability.get("temperature_range"),
            "salinity": applicability.get("salinity_tolerance"),
        },
        "evidence_level": performance.get("evidence_level", "medium"),
        "last_updated": str(date.today()),
    }

    yaml_lines = ["---"]
    for key, value in fm_fields.items():
        if isinstance(value, dict):
            yaml_lines.append(f"{key}:")
            for k, v in value.items():
                yaml_lines.append(f"  {k}: {json.dumps(v, ensure_ascii=False) if v is not None else 'null'}")
        elif isinstance(value, list):
            yaml_lines.append(f"{key}:")
            for item in value:
                yaml_lines.append(f"  - {item}")
        else:
            yaml_lines.append(f"{key}: {json.dumps(value, ensure_ascii=False) if value is not None else 'null'}")
    yaml_lines.append("---")

    body_lines = [
        f"\n# {prototype_id.replace('-', ' ').title()}\n",
        "## 1. Biological Prototype Introduction\n",
        narrative.get("problem_definition", {}).get("nature_challenge", "[待补充：生物原型介绍]"),
        "\n## 2. Adsorption Mechanism Details\n",
        "Mechanisms: " + ", ".join(performance.get("mechanisms_identified", ["[待补充]"])),
        "\n## 3. Structural Features\n",
        "Surface area: " + str(performance.get("material_characterization", {}).get("surface_area", "[待补充]")),
        "Pore size: " + str(performance.get("material_characterization", {}).get("pore_size", "[待补充]")),
        "\n## 4. Reported Performance Data\n",
        f"qmax: {_get_val(performance, 'qmax')} mg/g",
        f"Removal rate: {_get_val(performance, 'removal_rate')}%",
        f"Evidence level: {performance.get('evidence_level', '[待补充]')}",
        "\n## 5. Biomimetic Design Narrative\n",
        "### 5.1 Problem Definition\n",
        narrative.get("problem_definition", {}).get("water_treatment_mapping", "[待补充]"),
        "\n### 5.2 Biological Solution\n",
        narrative.get("biological_solution", {}).get("evolutionary_strategy", "[待补充]"),
        "\n### 5.3 Key Feature Extraction\n",
        "Must-keep: " + json.dumps(narrative.get("key_feature_extraction", {}).get("must_keep_features", []), ensure_ascii=False),
        "Adjustable: " + json.dumps(narrative.get("key_feature_extraction", {}).get("adjustable_features", []), ensure_ascii=False),
        "\n### 5.4 Design Mapping\n",
        narrative.get("design_mapping", {}).get("bio_to_material", "[待补充]"),
        "\n### 5.5 Explainability Anchors\n",
        narrative.get("explainability_anchors", {}).get("one_line_story", "[待补充]"),
        "\n## 6. Applicable Scenarios\n\n[待补充]",
        "\n## 7. Related Prototypes\n\n[待补充]",
        "\n## 8. References\n\n[待补充]",
    ]

    return "\n".join(yaml_lines) + "\n".join(body_lines)


def _get_val(data: dict, key: str) -> str:
    val = data.get(key)
    if isinstance(val, dict):
        return str(val.get("value", "[待补充]"))
    return str(val) if val is not None else "[待补充]"


def write_prototype_file(prototype_id: str, content: str, project_dir: Path = None) -> Path:
    project_dir = project_dir or PROJECT_DIR
    proto_dir = project_dir / "prototypes" / prototype_id
    proto_dir.mkdir(parents=True, exist_ok=True)
    output_path = proto_dir / "prototype.md"
    output_path.write_text(content, encoding="utf-8")
    return output_path


def update_feature_mapping(prototype_id: str, weight_assignments: list[dict], project_dir: Path = None) -> None:
    project_dir = project_dir or PROJECT_DIR
    mapping_path = project_dir / "feature-mapping.json"

    with open(mapping_path, encoding="utf-8") as f:
        mapping = json.load(f)

    for wa in weight_assignments:
        mapping_type = wa.get("mapping_type")
        entry_key = wa.get("entry_key")
        weight = wa.get("weight")

        if mapping_type == "pollutant_prototype_map":
            section = mapping.get("pollutant_prototype_map", {})
            if entry_key in section:
                _update_entries(section[entry_key], prototype_id, wa, weight)

        elif mapping_type == "feature_prototype_map":
            section = mapping.get("feature_prototype_map", {})
            if entry_key in section:
                _update_feature_entries(section[entry_key], prototype_id, wa, weight)

    with open(mapping_path, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=2)


def _update_entries(entries, prototype_id, wa, weight):
    if isinstance(entries, dict):
        for sub_key, sub_entries in entries.items():
            if isinstance(sub_entries, list):
                for entry in sub_entries:
                    if isinstance(entry, dict) and entry.get("id") == prototype_id:
                        entry["weight"] = weight
                        if wa.get("mechanism_summary"):
                            entry["mechanism_summary"] = wa["mechanism_summary"]
                        if wa.get("design_hint"):
                            entry["design_hint"] = wa["design_hint"]
    elif isinstance(entries, list):
        for entry in entries:
            if isinstance(entry, dict) and entry.get("id") == prototype_id:
                entry["weight"] = weight


def _update_feature_entries(entries, prototype_id, wa, weight):
    if isinstance(entries, list):
        for entry in entries:
            if isinstance(entry, dict) and entry.get("id") == prototype_id:
                entry["weight"] = weight
