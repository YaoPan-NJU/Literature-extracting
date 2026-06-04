# Biomimetic Extraction Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Literature-extracting project from PFAS pollutant extraction to biomimetic water-treatment adsorbent design knowledge extraction, producing structured data that directly populates the Biomimetic-design-library.

**Architecture:** Replace the existing schema/prompt/config files with biomimetic-focused equivalents, add 3 new Python scripts (map_to_prototypes, generate_prototype_md, update_feature_mapping) that post-process OpenClaw extraction results into prototype.md files and feature-mapping.json weight updates, and wrap everything in a unified pipeline shell script. All new Python code gets pytest coverage.

**Tech Stack:** Python 3.9+, JSON Schema Draft 2020-12, Bash, OpenClaw Gateway, pytest

---

## File Structure

```
Literature-extracting/                          (on biomimetic-extraction branch)
├── schema/
│   ├── jjj_literature_extraction.schema.json   # KEEP (original, unchanged)
│   └── biomimetic_extraction.schema.json       # CREATE: new schema (Task 2)
├── prompts/
│   ├── jjj_single_agent_extraction_prompt.md   # KEEP (original, unchanged)
│   └── biomimetic_extraction_prompt.md         # CREATE: new prompt (Task 3)
├── config/
│   ├── vocabulary_mapping.json                 # CREATE: standard term mapping (Task 4)
│   └── prototype_routing.json                  # CREATE: prototype keyword routing (Task 5)
├── scripts/
│   ├── (existing scripts unchanged)
│   ├── map_to_prototypes.py                    # CREATE: route + aggregate (Task 6)
│   ├── generate_prototype_md.py                # CREATE: write prototype.md (Task 7)
│   ├── update_feature_mapping.py               # CREATE: update weights (Task 8)
│   └── biomimetic_pipeline.sh                  # CREATE: end-to-end entry (Task 9)
├── tests/
│   ├── conftest.py                             # CREATE: shared fixtures (Task 1)
│   ├── test_schema.py                          # CREATE (Task 2)
│   ├── test_map_to_prototypes.py               # CREATE (Task 6)
│   ├── test_generate_prototype_md.py           # CREATE (Task 7)
│   └── test_update_feature_mapping.py          # CREATE (Task 8)
├── openclaw.json                               # MODIFY: add biomimetic agent (Task 10)
└── docs/
    └── superpowers/plans/
        └── this file
```

## External Data Dependencies

The scripts need read/write access to the Biomimetic-design-library. Set via environment variable:

```bash
BIOMIMETIC_LIB=/Users/panyao/.qoderworkcn/workspace/mpzh27rt8uc58fyx/Biomimetic-design-library
```

Scripts use `$BIOMIMETIC_LIB` to locate `feature-mapping.json`, `taxonomy/*.md`, `templates/prototype-template.md`, and write to `prototypes/`.

---

### Task 1: Set Up Test Infrastructure

**Files:**
- Create: `tests/__init__.py`
- Create: `tests/conftest.py`
- Create: `requirements-test.txt`

- [ ] **Step 1: Create requirements-test.txt**

```
pytest>=7.0
jsonschema>=4.17
```

- [ ] **Step 2: Create tests/__init__.py**

Empty file — marks directory as Python package.

- [ ] **Step 3: Create tests/conftest.py**

```python
"""Shared fixtures for biomimetic extraction tests."""

import json
import os
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
BIOMIMETIC_LIB = Path(
    os.environ.get(
        "BIOMIMETIC_LIB",
        REPO_ROOT.parent / "Biomimetic-design-library",
    )
)


@pytest.fixture
def repo_root():
    return REPO_ROOT


@pytest.fixture
def biomimetic_lib():
    return BIOMIMETIC_LIB


@pytest.fixture
def sample_extraction_result():
    """Minimal valid biomimetic extraction JSON (dict form)."""
    return {
        "schema_version": "biomimetic-v1",
        "paper_id": "zhang_2025_mussel",
        "bibliographic_metadata": {
            "title": "Mussel-inspired adsorbent for heavy metal removal",
            "authors": ["Zhang, X.", "Li, Y."],
            "year": 2025,
            "abstract": "We report a PDA-coated adsorbent...",
            "doi": "10.1000/example",
            "language": "en",
            "keywords": ["mussel", "PDA", "heavy metal", "adsorption"],
            "file_name": "zhang_2025_mussel.pdf",
        },
        "prototype_associations": [
            {
                "prototype_id": "mussel-foot-adhesion",
                "match_confidence": "high",
                "match_reason": "Paper directly studies mussel-inspired PDA coating",
            },
            {
                "prototype_id": "polydopamine-coating",
                "match_confidence": "high",
                "match_reason": "PDA coating is the primary material studied",
            },
        ],
        "biomimetic_design_chain": {
            "nature_challenge": "Mussels must adhere to wet surfaces in turbulent intertidal zones",
            "evolutionary_strategy": "Secrete DOPA-rich foot proteins that form strong bonds underwater",
            "key_mechanisms": [
                "Catechol-metal coordination",
                "Oxidative crosslinking of DOPA",
            ],
            "key_functional_groups": [
                {"group": "catechol", "function": "Bidentate metal coordination"},
                {"group": "amine", "function": "Surface anchoring and crosslinking"},
            ],
            "bio_to_material_mapping": [
                {
                    "bio_feature": "DOPA catechol group",
                    "material_design": "Polydopamine coating on substrates",
                    "confidence": "high",
                },
            ],
            "must_keep_features": [
                {"feature": "catechol group", "reason": "Essential for metal coordination"},
            ],
            "adjustable_features": [
                {"feature": "coating thickness", "adjustment_range": "10-200 nm"},
            ],
            "one_line_story": "Mimicking mussel DOPA proteins to create universal adhesive coatings for heavy metal capture",
            "design_traceability": "From Mytilus edulis foot protein chemistry to PDA dip-coating process",
        },
        "performance_data": [
            {
                "pollutant": "Pb2+",
                "material_form": "PDA-coated Fe3O4 nanoparticles",
                "qmax_mg_g": 185.2,
                "removal_rate_pct": 96.5,
                "pH": 5.0,
                "temperature_C": 25,
                "kinetics_model": "pseudo-second-order",
                "isotherm_model": "Langmuir",
                "selectivity": "Preferential for Pb2+ over Cd2+ and Zn2+",
                "reusability_cycles": 5,
                "data_source": "experimental",
                "reference": "Table 2, Zhang 2025",
                "confidence": "high",
            },
        ],
        "structural_features": {
            "macro_scale": {
                "feature": "Spherical nanoparticles aggregated into clusters",
                "size_range": "50-200 nm",
                "function": "Easy dispersion and recovery",
            },
            "meso_scale": {
                "feature": "Mesoporous PDA shell",
                "size_range": "2-10 nm pores",
                "function": "High surface area for metal ion access",
            },
            "micro_scale": {
                "feature": "Core-shell Fe3O4@PDA structure",
                "size_range": "20-50 nm shell",
                "function": "Magnetic recovery + adsorption",
            },
            "nano_scale": {
                "feature": "Catechol groups at molecular level",
                "size_range": "<1 nm",
                "function": "Direct metal coordination sites",
            },
            "structure_function_relationship": "Core-shell architecture combines magnetic recovery with high-density catechol sites; mesoporous shell ensures ion accessibility",
        },
        "mechanism_analysis": [
            {
                "mechanism_name": "配位螯合",
                "phenomenon": "PDA coating strongly binds heavy metal ions in aqueous solution",
                "molecular_basis": [
                    "Catechol hydroxyl groups deprotonate at pH 5, forming bidentate ligands",
                    "Metal-catechol complexes have stability constants log K > 10",
                ],
                "key_functional_groups": [
                    {"group": "catechol (-OH)", "role": "Primary metal coordination site"},
                    {"group": "amine (-NH2)", "role": "Secondary coordination and crosslinking"},
                ],
                "biomimetic_inspiration": "DOPA-rich coatings can be applied to any substrate for universal metal capture",
                "supporting_evidence": "XPS shows shift in O 1s peak after Pb2+ adsorption, confirming catechol involvement",
            },
        ],
        "engineering_constraints": [
            {
                "constraint": "高吸附容量",
                "assessment": "high",
                "explanation": "qmax=185.2 mg/g for Pb2+ is competitive",
            },
            {
                "constraint": "可回收性",
                "assessment": "high",
                "explanation": "Magnetic core enables easy separation; 5 cycles demonstrated",
            },
        ],
        "evidence_tracking": {
            "total_claims": 8,
            "evidence_backed": 7,
            "unsubstantiated": 1,
            "key_evidence": [
                {
                    "claim": "qmax = 185.2 mg/g for Pb2+",
                    "evidence_type": "experimental_data",
                    "location": "Table 2",
                    "quality": "reliable",
                },
            ],
        },
    }


@pytest.fixture
def feature_mapping(biomimetic_lib):
    """Load the real feature-mapping.json."""
    path = biomimetic_lib / "feature-mapping.json"
    if path.exists():
        with open(path) as f:
            return json.load(f)
    return None
```

- [ ] **Step 4: Install test dependencies and verify pytest works**

Run:
```bash
cd /Users/panyao/.qoderworkcn/workspace/mpzh27rt8uc58fyx/Literature-extracting
pip3 install -q pytest jsonschema
python3 -m pytest tests/ --collect-only
```

Expected: `no tests ran` with 0 errors (no test files yet, but framework works).

- [ ] **Step 5: Commit**

```bash
git add tests/ requirements-test.txt
git commit -m "test: add pytest infrastructure and shared fixtures"
```

---

### Task 2: Create biomimetic_extraction.schema.json

**Files:**
- Create: `schema/biomimetic_extraction.schema.json`
- Create: `tests/test_schema.py`

- [ ] **Step 1: Write the failing test**

Create `tests/test_schema.py`:

```python
"""Validate biomimetic extraction schema structure."""

import json
from pathlib import Path

import pytest

SCHEMA_PATH = Path(__file__).resolve().parent.parent / "schema" / "biomimetic_extraction.schema.json"


@pytest.fixture
def schema():
    with open(SCHEMA_PATH) as f:
        return json.load(f)


class TestSchemaStructure:
    def test_schema_file_exists(self):
        assert SCHEMA_PATH.exists(), f"Schema not found at {SCHEMA_PATH}"

    def test_schema_is_valid_json_schema_draft(self, schema):
        assert schema["$schema"] == "https://json-schema.org/draft-2020-12/schema"

    def test_schema_has_id(self, schema):
        assert schema["$id"] == "https://biomimetic.local/schema/biomimetic-v1.schema.json"

    def test_schema_required_top_level_fields(self, schema):
        required = schema["required"]
        expected = [
            "schema_version",
            "paper_id",
            "bibliographic_metadata",
            "prototype_associations",
            "biomimetic_design_chain",
            "performance_data",
            "structural_features",
            "mechanism_analysis",
            "engineering_constraints",
            "evidence_tracking",
        ]
        for field in expected:
            assert field in required, f"Missing required field: {field}"

    def test_schema_version_is_const(self, schema):
        assert schema["properties"]["schema_version"]["const"] == "biomimetic-v1"

    def test_performance_data_is_array(self, schema):
        perf = schema["properties"]["performance_data"]
        assert perf["type"] == "array"

    def test_mechanism_analysis_is_array(self, schema):
        mech = schema["properties"]["mechanism_analysis"]
        assert mech["type"] == "array"

    def test_engineering_constraints_is_array(self, schema):
        eng = schema["properties"]["engineering_constraints"]
        assert eng["type"] == "array"


class TestSchemaValidation:
    """Use jsonschema to validate the sample fixture against the schema."""

    def test_sample_fixture_validates(self, schema, sample_extraction_result):
        from jsonschema import validate
        validate(instance=sample_extraction_result, schema=schema)

    def test_missing_required_field_fails(self, schema, sample_extraction_result):
        from jsonschema import ValidationError
        del sample_extraction_result["paper_id"]
        with pytest.raises(ValidationError):
            from jsonschema import validate
            validate(instance=sample_extraction_result, schema=schema)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_schema.py -v`
Expected: FAIL — `FileNotFoundError: schema/biomimetic_extraction.schema.json`

- [ ] **Step 3: Create schema/biomimetic_extraction.schema.json**

Create the full schema file:

