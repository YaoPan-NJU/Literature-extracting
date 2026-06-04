# extraction/pipeline/phase3_supplement_plan.py
"""Phase 3: Generate targeted literature search queries.

Produces: gap-analysis/search-queries.md
"""

import json
from pathlib import Path
from collections import defaultdict

from config import OUTPUT_DIR

SEARCH_TEMPLATES = {
    "knowledge_gap": {
        "wos_en": 'TS=("biomimetic design" OR "bio-inspired" OR "nature-inspired") AND TS=("{prototype_keyword}") AND TS=("{mechanism}")',
        "wos_cn": '主题=("仿生设计" OR "仿生" OR "仿自然") AND 主题=("{prototype_cn}") AND 主题=("{mechanism_cn}")',
        "scholar": 'biomimetic design "{prototype_keyword}" "{mechanism}" water treatment adsorption',
    },
    "weight_gap": {
        "wos_en": 'TS=("biomimetic" OR "bio-inspired") AND TS=("adsorption" OR "water treatment") AND TS=("review" OR "comparative" OR "meta-analysis")',
        "scholar": 'biomimetic adsorption water treatment comparative review comprehensive',
    },
    "methodology_gap": {
        "wos_en": 'TS=("biomimetics" OR "biomimicry") AND TS=("standard" OR "framework" OR "methodology" OR "design guideline")',
        "scholar": 'biomimetics standard framework methodology ISO VDI design guideline',
    },
}

PROTOTYPE_NAMES = {
    "lotus-leaf": {"en": "lotus leaf", "cn": "荷叶"},
    "mussel-foot-adhesion": {"en": "mussel foot adhesion", "cn": "贻贝足粘附"},
    "polydopamine-coating": {"en": "polydopamine coating", "cn": "聚多巴胺涂层"},
    "diatom-microspheres": {"en": "diatom microspheres", "cn": "硅藻微球"},
    "sulfate-reducing-bacteria": {"en": "sulfate reducing bacteria", "cn": "硫酸盐还原菌"},
    "chitosan-adsorbent": {"en": "chitosan adsorbent", "cn": "壳聚糖吸附剂"},
    "mof-adsorbent": {"en": "MOF adsorbent", "cn": "MOF吸附剂"},
    "alginate-adsorbent": {"en": "alginate adsorbent", "cn": "海藻酸钠吸附剂"},
    "cellulose-adsorbent": {"en": "cellulose adsorbent", "cn": "纤维素吸附剂"},
    "biochar-adsorbent": {"en": "biochar adsorbent", "cn": "生物炭吸附剂"},
    "superhydrophobic-surface": {"en": "superhydrophobic surface", "cn": "超疏水表面"},
    "oyster-shell": {"en": "oyster shell", "cn": "牡蛎壳"},
    "mycelium": {"en": "mycelium", "cn": "菌丝"},
    "chlorella": {"en": "chlorella", "cn": "小球藻"},
    "mangrove": {"en": "mangrove", "cn": "红树林"},
}


def get_prototype_name(prototype_id: str) -> dict:
    return PROTOTYPE_NAMES.get(prototype_id, {"en": prototype_id.replace("-", " "), "cn": prototype_id.replace("-", " ")})


def generate_search_queries(gap_reports_dir: Path) -> dict:
    queries = defaultdict(list)
    for report_path in sorted(gap_reports_dir.glob("*.json")):
        with open(report_path, encoding="utf-8") as f:
            report = json.load(f)
        prototype_id = report["prototype_id"]
        name = get_prototype_name(prototype_id)
        for gap in report["gaps"]:
            gap_type = gap["gap_type"]
            if gap_type == "knowledge_gap" and gap["category"] == "biomimetic_narrative":
                t = SEARCH_TEMPLATES["knowledge_gap"]
                queries["第10组-仿生设计综述"].append({
                    "prototype_id": prototype_id, "field": gap["field"],
                    "wos_en": t["wos_en"].format(prototype_keyword=name["en"], mechanism=gap["field"].replace("_", " ")),
                    "wos_cn": t["wos_cn"].format(prototype_cn=name["cn"], mechanism_cn=gap["field"].replace("_", " ")),
                    "scholar": t["scholar"].format(prototype_keyword=name["en"], mechanism=gap["field"].replace("_", " ")),
                })
            elif gap_type == "weight_gap":
                t = SEARCH_TEMPLATES["weight_gap"]
                queries["第11组-跨原型比较"].append({"prototype_id": prototype_id, "field": gap["field"], "wos_en": t["wos_en"], "scholar": t["scholar"]})
            elif gap_type == "knowledge_gap" and gap["category"] == "engineering_constraints":
                queries["第10组-仿生设计综述"].append({
                    "prototype_id": prototype_id, "field": gap["field"],
                    "wos_en": f'TS=("biomimetic" OR "bio-inspired") AND TS=("{gap["field"].replace("_", " ")}") AND TS=("adsorbent" OR "water treatment")',
                    "scholar": f'biomimetic "{gap["field"].replace("_", " ")}" adsorbent water treatment',
                })

    t = SEARCH_TEMPLATES["methodology_gap"]
    queries["第9组-仿生方法论"].append({"prototype_id": "global", "field": "methodology", "wos_en": t["wos_en"], "scholar": t["scholar"]})
    return dict(queries)


def run_phase3(output_dir: Path = None) -> None:
    """Execute Phase 3: Generate supplementation plan with search queries."""
    output_dir = output_dir or OUTPUT_DIR
    gap_reports_dir = output_dir / "gap-analysis" / "gap-reports"

    print("Phase 3: Generating search queries from gap reports...")
    queries = generate_search_queries(gap_reports_dir)

    query_path = output_dir / "gap-analysis" / "search-queries.md"
    lines = ["## Literature Search Queries (Phase 3 Output)\n"]
    lines.append("Based on gap analysis, the following search queries are recommended.\n")

    total_queries = 0
    for group_name, group_queries in sorted(queries.items()):
        lines.append(f"### {group_name} ({len(group_queries)} queries)\n")
        for i, q in enumerate(group_queries, 1):
            total_queries += 1
            lines.append(f"**Query {i}** - {q['prototype_id']}.{q['field']}")
            lines.append(f"- WoS (EN): `{q.get('wos_en', 'N/A')}`")
            if "wos_cn" in q:
                lines.append(f"- CNKI: `{q['wos_cn']}`")
            lines.append(f"- Google Scholar: `{q.get('scholar', 'N/A')}`")
            lines.append("")

    lines.append(f"\n**Total queries: {total_queries}**")
    lines.append("\n### Screening Criteria\n")
    lines.append("- Prioritize papers with complete biomimetic design logic chain")
    lines.append("- Prioritize papers discussing feature extraction or design mapping")
    lines.append("- Prioritize cross-prototype comparative studies")
    lines.append("- Reviews preferred but high-quality case studies also valuable")
    lines.append("- Recent 5 years preferred, seminal works excepted")

    query_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Phase 3 complete. {total_queries} search queries written to {query_path}")
