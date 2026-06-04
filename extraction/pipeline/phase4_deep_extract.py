# extraction/pipeline/phase4_deep_extract.py
"""Phase 4: Deep Extraction - full extraction + weight assignment.

Produces: prototypes/<id>/prototype.md + updated feature-mapping.json
"""

import json
from pathlib import Path

from config import OUTPUT_DIR, PROJECT_DIR
from llm_client import LLMClient
from pdf_utils import extract_full_text
from validators import validate_performance_data, validate_weights
from writer import generate_prototype_md, write_prototype_file, update_feature_mapping
from jinja2 import Environment, FileSystemLoader

_env = Environment(loader=FileSystemLoader(str(Path(__file__).parent.parent / "prompts")))
_perf_prompt = _env.get_template("deep_performance.j2")
_narr_prompt = _env.get_template("biomimetic_narrative.j2")
_weight_prompt = _env.get_template("weight_assign.j2")


def extract_performance(prototype_id: str, paper_paths: list[str], llm: LLMClient) -> dict:
    all_results = []
    for path_str in paper_paths:
        full_text = extract_full_text(Path(path_str))
        if not full_text or len(full_text.strip()) < 200:
            continue
        prompt = _perf_prompt.render(paper_meta=Path(path_str).stem, prototype_id=prototype_id, full_text=full_text[:8000])
        try:
            result = llm.chat_json(prompt)
            all_results.append(result)
        except Exception as e:
            all_results.append({"_error": str(e), "_source": path_str})

    merged = {"_source_count": len(all_results), "_sources": [r for r in all_results if "_error" not in r]}
    if merged["_sources"]:
        best_qmax = max((s.get("performance_data", {}).get("qmax", {}) for s in merged["_sources"]), key=lambda x: float(x.get("value", 0) or 0), default={})
        merged["qmax"] = best_qmax
        all_mechanisms = set()
        for s in merged["_sources"]:
            m = s.get("mechanisms_identified", [])
            if m:
                all_mechanisms.update(m)
        merged["mechanisms_identified"] = list(all_mechanisms)
        for s in merged["_sources"]:
            if s.get("applicability"):
                merged.setdefault("applicability", {}).update(s["applicability"])
            if s.get("material_characterization"):
                merged.setdefault("material_characterization", {}).update(s["material_characterization"])
    return merged


def extract_narrative(prototype_id: str, paper_paths: list[str], llm: LLMClient) -> dict:
    all_results = []
    for path_str in paper_paths:
        full_text = extract_full_text(Path(path_str))
        if not full_text or len(full_text.strip()) < 200:
            continue
        prompt = _narr_prompt.render(paper_meta=Path(path_str).stem, prototype_id=prototype_id, prototype_name=prototype_id.replace("-", " ").title(), full_text=full_text[:8000])
        try:
            result = llm.chat_json(prompt, max_tokens=8192)
            all_results.append(result)
        except Exception as e:
            all_results.append({"_error": str(e)})

    merged = {}
    for key in ["problem_definition", "biological_solution", "key_feature_extraction", "design_mapping", "explainability_anchors", "engineering_constraints"]:
        for r in all_results:
            if key in r and r[key]:
                merged[key] = r[key]
                break
    return merged


def assign_weights(prototype_id: str, coarse_profile: dict, extraction_results: list[dict], mapping_entries: list[dict], llm: LLMClient) -> list[dict]:
    prompt = _weight_prompt.render(
        prototype_id=prototype_id, prototype_name=prototype_id.replace("-", " ").title(),
        coarse_profile_json=json.dumps(coarse_profile, ensure_ascii=False, indent=2)[:3000],
        extraction_results_json=json.dumps(extraction_results, ensure_ascii=False, indent=2)[:3000],
        mapping_entries_json=json.dumps(mapping_entries, ensure_ascii=False, indent=2)[:3000],
    )
    try:
        result = llm.chat_json(prompt, max_tokens=8192)
        return result.get("weight_assignments", [])
    except Exception as e:
        return [{"_error": str(e)}]


def run_phase4(output_dir: Path = None, project_dir: Path = None) -> None:
    """Execute Phase 4: Deep Extraction."""
    output_dir = output_dir or OUTPUT_DIR
    project_dir = project_dir or PROJECT_DIR
    profiles_dir = output_dir / "coarse-profiles"

    perf_llm = LLMClient.from_task_type("performance_extract")
    narr_llm = LLMClient.from_task_type("biomimetic_extract")
    weight_llm = LLMClient.from_task_type("weight_assign")

    print("Phase 4: Deep extraction...")

    for profile_path in sorted(profiles_dir.glob("*.json")):
        if profile_path.name == "coverage-heatmap.md":
            continue
        with open(profile_path, encoding="utf-8") as f:
            coarse_profile = json.load(f)

        prototype_id = coarse_profile["prototype_id"]
        print(f"  Processing {prototype_id}...")

        paper_paths = [p["path"] for p in coarse_profile.get("direct_papers", []) + coarse_profile.get("indirect_papers", [])[:5]]

        print(f"    Extracting performance data from {len(paper_paths)} papers...")
        performance = extract_performance(prototype_id, paper_paths, perf_llm)

        supplement_dir = Path(output_dir) / "supplemented-papers" / prototype_id
        supplement_paths = [str(p) for p in supplement_dir.glob("*.pdf")] if supplement_dir.exists() else []
        narrative = {}
        if supplement_paths:
            print(f"    Extracting biomimetic narrative from {len(supplement_paths)} supplemented papers...")
            narrative = extract_narrative(prototype_id, supplement_paths, narr_llm)

        mapping_path = project_dir / "feature-mapping.json"
        with open(mapping_path, encoding="utf-8") as f:
            full_mapping = json.load(f)
        relevant_entries = [{"section": s, "entries": full_mapping.get(s, {})} for s in ["pollutant_prototype_map", "feature_prototype_map"]]

        print(f"    Assigning weights...")
        extraction_results = [performance] + ([narrative] if narrative else [])
        weight_assignments = assign_weights(prototype_id, coarse_profile, extraction_results, relevant_entries, weight_llm)

        perf_errors = validate_performance_data(performance)
        weight_errors = validate_weights(weight_assignments)
        all_errors = perf_errors + weight_errors
        if all_errors:
            print(f"    WARNING: {len(all_errors)} validation errors for {prototype_id}")

        applicability = performance.get("applicability", {})
        content = generate_prototype_md(prototype_id, performance, narrative, applicability)
        out_path = write_prototype_file(prototype_id, content, project_dir)
        print(f"    Written {out_path}")

        if weight_assignments and not any("_error" in wa for wa in weight_assignments):
            update_feature_mapping(prototype_id, weight_assignments, project_dir)
            print(f"    Updated feature-mapping.json weights for {prototype_id}")

    print("Phase 4 complete.")