```json
{
  "$schema": "https://json-schema.org/draft-2020-12/schema",
  "$id": "https://biomimetic.local/schema/biomimetic-v1.schema.json",
  "title": "Biomimetic Extraction Schema v1",
  "description": "仿生水处理吸附材料设计知识提取 — 结构化输出格式",
  "type": "object",
  "required": [
    "schema_version",
    "paper_id",
    "bibliographic_metadata",
    "prototype_associations",
    "biomimetic_design_chain",
    "performance_data",
    "structural_features",
    "mechanism_analysis",
    "engineering_constraints",
    "evidence_tracking"
  ],
  "additionalProperties": false,
  "properties": {
    "schema_version": {
      "const": "biomimetic-v1"
    },
    "paper_id": {
      "type": "string",
      "description": "稳定短 ID: first_author_year_keyword"
    },
    "bibliographic_metadata": {
      "type": "object",
      "additionalProperties": true,
      "required": ["title", "authors", "year", "abstract"],
      "properties": {
        "title": {"type": ["string", "null"]},
        "authors": {"type": "array", "items": {"type": "string"}},
        "year": {"type": ["integer", "string", "null"]},
        "doi": {"type": ["string", "null"]},
        "language": {"type": ["string", "null"]},
        "keywords": {"type": "array", "items": {"type": "string"}},
        "abstract": {"type": ["string", "null"]},
        "file_name": {"type": ["string", "null"]}
      }
    },
    "prototype_associations": {
      "type": "array",
      "description": "该论文关联的仿生原型列表",
      "items": {
        "type": "object",
        "required": ["prototype_id", "match_confidence"],
        "additionalProperties": true,
        "properties": {
          "prototype_id": {
            "type": "string",
            "description": "原型ID，须匹配 feature-mapping.json 中 prototype_metadata 的 key"
          },
          "match_confidence": {
            "enum": ["high", "medium", "low"]
          },
          "match_reason": {"type": ["string", "null"]}
        }
      }
    },
    "biomimetic_design_chain": {
      "type": "object",
      "description": "仿生设计逻辑链 — 库的核心字段",
      "required": [
        "nature_challenge",
        "evolutionary_strategy",
        "key_mechanisms",
        "one_line_story"
      ],
      "additionalProperties": true,
      "properties": {
        "nature_challenge": {
          "type": ["string", "null"],
          "description": "生物在自然界中面临的具体挑战（50-200字）"
        },
        "evolutionary_strategy": {
          "type": ["string", "null"],
          "description": "生物通过进化形成的解决策略"
        },
        "key_mechanisms": {
          "type": "array",
          "items": {"type": "string"},
          "description": "支撑策略的关键生物机制列表"
        },
        "key_functional_groups": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["group", "function"],
            "properties": {
              "group": {"type": "string"},
              "function": {"type": "string"}
            }
          }
        },
        "bio_to_material_mapping": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["bio_feature", "material_design"],
            "properties": {
              "bio_feature": {"type": "string"},
              "material_design": {"type": "string"},
              "confidence": {"enum": ["high", "medium", "low"]}
            }
          }
        },
        "must_keep_features": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["feature", "reason"],
            "properties": {
              "feature": {"type": "string"},
              "reason": {"type": "string"}
            }
          }
        },
        "adjustable_features": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["feature", "adjustment_range"],
            "properties": {
              "feature": {"type": "string"},
              "adjustment_range": {"type": "string"}
            }
          }
        },
        "one_line_story": {
          "type": ["string", "null"],
          "description": "一句话仿生故事"
        },
        "design_traceability": {
          "type": ["string", "null"],
          "description": "设计可追溯性描述"
        }
      }
    },
    "performance_data": {
      "type": "array",
      "description": "吸附性能定量数据，每个实验条件一组",
      "items": {
        "type": "object",
        "required": ["pollutant", "data_source"],
        "additionalProperties": true,
        "properties": {
          "pollutant": {"type": "string", "description": "使用 taxonomy/pollutants.md 标准名称"},
          "material_form": {"type": ["string", "null"]},
          "qmax_mg_g": {"type": ["number", "null"]},
          "removal_rate_pct": {"type": ["number", "null"]},
          "pH": {"type": ["number", "null"]},
          "temperature_C": {"type": ["number", "null"]},
          "kinetics_model": {"type": ["string", "null"]},
          "isotherm_model": {"type": ["string", "null"]},
          "selectivity": {"type": ["string", "null"]},
          "reusability_cycles": {"type": ["integer", "null"]},
          "data_source": {"enum": ["experimental", "reported", "estimated"]},
          "reference": {"type": ["string", "null"]},
          "confidence": {"enum": ["high", "medium", "low"]}
        }
      }
    },
    "structural_features": {
      "type": "object",
      "description": "多尺度结构特征",
      "additionalProperties": true,
      "properties": {
        "macro_scale": {
          "type": ["object", "null"],
          "properties": {
            "feature": {"type": ["string", "null"]},
            "size_range": {"type": ["string", "null"]},
            "function": {"type": ["string", "null"]}
          }
        },
        "meso_scale": {
          "type": ["object", "null"],
          "properties": {
            "feature": {"type": ["string", "null"]},
            "size_range": {"type": ["string", "null"]},
            "function": {"type": ["string", "null"]}
          }
        },
        "micro_scale": {
          "type": ["object", "null"],
          "properties": {
            "feature": {"type": ["string", "null"]},
            "size_range": {"type": ["string", "null"]},
            "function": {"type": ["string", "null"]}
          }
        },
        "nano_scale": {
          "type": ["object", "null"],
          "properties": {
            "feature": {"type": ["string", "null"]},
            "size_range": {"type": ["string", "null"]},
            "function": {"type": ["string", "null"]}
          }
        },
        "structure_function_relationship": {"type": ["string", "null"]}
      }
    },
    "mechanism_analysis": {
      "type": "array",
      "description": "吸附机制详解，每个机制一条",
      "items": {
        "type": "object",
        "required": ["mechanism_name", "phenomenon"],
        "additionalProperties": true,
        "properties": {
          "mechanism_name": {"type": "string", "description": "使用 taxonomy/mechanisms.md 标准名称"},
          "phenomenon": {"type": "string"},
          "molecular_basis": {"type": "array", "items": {"type": "string"}},
          "key_functional_groups": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["group", "role"],
              "properties": {
                "group": {"type": "string"},
                "role": {"type": "string"}
              }
            }
          },
          "biomimetic_inspiration": {"type": ["string", "null"]},
          "supporting_evidence": {"type": ["string", "null"]}
        }
      }
    },
    "engineering_constraints": {
      "type": "array",
      "description": "工程约束评估",
      "items": {
        "type": "object",
        "required": ["constraint", "assessment"],
        "additionalProperties": true,
        "properties": {
          "constraint": {"type": "string"},
          "assessment": {"enum": ["high", "medium", "low"]},
          "explanation": {"type": ["string", "null"]}
        }
      }
    },
    "evidence_tracking": {
      "type": "object",
      "description": "证据溯源汇总",
      "additionalProperties": true,
      "properties": {
        "total_claims": {"type": ["integer", "null"]},
        "evidence_backed": {"type": ["integer", "null"]},
        "unsubstantiated": {"type": ["integer", "null"]},
        "key_evidence": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "claim": {"type": "string"},
              "evidence_type": {"type": "string"},
              "location": {"type": "string"},
              "quality": {"enum": ["reliable", "needs_review", "suspicious"]}
            }
          }
        }
      }
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest tests/test_schema.py -v`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add schema/biomimetic_extraction.schema.json tests/test_schema.py
git commit -m "feat: add biomimetic extraction schema v1 with tests"
```

---

### Task 3: Create vocabulary_mapping.json

**Files:**
- Create: `config/vocabulary_mapping.json`

This file maps literature raw terms to standard labels from `feature-mapping.json` (27 feature tags), `taxonomy/mechanisms.md` (16 mechanisms), and `taxonomy/pollutants.md` (all pollutant types).

- [ ] **Step 1: Create config/ directory**

```bash
mkdir -p /Users/panyao/.qoderworkcn/workspace/mpzh27rt8uc58fyx/Literature-extracting/config
```

- [ ] **Step 2: Create config/vocabulary_mapping.json**

```json
{
  "description": "标准词汇映射表：文献原始表述 → 仿生设计库标准标签",
  "feature_mapping": {
    "catechol group": "邻苯二酚基团",
    "catechol": "邻苯二酚基团",
    "DOPA": "邻苯二酚基团",
    "3,4-dihydroxyphenylalanine": "邻苯二酚基团",
    "polydopamine": "邻苯二酚基团",
    "tannin": "邻苯二酚基团",
    "hydrophobic": "疏水性",
    "hydrophobicity": "疏水性",
    "water-repellent": "疏水性",
    "oleophilic": "疏水性",
    "superhydrophobic": "超疏水性",
    "superhydrophobicity": "超疏水性",
    "Cassie-Baxter": "超疏水性",
    "lotus effect": "超疏水性",
    "contact angle >150": "超疏水性",
    "hydrophilic": "亲水性",
    "hydrophilicity": "亲水性",
    "water-attracting": "亲水性",
    "positively charged": "正电表面",
    "positive surface charge": "正电表面",
    "cationic surface": "正电表面",
    "zeta potential positive": "正电表面",
    "negatively charged": "负电表面",
    "negative surface charge": "负电表面",
    "anionic surface": "负电表面",
    "zeta potential negative": "负电表面",
    "microporous": "微孔",
    "micropore": "微孔",
    "pore <2nm": "微孔",
    "ultramicroporous": "微孔",
    "mesoporous": "介孔",
    "mesopore": "介孔",
    "pore 2-50nm": "介孔",
    "macroporous": "大孔",
    "macropore": "大孔",
    "pore >50nm": "大孔",
    "hierarchical pores": "层次孔",
    "hierarchical porosity": "层次孔",
    "multi-scale pores": "层次孔",
    "fibrous": "纤维状",
    "fiber": "纤维状",
    "nanofiber": "纤维状",
    "filament": "纤维状",
    "layered": "层状",
    "lamellar": "层状",
    "nacre-like": "层状",
    "brick-and-mortar": "层状",
    "papilla array": "乳突阵列",
    "papillae": "乳突阵列",
    "micro-papilla": "乳突阵列",
    "nano-papilla": "乳突阵列",
    "network": "网状",
    "mesh": "网状",
    "interconnected network": "网状",
    "amino group": "氨基",
    "amine": "氨基",
    "-NH2": "氨基",
    "NH2": "氨基",
    "chitosan amine": "氨基",
    "carboxyl group": "羧基",
    "carboxyl": "羧基",
    "-COOH": "羧基",
    "COOH": "羧基",
    "carboxylic acid": "羧基",
    "thiol group": "巯基",
    "thiol": "巯基",
    "-SH": "巯基",
    "sulfhydryl": "巯基",
    "metal coordination": "金属配位能力",
    "chelation": "金属配位能力",
    "metal binding": "金属配位能力",
    "coordination bond": "金属配位能力",
    "pi electron": "pi电子体系",
    "π electron": "pi电子体系",
    "pi-pi stacking": "pi电子体系",
    "aromatic ring": "pi电子体系",
    "conjugated system": "pi电子体系",
    "reactive oxygen": "活性氧位点",
    "ROS": "活性氧位点",
    "catalytic site": "活性氧位点",
    "Fenton-like": "活性氧位点",
    "wet adhesion": "湿态粘附",
    "underwater adhesion": "湿态粘附",
    "mussel adhesion": "湿态粘附",
    "self-cleaning": "自清洁",
    "self cleaning": "自清洁",
    "anti-fouling": "自清洁",
    "catalytic degradation": "催化降解",
    "photocatalytic": "催化降解",
    "Fenton degradation": "催化降解",
    "ion exchange": "离子交换",
    "cation exchange": "离子交换",
    "anion exchange": "离子交换",
    "molecular sieving": "分子筛分",
    "size exclusion": "分子筛分",
    "size-selective": "分子筛分",
    "biomineralization": "生物矿化模板",
    "biomineral": "生物矿化模板",
    "calcium carbonate template": "生物矿化模板",
    "anti-biofouling": "抗生物污染",
    "antimicrobial": "抗生物污染",
    "antibacterial": "抗生物污林",
    "biofilm resistance": "抗生物污林"
  },
  "mechanism_mapping": {
    "coordination chelation": "配位螯合",
    "coordination": "配位螯合",
    "chelation": "配位螯合",
    "metal coordination": "配位螯合",
    "complexation": "配位螯合",
    "electrostatic attraction": "静电吸附",
    "electrostatic": "静电吸附",
    "electrostatic adsorption": "静电吸附",
    "coulombic attraction": "静电吸附",
    "pi-pi stacking": "pi-pi堆积",
    "pi-pi interaction": "pi-pi堆积",
    "π-π stacking": "pi-pi堆积",
    "hydrogen bond": "氢键",
    "H-bond": "氢键",
    "hydrogen bonding": "氢键",
    "ion exchange": "离子交换",
    "cation exchange": "离子交换",
    "anion exchange": "离子交换",
    "micropore adsorption": "微孔吸附",
    "microporous adsorption": "微孔吸附",
    "mesopore adsorption": "介孔吸附",
    "mesoporous adsorption": "介孔吸附",
    "macropore adsorption": "大孔吸附",
    "macroporous adsorption": "大孔吸附",
    "hierarchical pore adsorption": "层次孔吸附",
    "superhydrophobic separation": "超疏水分离",
    "oil-water separation": "超疏水分离",
    "Cassie-Baxter": "超疏水分离",
    "SLIPS": "超滑表面",
    "slippery surface": "超滑表面",
    "liquid-infused": "超滑表面",
    "molecular sieving": "分子筛分",
    "size exclusion": "分子筛分",
    "network filtration": "网络过滤",
    "filtration": "网络过滤",
    "biomineralization": "生物矿化",
    "biological precipitation": "生物沉淀",
    "biosorption": "生物积累",
    "bioaccumulation": "生物积累",
    "catalytic degradation": "催化降解"
  },
  "pollutant_mapping": {
    "cadmium": "Cd2+",
    "Cd": "Cd2+",
    "Cd(II)": "Cd2+",
    "lead": "Pb2+",
    "Pb": "Pb2+",
    "Pb(II)": "Pb2+",
    "mercury": "Hg2+",
    "Hg": "Hg2+",
    "Hg(II)": "Hg2+",
    "copper": "Cu2+",
    "Cu": "Cu2+",
    "Cu(II)": "Cu2+",
    "zinc": "Zn2+",
    "Zn": "Zn2+",
    "Zn(II)": "Zn2+",
    "nickel": "Ni2+",
    "Ni": "Ni2+",
    "Ni(II)": "Ni2+",
    "chromium": "Cr3+/Cr6+",
    "Cr": "Cr3+/Cr6+",
    "Cr(III)": "Cr3+/Cr6+",
    "Cr(VI)": "Cr3+/Cr6+",
    "arsenic": "As3+/As5+",
    "As": "As3+/As5+",
    "As(III)": "As3+/As5+",
    "As(V)": "As3+/As5+",
    "iron": "Fe3+",
    "Fe": "Fe3+",
    "Fe(III)": "Fe3+",
    "manganese": "Mn2+",
    "Mn": "Mn2+",
    "cobalt": "Co2+",
    "Co": "Co2+",
    "methylene blue": "阳离子染料",
    "MB": "阳离子染料",
    "rhodamine B": "阳离子染料",
    "RhB": "阳离子染料",
    "methyl orange": "阴离子染料",
    "MO": "阴离子染料",
    "congo red": "阴离子染料",
    "phenol": "芳香族化合物",
    "bisphenol A": "芳香族化合物",
    "PAH": "芳香族化合物",
    "antibiotics": "抗生素",
    "tetracycline": "抗生素",
    "ciprofloxacin": "抗生素",
    "ammonium": "NH4+-N",
    "ammonia nitrogen": "NH4+-N",
    "NH4": "NH4+-N",
    "nitrate": "NO3-",
    "NO3": "NO3-",
    "phosphate": "PO43-",
    "PO4": "PO43-",
    "fluoride": "F-",
    "crude oil": "原油",
    "diesel": "柴油",
    "emulsified oil": "乳化油",
    "uranium": "U",
    "strontium": "Sr",
    "cesium": "Cs"
  },
  "category_mapping": {
    "bacteria": "微生物",
    "fungi": "微生物",
    "microalgae": "微生物",
    "plant": "植物",
    "animal": "动物",
    "mollusk": "动物",
    "arthropod": "动物",
    "insect": "动物",
    "synthetic polymer": "仿生材料",
    "inorganic porous": "仿生材料",
    "composite": "仿生材料",
    "biomolecule": "仿生材料"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add config/vocabulary_mapping.json
git commit -m "feat: add standard vocabulary mapping for 27 features, 16 mechanisms, 30+ pollutants"
```

---

### Task 4: Create prototype_routing.json

**Files:**
- Create: `config/prototype_routing.json`

This file defines keyword-based routing to match extraction results to the 33 prototypes defined in `feature-mapping.json` `prototype_metadata`.

- [ ] **Step 1: Create config/prototype_routing.json**

```json
{
  "description": "原型路由配置：基于关键词将提取结果关联到仿生原型",
  "prototypes": {
    "lotus-leaf": {
      "keywords_en": ["lotus", "Nelumbo", "superhydrophobic", "self-cleaning", "papilla", "Cassie-Baxter", "contact angle"],
      "keywords_cn": ["荷叶", "莲花", "超疏水", "自清洁", "乳突"],
      "category": "植物",
      "biomimetic_dimension": "形态仿生"
    },
    "superhydrophobic-artificial": {
      "keywords_en": ["superhydrophobic surface", "artificial superhydrophobic", "biomimetic superhydrophobic", "lotus-inspired"],
      "keywords_cn": ["仿荷叶", "超疏水表面", "人工超疏水"],
      "category": "仿生材料",
      "biomimetic_dimension": "形态仿生"
    },
    "water-strider-leg": {
      "keywords_en": ["water strider", "Gerridae", "water walking", "superhydrophobic leg", "setae"],
      "keywords_cn": ["水黾", "水面行走", "疏水腿"],
      "category": "动物",
      "biomimetic_dimension": "形态仿生"
    },
    "namib-beetle": {
      "keywords_en": ["Namib beetle", "Stenocara", "fog harvesting", "wettability pattern", "hydrophilic-hydrophobic"],
      "keywords_cn": ["Namib甲虫", "纳米布甲虫", "集雾", "润湿性图案"],
      "category": "动物",
      "biomimetic_dimension": "形态仿生"
    },
    "cactus-spine": {
      "keywords_en": ["cactus", "Opuntia", "spine", "fog collection", "wettability gradient", "conical"],
      "keywords_cn": ["仙人掌", "仙人掌刺", "集雾", "润湿梯度"],
      "category": "植物",
      "biomimetic_dimension": "形态仿生"
    },
    "mussel-foot-adhesion": {
      "keywords_en": ["mussel", "Mytilus", "DOPA", "foot protein", "byssus", "wet adhesion", "underwater adhesion", "catechol", "mussel-inspired"],
      "keywords_cn": ["贻贝", "足丝", "足蛋白", "DOPA", "湿态粘附", "仿贻贝"],
      "category": "动物",
      "biomimetic_dimension": "分子仿生"
    },
    "spider-silk": {
      "keywords_en": ["spider silk", "dragline", "spidroin", "tensile strength", "beta-sheet", "silk fiber"],
      "keywords_cn": ["蜘蛛丝", "牵引丝", "蛛丝蛋白", "beta折叠"],
      "category": "动物",
      "biomimetic_dimension": "分子仿生"
    },
    "cellulose-nanocrystal": {
      "keywords_en": ["cellulose nanocrystal", "CNC", "cellulose nanofiber", "CNF", "nanocellulose", "cellulose whisker"],
      "keywords_cn": ["纤维素纳米晶", "纳米纤维素", "纤维素晶须"],
      "category": "仿生材料",
      "biomimetic_dimension": "结构仿生"
    },
    "chitosan": {
      "keywords_en": ["chitosan", "chitin", "deacetylated", "amino polysaccharide", "crustacean shell"],
      "keywords_cn": ["壳聚糖", "甲壳素", "氨基多糖", "脱乙酰化"],
      "category": "仿生材料",
      "biomimetic_dimension": "分子仿生"
    },
    "chlorella-cell-wall": {
      "keywords_en": ["Chlorella", "microalgae", "algal cell wall", "biosorption", "algal biomass"],
      "keywords_cn": ["小球藻", "微藻", "藻类细胞壁", "生物吸附"],
      "category": "微生物",
      "biomimetic_dimension": "功能仿生"
    },
    "alginate": {
      "keywords_en": ["alginate", "alginic acid", "brown algae", "egg-box", "guluronic acid", "mannuronic acid", "calcium alginate"],
      "keywords_cn": ["海藻酸钠", "褐藻酸", "蛋盒结构", "海藻酸"],
      "category": "仿生材料",
      "biomimetic_dimension": "分子仿生"
    },
    "metal-organic-framework": {
      "keywords_en": ["metal-organic framework", "MOF", "coordination polymer", "porous coordination", "zeolitic imidazolate", "ZIF", "UiO", "MIL"],
      "keywords_cn": ["金属有机框架", "MOF", "配位聚合物", "多孔配位"],
      "category": "仿生材料",
      "biomimetic_dimension": "结构仿生"
    },
    "starch-granule": {
      "keywords_en": ["starch", "amylose", "amylopectin", "starch granule", "gelatinization"],
      "keywords_cn": ["淀粉", "直链淀粉", "支链淀粉", "淀粉颗粒"],
      "category": "植物",
      "biomimetic_dimension": "结构仿生"
    },
    "diatom-frustule": {
      "keywords_en": ["diatom", "frustule", "siliceous", "Bacillariophyta", "diatomite", "diatomaceous"],
      "keywords_cn": ["硅藻", "硅藻壳", "硅藻土", "蛋白石"],
      "category": "微生物",
      "biomimetic_dimension": "结构仿生"
    },
    "diatom-inspired-porous": {
      "keywords_en": ["diatom-inspired", "diatom-mimetic", "biomimetic porous microsphere", "silica microsphere", "ordered mesoporous silica"],
      "keywords_cn": ["仿硅藻", "仿生多孔微球", "有序介孔二氧化硅"],
      "category": "仿生材料",
      "biomimetic_dimension": "结构仿生"
    },
    "coral-skeleton": {
      "keywords_en": ["coral", "coral skeleton", "calcium carbonate", "aragonite", "coralline", "reef"],
      "keywords_cn": ["珊瑚", "珊瑚骨骼", "碳酸钙", "文石"],
      "category": "动物",
      "biomimetic_dimension": "结构仿生"
    },
    "wood-xylem": {
      "keywords_en": ["wood", "xylem", "cellulose fiber", "lignin", "wood-derived", "natural wood", "wood char"],
      "keywords_cn": ["木材", "木质部", "木纤维", "木质素"],
      "category": "植物",
      "biomimetic_dimension": "结构仿生"
    },
    "bone-structure": {
      "keywords_en": ["bone", "hydroxyapatite", "collagen", "osteocyte", "bone char", "bone-derived", "HAP"],
      "keywords_cn": ["骨骼", "羟基磷灰石", "胶原蛋白", "骨炭"],
      "category": "动物",
      "biomimetic_dimension": "结构仿生"
    },
    "oyster-shell": {
      "keywords_en": ["oyster", "oyster shell", "nacre", "mother of pearl", "CaCO3 biomineralization", "calcium carbonate shell"],
      "keywords_cn": ["牡蛎", "牡蛎壳", "珍珠层", "碳酸钙生物矿化"],
      "category": "动物",
      "biomimetic_dimension": "过程仿生"
    },
    "iron-oxidizing-bacteria": {
      "keywords_en": ["iron-oxidizing bacteria", "Gallionella", "Leptothrix", "iron bacteria", "biogenic iron oxide", "iron oxyhydroxide"],
      "keywords_cn": ["铁氧化细菌", "铁细菌", "生物成因氧化铁"],
      "category": "微生物",
      "biomimetic_dimension": "过程仿生"
    },
    "silk-fibroin": {
      "keywords_en": ["silk fibroin", "Bombyx mori", "silkworm silk", "silk protein", "fibroin membrane", "regenerated silk"],
      "keywords_cn": ["丝素蛋白", "蚕丝", "家蚕", "丝蛋白膜"],
      "category": "动物",
      "biomimetic_dimension": "分子仿生"
    },
    "mycelium": {
      "keywords_en": ["mycelium", "fungal hyphae", "mycelial network", "Aspergillus", "Penicillium", "fungal biosorption"],
      "keywords_cn": ["菌丝体", "真菌菌丝", "菌丝网络", "真菌生物吸附"],
      "category": "微生物",
      "biomimetic_dimension": "系统仿生"
    },
    "lobster-exoskeleton": {
      "keywords_en": ["lobster", "exoskeleton", "chitin", "crustacean", "Bouligand structure", "helicoidal"],
      "keywords_cn": ["龙虾", "外骨骼", "甲壳素", "Bouligand结构"],
      "category": "动物",
      "biomimetic_dimension": "结构仿生"
    },
    "scallop-shell": {
      "keywords_en": ["scallop", "scallop shell", "bivalve", "crossed-lamellar", "shell biomineralization"],
      "keywords_cn": ["扇贝", "扇贝壳", "交叉层状结构"],
      "category": "动物",
      "biomimetic_dimension": "结构仿生"
    },
    "sulfate-reducing-bacteria": {
      "keywords_en": ["sulfate-reducing bacteria", "SRB", "Desulfovibrio", "hydrogen sulfide", "metal sulfide precipitation", "biogenic sulfide"],
      "keywords_cn": ["硫酸盐还原菌", "SRB", "硫化氢", "金属硫化物沉淀"],
      "category": "微生物",
      "biomimetic_dimension": "过程仿生"
    },
    "polydopamine-coating": {
      "keywords_en": ["polydopamine", "PDA", "dopamine polymerization", "PDA coating", "mussel-inspired coating", "self-polymerized dopamine"],
      "keywords_cn": ["聚多巴胺", "PDA", "多巴胺聚合", "PDA涂层", "仿贻贝涂层"],
      "category": "仿生材料",
      "biomimetic_dimension": "分子仿生"
    },
    "plant-tannin": {
      "keywords_en": ["tannin", "plant tannin", "condensed tannin", "proanthocyanidin", "tannic acid", "polyphenol"],
      "keywords_cn": ["单宁", "植物单宁", "缩合单宁", "单宁酸", "多酚"],
      "category": "植物",
      "biomimetic_dimension": "分子仿生"
    },
    "shark-skin": {
      "keywords_en": ["shark skin", "dermal denticles", "placoid scales", "riblet", "anti-fouling", "drag reduction"],
      "keywords_cn": ["鲨鱼皮", "盾鳞", "减阻", "防污"],
      "category": "动物",
      "biomimetic_dimension": "形态仿生"
    },
    "pitcher-plant-slippery-surface": {
      "keywords_en": ["pitcher plant", "Nepenthes", "SLIPS", "slippery liquid-infused", "peristome", "liquid repellent"],
      "keywords_cn": ["猪笼草", "超滑表面", "SLIPS", "液体注入多孔表面"],
      "category": "植物",
      "biomimetic_dimension": "形态仿生"
    },
    "mangrove-root": {
      "keywords_en": ["mangrove", "pneumatophore", "mangrove root", "Rhizophora", "salt exclusion", "root filtration"],
      "keywords_cn": ["红树林", "气生根", "红树根系", "盐分排除"],
      "category": "植物",
      "biomimetic_dimension": "系统仿生"
    },
    "fish-scale-hydroxyapatite": {
      "keywords_en": ["fish scale", "fish scale hydroxyapatite", "scale-derived HAP", "fish bone", "fish scale biomineralization"],
      "keywords_cn": ["鱼鳞", "鱼鳞羟基磷灰石", "鱼骨"],
      "category": "动物",
      "biomimetic_dimension": "过程仿生"
    },
    "cell-membrane-ion-channel": {
      "keywords_en": ["ion channel", "cell membrane", "selective transport", "aquaporin", "ion selective", "membrane protein channel"],
      "keywords_cn": ["离子通道", "细胞膜", "选择性传输", "水通道蛋白"],
      "category": "仿生材料",
      "biomimetic_dimension": "分子仿生"
    },
    "magnetic-bacteria": {
      "keywords_en": ["magnetotactic bacteria", "magnetosome", "magnetite nanoparticle", "biogenic magnetite", "Fe3O4 biomineralization"],
      "keywords_cn": ["磁性细菌", "趋磁细菌", "磁小体", "生物成因磁铁矿"],
      "category": "微生物",
      "biomimetic_dimension": "过程仿生"
    }
  },
  "routing_rules": {
    "match_threshold": 2,
    "max_prototypes_per_paper": 3,
    "prefer_direct": true,
    "case_insensitive": true
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add config/prototype_routing.json
git commit -m "feat: add prototype routing config for all 33 prototypes with EN/CN keywords"
```

---

### Task 5: Write biomimetic_extraction_prompt.md

**Files:**
- Create: `prompts/biomimetic_extraction_prompt.md`

- [ ] **Step 1: Create prompts/biomimetic_extraction_prompt.md**

This is a long prompt file (~400 lines). Write the complete file:

```markdown
# 仿生水处理吸附材料设计知识提取 — 单篇论文提取提示词

> 版本: biomimetic-v1
> 适用范围: 学术论文全文（含文本、表格、图表描述）
> 输出格式: 严格遵循 biomimetic_extraction.schema.json

---

## 角色定义

你是一位**仿生材料设计领域的科学文献分析专家**。你的任务是从水处理吸附材料相关论文中提取仿生设计知识，产出可直接写入仿生设计库的结构化数据。

### 你的核心目标

从论文中提取"生物原型→设计策略→材料实现"的完整知识链，使AI材料设计Agent能够：
1. 理解生物如何解决自然界中的水处理相关挑战
2. 将生物策略映射为材料设计方向
3. 获得定量性能数据用于评估设计可行性
4. 获得机制解释用于设计决策的可解释性

### 你不应该做的事

- **不要推断**论文中未明确报告的数据
- **不要编造**参考文献或数据点
- **不要使用**通用表述替代具体数据（如"良好的吸附性能"而不给出具体数值）
- **不要遗漏**论文中明确给出的定量数据

---

## 提取工作流

对每篇论文，按以下6个步骤依次提取：

### 步骤1：论文理解与原型关联

**首先**，快速扫描论文标题、摘要、关键词，回答：
- 这篇论文研究的是什么材料/生物/机制？
- 与哪些仿生原型相关？（从以下原型列表中选择1-3个最相关的）

**可用原型列表**：
lotus-leaf, superhydrophobic-artificial, water-strider-leg, namib-beetle, cactus-spine, mussel-foot-adhesion, spider-silk, cellulose-nanocrystal, chitosan, chlorella-cell-wall, alginate, metal-organic-framework, starch-granule, diatom-frustule, diatom-inspired-porous, coral-skeleton, wood-xylem, bone-structure, oyster-shell, iron-oxidizing-bacteria, silk-fibroin, mycelium, lobster-exoskeleton, scallop-shell, sulfate-reducing-bacteria, polydopamine-coating, plant-tannin, shark-skin, pitcher-plant-slippery-surface, mangrove-root, fish-scale-hydroxyapatite, cell-membrane-ion-channel, magnetic-bacteria

**关联规则**：
- match_confidence = "high"：论文直接研究该生物原型或其仿生衍生材料
- match_confidence = "medium"：论文涉及相关机制或间接提及该原型
- match_confidence = "low"：仅有弱关联

### 步骤2：仿生设计逻辑链 [最核心]

这是整个提取中**最重要的部分**。你需要识别"生物→设计→材料"的完整因果链：

1. **nature_challenge**：该生物在自然界中面临什么具体挑战？
   - 要求：50-200字，具体描述（不要泛泛而谈）
   - 好例子："贻贝栖息在潮间带岩石上，必须在高盐度、湍流、波浪冲击的湿润环境中牢固粘附"
   - 坏例子："贻贝需要粘附"

2. **evolutionary_strategy**：生物进化出了什么解决策略？
   - 要求：描述具体的生物策略，包含进化适应的细节

3. **key_mechanisms**：支撑该策略的关键生物机制有哪些？
   - 要求：列出2-5个关键机制

4. **key_functional_groups**：关键的官能团或结构特征
   - 每个条目包含 group（基团名称）和 function（功能描述）

5. **bio_to_material_mapping**：从生物特征到材料设计的映射
   - 每个条目包含 bio_feature（生物特征）、material_design（材料设计方向）、confidence

6. **must_keep_features**：仿生设计中必须保留的特征
7. **adjustable_features**：可以灵活调整的特征
8. **one_line_story**：一句话概括这个仿生故事
9. **design_traceability**：设计可追溯性

### 步骤3：吸附性能数据

提取论文中**明确报告**的实验数据，不要推断或编造。

对每个实验条件/材料组合，提取：
- pollutant（污染物名称，使用标准名称）
- material_form（材料形态描述）
- qmax_mg_g（最大吸附容量，mg/g，只提取论文中明确给出的数值）
- removal_rate_pct（去除率，%）
- pH, temperature_C（实验条件）
- kinetics_model（动力学模型，如 pseudo-second-order）
- isotherm_model（等温线模型，如 Langmuir）
- selectivity（选择性描述）
- reusability_cycles（循环次数）
- data_source（"experimental" / "reported" / "estimated"）
- reference（数据来源位置，如"Table 2"）
- confidence（数据可靠度）

**重要**：
- qmax 和 removal_rate 如果论文未报告，填 null，不要估算
- data_source = "experimental" 仅当数据来自作者自己的实验
- data_source = "reported" 当数据引自其他文献

### 步骤4：多尺度结构特征

从论文中识别四个尺度的结构特征：
- macro_scale（宏观，>100μm）
- meso_scale（介观，2-50nm）
- micro_scale（微观，1-100μm）
- nano_scale（纳米，<2nm）

每个尺度包含：feature（特征描述）、size_range（尺寸范围）、function（功能作用）

同时描述 structure_function_relationship（结构-功能关系的综合描述）。

### 步骤5：吸附机制详解

对论文中讨论的**每个**吸附机制：

1. mechanism_name：使用标准机制名称（从以下列表中选择）
   标准名称：配位螯合, 静电吸附, pi-pi堆积, 氢键, 离子交换, 微孔吸附, 介孔吸附, 大孔吸附, 层次孔吸附, 超疏水分离, 超滑表面, 分子筛分, 网络过滤, 生物矿化, 生物沉淀, 生物积累, 催化降解

2. phenomenon：可观察到的吸附/粘附/分离现象
3. molecular_basis：分子层面的解释（可多条）
4. key_functional_groups：关键官能团及其角色
5. biomimetic_inspiration：对仿生材料设计的启示
6. supporting_evidence：论文中的支持证据

### 步骤6：工程约束评估

评估以下11项工程约束的适用性：
- 抗菌性 (Antimicrobial)
- 耐酸性 (Acid resistance)
- 耐碱性 (Alkali resistance)
- 可回收性 (Recyclability)
- 低成本 (Low cost)
- 高吸附容量 (High capacity)
- 快速吸附 (Fast adsorption)
- 高选择性 (High selectivity)
- 易合成 (Easy synthesis)
- 环境友好 (Eco-friendly)

对每项约束给出 assessment（high/medium/low）和 explanation。
仅评估论文中有证据支持的约束，没有证据的不要填。

---

## 词汇规范化规则

提取结果中的特征、机制、污染物名称必须使用以下标准词汇。如果论文中使用了非标准表述，请映射到对应的标准词汇。

### 特征标签标准词汇（映射到 feature-mapping.json）

| 标准标签 | 常见文献表述 |
|---------|------------|
| 邻苯二酚基团 | catechol, DOPA, 3,4-dihydroxyphenylalanine, polydopamine |
| 疏水性 | hydrophobic, water-repellent, oleophilic |
| 亲水性 | hydrophilic, water-attracting |
| 正电表面 | positively charged, cationic surface, positive zeta potential |
| 负电表面 | negatively charged, anionic surface, negative zeta potential |
| 微孔 | microporous, micropore, pore <2nm |
| 介孔 | mesoporous, mesopore, pore 2-50nm |
| 大孔 | macroporous, macropore, pore >50nm |
| 层次孔 | hierarchical pores, multi-scale porosity |
| 纤维状 | fibrous, fiber, nanofiber, filament |
| 层状 | layered, lamellar, nacre-like |
| 乳突阵列 | papilla array, papillae |
| 网状 | network, mesh, interconnected |
| 氨基 | amino group, amine, -NH2 |
| 羧基 | carboxyl group, -COOH, carboxylic acid |
| 巯基 | thiol group, -SH, sulfhydryl |
| 金属配位能力 | metal coordination, chelation, metal binding |
| pi电子体系 | pi electron, aromatic ring, conjugated system |
| 活性氧位点 | reactive oxygen species, ROS, catalytic site |
| 湿态粘附 | wet adhesion, underwater adhesion |
| 自清洁 | self-cleaning, anti-fouling |
| 催化降解 | catalytic degradation, photocatalytic, Fenton |
| 离子交换 | ion exchange, cation exchange |
| 分子筛分 | molecular sieving, size exclusion |
| 生物矿化模板 | biomineralization, biomineral template |
| 抗生物污林 | anti-biofouling, antimicrobial, antibacterial |

### 机制标准名称

配位螯合, 静电吸附, pi-pi堆积, 氢键, 离子交换, 微孔吸附, 介孔吸附, 大孔吸附, 层次孔吸附, 超疏水分离, 超滑表面, 分子筛分, 网络过滤, 生物矿化, 生物沉淀, 生物积累, 催化降解

### 污染物标准名称

重金属：Hg²⁺, Cd²⁺, Pb²⁺, Cu²⁺, Zn²⁺, Ni²⁺, Cr³⁺/Cr⁶⁺, As³⁺/As⁵⁺
有机：阳离子染料, 阴离子染料, 芳香族化合物, 抗生素
无机：NH₄⁺-N, NO₃⁻, PO₄³⁻, F⁻
油类：原油, 柴油, 乳化油
放射性：U, Sr, Cs

---

## 多模态提取指令

如果论文中包含以下类型的图表，请额外提取相关信息：

- **SEM/TEM图像**：描述形貌特征（颗粒大小、孔隙结构、表面粗糙度），提取尺寸数据，标注与吸附性能的关系
- **吸附等温线图**：提取qmax值和等温线模型（Langmuir/Freundlich等）
- **动力学曲线**：提取动力学模型（伪一级/伪二级）和速率常数
- **FTIR/XPS谱图**：识别关键官能团和化学键信息
- **对比表格**：提取不同材料/条件下的性能对比数据
- **机理示意图**：提取吸附机制的可视化描述

---

## 输出格式

严格遵循 `biomimetic_extraction.schema.json` 定义的JSON格式输出。

**关键规则**：
1. 所有字段名必须与Schema完全一致
2. 枚举值必须使用Schema定义的值
3. 未找到数据的数值字段填 null，不要留空字符串
4. 数组字段即使只有一个元素也要用数组格式
5. paper_id 格式：`第一作者姓_年份_关键词`（如 `zhang_2025_mussel_pda`）

---

## 质量自检清单

提取完成后，逐项检查：

- [ ] paper_id 是否为稳定短ID？
- [ ] 所有 prototype_id 是否在可用原型列表中？
- [ ] biomimetic_design_chain 的 nature_challenge 是否具体（非泛泛而谈）？
- [ ] performance_data 中的数值是否来自论文原文（非推断）？
- [ ] 机制名称是否使用标准名称？
- [ ] 污染物名称是否使用标准名称？
- [ ] 特征标签是否使用标准词汇？
- [ ] null 值是否正确使用（不要空字符串替代）？
```

- [ ] **Step 2: Commit**

```bash
git add prompts/biomimetic_extraction_prompt.md
git commit -m "feat: add biomimetic extraction prompt with 6-step workflow and vocabulary rules"
```

---

### Task 6: Write map_to_prototypes.py

**Files:**
- Create: `scripts/map_to_prototypes.py`
- Create: `tests/test_map_to_prototypes.py`

This script reads extraction result JSONs, normalizes vocabulary, matches them to prototypes, and aggregates results per prototype.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_map_to_prototypes.py`:

```python
"""Tests for map_to_prototypes.py."""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from map_to_prototypes import (
    load_vocabulary,
    load_prototype_routing,
    normalize_feature,
    normalize_mechanism,
    normalize_pollutant,
    match_prototypes,
    aggregate_by_prototype,
)


class TestLoadConfigs:
    def test_load_vocabulary(self, repo_root):
        vocab = load_vocabulary(repo_root / "config" / "vocabulary_mapping.json")
        assert "feature_mapping" in vocab
        assert "mechanism_mapping" in vocab
        assert "pollutant_mapping" in vocab

    def test_load_prototype_routing(self, repo_root):
        routing = load_prototype_routing(repo_root / "config" / "prototype_routing.json")
        assert "prototypes" in routing
        assert "mussel-foot-adhesion" in routing["prototypes"]


class TestNormalize:
    @pytest.fixture
    def vocab(self, repo_root):
        return load_vocabulary(repo_root / "config" / "vocabulary_mapping.json")

    def test_normalize_feature_exact_match(self, vocab):
        assert normalize_feature("catechol group", vocab) == "邻苯二酚基团"

    def test_normalize_feature_case_insensitive(self, vocab):
        assert normalize_feature("DOPA", vocab) == "邻苯二酚基团"

    def test_normalize_feature_unknown_returns_original(self, vocab):
        assert normalize_feature("unknown_feature_xyz", vocab) == "unknown_feature_xyz"

    def test_normalize_mechanism(self, vocab):
        assert normalize_mechanism("coordination chelation", vocab) == "配位螯合"

    def test_normalize_pollutant(self, vocab):
        assert normalize_pollutant("methylene blue", vocab) == "阳离子染料"

    def test_normalize_pollutant_cd(self, vocab):
        assert normalize_pollutant("Cd(II)", vocab) == "Cd2+"


class TestMatchPrototypes:
    @pytest.fixture
    def routing(self, repo_root):
        return load_prototype_routing(repo_root / "config" / "prototype_routing.json")

    def test_match_mussel_keywords(self, routing):
        text = "mussel-inspired polydopamine coating for DOPA-mediated heavy metal removal"
        matches = match_prototypes(text, routing)
        ids = [m["prototype_id"] for m in matches]
        assert "mussel-foot-adhesion" in ids

    def test_match_lotus_keywords(self, routing):
        text = "superhydrophobic surface inspired by lotus leaf with Cassie-Baxter state"
        matches = match_prototypes(text, routing)
        ids = [m["prototype_id"] for m in matches]
        assert "lotus-leaf" in ids

    def test_match_threshold_filters_weak(self, routing):
        text = "a generic paper about water treatment"
        matches = match_prototypes(text, routing)
        assert len(matches) == 0

    def test_max_prototypes_limit(self, routing):
        text = "mussel DOPA lotus superhydrophobic chitosan alginate MOF diatom"
        matches = match_prototypes(text, routing)
        assert len(matches) <= routing["routing_rules"]["max_prototypes_per_paper"]


class TestAggregateByPrototype:
    def test_aggregate_groups_results(self, sample_extraction_result):
        results = [sample_extraction_result]
        aggregated = aggregate_by_prototype(results)
        assert "mussel-foot-adhesion" in aggregated
        assert "polydopamine-coating" in aggregated

    def test_aggregate_empty_list(self):
        aggregated = aggregate_by_prototype([])
        assert aggregated == {}

    def test_aggregate_normalizes_performance_data(self, sample_extraction_result, repo_root):
        vocab = load_vocabulary(repo_root / "config" / "vocabulary_mapping.json")
        results = [sample_extraction_result]
        aggregated = aggregate_by_prototype(results, vocab=vocab)
        mussel_data = aggregated.get("mussel-foot-adhesion", {})
        perf = mussel_data.get("performance_data", [])
        if perf:
            assert perf[0]["pollutant"] == "Pb2+"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_map_to_prototypes.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'map_to_prototypes'`

- [ ] **Step 3: Write scripts/map_to_prototypes.py**

```python
#!/usr/bin/env python3
"""Map extraction results to biomimetic prototypes and aggregate by prototype.

Usage:
    python3 map_to_prototypes.py --input-dir outputs/extractions --output-dir outputs/aggregated
"""

import argparse
import json
import re
import sys
from pathlib import Path
from collections import defaultdict


def load_vocabulary(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def load_prototype_routing(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def normalize_feature(raw: str, vocab: dict) -> str:
    """Map a raw feature string to standard label via vocabulary_mapping."""
    fm = vocab.get("feature_mapping", {})
    lower = raw.lower().strip()
    if lower in fm:
        return fm[lower]
    for key, val in fm.items():
        if key.lower() in lower or lower in key.lower():
            return val
    return raw


def normalize_mechanism(raw: str, vocab: dict) -> str:
    mm = vocab.get("mechanism_mapping", {})
    lower = raw.lower().strip()
    if lower in mm:
        return mm[lower]
    for key, val in mm.items():
        if key.lower() in lower or lower in key.lower():
            return val
    return raw


def normalize_pollutant(raw: str, vocab: dict) -> str:
    pm = vocab.get("pollutant_mapping", {})
    lower = raw.lower().strip()
    if lower in pm:
        return pm[lower]
    for key, val in pm.items():
        if key.lower() in lower or lower in key.lower():
            return val
    return raw


def match_prototypes(text: str, routing: dict) -> list:
    """Match free text against prototype keywords. Return top matches."""
    rules = routing.get("routing_rules", {})
    threshold = rules.get("match_threshold", 2)
    max_proto = rules.get("max_prototypes_per_paper", 3)
    case_insensitive = rules.get("case_insensitive", True)

    if case_insensitive:
        text_lower = text.lower()
    else:
        text_lower = text

    scores = []
    for proto_id, proto_cfg in routing.get("prototypes", {}).items():
        count = 0
        keywords = proto_cfg.get("keywords_en", []) + proto_cfg.get("keywords_cn", [])
        for kw in keywords:
            kw_check = kw.lower() if case_insensitive else kw
            if kw_check in text_lower:
                count += 1
        if count >= threshold:
            confidence = "high" if count >= threshold * 2 else "medium"
            scores.append({
                "prototype_id": proto_id,
                "match_confidence": confidence,
                "keyword_hits": count,
            })

    scores.sort(key=lambda x: x["keyword_hits"], reverse=True)
    return scores[:max_proto]


def normalize_extraction(result: dict, vocab: dict) -> dict:
    """Normalize vocabulary terms in an extraction result (in-place)."""
    for perf in result.get("performance_data", []):
        if perf.get("pollutant"):
            perf["pollutant"] = normalize_pollutant(perf["pollutant"], vocab)

    for mech in result.get("mechanism_analysis", []):
        if mech.get("mechanism_name"):
            mech["mechanism_name"] = normalize_mechanism(mech["mechanism_name"], vocab)

    chain = result.get("biomimetic_design_chain", {})
    for fg in chain.get("key_functional_groups", []):
        if fg.get("group"):
            fg["group"] = normalize_feature(fg["group"], vocab)

    return result


def aggregate_by_prototype(results: list, vocab: dict = None) -> dict:
    """Group extraction results by prototype_id.

    Each result may have prototype_associations; we group by those.
    Returns {prototype_id: {performance_data: [], mechanism_analysis: [], ...}}
    """
    aggregated = defaultdict(lambda: {
        "performance_data": [],
        "mechanism_analysis": [],
        "biomimetic_design_chains": [],
        "structural_features": [],
        "engineering_constraints": [],
        "papers": [],
    })

    for result in results:
        if vocab:
            normalize_extraction(result, vocab)

        paper_id = result.get("paper_id", "unknown")
        associations = result.get("prototype_associations", [])

        for assoc in associations:
            pid = assoc.get("prototype_id")
            if not pid:
                continue

            bucket = aggregated[pid]
            bucket["papers"].append({
                "paper_id": paper_id,
                "confidence": assoc.get("match_confidence", "low"),
            })

            bucket["performance_data"].extend(
                result.get("performance_data", [])
            )
            bucket["mechanism_analysis"].extend(
                result.get("mechanism_analysis", [])
            )

            chain = result.get("biomimetic_design_chain")
            if chain:
                bucket["biomimetic_design_chains"].append({
                    "paper_id": paper_id,
                    "chain": chain,
                })

            sf = result.get("structural_features")
            if sf:
                bucket["structural_features"].append({
                    "paper_id": paper_id,
                    "features": sf,
                })

            bucket["engineering_constraints"].extend(
                result.get("engineering_constraints", [])
            )

    return dict(aggregated)


def load_extraction_results(input_dir: Path) -> list:
    """Load all JSON extraction results from a directory."""
    results = []
    if not input_dir.exists():
        return results
    for json_file in sorted(input_dir.rglob("*.json")):
        try:
            with open(json_file) as f:
                data = json.load(f)
            if isinstance(data, dict) and data.get("schema_version") == "biomimetic-v1":
                results.append(data)
        except (json.JSONDecodeError, KeyError):
            continue
    return results


def main():
    parser = argparse.ArgumentParser(description="Map extraction results to prototypes")
    parser.add_argument("--input-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument(
        "--vocab",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "config" / "vocabulary_mapping.json",
    )
    parser.add_argument(
        "--routing",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "config" / "prototype_routing.json",
    )
    args = parser.parse_args()

    vocab = load_vocabulary(args.vocab)
    routing = load_prototype_routing(args.routing)
    results = load_extraction_results(args.input_dir)
    print(f"Loaded {len(results)} extraction results from {args.input_dir}")

    # For results without prototype_associations, try keyword matching
    for result in results:
        if not result.get("prototype_associations"):
            text = " ".join([
                result.get("bibliographic_metadata", {}).get("title", ""),
                result.get("bibliographic_metadata", {}).get("abstract", ""),
                " ".join(result.get("bibliographic_metadata", {}).get("keywords", [])),
            ])
            matches = match_prototypes(text, routing)
            result["prototype_associations"] = [
                {"prototype_id": m["prototype_id"], "match_confidence": m["match_confidence"]}
                for m in matches
            ]

    aggregated = aggregate_by_prototype(results, vocab=vocab)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for proto_id, data in aggregated.items():
        out_path = args.output_dir / f"{proto_id}.json"
        with open(out_path, "w") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        n_papers = len(data["papers"])
        n_perf = len(data["performance_data"])
        print(f"  {proto_id}: {n_papers} papers, {n_perf} performance records")

    print(f"\nAggregated {len(aggregated)} prototypes → {args.output_dir}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest tests/test_map_to_prototypes.py -v`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/map_to_prototypes.py tests/test_map_to_prototypes.py
git commit -m "feat: add prototype mapping and aggregation script with tests"
```

---

### Task 7: Write generate_prototype_md.py

**Files:**
- Create: `scripts/generate_prototype_md.py`
- Create: `tests/test_generate_prototype_md.py`

This script reads aggregated prototype JSON and generates a `prototype.md` conforming to the template at `templates/prototype-template.md`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_generate_prototype_md.py`:

```python
"""Tests for generate_prototype_md.py."""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from generate_prototype_md import (
    generate_frontmatter,
    generate_section1_intro,
    generate_section2_mechanisms,
    generate_section3_structure,
    generate_section4_performance,
    generate_section5_narrative,
    generate_section6_scenarios,
    generate_section7_related,
    generate_references,
    generate_prototype_md,
)


@pytest.fixture
def aggregated_mussel():
    """Sample aggregated data for mussel-foot-adhesion."""
    return {
        "performance_data": [
            {
                "pollutant": "Pb2+",
                "material_form": "PDA-coated Fe3O4 nanoparticles",
                "qmax_mg_g": 185.2,
                "removal_rate_pct": 96.5,
                "pH": 5.0,
                "temperature_C": 25,
                "kinetics_model": "pseudo-second-order",
                "isotherm_model": "Langmuir",
                "data_source": "experimental",
                "reference": "Table 2, Zhang 2025",
                "confidence": "high",
            },
        ],
        "mechanism_analysis": [
            {
                "mechanism_name": "配位螯合",
                "phenomenon": "PDA strongly binds heavy metal ions",
                "molecular_basis": ["Catechol groups form bidentate ligands"],
                "key_functional_groups": [
                    {"group": "catechol (-OH)", "role": "Primary coordination site"},
                ],
                "biomimetic_inspiration": "DOPA-rich coatings for universal metal capture",
                "supporting_evidence": "XPS O 1s peak shift after Pb2+ adsorption",
            },
        ],
        "biomimetic_design_chains": [
            {
                "paper_id": "zhang_2025_mussel",
                "chain": {
                    "nature_challenge": "Mussels must adhere to wet surfaces in turbulent intertidal zones",
                    "evolutionary_strategy": "Secrete DOPA-rich foot proteins",
                    "key_mechanisms": ["Catechol-metal coordination"],
                    "key_functional_groups": [
                        {"group": "catechol", "function": "Bidentate metal coordination"},
                    ],
                    "bio_to_material_mapping": [
                        {
                            "bio_feature": "DOPA catechol group",
                            "material_design": "PDA coating on substrates",
                            "confidence": "high",
                        },
                    ],
                    "must_keep_features": [
                        {"feature": "catechol group", "reason": "Essential for metal coordination"},
                    ],
                    "adjustable_features": [
                        {"feature": "coating thickness", "adjustment_range": "10-200 nm"},
                    ],
                    "one_line_story": "Mimicking mussel DOPA for adhesive coatings",
                    "design_traceability": "From Mytilus edulis to PDA dip-coating",
                },
            },
        ],
        "structural_features": [
            {
                "paper_id": "zhang_2025_mussel",
                "features": {
                    "macro_scale": {"feature": "Aggregated clusters", "size_range": "50-200 nm", "function": "Easy recovery"},
                    "meso_scale": {"feature": "Mesoporous PDA shell", "size_range": "2-10 nm", "function": "High surface area"},
                    "micro_scale": {"feature": "Core-shell structure", "size_range": "20-50 nm shell", "function": "Magnetic + adsorption"},
                    "nano_scale": {"feature": "Catechol groups", "size_range": "<1 nm", "function": "Coordination sites"},
                    "structure_function_relationship": "Core-shell combines magnetic recovery with catechol sites",
                },
            },
        ],
        "engineering_constraints": [
            {"constraint": "高吸附容量", "assessment": "high", "explanation": "qmax=185.2 mg/g"},
        ],
        "papers": [
            {"paper_id": "zhang_2025_mussel", "confidence": "high"},
        ],
    }


class TestGenerateFrontmatter:
    def test_contains_required_yaml_fields(self, aggregated_mussel):
        fm = generate_frontmatter("mussel-foot-adhesion", aggregated_mussel)
        assert "id: mussel-foot-adhesion" in fm
        assert "features:" in fm
        assert "pollutants:" in fm
        assert "adsorption_mechanisms:" in fm

    def test_includes_pollutant_from_performance(self, aggregated_mussel):
        fm = generate_frontmatter("mussel-foot-adhesion", aggregated_mussel)
        assert "Pb2+" in fm

    def test_includes_mechanism(self, aggregated_mussel):
        fm = generate_frontmatter("mussel-foot-adhesion", aggregated_mussel)
        assert "配位螯合" in fm


class TestGenerateSections:
    def test_section1_intro_not_empty(self, aggregated_mussel):
        section = generate_section1_intro("mussel-foot-adhesion", aggregated_mussel)
        assert len(section) > 50

    def test_section2_mechanisms_includes_mechanism_name(self, aggregated_mussel):
        section = generate_section2_mechanisms(aggregated_mussel)
        assert "配位螯合" in section
        assert "现象" in section

    def test_section3_structure_includes_table(self, aggregated_mussel):
        section = generate_section3_structure(aggregated_mussel)
        assert "宏观" in section
        assert "纳米" in section

    def test_section4_performance_includes_data_table(self, aggregated_mussel):
        section = generate_section4_performance(aggregated_mussel)
        assert "185.2" in section
        assert "Pb2+" in section

    def test_section5_narrative_has_subsections(self, aggregated_mussel):
        section = generate_section5_narrative(aggregated_mussel)
        assert "5.1" in section
        assert "5.2" in section
        assert "5.3" in section

    def test_section4_empty_when_no_data(self):
        section = generate_section4_performance({"performance_data": []})
        assert "暂无" in section or "待补充" in section or len(section.strip()) < 200


class TestGenerateFullPrototype:
    def test_full_md_generation(self, aggregated_mussel):
        md = generate_prototype_md("mussel-foot-adhesion", aggregated_mussel)
        assert "---" in md  # frontmatter
        assert "## 1." in md
        assert "## 2." in md
        assert "## 5." in md
        assert "mussel" in md.lower() or "贻贝" in md

    def test_references_section(self, aggregated_mussel):
        section = generate_references(aggregated_mussel)
        assert "zhang_2025_mussel" in section
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_generate_prototype_md.py -v`
Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Write scripts/generate_prototype_md.py**

```python
#!/usr/bin/env python3
"""Generate prototype.md files from aggregated extraction data.

Usage:
    python3 generate_prototype_md.py --input-dir outputs/aggregated --biomimetic-lib /path/to/Biomimetic-design-library
"""

import argparse
import json
import os
from pathlib import Path


def generate_frontmatter(prototype_id: str, data: dict) -> str:
    """Generate YAML frontmatter block."""
    pollutants = sorted(set(
        p.get("pollutant", "") for p in data.get("performance_data", [])
        if p.get("pollutant")
    ))
    mechanisms = sorted(set(
        m.get("mechanism_name", "") for m in data.get("mechanism_analysis", [])
        if m.get("mechanism_name")
    ))
    features = sorted(set(
        fg.get("group", "")
        for chain_item in data.get("biomimetic_design_chains", [])
        for fg in chain_item.get("chain", {}).get("key_functional_groups", [])
        if fg.get("group")
    ))

    # Determine qmax range
    qmax_values = [
        p.get("qmax_mg_g") for p in data.get("performance_data", [])
        if p.get("qmax_mg_g") is not None
    ]
    qmax_range = ""
    if qmax_values:
        qmax_range = f"{min(qmax_values):.1f}~{max(qmax_values):.1f} mg/g"

    # Determine engineering constraints
    constraints = data.get("engineering_constraints", [])
    constraint_lines = []
    for c in constraints:
        constraint_lines.append(
            f"  - constraint: {c.get('constraint', '')}\n"
            f"    relevance: {c.get('assessment', 'medium')}\n"
            f"    explanation: {c.get('explanation', '')}"
        )

    pollutants_str = json.dumps(pollutants, ensure_ascii=False) if pollutants else "[]"
    mechanisms_str = json.dumps(mechanisms, ensure_ascii=False) if mechanisms else "[]"
    features_str = json.dumps(features, ensure_ascii=False) if features else "[]"
    constraints_str = "\n".join(constraint_lines) if constraint_lines else "  []"

    lines = [
        "---",
        f"id: {prototype_id}",
        f"name: {prototype_id}",
        f"features: {features_str}",
        f"pollutants: {pollutants_str}",
        f"adsorption_mechanisms: {mechanisms_str}",
        f'qmax_range: "{qmax_range}"' if qmax_range else 'qmax_range: "待补充"',
        'removal_rate: "待补充"',
        "applicability:",
        "  pH_range: [待补充, 待补充]",
        "  temp_range: [待补充, 待补充]",
        "  salinity: 待补充",
        "evidence_level: medium",
        "engineering_constraints:",
        constraints_str,
        "---",
    ]
    return "\n".join(lines)


def generate_section1_intro(prototype_id: str, data: dict) -> str:
    """Section 1: Biological Prototype Introduction."""
    chains = data.get("biomimetic_design_chains", [])
    if chains:
        chain = chains[0].get("chain", {})
        challenge = chain.get("nature_challenge", "待补充")
        strategy = chain.get("evolutionary_strategy", "待补充")
        intro = f"{challenge}\n\n{strategy}"
    else:
        intro = "[待补充：生物原型简介，200-300字]"

    return f"## 1. 生物原型简介\n\n{intro}"


def generate_section2_mechanisms(data: dict) -> str:
    """Section 2: Adsorption Mechanism Details."""
    mechanisms = data.get("mechanism_analysis", [])
    if not mechanisms:
        return "## 2. 吸附机制详解\n\n[待补充]"

    sections = ["## 2. 吸附机制详解"]
    seen = set()
    for i, mech in enumerate(mechanisms, 1):
        name = mech.get("mechanism_name", f"机制{i}")
        if name in seen:
            continue
        seen.add(name)

        phenomenon = mech.get("phenomenon", "待补充")
        mol_basis = "\n".join(
            f"- {b}" for b in mech.get("molecular_basis", ["待补充"])
        )
        fg_lines = "\n".join(
            f"- {fg.get('group', '')} → {fg.get('role', '')}"
            for fg in mech.get("key_functional_groups", [])
        ) or "- 待补充"
        inspiration = mech.get("biomimetic_inspiration", "待补充")
        evidence = mech.get("supporting_evidence", "待补充")

        sections.append(
            f"\n### 机制{i}：{name}\n\n"
            f"**现象**：{phenomenon}\n\n"
            f"**分子基础**：\n{mol_basis}\n\n"
            f"**关键官能团**：\n{fg_lines}\n\n"
            f"**仿生设计启示**：\n- {inspiration}\n\n"
            f"**支持证据**：{evidence}"
        )
    return "\n".join(sections)


def generate_section3_structure(data: dict) -> str:
    """Section 3: Structural Features."""
    sf_list = data.get("structural_features", [])
    if not sf_list:
        return (
            "## 3. 结构特征与结构-功能关系\n\n"
            "### 多尺度结构描述\n\n"
            "| 尺度 | 特征 | 尺寸范围 | 功能作用 |\n"
            "|------|------|----------|----------|\n"
            "| 宏观 | 待补充 | 待补充 | 待补充 |\n"
            "| 介观 | 待补充 | 待补充 | 待补充 |\n"
            "| 微观 | 待补充 | 待补充 | 待补充 |\n"
            "| 纳米 | 待补充 | 待补充 | 待补充 |\n"
        )

    sf = sf_list[0].get("features", {})
    scales = ["macro_scale", "meso_scale", "micro_scale", "nano_scale"]
    scale_names = {"macro_scale": "宏观", "meso_scale": "介观", "micro_scale": "微观", "nano_scale": "纳米"}

    table_rows = []
    for s in scales:
        info = sf.get(s) or {}
        table_rows.append(
            f"| {scale_names[s]} | {info.get('feature', '待补充')} "
            f"| {info.get('size_range', '待补充')} "
            f"| {info.get('function', '待补充')} |"
        )

    sfr = sf.get("structure_function_relationship", "待补充")

    return (
        "## 3. 结构特征与结构-功能关系\n\n"
        "### 多尺度结构描述\n\n"
        "| 尺度 | 特征 | 尺寸范围 | 功能作用 |\n"
        "|------|------|----------|----------|\n"
        + "\n".join(table_rows) + "\n\n"
        f"### 结构-功能关系\n\n{sfr}"
    )


def generate_section4_performance(data: dict) -> str:
    """Section 4: Performance Data Table."""
    perf = data.get("performance_data", [])
    if not perf:
        return "## 4. 已报道性能数据\n\n[暂无可靠文献数据，待补充]"

    header = "| 污染物 | 材料形态 | 去除率(%) | qmax(mg/g) | pH | 温度(°C) | 数据来源 | 文献 |\n"
    header += "|--------|----------|-----------|------------|-----|----------|----------|------|\n"
    rows = []
    seen = set()
    for p in perf:
        key = (p.get("pollutant", ""), p.get("qmax_mg_g"), p.get("reference", ""))
        if key in seen:
            continue
        seen.add(key)
        qmax = f"{p['qmax_mg_g']:.1f}" if p.get("qmax_mg_g") is not None else "-"
        rr = f"{p['removal_rate_pct']:.1f}" if p.get("removal_rate_pct") is not None else "-"
        ph = f"{p['pH']:.1f}" if p.get("pH") is not None else "-"
        temp = f"{p['temperature_C']:.0f}" if p.get("temperature_C") is not None else "-"
        rows.append(
            f"| {p.get('pollutant', '-')} "
            f"| {p.get('material_form', '-')} "
            f"| {rr} "
            f"| {qmax} "
            f"| {ph} "
            f"| {temp} "
            f"| {p.get('data_source', '-')} "
            f"| {p.get('reference', '-')} |"
        )
    return "## 4. 已报道性能数据\n\n" + header + "\n".join(rows)


def generate_section5_narrative(data: dict) -> str:
    """Section 5: Biomimetic Design Narrative."""
    chains = data.get("biomimetic_design_chains", [])
    if not chains:
        return (
            "## 5. 仿生设计叙事\n\n"
            "### 5.1 问题定义\n\n[待补充]\n\n"
            "### 5.2 生物解决方案\n\n[待补充]\n\n"
            "### 5.3 关键特征提取\n\n[待补充]\n\n"
            "### 5.4 设计思路映射\n\n[待补充]\n\n"
            "### 5.5 可解释性锚点\n\n[待补充]"
        )

    chain = chains[0].get("chain", {})

    # 5.1 Problem
    nature_challenge = chain.get("nature_challenge", "待补充")

    # 5.2 Biological Solution
    evo_strategy = chain.get("evolutionary_strategy", "待补充")
    mechanisms = "\n".join(
        f"- {m}" for m in chain.get("key_mechanisms", ["待补充"])
    )

    # 5.3 Key Features
    must_keep = "\n".join(
        f"- **{f.get('feature', '')}**：{f.get('reason', '')}"
        for f in chain.get("must_keep_features", [])
    ) or "- 待补充"
    adjustable = "\n".join(
        f"- **{f.get('feature', '')}**：{f.get('adjustment_range', '')}"
        for f in chain.get("adjustable_features", [])
    ) or "- 待补充"

    # 5.4 Design Mapping
    bio_map = "\n".join(
        f"- {m.get('bio_feature', '')} → {m.get('material_design', '')}"
        for m in chain.get("bio_to_material_mapping", [])
    ) or "- 待补充"

    # 5.5 Explainability
    one_liner = chain.get("one_line_story", "待补充")
    trace = chain.get("design_traceability", "待补充")

    return (
        "## 5. 仿生设计叙事\n\n"
        f"### 5.1 问题定义\n\n**自然界中的挑战**：{nature_challenge}\n\n"
        f"### 5.2 生物解决方案\n\n**进化策略**：{evo_strategy}\n\n"
        f"**关键机制**：\n{mechanisms}\n\n"
        f"### 5.3 关键特征提取\n\n"
        f"**必须保留的特征**：\n{must_keep}\n\n"
        f"**可灵活调整的特征**：\n{adjustable}\n\n"
        f"### 5.4 设计思路映射\n\n**从生物到材料**：\n{bio_map}\n\n"
        f"### 5.5 可解释性锚点\n\n"
        f"**仿生故事线**：{one_liner}\n\n"
        f"**设计溯源**：{trace}"
    )


def generate_section6_scenarios(data: dict) -> str:
    """Section 6: Applicable Scenarios."""
    constraints = data.get("engineering_constraints", [])
    if constraints:
        suitable = [c["constraint"] for c in constraints if c.get("assessment") == "high"]
        suitable_str = "、".join(suitable) if suitable else "待补充"
    else:
        suitable_str = "待补充"

    return (
        "## 6. 适用场景\n\n"
        f"**最适合**：{suitable_str}\n\n"
        "**不适用的情况**：待补充"
    )


def generate_section7_related(data: dict) -> str:
    """Section 7: Related Prototypes."""
    return "## 7. 相关原型\n\n- 待补充"


def generate_references(data: dict) -> str:
    """References section from paper list."
    papers = data.get("papers", [])
    if not papers:
        return "## 参考文献\n\n[待补充]"
    refs = [f"[{i+1}] {p.get('paper_id', 'unknown')}" for i, p in enumerate(papers)]
    return "## 参考文献\n\n" + "\n".join(refs)


def generate_prototype_md(prototype_id: str, data: dict) -> str:
    """Generate complete prototype.md content."""
    parts = [
        generate_frontmatter(prototype_id, data),
        "",
        f"# {prototype_id}",
        "",
        generate_section1_intro(prototype_id, data),
        "",
        generate_section2_mechanisms(data),
        "",
        generate_section3_structure(data),
        "",
        generate_section4_performance(data),
        "",
        generate_section5_narrative(data),
        "",
        generate_section6_scenarios(data),
        "",
        generate_section7_related(data),
        "",
        generate_references(data),
    ]
    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser(description="Generate prototype.md files")
    parser.add_argument("--input-dir", required=True, type=Path)
    parser.add_argument(
        "--biomimetic-lib",
        type=Path,
        default=Path(os.environ.get(
            "BIOMIMETIC_LIB",
            Path(__file__).resolve().parent.parent.parent / "Biomimetic-design-library",
        )),
    )
    parser.add_argument("--dry-run", action="store_true", help="Print output instead of writing")
    args = parser.parse_args()

    proto_dir = args.biomimetic_lib / "prototypes"
    written = 0

    for json_file in sorted(args.input_dir.glob("*.json")):
        proto_id = json_file.stem
        with open(json_file) as f:
            data = json.load(f)

        md = generate_prototype_md(proto_id, data)

        if args.dry_run:
            print(f"=== {proto_id} ===")
            print(md[:500])
            print("...")
        else:
            target_dir = proto_dir / proto_id
            target_dir.mkdir(parents=True, exist_ok=True)
            target_path = target_dir / "prototype.md"
            with open(target_path, "w") as f:
                f.write(md)
            written += 1
            print(f"  Written: {target_path}")

    if not args.dry_run:
        print(f"\nGenerated {written} prototype.md files")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest tests/test_generate_prototype_md.py -v`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate_prototype_md.py tests/test_generate_prototype_md.py
git commit -m "feat: add prototype.md generator with template-compliant output and tests"
```

---

### Task 8: Write update_feature_mapping.py

**Files:**
- Create: `scripts/update_feature_mapping.py`
- Create: `tests/test_update_feature_mapping.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_update_feature_mapping.py`:

```python
"""Tests for update_feature_mapping.py."""

import copy
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from update_feature_mapping import (
    compute_evidence_weight,
    update_pollutant_weights,
    update_feature_weights,
    update_feature_mapping,
)


class TestComputeEvidenceWeight:
    def test_high_confidence_experimental(self):
        w = compute_evidence_weight(
            confidence="high", data_source="experimental", match_confidence="high"
        )
        assert 0.5 <= w <= 1.0

    def test_low_confidence_estimated(self):
        w = compute_evidence_weight(
            confidence="low", data_source="estimated", match_confidence="low"
        )
        assert 0.0 < w < 0.5

    def test_none_inputs_returns_minimum(self):
        w = compute_evidence_weight(None, None, None)
        assert w == 0.1


class TestUpdatePollutantWeights:
    def test_adds_new_prototype_entry(self):
        fm = {
            "pollutant_prototype_map": {
                "重金属": {
                    "Pb2+": {
                        "prototypes": [
                            {"id": "chitosan", "weight": 0.9, "mechanism_summary": "", "design_hint": ""}
                        ]
                    }
                }
            }
        }
        perf = [{"pollutant": "Pb2+", "qmax_mg_g": 200, "confidence": "high", "data_source": "experimental"}]
        updated = update_pollutant_weights(fm, "mussel-foot-adhesion", perf, "配位螯合")
        proto_list = updated["pollutant_prototype_map"]["重金属"]["Pb2+"]["prototypes"]
        ids = [p["id"] for p in proto_list]
        assert "mussel-foot-adhesion" in ids

    def test_does_not_overwrite_higher_weight(self):
        fm = {
            "pollutant_prototype_map": {
                "重金属": {
                    "Pb2+": {
                        "prototypes": [
                            {"id": "mussel-foot-adhesion", "weight": 0.95, "mechanism_summary": "", "design_hint": ""}
                        ]
                    }
                }
            }
        }
        perf = [{"pollutant": "Pb2+", "qmax_mg_g": 100, "confidence": "medium", "data_source": "reported"}]
        updated = update_pollutant_weights(fm, "mussel-foot-adhesion", perf, "配位螯合")
        proto_list = updated["pollutant_prototype_map"]["重金属"]["Pb2+"]["prototypes"]
        mussel = [p for p in proto_list if p["id"] == "mussel-foot-adhesion"][0]
        assert mussel["weight"] == 0.95  # not overwritten


class TestUpdateFeatureWeights:
    def test_updates_existing_feature_weight(self):
        fm = {
            "feature_prototype_map": {
                "邻苯二酚基团": {
                    "dimension": "化学性质",
                    "description": "catechol",
                    "prototypes": [
                        {"id": "mussel-foot-adhesion", "weight": 0.8}
                    ]
                }
            }
        }
        updated = update_feature_weights(fm, "mussel-foot-adhesion", ["邻苯二酚基团"], 0.9)
        proto = updated["feature_prototype_map"]["邻苯二酚基团"]["prototypes"][0]
        assert proto["weight"] == 0.9

    def test_adds_new_prototype_to_feature(self):
        fm = {
            "feature_prototype_map": {
                "邻苯二酚基团": {
                    "dimension": "化学性质",
                    "description": "catechol",
                    "prototypes": []
                }
            }
        }
        updated = update_feature_weights(fm, "polydopamine-coating", ["邻苯二酚基团"], 0.85)
        protos = updated["feature_prototype_map"]["邻苯二酚基团"]["prototypes"]
        assert any(p["id"] == "polydopamine-coating" for p in protos)


class TestUpdateFeatureMapping:
    def test_full_update_returns_dict(self):
        fm = {
            "pollutant_prototype_map": {"重金属": {"Pb2+": {"prototypes": []}}},
            "feature_prototype_map": {"邻苯二酚基团": {"dimension": "化学性质", "description": "", "prototypes": []}},
            "prototype_metadata": {},
            "mechanism_feature_bridge": {},
            "constraint_prototype_map": {},
        }
        aggregated = {
            "mussel-foot-adhesion": {
                "performance_data": [
                    {"pollutant": "Pb2+", "qmax_mg_g": 200, "confidence": "high", "data_source": "experimental"}
                ],
                "mechanism_analysis": [
                    {"mechanism_name": "配位螯合", "key_functional_groups": [{"group": "邻苯二酚基团", "role": "coordination"}]}
                ],
                "engineering_constraints": [],
                "papers": [{"paper_id": "test", "confidence": "high"}],
            }
        }
        result = update_feature_mapping(fm, aggregated)
        assert isinstance(result, dict)
        assert "pollutant_prototype_map" in result
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_update_feature_mapping.py -v`
Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Write scripts/update_feature_mapping.py**

```python
#!/usr/bin/env python3
"""Update feature-mapping.json weights based on aggregated extraction results.

Usage:
    python3 update_feature_mapping.py --input-dir outputs/aggregated --biomimetic-lib /path/to/Biomimetic-design-library
"""

import argparse
import copy
import json
import os
from pathlib import Path


# Pollutant → category mapping for locating the right section in pollutant_prototype_map
POLLUTANT_CATEGORIES = {
    "Hg2+": "重金属", "Cd2+": "重金属", "Pb2+": "重金属", "Cu2+": "重金属",
    "Zn2+": "重金属", "Ni2+": "重金属", "Cr3+/Cr6+": "重金属", "As3+/As5+": "重金属",
    "Fe3+": "重金属", "Mn2+": "重金属", "Co2+": "重金属",
    "阳离子染料": "有机污染物", "阴离子染料": "有机污染物",
    "芳香族化合物": "有机污染物", "抗生素": "有机污染物",
    "NH4+-N": "无机非金属污染物", "NO3-": "无机非金属污染物",
    "PO43-": "无机非金属污染物", "F-": "无机非金属污染物",
    "原油": "油类", "柴油": "油类", "乳化油": "油类",
    "U": "放射性元素", "Sr": "放射性元素", "Cs": "放射性元素",
}


def compute_evidence_weight(confidence, data_source, match_confidence) -> float:
    """Compute a weight value (0.1-1.0) based on evidence quality."""
    score = 0.1
    conf_map = {"high": 0.4, "medium": 0.2, "low": 0.1}
    source_map = {"experimental": 0.3, "reported": 0.15, "estimated": 0.05}
    match_map = {"high": 0.3, "medium": 0.15, "low": 0.05}

    score += conf_map.get(confidence, 0)
    score += source_map.get(data_source, 0)
    score += match_map.get(match_confidence, 0)
    return min(score, 1.0)


def find_pollutant_category(pollutant: str, fm: dict) -> str:
    """Find which category a pollutant belongs to in the feature-mapping."""
    if pollutant in POLLUTANT_CATEGORIES:
        return POLLUTANT_CATEGORIES[pollutant]
    ppm = fm.get("pollutant_prototype_map", {})
    for category, subcats in ppm.items():
        if isinstance(subcats, dict):
            for key in subcats:
                if pollutant in key or key in pollutant:
                    return category
    return None


def update_pollutant_weights(fm: dict, prototype_id: str, performance_data: list, mechanism_name: str = "") -> dict:
    """Update pollutant_prototype_map with new evidence."""
    fm = copy.deepcopy(fm)
    ppm = fm.get("pollutant_prototype_map", {})

    for perf in performance_data:
        pollutant = perf.get("pollutant", "")
        if not pollutant:
            continue

        weight = compute_evidence_weight(
            perf.get("confidence"), perf.get("data_source"), "medium"
        )

        category = find_pollutant_category(pollutant, fm)
        if not category:
            continue

        subcats = ppm.get(category, {})
        target_key = None
        for key in subcats:
            if pollutant in key or key in pollutant:
                target_key = key
                break
        if not target_key:
            continue

        proto_list = subcats[target_key].get("prototypes", [])
        existing = [p for p in proto_list if p.get("id") == prototype_id]

        if existing:
            if existing[0].get("weight", 0) >= weight:
                continue  # don't overwrite higher weight
            existing[0]["weight"] = weight
        else:
            proto_list.append({
                "id": prototype_id,
                "weight": round(weight, 2),
                "mechanism_summary": mechanism_name,
                "design_hint": "",
            })

    return fm


def update_feature_weights(fm: dict, prototype_id: str, features: list, weight: float) -> dict:
    """Update feature_prototype_map with new weights."""
    fm = copy.deepcopy(fm)
    fpm = fm.get("feature_prototype_map", {})

    for feature in features:
        if feature not in fpm:
            continue
        proto_list = fpm[feature].get("prototypes", [])
        existing = [p for p in proto_list if p.get("id") == prototype_id]

        if existing:
            if existing[0].get("weight", 0) >= weight:
                continue
            existing[0]["weight"] = round(weight, 2)
        else:
            proto_list.append({"id": prototype_id, "weight": round(weight, 2)})

    return fm


def update_feature_mapping(fm: dict, aggregated: dict) -> dict:
    """Main update function: process all prototypes and update feature-mapping."""
    fm = copy.deepcopy(fm)

    for proto_id, data in aggregated.items():
        # Update pollutant weights
        perf_data = data.get("performance_data", [])
        mechanisms = data.get("mechanism_analysis", [])
        mechanism_name = mechanisms[0].get("mechanism_name", "") if mechanisms else ""
        fm = update_pollutant_weights(fm, proto_id, perf_data, mechanism_name)

        # Update feature weights
        features = set()
        for chain_item in data.get("biomimetic_design_chains", []):
            chain = chain_item.get("chain", {})
            for fg in chain.get("key_functional_groups", []):
                if fg.get("group"):
                    features.add(fg["group"])
        for mech in mechanisms:
            for fg in mech.get("key_functional_groups", []):
                if fg.get("group"):
                    features.add(fg["group"])

        if features:
            weight = 0.7  # default weight for feature evidence
            fm = update_feature_weights(fm, proto_id, list(features), weight)

    return fm


def main():
    parser = argparse.ArgumentParser(description="Update feature-mapping.json")
    parser.add_argument("--input-dir", required=True, type=Path)
    parser.add_argument(
        "--biomimetic-lib",
        type=Path,
        default=Path(os.environ.get(
            "BIOMIMETIC_LIB",
            Path(__file__).resolve().parent.parent.parent / "Biomimetic-design-library",
        )),
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    fm_path = args.biomimetic_lib / "feature-mapping.json"
    with open(fm_path) as f:
        fm = json.load(f)
    print(f"Loaded feature-mapping.json (version {fm.get('version', '?')})")

    aggregated = {}
    for json_file in sorted(args.input_dir.glob("*.json")):
        with open(json_file) as f:
            aggregated[json_file.stem] = json.load(f)
    print(f"Loaded {len(aggregated)} aggregated prototype files")

    updated_fm = update_feature_mapping(fm, aggregated)

    if args.dry_run:
        print("Dry run — no changes written")
        print(json.dumps(updated_fm, ensure_ascii=False, indent=2)[:1000])
    else:
        backup_path = fm_path.with_suffix(".json.bak")
        with open(backup_path, "w") as f:
            json.dump(fm, f, ensure_ascii=False, indent=2)
        print(f"Backup saved: {backup_path}")

        with open(fm_path, "w") as f:
            json.dump(updated_fm, f, ensure_ascii=False, indent=2)
        print(f"Updated: {fm_path}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest tests/test_update_feature_mapping.py -v`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/update_feature_mapping.py tests/test_update_feature_mapping.py
git commit -m "feat: add feature-mapping.json updater with confidence-based weight calculation"
```

---

### Task 9: Write biomimetic_pipeline.sh

**Files:**
- Create: `scripts/biomimetic_pipeline.sh`

This is the end-to-end entry script that chains all stages.

- [ ] **Step 1: Create scripts/biomimetic_pipeline.sh**

```bash
#!/usr/bin/env bash
# End-to-end biomimetic extraction pipeline.
#
# Stages:
#   0. PDF preprocessing (reuse preprocess.py)
#   1. OpenClaw batch extraction (reuse multi_worker_extract.sh)
#   2. Prototype mapping & aggregation (map_to_prototypes.py)
#   3. Library file generation (generate_prototype_md.py + update_feature_mapping.py)
#   4. Quality report
#
# Usage:
#   ./scripts/biomimetic_pipeline.sh --pdf-dir /path/to/pdfs --stage 0-4
#   ./scripts/biomimetic_pipeline.sh --pdf-dir /path/to/pdfs --stage 2-4  # skip extraction

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$REPO_DIR/scripts"
PYTHON_BIN="${PYTHON_BIN:-python3}"

BIOMIMETIC_LIB="${BIOMIMETIC_LIB:-$(dirname "$REPO_DIR")/Biomimetic-design-library}"
OUTPUT_DIR="$REPO_DIR/outputs"
EXTRACTION_DIR="$OUTPUT_DIR/extractions"
AGGREGATED_DIR="$OUTPUT_DIR/aggregated"

# ── Args ──────────────────────────────────────────────────────────
PDF_DIR=""
STAGE_START=0
STAGE_END=4
WORKERS=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf-dir)    PDF_DIR="$2"; shift 2 ;;
    --stage)
      IFS='-' read -r STAGE_START STAGE_END <<< "$2"
      shift 2 ;;
    --workers)    WORKERS="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --biomimetic-lib) BIOMIMETIC_LIB="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$PDF_DIR" ]]; then
  echo "Usage: $0 --pdf-dir /path/to/pdfs [--stage 0-4] [--workers 3]"
  exit 1
fi

echo "=== Biomimetic Extraction Pipeline ==="
echo "  PDF dir:     $PDF_DIR"
echo "  Output dir:  $OUTPUT_DIR"
echo "  Biomim lib:  $BIOMIMETIC_LIB"
echo "  Stages:      $STAGE_START - $STAGE_END"
echo "  Workers:     $WORKERS"
echo ""

mkdir -p "$OUTPUT_DIR" "$EXTRACTION_DIR" "$AGGREGATED_DIR"

# ── Stage 0: Preprocessing ────────────────────────────────────────
if [[ "$STAGE_START" -le 0 ]]; then
  echo "--- Stage 0: PDF Preprocessing ---"
  "$PYTHON_BIN" "$SCRIPTS/preprocess.py" \
    --pdf-dir "$PDF_DIR" \
    --output-dir "$OUTPUT_DIR/preprocessed" \
    2>&1 || echo "[WARN] Preprocessing had errors (continuing)"
  echo "  Done."
fi

# ── Stage 1: OpenClaw Extraction ─────────────────────────────────
if [[ "$STAGE_START" -le 1 && "$STAGE_END" -ge 1 ]]; then
  echo "--- Stage 1: OpenClaw Batch Extraction ---"
  MULTI_EXTRACT_RUN_DIR="/tmp/openclaw/biomimetic_runs/$(date +%Y%m%d%H%M%S)" \
  MULTIMODAL=1 \
  WORKERS="$WORKERS" \
  bash "$SCRIPTS/multi_worker_extract.sh" \
    "$PDF_DIR" \
    "$EXTRACTION_DIR" \
    "$REPO_DIR/prompts/biomimetic_extraction_prompt.md" \
    2>&1 || echo "[WARN] Extraction had errors (continuing)"
  echo "  Done."
fi

# ── Stage 2: Prototype Mapping & Aggregation ──────────────────────
if [[ "$STAGE_START" -le 2 && "$STAGE_END" -ge 2 ]]; then
  echo "--- Stage 2: Prototype Mapping & Aggregation ---"
  "$PYTHON_BIN" "$SCRIPTS/map_to_prototypes.py" \
    --input-dir "$EXTRACTION_DIR" \
    --output-dir "$AGGREGATED_DIR" \
    --vocab "$REPO_DIR/config/vocabulary_mapping.json" \
    --routing "$REPO_DIR/config/prototype_routing.json" \
    2>&1
  echo "  Done."
fi

# ── Stage 3: Library File Generation ──────────────────────────────
if [[ "$STAGE_START" -le 3 && "$STAGE_END" -ge 3 ]]; then
  echo "--- Stage 3: Library File Generation ---"

  echo "  3a. Generating prototype.md files..."
  "$PYTHON_BIN" "$SCRIPTS/generate_prototype_md.py" \
    --input-dir "$AGGREGATED_DIR" \
    --biomimetic-lib "$BIOMIMETIC_LIB" \
    2>&1

  echo "  3b. Updating feature-mapping.json..."
  "$PYTHON_BIN" "$SCRIPTS/update_feature_mapping.py" \
    --input-dir "$AGGREGATED_DIR" \
    --biomimetic-lib "$BIOMIMETIC_LIB" \
    2>&1

  echo "  Done."
fi

# ── Stage 4: Quality Report ──────────────────────────────────────
if [[ "$STAGE_END" -ge 4 ]]; then
  echo "--- Stage 4: Quality Report ---"

  TOTAL_PAPERS=$(find "$EXTRACTION_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
  TOTAL_PROTOS=$(ls "$AGGREGATED_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
  TOTAL_PROTO_MD=$(find "$BIOMIMETIC_LIB/prototypes" -name "prototype.md" 2>/dev/null | wc -l | tr -d ' ')

  PERF_COUNT=0
  NARRATIVE_COUNT=0
  for f in "$AGGREGATED_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    PC=$("$PYTHON_BIN" -c "import json; d=json.load(open('$f')); print(len(d.get('performance_data',[])))" 2>/dev/null || echo 0)
    PERF_COUNT=$((PERF_COUNT + PC))
    NC=$("$PYTHON_BIN" -c "import json; d=json.load(open('$f')); print(len(d.get('biomimetic_design_chains',[])))" 2>/dev/null || echo 0)
    NARRATIVE_COUNT=$((NARRATIVE_COUNT + NC))
  done

  REPORT="$OUTPUT_DIR/quality-report-$(date +%Y-%m-%d).md"
  cat > "$REPORT" << EOF
# Biomimetic Extraction Quality Report

Date: $(date +%Y-%m-%d %H:%M:%S)

## Summary

| Metric | Count |
|--------|-------|
| Papers processed | $TOTAL_PAPERS |
| Prototypes with data | $TOTAL_PROTOS |
| prototype.md files in library | $TOTAL_PROTO_MD |
| Performance data records | $PERF_COUNT |
| Biomimetic design chains | $NARRATIVE_COUNT |

## Coverage

Prototypes with data: $(ls "$AGGREGATED_DIR"/*.json 2>/dev/null | xargs -I{} basename {} .json | tr '\n' ', ')

## Next Steps

- Review prototype.md files for quality
- Check feature-mapping.json weight updates
- Supplement literature for zero-coverage prototypes
EOF

  echo "  Report saved: $REPORT"
fi

echo ""
echo "=== Pipeline Complete ==="
```

- [ ] **Step 2: Make executable**

```bash
chmod +x /Users/panyao/.qoderworkcn/workspace/mpzh27rt8uc58fyx/Literature-extracting/scripts/biomimetic_pipeline.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/biomimetic_pipeline.sh
git commit -m "feat: add end-to-end biomimetic extraction pipeline script"
```

---

### Task 10: Update openclaw.json

**Files:**
- Modify: `openclaw.json`

Add a `biomimetic-extract` agent alongside the existing `lit-extract` agent, and enable multimodal input on mimo and dashscope models.

- [ ] **Step 1: Update openclaw.json**

In the `models.providers` section, update `mimo` and `dashscope` to include `"image"` in their `input` arrays:

Change `mimo.models[0].input` from `["text"]` to `["text", "image"]`.
Change `dashscope.models[0].input` from `["text"]` to `["text", "image"]`.

In the `agents.list` array, add a new agent entry:

```json
{
  "id": "biomimetic-extract",
  "name": "biomimetic-extract",
  "workspace": "./workspace",
  "agentDir": "./agents/lit-extract/agent",
  "identity": {
    "name": "BiomimExtract",
    "theme": "仿生设计知识提取智能体",
    "emoji": "🧬"
  },
  "model": "mimo/mimo-v2.5-pro"
}
```

- [ ] **Step 2: Verify JSON validity**

Run: `python3 -c "import json; json.load(open('openclaw.json')); print('Valid JSON')"`
Expected: `Valid JSON`

- [ ] **Step 3: Commit**

```bash
git add openclaw.json
git commit -m "feat: add biomimetic-extract agent and enable multimodal input"
```

---

### Task 11: Run All Tests

- [ ] **Step 1: Run full test suite**

Run:
```bash
cd /Users/panyao/.qoderworkcn/workspace/mpzh27rt8uc58fyx/Literature-extracting
python3 -m pytest tests/ -v
```

Expected: All tests pass.

- [ ] **Step 2: Verify schema validates against sample fixture**

Run:
```bash
python3 -c "
import json
from jsonschema import validate
schema = json.load(open('schema/biomimetic_extraction.schema.json'))
# Create a minimal valid doc
doc = {
    'schema_version': 'biomimetic-v1',
    'paper_id': 'test',
    'bibliographic_metadata': {'title': 'T', 'authors': ['A'], 'year': 2025, 'abstract': 'A'},
    'prototype_associations': [{'prototype_id': 'lotus-leaf', 'match_confidence': 'high'}],
    'biomimetic_design_chain': {'nature_challenge': 'C', 'evolutionary_strategy': 'S', 'key_mechanisms': ['M'], 'one_line_story': 'O'},
    'performance_data': [],
    'structural_features': {},
    'mechanism_analysis': [],
    'engineering_constraints': [],
    'evidence_tracking': {}
}
validate(instance=doc, schema=schema)
print('Schema validation: PASS')
"
```

Expected: `Schema validation: PASS`

- [ ] **Step 3: Dry-run the pipeline scripts**

```bash
# Test map_to_prototypes with empty dir
python3 scripts/map_to_prototypes.py --input-dir /tmp/empty_test --output-dir /tmp/agg_test
# Should print "Loaded 0 extraction results"

# Test generate_prototype_md with sample data
mkdir -p /tmp/test_agg
echo '{"performance_data":[],"mechanism_analysis":[],"biomimetic_design_chains":[],"structural_features":[],"engineering_constraints":[],"papers":[]}' > /tmp/test_agg/test-proto.json
python3 scripts/generate_prototype_md.py --input-dir /tmp/test_agg --biomimetic-lib /tmp --dry-run
```

- [ ] **Step 4: Commit final state**

```bash
git add -A
git status
git commit -m "test: verify full pipeline integration" || echo "Nothing to commit"
```

---

### Task 12: Push and Document

- [ ] **Step 1: Push to GitHub**

```bash
git push origin biomimetic-extraction
```

- [ ] **Step 2: Update project board**

Update `docs/project-board.md` to mark T2-T10 as done.

- [ ] **Step 3: Update conversation context**

Update `docs/conversation-context.md` with implementation completion details.

- [ ] **Step 4: Final commit and push**

```bash
git add docs/
git commit -m "docs: update project board and context after implementation"
git push origin biomimetic-extraction
```
