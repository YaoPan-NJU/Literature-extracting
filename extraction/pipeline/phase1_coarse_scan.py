# extraction/pipeline/phase1_coarse_scan.py
"""Phase 1: Coarse Scan - lightweight extraction from all papers.

Produces: coarse-profiles/<prototype_id>.json + coverage-heatmap.md
"""

import json
from pathlib import Path
from collections import defaultdict

from config import LITERATURE_DIR, OUTPUT_DIR, PAPER_GROUPS
from filename_parser import parse_filename
from pdf_utils import extract_first_page_text
from prototype_mapper import PrototypeMapper
from llm_client import LLMClient
from jinja2 import Environment, FileSystemLoader

_env = Environment(loader=FileSystemLoader(str(Path(__file__).parent.parent / "prompts")))
_coarse_prompt = _env.get_template("coarse_extract.j2")


def scan_literature_library(literature_dir: Path = None) -> dict:
    """Walk the literature directory and parse all paper filenames."""
    literature_dir = literature_dir or LITERATURE_DIR
    papers_dir = literature_dir / "论文"
    mapper_result = defaultdict(list)

    if not papers_dir.exists():
        return mapper_result

    for group_dir in sorted(papers_dir.iterdir()):
        if not group_dir.is_dir():
            continue
        group_key = None
        for cn_name, en_name in PAPER_GROUPS.items():
            if cn_name in group_dir.name:
                group_key = en_name
                break
        if group_key is None:
            continue

        for pdf_path in sorted(group_dir.glob("*.pdf")):
            meta = parse_filename(pdf_path.name)
            mapper_result[group_key].append((pdf_path, meta))

    return dict(mapper_result)


def map_papers_to_prototypes(papers_by_group: dict) -> dict:
    """Map all papers to prototypes."""
    mapper = PrototypeMapper()
    prototype_papers = defaultdict(list)

    for group_key, papers in papers_by_group.items():
        for pdf_path, meta in papers:
            mappings = mapper.map_paper(meta, group=group_key)
            for m in mappings:
                prototype_papers[m["prototype_id"]].append({
                    "path": str(pdf_path),
                    "filename": pdf_path.name,
                    "year": meta.year,
                    "author": meta.author,
                    "keywords": meta.keywords,
                    "is_review": meta.is_review,
                    "association": m["association"],
                    "matched_keywords": m["matched_keywords"],
                    "group": group_key,
                })

    return dict(prototype_papers)


def extract_coarse_profile(prototype_id: str, papers: list[dict], llm: LLMClient) -> dict:
    """Extract a coarse profile for one prototype from its associated papers."""
    profile = {
        "prototype_id": prototype_id,
        "paper_count": len(papers),
        "direct_papers": [p for p in papers if p["association"] == "direct"],
        "indirect_papers": [p for p in papers if p["association"] == "indirect"],
        "extracted_fields": [],
        "coverage": {"pollutants": set(), "mechanisms": set(), "materials": set()},
    }

    priority_papers = sorted(
        papers,
        key=lambda p: (0 if p["association"] == "direct" else 1, 0 if p["is_review"] else 1),
    )[:5]

    for paper in priority_papers:
        pdf_path = Path(paper["path"])
        first_page = extract_first_page_text(pdf_path)
        if not first_page or len(first_page.strip()) < 50:
            continue

        prompt = _coarse_prompt.render(
            filename_info=f"{paper['year']}-{paper['author']}-{'-'.join(paper['keywords'])}",
            abstract_text=first_page[:3000],
        )

        try:
            result = llm.chat_json(prompt)
            result["_source_paper"] = paper["filename"]
            profile["extracted_fields"].append(result)

            if result.get("target_pollutants"):
                profile["coverage"]["pollutants"].update(result["target_pollutants"])
            if result.get("adsorption_mechanisms"):
                profile["coverage"]["mechanisms"].update(result["adsorption_mechanisms"])
            if result.get("material_type"):
                profile["coverage"]["materials"].add(result["material_type"])
        except Exception as e:
            profile["extracted_fields"].append({"_source_paper": paper["filename"], "_error": str(e)})

    profile["coverage"] = {k: sorted(v) for k, v in profile["coverage"].items()}
    return profile


def run_phase1(literature_dir: Path = None, output_dir: Path = None) -> None:
    """Execute Phase 1: Coarse Scan."""
    output_dir = output_dir or OUTPUT_DIR
    profiles_dir = output_dir / "coarse-profiles"
    profiles_dir.mkdir(parents=True, exist_ok=True)

    print("Phase 1: Scanning literature library...")
    papers_by_group = scan_literature_library(literature_dir)
    total_papers = sum(len(v) for v in papers_by_group.values())
    print(f"  Found {total_papers} papers in {len(papers_by_group)} groups")

    print("Phase 1: Mapping papers to prototypes...")
    prototype_papers = map_papers_to_prototypes(papers_by_group)
    print(f"  Mapped to {len(prototype_papers)} prototypes")

    print("Phase 1: Extracting coarse profiles...")
    llm = LLMClient.from_task_type("coarse_scan")

    coverage_summary = {}
    for prototype_id, papers in sorted(prototype_papers.items()):
        print(f"  Processing {prototype_id} ({len(papers)} papers)...")
        profile = extract_coarse_profile(prototype_id, papers, llm)

        profile_path = profiles_dir / f"{prototype_id}.json"
        with open(profile_path, "w", encoding="utf-8") as f:
            json.dump(profile, f, ensure_ascii=False, indent=2)

        coverage_summary[prototype_id] = {
            "total_papers": profile["paper_count"],
            "direct_papers": len(profile["direct_papers"]),
            "indirect_papers": len(profile["indirect_papers"]),
            "pollutants": profile["coverage"]["pollutants"],
            "mechanisms": profile["coverage"]["mechanisms"],
        }

    heatmap_path = profiles_dir / "coverage-heatmap.md"
    _write_coverage_heatmap(coverage_summary, heatmap_path)
    print(f"Phase 1 complete. Output written to {profiles_dir}")


def _write_coverage_heatmap(summary: dict, output_path: Path) -> None:
    lines = ["## Coverage Heatmap (Phase 1 Coarse Scan)\n"]
    lines.append("| Prototype | Total Papers | Direct | Pollutants | Mechanisms |")
    lines.append("|-----------|-------------|--------|------------|------------|")

    for proto_id, data in sorted(summary.items()):
        pollutants = ", ".join(data["pollutants"][:5])
        if len(data["pollutants"]) > 5:
            pollutants += f" (+{len(data['pollutants']) - 5})"
        mechanisms = ", ".join(data["mechanisms"][:3])
        if len(data["mechanisms"]) > 3:
            mechanisms += f" (+{len(data['mechanisms']) - 3})"
        lines.append(f"| {proto_id} | {data['total_papers']} | {data['direct_papers']} | {pollutants} | {mechanisms} |")

    output_path.write_text("\n".join(lines), encoding="utf-8")
