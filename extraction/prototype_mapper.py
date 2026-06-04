# extraction/prototype_mapper.py
"""Map papers to prototypes via filename keywords and mechanism group fallback."""

from __future__ import annotations

from dataclasses import dataclass
from filename_parser import PaperMeta

PROTOTYPE_KEYWORDS: dict[str, set[str]] = {
    "lotus-leaf": {"lotus", "莲", "荷叶", "乳突", "papilla", "superhydrophobic surface", "cassie"},
    "mussel-foot-adhesion": {"mussel", "贻贝", "足丝", "adhesion", "粘附", "catechol", "儿茶酚", "dopamine", "多巴胺"},
    "polydopamine-coating": {"polydopamine", "PDA", "聚多巴胺", "dopamine coating"},
    "oyster-shell": {"oyster", "牡蛎", "牡蛎壳", "oyster shell"},
    "scallop-shell": {"scallop", "扇贝", "扇贝壳"},
    "diatom-microspheres": {"diatom", "硅藻", "diatomite", "硅藻土"},
    "sulfate-reducing-bacteria": {"sulfate-reducing", "硫酸盐还原菌", "SRB"},
    "magnetic-bacteria": {"magnetic bacteria", "磁性细菌", "magnetotactic"},
    "iron-oxidizing-bacteria": {"iron-oxidizing", "铁氧化菌", "Gallionella"},
    "mycelium": {"mycelium", "菌丝", "fungal", "真菌"},
    "chlorella": {"chlorella", "小球藻", "microalgae", "微藻"},
    "mangrove": {"mangrove", "红树林"},
    "wood-structure": {"wood", "木材", "cellulose framework"},
    "cactus-spine": {"cactus", "仙人掌"},
    "spider-silk": {"spider", "蜘蛛", "spider silk", "蛛丝"},
    "silkworm-silk": {"silkworm", "蚕", "silk fibroin", "丝素", "丝素蛋白"},
    "shark-skin": {"shark", "鲨鱼"},
    "fish-scale": {"fish scale", "鱼鳞"},
    "water-strider": {"water strider", "水黾"},
    "namib-beetle": {"namib", "纳米布甲虫", "fog collection"},
    "lobster-shell": {"lobster", "龙虾", "crustacean"},
    "chitosan-adsorbent": {"chitosan", "壳聚糖"},
    "alginate-adsorbent": {"alginate", "海藻酸钠", "海藻酸"},
    "cellulose-adsorbent": {"cellulose", "纤维素", "nanocellulose", "纳米纤维素"},
    "starch-adsorbent": {"starch", "淀粉"},
    "mof-adsorbent": {"MOF", "金属有机框架", "metal-organic framework"},
    "biochar-adsorbent": {"biochar", "生物炭"},
    "hydroxyapatite-adsorbent": {"hydroxyapatite", "羟基磷灰石", "HAP"},
    "superhydrophobic-surface": {"superhydrophobic", "超疏水"},
    "slips-surface": {"SLIPS", "slippery", "润滑注入"},
    "molecularly-imprinted-polymer": {"molecularly imprinted", "分子印迹", "MIP"},
    "dna-aptamer": {"aptamer", "适配体", "DNA aptamer"},
    "biomineralization-template": {"biomineralization", "生物矿化", "生物沉淀"},
}

MECHANISM_GROUP_PROTOTYPES: dict[str, list[str]] = {
    "coordination_chelation": [
        "chitosan-adsorbent", "alginate-adsorbent", "cellulose-adsorbent",
        "mussel-foot-adhesion", "polydopamine-coating", "starch-adsorbent",
    ],
    "superhydrophobic": [
        "lotus-leaf", "superhydrophobic-surface", "slips-surface",
        "shark-skin", "namib-beetle", "water-strider",
    ],
    "porous_structure": [
        "diatom-microspheres", "wood-structure", "mof-adsorbent",
        "biochar-adsorbent", "hydroxyapatite-adsorbent",
    ],
    "biomineralization": [
        "biomineralization-template", "oyster-shell", "scallop-shell",
        "sulfate-reducing-bacteria", "hydroxyapatite-adsorbent",
    ],
    "fiber_structure": [
        "cellulose-adsorbent", "silkworm-silk", "spider-silk",
        "mycelium", "wood-structure",
    ],
    "functional_biomimetics": [
        "magnetic-bacteria", "molecularly-imprinted-polymer",
        "dna-aptamer", "superhydrophobic-surface",
    ],
    "system_biomimetics": [
        "chlorella", "mangrove", "sulfate-reducing-bacteria",
        "iron-oxidizing-bacteria",
    ],
    "biomimetic_materials": [
        "mof-adsorbent", "starch-adsorbent", "polydopamine-coating",
        "chitosan-adsorbent", "cellulose-adsorbent",
    ],
    "global_review": [],
}


def load_prototype_keywords() -> dict[str, set[str]]:
    return {k: {w.lower() for w in v} for k, v in PROTOTYPE_KEYWORDS.items()}


class PrototypeMapper:
    def __init__(self):
        self.keywords = load_prototype_keywords()

    def map_paper(self, meta: PaperMeta, group: str) -> list[dict]:
        results = []
        paper_keywords_lower = {kw.lower() for kw in meta.keywords}

        for prototype_id, proto_keywords in self.keywords.items():
            matched = paper_keywords_lower & proto_keywords
            if matched:
                results.append({
                    "prototype_id": prototype_id,
                    "association": "direct",
                    "matched_keywords": list(matched),
                })

        if not results and group in MECHANISM_GROUP_PROTOTYPES:
            for prototype_id in MECHANISM_GROUP_PROTOTYPES[group]:
                results.append({
                    "prototype_id": prototype_id,
                    "association": "indirect",
                    "matched_keywords": [],
                })

        return results
