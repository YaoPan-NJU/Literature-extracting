# 仿生设计库文献提参流水线 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Python project that automates the 4-phase literature extraction pipeline — coarse scan, gap analysis, targeted supplementation planning, and deep dive extraction — to populate 33 prototype entries in the Biomimetic Design Library from 341 existing PDFs plus supplemented literature.

**Architecture:** The project is a CLI-driven pipeline with 4 sequential phases. Each phase reads from the previous phase's output (JSON files), processes via LLM calls, and writes structured output. A unified LLM client routes requests to three API providers (Alibaba Cloud coding plan, Alibaba Cloud pay-per-use, Xiaomi MiMo) based on task complexity. PDF text extraction uses PyMuPDF. All configuration is externalized to `.env`.

**Tech Stack:** Python 3.11+, PyMuPDF (PDF extraction), OpenAI SDK (API-compatible client for all 3 providers), python-dotenv (config), Jinja2 (prompt templates), pytest (testing), pydantic (data models).

**API Providers:**

| Provider | Model | Base URL | Use Case |
|----------|-------|----------|----------|
| Alibaba Cloud coding plan | qwen3.6-plus (multimodal) | `https://coding.dashscope.aliyuncs.com/v1` | Phase 1 coarse scan |
| Alibaba Cloud pay-per-use | qwen3.7-max (single-modal) | `https://dashscope.aliyuncs.com/compatible-mode/v1` | Phase 2 deep reading, Phase 4 biomimetic extraction & weight assignment |
| Xiaomi MiMo token plan | Mimo-v2.5 (multimodal) | `https://token-plan-cn.xiaomimimo.com/v1` | Phase 4 multimodal extraction (tables/figures) |

---

## File Structure

```
extraction/                              # New directory in project root
├── .env.example                         # API key template (no real keys)
├── requirements.txt                     # Python dependencies
├── config.py                            # Settings loaded from .env
├── llm_client.py                        # Unified LLM client with model routing
├── pdf_utils.py                         # PDF text extraction (first page, full text, tables)
├── filename_parser.py                   # Parse year/author/keywords from filename
├── prototype_mapper.py                  # Map papers to prototypes via keywords + mechanism groups
├── prompts/                             # LLM prompt templates (Jinja2)
│   ├── coarse_extract.j2               # Phase 1: extract structured fields from abstract
│   ├── deep_performance.j2             # Phase 4: extract performance data from full text
│   ├── biomimetic_narrative.j2         # Phase 4: extract biomimetic design knowledge
│   └── weight_assign.j2               # Phase 4: assign weights to feature-mapping entries
├── pipeline/                            # Phase implementations
│   ├── __init__.py
│   ├── phase1_coarse_scan.py           # Batch coarse scan over all papers
│   ├── phase2_gap_analysis.py          # Gap analysis: breadth + depth assessment
│   ├── phase3_supplement_plan.py       # Generate targeted supplementation plan
│   └── phase4_deep_extract.py          # Deep extraction + weight assignment
├── validators.py                        # Automated quality checks on extraction results
├── writer.py                            # Write results to prototype.md and feature-mapping.json
├── run_pipeline.py                      # CLI entry point with phase selection
└── tests/
    ├── test_filename_parser.py
    ├── test_prototype_mapper.py
    ├── test_llm_client.py
    ├── test_pdf_utils.py
    └── test_validators.py
```

**Data flow (input → output):**

```
Literature PDFs (341)
    → Phase 1: coarse-profiles/*.json + coverage-heatmap.md
    → Phase 2: gap-analysis/gap-reports/*.json + supplementation-plan.md
    → Phase 3: supplementation-plan.md (refined)
    → Phase 4: prototypes/*/prototype.md + feature-mapping.json (updated weights)
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `extraction/requirements.txt`
- Create: `extraction/.env.example`
- Create: `extraction/config.py`

- [ ] **Step 1: Create requirements.txt**

```txt
# extraction/requirements.txt
pymupdf>=1.24.0
openai>=1.30.0
python-dotenv>=1.0.0
jinja2>=3.1.0
pydantic>=2.7.0
pdfplumber>=0.11.0
```

- [ ] **Step 2: Create .env.example**

```ini
# extraction/.env.example
# Alibaba Cloud Coding Plan - qwen3.6-plus (multimodal) - for coarse scan
CODING_PLAN_API_KEY=your-coding-plan-api-key-here
CODING_PLAN_BASE_URL=https://coding.dashscope.aliyuncs.com/v1
CODING_PLAN_MODEL=qwen3.6-plus

# Alibaba Cloud Pay-per-use - qwen3.7-max (single-modal) - for deep extraction
DASHSCOPE_API_KEY=your-dashscope-api-key-here
DASHSCOPE_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
DASHSCOPE_MODEL=qwen3.7-max

# Xiaomi MiMo Token Plan - Mimo-v2.5 (multimodal) - for multimodal extraction
MIMO_API_KEY=your-mimo-api-key-here
MIMO_BASE_URL=https://token-plan-cn.xiaomimimo.com/v1
MIMO_MODEL=mimo-v2.5

# Paths
LITERATURE_DIR=/Users/panyao/Desktop/仿生文献库
PROJECT_DIR=.
OUTPUT_DIR=./extraction-output
```

- [ ] **Step 3: Create config.py**

```python
# extraction/config.py
"""Configuration loaded from .env file."""

import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

# API provider configurations
PROVIDERS = {
    "coding_plan": {
        "api_key": os.getenv("CODING_PLAN_API_KEY", ""),
        "base_url": os.getenv("CODING_PLAN_BASE_URL", "https://coding.dashscope.aliyuncs.com/v1"),
        "model": os.getenv("CODING_PLAN_MODEL", "qwen3.6-plus"),
    },
    "dashscope": {
        "api_key": os.getenv("DASHSCOPE_API_KEY", ""),
        "base_url": os.getenv("DASHSCOPE_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1"),
        "model": os.getenv("DASHSCOPE_MODEL", "qwen3.7-max"),
    },
    "mimo": {
        "api_key": os.getenv("MIMO_API_KEY", ""),
        "base_url": os.getenv("MIMO_BASE_URL", "https://token-plan-cn.xiaomimimo.com/v1"),
        "model": os.getenv("MIMO_MODEL", "mimo-v2.5"),
    },
}

# Model routing: task type → provider
MODEL_ROUTING = {
    "coarse_scan": "coding_plan",       # qwen3.6-plus: fast, cheap
    "performance_extract": "coding_plan",  # qwen3.6-plus: mechanical extraction
    "deep_read": "dashscope",           # qwen3.7-max: complex understanding
    "biomimetic_extract": "dashscope",  # qwen3.7-max: complex design logic
    "weight_assign": "dashscope",       # qwen3.7-max: reasoning + judgment
    "multimodal_extract": "mimo",       # Mimo-v2.5: tables/figures
}

# File paths
LITERATURE_DIR = Path(os.getenv("LITERATURE_DIR", ""))
PROJECT_DIR = Path(os.getenv("PROJECT_DIR", ".")).resolve()
OUTPUT_DIR = Path(os.getenv("OUTPUT_DIR", "./extraction-output"))

# Paper groups in literature library
PAPER_GROUPS = {
    "全局综述": "global_review",
    "第1组-配位螯合": "coordination_chelation",
    "第2组-超疏水": "superhydrophobic",
    "第3组-多孔结构": "porous_structure",
    "第4组-生物矿化": "biomineralization",
    "第5组-纤维结构": "fiber_structure",
    "第6组-功能仿生": "functional_biomimetics",
    "第7组-系统仿生": "system_biomimetics",
    "第8组-仿生材料": "biomimetic_materials",
}

# New supplementary groups
SUPPLEMENT_GROUPS = {
    "第9组-仿生方法论": "methodology_standards",
    "第10组-仿生设计综述": "biomimetic_reviews",
    "第11组-跨原型比较": "cross_prototype",
    "第12组-仿生设计案例": "design_cases",
}
```

- [ ] **Step 4: Commit**

```bash
cd Biomimetic-design-library
git checkout feature/biomimetic-story-v2
git add extraction/requirements.txt extraction/.env.example extraction/config.py
git commit -m "feat: add extraction pipeline scaffolding (config, deps, env template)"
```

---

### Task 2: LLM Client

**Files:**
- Create: `extraction/llm_client.py`
- Test: `extraction/tests/test_llm_client.py`

- [ ] **Step 1: Write the failing test**

```python
# extraction/tests/test_llm_client.py
import pytest
from unittest.mock import patch, MagicMock
from llm_client import LLMClient


class TestLLMClient:
    def test_init_loads_provider_config(self):
        """Client initializes with provider name and loads config."""
        client = LLMClient(provider="coding_plan")
        assert client.model == "qwen3.6-plus"
        assert "coding.dashscope" in client.base_url

    def test_route_task_returns_correct_provider(self):
        """route_task maps task types to correct providers."""
        assert LLMClient.route_task("coarse_scan") == "coding_plan"
        assert LLMClient.route_task("deep_read") == "dashscope"
        assert LLMClient.route_task("multimodal_extract") == "mimo"

    def test_chat_calls_openai_api(self):
        """chat() sends message to the correct provider's API."""
        client = LLMClient(provider="coding_plan")
        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = '{"result": "ok"}'

        with patch.object(client.client.chat.completions, "create", return_value=mock_response) as mock_create:
            result = client.chat("Extract data from this abstract: ...")
            mock_create.assert_called_once()
            assert result == '{"result": "ok"}'

    def test_chat_json_parses_structured_output(self):
        """chat_json() parses JSON from LLM response."""
        client = LLMClient(provider="coding_plan")
        with patch.object(client, "chat", return_value='{"pollutants": ["Pb", "Cd"], "qmax": "120 mg/g"}'):
            result = client.chat_json("test prompt")
            assert result == {"pollutants": ["Pb", "Cd"], "qmax": "120 mg/g"}

    def test_chat_json_handles_markdown_fences(self):
        """chat_json() strips markdown code fences before parsing."""
        client = LLMClient(provider="coding_plan")
        raw = '```json\n{"key": "value"}\n```'
        with patch.object(client, "chat", return_value=raw):
            result = client.chat_json("test prompt")
            assert result == {"key": "value"}

    def test_from_task_type_creates_routed_client(self):
        """from_task_type() creates a client routed to the correct provider."""
        client = LLMClient.from_task_type("biomimetic_extract")
        assert client.provider == "dashscope"
        assert client.model == "qwen3.7-max"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd extraction && python -m pytest tests/test_llm_client.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'llm_client'`

- [ ] **Step 3: Write the LLM client implementation**

```python
# extraction/llm_client.py
"""Unified LLM client supporting three API providers via OpenAI-compatible interface."""

import json
import re
from openai import OpenAI
from config import PROVIDERS, MODEL_ROUTING


class LLMClient:
    """A unified client for calling LLMs across three providers.

    All three providers expose OpenAI-compatible chat completion endpoints,
    so we use the openai SDK with custom base_url and api_key per provider.
    """

    def __init__(self, provider: str):
        """Initialize client for a specific provider.

        Args:
            provider: One of 'coding_plan', 'dashscope', 'mimo'.
        """
        if provider not in PROVIDERS:
            raise ValueError(f"Unknown provider: {provider}. Must be one of {list(PROVIDERS.keys())}")

        self.provider = provider
        cfg = PROVIDERS[provider]
        self.model = cfg["model"]
        self.base_url = cfg["base_url"]

        self.client = OpenAI(
            api_key=cfg["api_key"],
            base_url=cfg["base_url"],
        )

    @classmethod
    def from_task_type(cls, task_type: str) -> "LLMClient":
        """Create a client routed to the correct provider for a given task type.

        Args:
            task_type: One of the keys in MODEL_ROUTING
                       (coarse_scan, performance_extract, deep_read,
                        biomimetic_extract, weight_assign, multimodal_extract).

        Returns:
            LLMClient configured for the appropriate provider.
        """
        if task_type not in MODEL_ROUTING:
            raise ValueError(f"Unknown task type: {task_type}. Must be one of {list(MODEL_ROUTING.keys())}")
        provider = MODEL_ROUTING[task_type]
        return cls(provider=provider)

    @staticmethod
    def route_task(task_type: str) -> str:
        """Return the provider name for a given task type."""
        if task_type not in MODEL_ROUTING:
            raise ValueError(f"Unknown task type: {task_type}")
        return MODEL_ROUTING[task_type]

    def chat(
        self,
        prompt: str,
        system_prompt: str = "You are a scientific literature analysis assistant. Respond in the language of the input.",
        temperature: float = 0.1,
        max_tokens: int = 4096,
    ) -> str:
        """Send a chat completion request and return the response text.

        Args:
            prompt: The user message.
            system_prompt: System instruction.
            temperature: Sampling temperature (low for extraction tasks).
            max_tokens: Maximum response tokens.

        Returns:
            The model's response text.
        """
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ],
            temperature=temperature,
            max_tokens=max_tokens,
        )
        return response.choices[0].message.content

    def chat_json(
        self,
        prompt: str,
        system_prompt: str = "You are a scientific literature analysis assistant. Always respond with valid JSON.",
        temperature: float = 0.1,
        max_tokens: int = 4096,
    ) -> dict:
        """Send a chat request and parse the response as JSON.

        Handles markdown code fences (```json ... ```) that models sometimes wrap around JSON.

        Args:
            prompt: The user message.
            system_prompt: System instruction (defaults to JSON-mode instruction).
            temperature: Sampling temperature.
            max_tokens: Maximum response tokens.

        Returns:
            Parsed JSON as a dict.
        """
        raw = self.chat(prompt, system_prompt=system_prompt, temperature=temperature, max_tokens=max_tokens)
        # Strip markdown code fences if present
        cleaned = re.sub(r"```(?:json)?\s*\n?", "", raw).strip()
        return json.loads(cleaned)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd extraction && python -m pytest tests/test_llm_client.py -v`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add extraction/llm_client.py extraction/tests/test_llm_client.py
git commit -m "feat: add unified LLM client with 3-provider routing"
```

---

### Task 3: PDF Utilities

**Files:**
- Create: `extraction/pdf_utils.py`
- Test: `extraction/tests/test_pdf_utils.py`

- [ ] **Step 1: Write the failing test**

```python
# extraction/tests/test_pdf_utils.py
import pytest
from pathlib import Path
from pdf_utils import extract_first_page_text, extract_full_text, extract_tables


@pytest.fixture
def sample_pdf(tmp_path):
    """Create a minimal PDF for testing."""
    import fitz  # PyMuPDF

    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((72, 72), "Abstract: This study investigates biomimetic adsorption.")
    page.insert_text((72, 100), "Keywords: chitosan, heavy metal, lead, adsorption")
    doc.save(str(tmp_path / "test.pdf"))
    doc.close()
    return tmp_path / "test.pdf"


class TestPdfUtils:
    def test_extract_first_page_text(self, sample_pdf):
        """Extract text from the first page of a PDF."""
        text = extract_first_page_text(sample_pdf)
        assert "Abstract" in text
        assert "biomimetic" in text

    def test_extract_full_text(self, sample_pdf):
        """Extract text from all pages of a PDF."""
        text = extract_full_text(sample_pdf)
        assert "adsorption" in text

    def test_extract_first_page_handles_missing_file(self, tmp_path):
        """Return empty string for non-existent PDF."""
        result = extract_first_page_text(tmp_path / "nonexistent.pdf")
        assert result == ""

    def test_extract_tables_returns_list(self, sample_pdf):
        """extract_tables returns a list (empty if no tables found)."""
        tables = extract_tables(sample_pdf)
        assert isinstance(tables, list)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd extraction && python -m pytest tests/test_pdf_utils.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'pdf_utils'`

- [ ] **Step 3: Write the PDF utilities implementation**

```python
# extraction/pdf_utils.py
"""PDF text extraction utilities using PyMuPDF and pdfplumber."""

from pathlib import Path


def extract_first_page_text(pdf_path: Path) -> str:
    """Extract text from the first page of a PDF.

    Args:
        pdf_path: Path to the PDF file.

    Returns:
        Text content of the first page, or empty string if file not found.
    """
    try:
        import fitz  # PyMuPDF

        doc = fitz.open(str(pdf_path))
        if doc.page_count == 0:
            doc.close()
            return ""
        text = doc[0].get_text()
        doc.close()
        return text
    except (FileNotFoundError, Exception):
        return ""


def extract_full_text(pdf_path: Path) -> str:
    """Extract text from all pages of a PDF.

    Args:
        pdf_path: Path to the PDF file.

    Returns:
        Full text content of the PDF, or empty string if file not found.
    """
    try:
        import fitz  # PyMuPDF

        doc = fitz.open(str(pdf_path))
        texts = []
        for page in doc:
            texts.append(page.get_text())
        doc.close()
        return "\n\n".join(texts)
    except (FileNotFoundError, Exception):
        return ""


def extract_tables(pdf_path: Path) -> list:
    """Extract tables from a PDF using pdfplumber.

    Args:
        pdf_path: Path to the PDF file.

    Returns:
        List of tables, where each table is a list of rows (list of cell strings).
        Returns empty list if no tables found or file not accessible.
    """
    try:
        import pdfplumber

        tables = []
        with pdfplumber.open(str(pdf_path)) as pdf:
            for page in pdf.pages:
                page_tables = page.extract_tables()
                if page_tables:
                    tables.extend(page_tables)
        return tables
    except (FileNotFoundError, Exception):
        return []
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd extraction && python -m pytest tests/test_pdf_utils.py -v`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add extraction/pdf_utils.py extraction/tests/test_pdf_utils.py
git commit -m "feat: add PDF text and table extraction utilities"
```

---

### Task 4: Filename Parser

**Files:**
- Create: `extraction/filename_parser.py`
- Test: `extraction/tests/test_filename_parser.py`

- [ ] **Step 1: Write the failing test**

```python
# extraction/tests/test_filename_parser.py
import pytest
from filename_parser import parse_filename, PaperMeta


class TestFilenameParser:
    def test_parse_english_paper(self):
        """Parse a standard English paper filename."""
        meta = parse_filename("2022-Eltaweil-alginate-bone-magnetic-adsorption-review.pdf")
        assert meta.year == 2022
        assert meta.author == "Eltaweil"
        assert meta.keywords == ["alginate", "bone", "magnetic", "adsorption"]
        assert meta.is_review is True

    def test_parse_chinese_paper(self):
        """Parse a Chinese paper filename."""
        meta = parse_filename("2021-李-壳聚糖-吸附-重金属-铅.pdf")
        assert meta.year == 2021
        assert meta.author == "李"
        assert meta.keywords == ["壳聚糖", "吸附", "重金属", "铅"]
        assert meta.is_review is False

    def test_parse_patent(self):
        """Parse a patent filename."""
        meta = parse_filename("2022-CN114873705A-壳聚糖-磁性-重金属-废水.pdf")
        assert meta.year == 2022
        assert meta.author == "CN114873705A"
        assert meta.is_patent is True

    def test_parse_review_markers(self):
        """Detect review papers from various markers."""
        meta1 = parse_filename("2022-Smith-chitosan-review.pdf")
        assert meta1.is_review is True

        meta2 = parse_filename("2021-王-纤维素-综述.pdf")
        assert meta2.is_review is True

        meta3 = parse_filename("2020-Zhang-MOF-adsorption.pdf")
        assert meta3.is_review is False

    def test_parse_handles_unknown_format(self):
        """Gracefully handle non-standard filenames."""
        meta = parse_filename("random-document.pdf")
        assert meta.year is None
        assert meta.author == "random-document"
        assert meta.keywords == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd extraction && python -m pytest tests/test_filename_parser.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'filename_parser'`

- [ ] **Step 3: Write the filename parser implementation**

```python
# extraction/filename_parser.py
"""Parse structured metadata from paper filenames.

Filename convention: YEAR-AuthorSurname-Keyword1-Keyword2-...[-review].pdf
Examples:
  2022-Eltaweil-alginate-bone-magnetic-adsorption-review.pdf
  2021-李-壳聚糖-吸附-重金属-铅.pdf
  2022-CN114873705A-壳聚糖-磁性-重金属-废水.pdf
"""

import re
from dataclasses import dataclass, field
from pathlib import Path


# Keywords that indicate a review paper
REVIEW_MARKERS = {"review", "综述", "研究进展", "progress", "overview"}


@dataclass
class PaperMeta:
    """Structured metadata parsed from a paper's filename."""

    year: int | None = None
    author: str = ""
    keywords: list[str] = field(default_factory=list)
    is_review: bool = False
    is_patent: bool = False
    original_filename: str = ""


def parse_filename(filename: str) -> PaperMeta:
    """Parse a paper filename into structured metadata.

    Args:
        filename: The filename (not full path) of a paper PDF.

    Returns:
        PaperMeta with extracted fields.
    """
    stem = Path(filename).stem  # Remove .pdf extension
    parts = stem.split("-")

    meta = PaperMeta(original_filename=filename)

    if len(parts) < 2:
        # Non-standard filename — best effort
        meta.author = stem
        return meta

    # First part: year (4 digits)
    if parts[0].isdigit() and len(parts[0]) == 4:
        meta.year = int(parts[0])
    else:
        # Not a year — treat entire stem as author
        meta.author = stem
        return meta

    # Second part: author or patent number
    meta.author = parts[1]
    if re.match(r"CN\d+", meta.author):
        meta.is_patent = True

    # Remaining parts: keywords (filter out review markers)
    remaining = parts[2:]
    for kw in remaining:
        kw_lower = kw.strip().lower()
        if kw_lower in REVIEW_MARKERS:
            meta.is_review = True
        else:
            meta.keywords.append(kw.strip())

    return meta
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd extraction && python -m pytest tests/test_filename_parser.py -v`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add extraction/filename_parser.py extraction/tests/test_filename_parser.py
git commit -m "feat: add filename parser for paper metadata extraction"
```

---

### Task 5: Prototype Mapper

**Files:**
- Create: `extraction/prototype_mapper.py`
- Test: `extraction/tests/test_prototype_mapper.py`

- [ ] **Step 1: Write the failing test**

```python
# extraction/tests/test_prototype_mapper.py
import pytest
from prototype_mapper import PrototypeMapper, load_prototype_keywords
from filename_parser import PaperMeta


class TestPrototypeMapper:
    @pytest.fixture
    def mapper(self):
        return PrototypeMapper()

    def test_load_prototype_keywords_returns_dict(self):
        """Prototype keywords loaded as a dict mapping prototype_id → keyword set."""
        kw = load_prototype_keywords()
        assert isinstance(kw, dict)
        assert "mussel-foot-adhesion" in kw or "lotus-leaf" in kw

    def test_map_by_direct_keyword(self, mapper):
        """Paper with '贻贝' in keywords maps to mussel-foot-adhesion."""
        meta = PaperMeta(year=2022, author="Test", keywords=["贻贝", "吸附", "重金属"])
        results = mapper.map_paper(meta, group="coordination_chelation")
        prototype_ids = [r["prototype_id"] for r in results]
        assert "mussel-foot-adhesion" in prototype_ids

    def test_map_by_english_keyword(self, mapper):
        """Paper with 'lotus' in keywords maps to lotus-leaf."""
        meta = PaperMeta(year=2021, author="Smith", keywords=["lotus", "superhydrophobic"])
        results = mapper.map_paper(meta, group="superhydrophobic")
        prototype_ids = [r["prototype_id"] for r in results]
        assert "lotus-leaf" in prototype_ids

    def test_map_fallback_to_mechanism_group(self, mapper):
        """Paper with no direct keyword match falls back to mechanism group mapping."""
        meta = PaperMeta(year=2022, author="Wang", keywords=["chitosan", "Pb", "adsorption"])
        results = mapper.map_paper(meta, group="coordination_chelation")
        # Should still return some results via mechanism-group fallback
        assert len(results) > 0
        # All results should be marked as indirect association
        for r in results:
            assert r["association"] == "indirect"

    def test_map_returns_empty_for_unknown_group(self, mapper):
        """Unknown mechanism group with no keyword match returns empty."""
        meta = PaperMeta(year=2020, author="Test", keywords=["unknown", "terms"])
        results = mapper.map_paper(meta, group="nonexistent_group")
        assert results == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd extraction && python -m pytest tests/test_prototype_mapper.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'prototype_mapper'`

- [ ] **Step 3: Write the prototype mapper implementation**

```python
# extraction/prototype_mapper.py
"""Map papers to prototypes via filename keywords and mechanism group fallback.

Two-step mapping:
1. Direct match: paper keywords → prototype keyword dictionary
2. Fallback: paper's mechanism group → all prototypes associated with that mechanism
"""

from dataclasses import dataclass
from filename_parser import PaperMeta


# Keyword → prototype_id mapping (bilingual: Chinese + English)
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

# Mechanism group → prototype_ids fallback mapping
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
    "global_review": [],  # Global reviews map to all prototypes (handled separately)
}


def load_prototype_keywords() -> dict[str, set[str]]:
    """Load the prototype keyword dictionary.

    Returns:
        Dict mapping prototype_id to a set of keyword strings (case-insensitive).
    """
    return {k: {w.lower() for w in v} for k, v in PROTOTYPE_KEYWORDS.items()}


@dataclass
class MappingResult:
    """Result of mapping a paper to prototypes."""
    prototype_id: str
    association: str  # "direct" or "indirect"
    matched_keywords: list[str]


class PrototypeMapper:
    """Maps papers to prototypes using keyword matching and mechanism group fallback."""

    def __init__(self):
        self.keywords = load_prototype_keywords()

    def map_paper(self, meta: PaperMeta, group: str) -> list[dict]:
        """Map a paper to one or more prototypes.

        Args:
            meta: Parsed paper metadata from filename_parser.
            group: The mechanism group the paper belongs to
                   (e.g., 'coordination_chelation', 'superhydrophobic').

        Returns:
            List of dicts with keys: prototype_id, association, matched_keywords.
        """
        results = []
        paper_keywords_lower = {kw.lower() for kw in meta.keywords}

        # Step 1: Direct keyword match
        for prototype_id, proto_keywords in self.keywords.items():
            matched = paper_keywords_lower & proto_keywords
            if matched:
                results.append({
                    "prototype_id": prototype_id,
                    "association": "direct",
                    "matched_keywords": list(matched),
                })

        # Step 2: Fallback to mechanism group if no direct match
        if not results and group in MECHANISM_GROUP_PROTOTYPES:
            for prototype_id in MECHANISM_GROUP_PROTOTYPES[group]:
                results.append({
                    "prototype_id": prototype_id,
                    "association": "indirect",
                    "matched_keywords": [],
                })

        return results
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd extraction && python -m pytest tests/test_prototype_mapper.py -v`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add extraction/prototype_mapper.py extraction/tests/test_prototype_mapper.py
git commit -m "feat: add prototype mapper with keyword and mechanism-group matching"
```

---

### Task 6: Prompt Templates

**Files:**
- Create: `extraction/prompts/coarse_extract.j2`
- Create: `extraction/prompts/deep_performance.j2`
- Create: `extraction/prompts/biomimetic_narrative.j2`
- Create: `extraction/prompts/weight_assign.j2`

- [ ] **Step 1: Create coarse extraction prompt**

```jinja2
{# extraction/prompts/coarse_extract.j2 #}
{# Phase 1: Extract structured fields from paper abstract/first page #}

你是一个科学文献分析助手。请从以下论文摘要中提取结构化信息，以JSON格式输出。

论文标题/文件名信息：{{ filename_info }}
论文摘要/首页文本：
"""
{{ abstract_text }}
"""

请提取以下字段（如果文本中没有相关信息，输出null）：

```json
{
  "target_pollutants": ["检测到的目标污染物列表，使用标准化学名称"],
  "adsorption_mechanisms": ["检测到的吸附机制，使用以下标准术语：配位螯合/静电吸附/π-π堆积/氢键/离子交换/孔隙吸附/表面吸附/超疏水分离/梯度润湿/分子筛分/生物矿化/生物沉淀/生物富集"],
  "material_type": "吸附材料类型（如壳聚糖、MOF、生物炭等）",
  "biological_source": "生物来源（如有，如贻贝、莲花、硅藻等）",
  "qmax_value": "最大吸附容量数值（仅数字，单位mg/g）或null",
  "qmax_pollutant": "qmax对应的目标污染物",
  "removal_rate": "去除率百分比（仅数字）或null",
  "ph_range": "适用pH范围（如'3-8'）或null",
  "temperature_range": "适用温度范围（如'25-45°C'）或null",
  "key_findings": "一句话总结核心发现"
}
```

注意事项：
- 只提取文本中明确提及的信息，不要推断或编造
- 污染物使用标准化学名称（如Pb²⁺写为"Pb2+"，亚甲基蓝写为"methylene blue"）
- 如果摘要中提到了多个污染物或机制，全部列出
- 确保输出是合法的JSON格式
```

- [ ] **Step 2: Create deep performance extraction prompt**

```jinja2
{# extraction/prompts/deep_performance.j2 #}
{# Phase 4: Extract detailed performance data from full paper text #}

你是一个科学文献数据分析专家。请从以下论文全文中提取水处理吸附材料的详细性能数据，以JSON格式输出。

论文信息：{{ paper_meta }}
原型ID：{{ prototype_id }}

论文全文：
"""
{{ full_text }}
"""

请提取以下字段（如果文本中没有相关信息，输出null）：

```json
{
  "performance_data": {
    "qmax": {"value": "数值(mg/g)", "pollutant": "对应污染物", "conditions": "实验条件(pH, 温度等)", "source_page": "来源段落摘要"},
    "removal_rate": {"value": "去除率(%)", "pollutant": "对应污染物", "conditions": "实验条件", "source_page": "来源段落摘要"},
    "kinetics": {"model": "动力学模型(pseudo-first/pseudo-second/intraparticle等)", "rate_constant": "速率常数", "source_page": "来源段落摘要"},
    "isotherm": {"model": "等温线模型(Langmuir/Freundlich等)", "parameters": "关键参数", "source_page": "来源段落摘要"},
    "selectivity": "选择性描述或null",
    "reusability": {"cycles": "可循环次数", "retention_rate": "循环后保持率(%)", "source_page": "来源段落摘要"}
  },
  "applicability": {
    "ph_range": "适用pH范围",
    "ph_optimal": "最优pH",
    "temperature_range": "适用温度范围",
    "temperature_optimal": "最优温度",
    "salinity_tolerance": "盐度耐受描述或null",
    "real_water_tested": "是否用真实水样测试(true/false)"
  },
  "material_characterization": {
    "surface_area": "比表面积(m²/g)或null",
    "pore_size": "孔径(nm)或null",
    "functional_groups": ["关键官能团列表"],
    "morphology": "形貌描述"
  },
  "mechanisms_identified": ["论文中明确识别的吸附机制"],
  "evidence_level": "high/medium/low（基于数据完整性和实验设计质量判断）"
}
```

注意事项：
- 只提取文本中明确报告的数据，不要推断
- 数值必须带单位
- source_page字段简要引用包含该数据的文本段落（50字以内）
- 如果同一论文报告了多个污染物/条件下的数据，取最优值和范围
```

- [ ] **Step 3: Create biomimetic narrative extraction prompt**

```jinja2
{# extraction/prompts/biomimetic_narrative.j2 #}
{# Phase 4: Extract biomimetic design knowledge from supplemented literature #}

你是一个仿生设计分析专家。请从以下论文中提取仿生设计知识，以JSON格式输出。

论文信息：{{ paper_meta }}
目标原型ID：{{ prototype_id }}
目标原型名称：{{ prototype_name }}

论文全文：
"""
{{ full_text }}
"""

请按照仿生设计叙事的五个维度提取信息（如果文本中没有相关信息，输出null）：

```json
{
  "problem_definition": {
    "nature_challenge": "该生物原型在自然界中面临的挑战是什么",
    "water_treatment_mapping": "这个挑战如何映射到水处理领域的问题",
    "source_evidence": "来源段落摘要（50字以内）"
  },
  "biological_solution": {
    "evolutionary_strategy": "生物通过什么进化策略解决这个问题",
    "key_mechanisms": ["关键机制列表"],
    "success_cases": "自然界中该策略成功的案例",
    "source_evidence": "来源段落摘要"
  },
  "key_feature_extraction": {
    "must_keep_features": ["从生物到材料迁移时必须保留的特征（改变则失效）"],
    "adjustable_features": ["可以根据工程需求调整的特征"],
    "feature_rationale": "为什么这些特征分别是must-keep或adjustable的",
    "source_evidence": "来源段落摘要"
  },
  "design_mapping": {
    "bio_to_material": "从生物特征到材料设计的映射关系描述",
    "soft_constraints": ["设计建议（非硬性约束，但偏离时需要额外论证）"],
    "design_examples": "论文中提到的具体材料设计案例",
    "source_evidence": "来源段落摘要"
  },
  "explainability_anchors": {
    "one_line_story": "一句话仿生故事（概括从生物启发到材料设计的完整逻辑链）",
    "design_traceability": "设计可追溯性——每个设计决策可以追溯到哪个生物学发现"
  },
  "engineering_constraints": [
    {"constraint_name": "约束名（如抗菌性/耐酸性/可回收性等）", "relevance": "high/medium/low", "explanation": "该原型与此约束的关系"}
  ]
}
```

注意事项：
- 重点关注论文中"从生物到材料"的设计逻辑链，而非单纯的性能数据
- must_keep_features和adjustable_features的区分非常关键——前者改变则仿生优势丧失，后者可根据工程需求调整
- one_line_story要简洁有力，例如："受贻贝足丝分泌的多巴胺粘附蛋白启发，将儿茶酚基团引入聚合物表面，实现水下强粘附功能涂层"
- 确保输出是合法的JSON格式
```

- [ ] **Step 4: Create weight assignment prompt**

```jinja2
{# extraction/prompts/weight_assign.j2 #}
{# Phase 4: Assign weights to feature-mapping.json entries #}

你是一个仿生材料设计领域的评审专家。请基于以下证据为仿生原型在feature-mapping中的映射关系赋权重。

原型ID：{{ prototype_id }}
原型名称：{{ prototype_name }}

## 原型的综合画像
{{ coarse_profile_json }}

## 相关论文的提取结果
{{ extraction_results_json }}

## 需要赋权的映射条目
{{ mapping_entries_json }}

权重赋值原则（来自项目设计规范）：
- 权重范围：0-1的连续值，代表"实际匹配程度"
- 权重构成：70%推理知识（生物原型机制与目标污染物/特征的逻辑匹配度）+ 20%文献数据（有多少篇论文证实了这个映射）+ 10%证据链强度（数据一致性、跨文献交叉验证）
- 评分标准：0.9-1.0强匹配，0.7-0.9中等匹配，0.5-0.7弱匹配，<0.5不匹配

请对每个映射条目输出：

```json
{
  "weight_assignments": [
    {
      "mapping_type": "pollutant_prototype_map 或 feature_prototype_map",
      "entry_key": "污染物名或特征名",
      "weight": "0-1之间的数值",
      "reasoning_score": "0-1，推理知识部分得分",
      "reasoning_justification": "推理知识打分理由（一句话）",
      "literature_score": "0-1，文献数据部分得分",
      "literature_count": "支撑该映射的论文数量",
      "evidence_score": "0-1，证据链强度得分",
      "evidence_description": "证据链评价（一句话）",
      "mechanism_summary": "机制摘要（更新版，基于提取结果）",
      "design_hint": "设计提示（更新版，基于提取结果）"
    }
  ]
}
```

注意事项：
- 每个映射条目都必须给出权重和完整的打分理由
- 如果某个映射完全缺乏证据，weight设为0并在理由中说明
- mechanism_summary和design_hint应基于实际提取结果更新，而非简单复制原有内容
```

- [ ] **Step 5: Commit**

```bash
git add extraction/prompts/
git commit -m "feat: add LLM prompt templates for all extraction phases"
```

---

### Task 7: Phase 1 — Coarse Scan Pipeline

**Files:**
- Create: `extraction/pipeline/__init__.py`
- Create: `extraction/pipeline/phase1_coarse_scan.py`

- [ ] **Step 1: Create pipeline package init**

```python
# extraction/pipeline/__init__.py
"""Extraction pipeline phases."""
```

- [ ] **Step 2: Write Phase 1 implementation**

```python
# extraction/pipeline/phase1_coarse_scan.py
"""Phase 1: Coarse Scan — lightweight extraction from all 341 papers.

Produces:
- coarse-profiles/<prototype_id>.json for each prototype
- coverage-heatmap.md summarizing coverage across all prototypes
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


# Load prompt template
_env = Environment(loader=FileSystemLoader(str(Path(__file__).parent.parent / "prompts")))
_coarse_prompt = _env.get_template("coarse_extract.j2")


def scan_literature_library(literature_dir: Path = None) -> dict:
    """Walk the literature directory and parse all paper filenames.

    Args:
        literature_dir: Path to the literature library root.

    Returns:
        Dict mapping group_name to list of (path, PaperMeta) tuples.
    """
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
    """Map all papers to prototypes.

    Args:
        papers_by_group: Output of scan_literature_library().

    Returns:
        Dict mapping prototype_id to list of paper info dicts.
    """
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
    """Extract a coarse profile for one prototype from its associated papers.

    For each paper, extracts the abstract via first-page text and asks LLM
    to identify structured fields. Results are aggregated per prototype.

    Args:
        prototype_id: The prototype identifier.
        papers: List of paper info dicts from map_papers_to_prototypes().
        llm: LLMClient configured for coarse_scan task.

    Returns:
        Coarse profile dict for this prototype.
    """
    profile = {
        "prototype_id": prototype_id,
        "paper_count": len(papers),
        "direct_papers": [p for p in papers if p["association"] == "direct"],
        "indirect_papers": [p for p in papers if p["association"] == "indirect"],
        "extracted_fields": [],
        "coverage": {
            "pollutants": set(),
            "mechanisms": set(),
            "materials": set(),
        },
    }

    # Extract from top papers (prioritize direct association, then reviews)
    priority_papers = sorted(
        papers,
        key=lambda p: (0 if p["association"] == "direct" else 1, 0 if p["is_review"] else 1),
    )[:5]  # Top 5 papers per prototype for coarse scan

    for paper in priority_papers:
        pdf_path = Path(paper["path"])
        first_page = extract_first_page_text(pdf_path)
        if not first_page or len(first_page.strip()) < 50:
            continue

        prompt = _coarse_prompt.render(
            filename_info=f"{paper['year']}-{paper['author']}-{'-'.join(paper['keywords'])}",
            abstract_text=first_page[:3000],  # Truncate to avoid token limits
        )

        try:
            result = llm.chat_json(prompt)
            result["_source_paper"] = paper["filename"]
            profile["extracted_fields"].append(result)

            # Aggregate coverage
            if result.get("target_pollutants"):
                profile["coverage"]["pollutants"].update(result["target_pollutants"])
            if result.get("adsorption_mechanisms"):
                profile["coverage"]["mechanisms"].update(result["adsorption_mechanisms"])
            if result.get("material_type"):
                profile["coverage"]["materials"].add(result["material_type"])
        except Exception as e:
            profile["extracted_fields"].append({
                "_source_paper": paper["filename"],
                "_error": str(e),
            })

    # Convert sets to sorted lists for JSON serialization
    profile["coverage"] = {k: sorted(v) for k, v in profile["coverage"].items()}

    return profile


def run_phase1(literature_dir: Path = None, output_dir: Path = None) -> None:
    """Execute Phase 1: Coarse Scan.

    Args:
        literature_dir: Path to literature library root.
        output_dir: Path to write output files.
    """
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

        # Save individual profile
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

    # Save coverage heatmap
    heatmap_path = output_dir / "coarse-profiles" / "coverage-heatmap.md"
    _write_coverage_heatmap(coverage_summary, heatmap_path)
    print(f"Phase 1 complete. Output written to {profiles_dir}")


def _write_coverage_heatmap(summary: dict, output_path: Path) -> None:
    """Write a markdown coverage heatmap."""
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
        lines.append(
            f"| {proto_id} | {data['total_papers']} | {data['direct_papers']} "
            f"| {pollutants} | {mechanisms} |"
        )

    output_path.write_text("\n".join(lines), encoding="utf-8")
```

- [ ] **Step 3: Commit**

```bash
git add extraction/pipeline/__init__.py extraction/pipeline/phase1_coarse_scan.py
git commit -m "feat: implement Phase 1 coarse scan pipeline"
```

---

### Task 8: Phase 2 — Gap Analysis

**Files:**
- Create: `extraction/pipeline/phase2_gap_analysis.py`

- [ ] **Step 1: Write Phase 2 implementation**

```python
# extraction/pipeline/phase2_gap_analysis.py
"""Phase 2: Gap Analysis — identify knowledge gaps per prototype.

Two-step structure:
1. Breadth assessment from coarse profiles (how many papers, how relevant)
2. Depth assessment via sample deep-reads (can existing papers fill deep fields?)

Produces:
- gap-analysis/gap-reports/<prototype_id>.json for each prototype
- gap-analysis/supplementation-plan.md (global supplementation plan)
"""

import json
from pathlib import Path
from collections import defaultdict

from config import OUTPUT_DIR
from llm_client import LLMClient
from pdf_utils import extract_full_text


# Fields required by prototype-template (from feature branch)
REQUIRED_FIELDS = {
    # Performance data fields (can come from existing papers)
    "performance": [
        "qmax", "removal_rate", "kinetics", "isotherm",
        "selectivity", "reusability",
    ],
    # Applicability fields (can come from existing papers)
    "applicability": [
        "ph_range", "ph_optimal", "temperature_range",
        "temperature_optimal", "salinity_tolerance",
    ],
    # Biomimetic narrative fields (need supplemented literature)
    "biomimetic_narrative": [
        "problem_definition", "biological_solution",
        "key_feature_extraction", "design_mapping",
        "explainability_anchors",
    ],
    # Engineering constraint fields (need supplemented literature)
    "engineering_constraints": [
        "antibacterial", "acid_resistance", "alkali_resistance",
        "recyclability", "low_cost", "high_capacity",
        "fast_adsorption", "high_selectivity", "easy_synthesis",
        "environmentally_friendly",
    ],
}

# Gap types
GAP_TYPE_DATA = "data_gap"           # Has value but low confidence / few data points
GAP_TYPE_KNOWLEDGE = "knowledge_gap"  # Field empty, needs new literature
GAP_TYPE_WEIGHT = "weight_gap"        # Insufficient evidence for weight assignment


def assess_breadth(coarse_profile: dict) -> dict:
    """Assess the breadth of literature coverage for a prototype.

    Args:
        coarse_profile: A coarse profile dict from Phase 1.

    Returns:
        Breadth assessment dict.
    """
    direct_count = len(coarse_profile.get("direct_papers", []))
    indirect_count = len(coarse_profile.get("indirect_papers", []))
    pollutants = coarse_profile.get("coverage", {}).get("pollutants", [])
    mechanisms = coarse_profile.get("coverage", {}).get("mechanisms", [])

    return {
        "direct_papers": direct_count,
        "indirect_papers": indirect_count,
        "pollutant_coverage": len(pollutants),
        "mechanism_coverage": len(mechanisms),
        "breadth_score": min(1.0, (direct_count * 0.3 + indirect_count * 0.1 + len(pollutants) * 0.1 + len(mechanisms) * 0.1)),
        "assessment": "sufficient" if direct_count >= 3 else "sparse" if direct_count >= 1 else "empty",
    }


def assess_depth(prototype_id: str, coarse_profile: dict, llm: LLMClient) -> dict:
    """Assess the depth of existing literature via sample deep-reads.

    Picks 2-3 most relevant papers and tries to fill all template fields.
    Identifies which fields can/cannot be filled from existing literature.

    Args:
        prototype_id: The prototype identifier.
        coarse_profile: A coarse profile dict from Phase 1.
        llm: LLMClient configured for deep_read task.

    Returns:
        Depth assessment dict with per-field fill-ability.
    """
    # Select top 3 direct-association review papers for deep reading
    all_papers = coarse_profile.get("direct_papers", []) + coarse_profile.get("indirect_papers", [])
    sample_papers = sorted(
        all_papers,
        key=lambda p: (0 if p["association"] == "direct" else 1, 0 if p.get("is_review") else 1),
    )[:3]

    field_fillability = {}

    for paper in sample_papers:
        pdf_path = Path(paper["path"])
        full_text = extract_full_text(pdf_path)
        if not full_text or len(full_text.strip()) < 200:
            continue

        # Try to extract ALL fields (performance + biomimetic) from this paper
        # Use a simplified prompt that checks each field
        prompt = f"""请分析以下论文，判断哪些字段可以从中提取到有效信息。

原型ID: {prototype_id}
论文: {paper.get("filename", "unknown")}

论文全文（前5000字）:
{full_text[:5000]}

请对以下每个字段判断：可以提取(can_extract)、部分可提取(partial)、无法提取(cannot_extract)。

性能字段: {json.dumps(REQUIRED_FIELDS["performance"])}
适用性字段: {json.dumps(REQUIRED_FIELDS["applicability"])}
仿生叙事字段: {json.dumps(REQUIRED_FIELDS["biomimetic_narrative"])}
工程约束字段: {json.dumps(REQUIRED_FIELDS["engineering_constraints"])}

输出JSON格式:
{{"field_assessment": {{"field_name": "can_extract|partial|cannot_extract", ...}}}}
"""
        try:
            result = llm.chat_json(prompt)
            assessments = result.get("field_assessment", {})
            for field_name, status in assessments.items():
                if field_name not in field_fillability:
                    field_fillability[field_name] = []
                field_fillability[field_name].append(status)
        except Exception:
            continue

    # Aggregate: a field is fillable if ANY sample paper says can_extract
    depth_results = {}
    for field_name, statuses in field_fillability.items():
        if "can_extract" in statuses:
            depth_results[field_name] = "fillable"
        elif "partial" in statuses:
            depth_results[field_name] = "partially_fillable"
        else:
            depth_results[field_name] = "not_fillable"

    return {
        "sample_papers": [p.get("filename") for p in sample_papers],
        "field_fillability": depth_results,
    }


def generate_gap_report(prototype_id: str, breadth: dict, depth: dict) -> dict:
    """Generate a gap report for one prototype.

    Args:
        prototype_id: The prototype identifier.
        breadth: Breadth assessment dict.
        depth: Depth assessment dict.

    Returns:
        Gap report dict with per-field gap classification.
    """
    gap_report = {
        "prototype_id": prototype_id,
        "breadth": breadth,
        "gaps": [],
    }

    fillability = depth.get("field_fillability", {})

    # Performance and applicability fields
    for category in ["performance", "applicability"]:
        for field_name in REQUIRED_FIELDS[category]:
            status = fillability.get(field_name, "not_assessed")
            if status == "fillable":
                gap_type = None  # No gap
                action = "deep_extract_from_existing"
            elif status == "partially_fillable":
                gap_type = GAP_TYPE_DATA
                action = "deep_extract_from_existing + supplement_if_needed"
            else:
                gap_type = GAP_TYPE_DATA
                action = "supplement_literature"

            if gap_type:
                gap_report["gaps"].append({
                    "field": field_name,
                    "category": category,
                    "status": status,
                    "gap_type": gap_type,
                    "recommended_action": action,
                    "supplement_topic": None,
                })

    # Biomimetic narrative fields (almost always knowledge gaps)
    for field_name in REQUIRED_FIELDS["biomimetic_narrative"]:
        status = fillability.get(field_name, "not_fillable")
        gap_type = GAP_TYPE_KNOWLEDGE if status != "fillable" else None
        if gap_type:
            gap_report["gaps"].append({
                "field": field_name,
                "category": "biomimetic_narrative",
                "status": status,
                "gap_type": gap_type,
                "recommended_action": "supplement_biomimetic_literature",
                "supplement_topic": f"biomimetic design {field_name} for {prototype_id}",
            })

    # Engineering constraints (always knowledge gaps with current literature)
    for field_name in REQUIRED_FIELDS["engineering_constraints"]:
        gap_report["gaps"].append({
            "field": field_name,
            "category": "engineering_constraints",
            "status": "not_fillable",
            "gap_type": GAP_TYPE_KNOWLEDGE,
            "recommended_action": "supplement_biomimetic_literature",
            "supplement_topic": f"engineering constraint {field_name} for biomimetic adsorbents",
        })

    # Weight gap: if breadth is sparse
    if breadth["direct_papers"] < 3:
        gap_report["gaps"].append({
            "field": "weight_assignment",
            "category": "weight",
            "status": "insufficient_evidence",
            "gap_type": GAP_TYPE_WEIGHT,
            "recommended_action": "supplement_comparative_studies",
            "supplement_topic": f"comparative biomimetic adsorption studies involving {prototype_id}",
        })

    return gap_report


def run_phase2(output_dir: Path = None) -> None:
    """Execute Phase 2: Gap Analysis.

    Args:
        output_dir: Path to write output files.
    """
    output_dir = output_dir or OUTPUT_DIR
    profiles_dir = output_dir / "coarse-profiles"
    gap_dir = output_dir / "gap-analysis" / "gap-reports"
    gap_dir.mkdir(parents=True, exist_ok=True)

    print("Phase 2: Running gap analysis...")
    llm = LLMClient.from_task_type("deep_read")

    all_gap_reports = {}
    supplement_needs = defaultdict(list)

    for profile_path in sorted(profiles_dir.glob("*.json")):
        if profile_path.name == "coverage-heatmap.md":
            continue

        with open(profile_path, encoding="utf-8") as f:
            coarse_profile = json.load(f)

        prototype_id = coarse_profile["prototype_id"]
        print(f"  Analyzing {prototype_id}...")

        breadth = assess_breadth(coarse_profile)
        depth = assess_depth(prototype_id, coarse_profile, llm)
        gap_report = generate_gap_report(prototype_id, breadth, depth)

        # Save individual gap report
        report_path = gap_dir / f"{prototype_id}.json"
        with open(report_path, "w", encoding="utf-8") as f:
            json.dump(gap_report, f, ensure_ascii=False, indent=2)

        all_gap_reports[prototype_id] = gap_report

        # Collect supplement needs
        for gap in gap_report["gaps"]:
            if gap.get("supplement_topic"):
                supplement_needs[gap["gap_type"]].append({
                    "prototype_id": prototype_id,
                    "field": gap["field"],
                    "topic": gap["supplement_topic"],
                })

    # Write global supplementation plan
    plan_path = output_dir / "gap-analysis" / "supplementation-plan.md"
    _write_supplementation_plan(supplement_needs, plan_path)
    print(f"Phase 2 complete. {len(all_gap_reports)} gap reports written to {gap_dir}")


def _write_supplementation_plan(needs: dict, output_path: Path) -> None:
    """Write the global supplementation plan."""
    lines = ["## Literature Supplementation Plan (Phase 2 Output)\n"]

    for gap_type, items in sorted(needs.items()):
        lines.append(f"### {gap_type} ({len(items)} needs)\n")

        # Deduplicate topics
        topics = {}
        for item in items:
            topic = item["topic"]
            if topic not in topics:
                topics[topic] = []
            topics[topic].append(item["prototype_id"])

        for topic, prototypes in sorted(topics.items()):
            proto_list = ", ".join(prototypes)
            lines.append(f"- **{topic}** → prototypes: {proto_list}")

        lines.append("")

    output_path.write_text("\n".join(lines), encoding="utf-8")
```

- [ ] **Step 2: Commit**

```bash
git add extraction/pipeline/phase2_gap_analysis.py
git commit -m "feat: implement Phase 2 gap analysis with breadth + depth assessment"
```

---

### Task 9: Phase 3 — Supplementation Planning

**Files:**
- Create: `extraction/pipeline/phase3_supplement_plan.py`

- [ ] **Step 1: Write Phase 3 implementation**

```python
# extraction/pipeline/phase3_supplement_plan.py
"""Phase 3: Generate targeted literature search queries and supplementation plan.

Reads gap analysis output and produces:
- Structured search queries for each supplement group
- Recommended databases and search strategies
- Screening criteria for supplemented literature
"""

import json
from pathlib import Path
from collections import defaultdict

from config import OUTPUT_DIR, SUPPLEMENT_GROUPS


# Search templates per gap type
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

# Prototype display names (Chinese + English)
PROTOTYPE_NAMES = {
    "lotus-leaf": {"en": "lotus leaf", "cn": "荷叶"},
    "mussel-foot-adhesion": {"en": "mussel foot adhesion", "cn": "贻贝足粘附"},
    "polydopamine-coating": {"en": "polydopamine coating", "cn": "聚多巴胺涂层"},
    "diatom-microspheres": {"en": "diatom microspheres", "cn": "硅藻微球"},
    "sulfate-reducing-bacteria": {"en": "sulfate reducing bacteria", "cn": "硫酸盐还原菌"},
    "chitosan-adsorbent": {"en": "chitosan adsorbent", "cn": "壳聚糖吸附剂"},
    "mof-adsorbent": {"en": "MOF adsorbent", "cn": "MOF吸附剂"},
    # ... (other prototypes as needed, defaults to prototype_id)
}


def get_prototype_name(prototype_id: str) -> dict:
    """Get display name for a prototype."""
    return PROTOTYPE_NAMES.get(prototype_id, {"en": prototype_id, "cn": prototype_id})


def generate_search_queries(gap_reports_dir: Path) -> dict:
    """Generate search queries from gap reports.

    Args:
        gap_reports_dir: Path to gap-analysis/gap-reports/ directory.

    Returns:
        Dict mapping supplement group to list of search query dicts.
    """
    queries = defaultdict(list)

    for report_path in sorted(gap_reports_dir.glob("*.json")):
        with open(report_path, encoding="utf-8") as f:
            report = json.load(f)

        prototype_id = report["prototype_id"]
        name = get_prototype_name(prototype_id)

        for gap in report["gaps"]:
            gap_type = gap["gap_type"]

            if gap_type == "knowledge_gap" and gap["category"] == "biomimetic_narrative":
                template = SEARCH_TEMPLATES["knowledge_gap"]
                queries["第10组-仿生设计综述"].append({
                    "prototype_id": prototype_id,
                    "field": gap["field"],
                    "wos_en": template["wos_en"].format(
                        prototype_keyword=name["en"],
                        mechanism=gap["field"].replace("_", " "),
                    ),
                    "wos_cn": template["wos_cn"].format(
                        prototype_cn=name["cn"],
                        mechanism_cn=gap["field"].replace("_", " "),
                    ),
                    "scholar": template["scholar"].format(
                        prototype_keyword=name["en"],
                        mechanism=gap["field"].replace("_", " "),
                    ),
                })

            elif gap_type == "weight_gap":
                template = SEARCH_TEMPLATES["weight_gap"]
                queries["第11组-跨原型比较"].append({
                    "prototype_id": prototype_id,
                    "field": gap["field"],
                    "wos_en": template["wos_en"],
                    "scholar": template["scholar"],
                })

            elif gap_type == "knowledge_gap" and gap["category"] == "engineering_constraints":
                queries["第10组-仿生设计综述"].append({
                    "prototype_id": prototype_id,
                    "field": gap["field"],
                    "wos_en": f'TS=("biomimetic" OR "bio-inspired") AND TS=("{gap["field"].replace("_", " ")}") AND TS=("adsorbent" OR "water treatment")',
                    "scholar": f'biomimetic "{gap["field"].replace("_", " ")}" adsorbent water treatment',
                })

    # Add methodology queries (global, not per-prototype)
    template = SEARCH_TEMPLATES["methodology_gap"]
    queries["第9组-仿生方法论"].append({
        "prototype_id": "global",
        "field": "methodology",
        "wos_en": template["wos_en"],
        "scholar": template["scholar"],
    })

    return dict(queries)


def run_phase3(output_dir: Path = None) -> None:
    """Execute Phase 3: Generate supplementation plan with search queries.

    Args:
        output_dir: Path to read gap reports from and write queries to.
    """
    output_dir = output_dir or OUTPUT_DIR
    gap_reports_dir = output_dir / "gap-analysis" / "gap-reports"

    print("Phase 3: Generating search queries from gap reports...")
    queries = generate_search_queries(gap_reports_dir)

    # Write structured query plan
    query_path = output_dir / "gap-analysis" / "search-queries.md"
    lines = ["## Literature Search Queries (Phase 3 Output)\n"]
    lines.append("Based on gap analysis, the following search queries are recommended.\n")

    total_queries = 0
    for group_name, group_queries in sorted(queries.items()):
        lines.append(f"### {group_name} ({len(group_queries)} queries)\n")
        for i, q in enumerate(group_queries, 1):
            total_queries += 1
            lines.append(f"**Query {i}** — {q['prototype_id']}.{q['field']}")
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
```

- [ ] **Step 2: Commit**

```bash
git add extraction/pipeline/phase3_supplement_plan.py
git commit -m "feat: implement Phase 3 targeted supplementation planning"
```

---

### Task 10: Validators

**Files:**
- Create: `extraction/validators.py`
- Test: `extraction/tests/test_validators.py`

- [ ] **Step 1: Write the failing test**

```python
# extraction/tests/test_validators.py
import pytest
from validators import validate_performance_data, validate_applicability, validate_weights


class TestValidators:
    def test_valid_performance_data(self):
        """Valid performance data passes validation."""
        data = {"qmax": 120.5, "removal_rate": 95.2, "evidence_level": "high"}
        errors = validate_performance_data(data)
        assert errors == []

    def test_negative_qmax_fails(self):
        """Negative qmax value fails validation."""
        data = {"qmax": -10, "removal_rate": 95.2}
        errors = validate_performance_data(data)
        assert any("qmax" in e for e in errors)

    def test_removal_rate_over_100_fails(self):
        """Removal rate over 100% fails validation."""
        data = {"removal_rate": 105}
        errors = validate_performance_data(data)
        assert any("removal_rate" in e for e in errors)

    def test_invalid_evidence_level(self):
        """Invalid evidence level value fails."""
        data = {"evidence_level": "super_high"}
        errors = validate_performance_data(data)
        assert any("evidence_level" in e for e in errors)

    def test_valid_applicability(self):
        """Valid applicability data passes."""
        data = {"ph_range": "3-8", "temperature_range": "25-45°C"}
        errors = validate_applicability(data)
        assert errors == []

    def test_ph_out_of_range(self):
        """pH values outside 0-14 range fail."""
        data = {"ph_optimal": 15}
        errors = validate_applicability(data)
        assert any("ph" in e.lower() for e in errors)

    def test_valid_weights(self):
        """Valid weight assignments pass."""
        weights = [{"weight": 0.85, "reasoning_score": 0.9, "literature_score": 0.7, "evidence_score": 0.8}]
        errors = validate_weights(weights)
        assert errors == []

    def test_weight_out_of_range(self):
        """Weight values outside 0-1 range fail."""
        weights = [{"weight": 1.5}]
        errors = validate_weights(weights)
        assert len(errors) > 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd extraction && python -m pytest tests/test_validators.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'validators'`

- [ ] **Step 3: Write validators implementation**

```python
# extraction/validators.py
"""Automated quality checks for extraction results."""


VALID_EVIDENCE_LEVELS = {"high", "medium", "low"}


def validate_performance_data(data: dict) -> list[str]:
    """Validate performance data fields.

    Args:
        data: Dict with performance fields (qmax, removal_rate, etc.).

    Returns:
        List of error messages. Empty list means all checks passed.
    """
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
    """Validate applicability fields.

    Args:
        data: Dict with applicability fields (ph_range, temperature_range, etc.).

    Returns:
        List of error messages.
    """
    errors = []

    for ph_field in ["ph_optimal", "ph_min", "ph_max"]:
        if ph_field in data and data[ph_field] is not None:
            try:
                val = float(data[ph_field])
                if val < 0 or val > 14:
                    errors.append(f"{ph_field} must be 0-14, got {val}")
            except (TypeError, ValueError):
                errors.append(f"{ph_field} must be numeric, got {data[ph_field]}")

    for temp_field in ["temperature_optimal", "temperature_min", "temperature_max"]:
        if temp_field in data and data[temp_field] is not None:
            try:
                val = float(data[temp_field])
                if val < -50 or val > 500:
                    errors.append(f"{temp_field} suspicious value: {val}")
            except (TypeError, ValueError):
                pass  # Temperature ranges may be strings like "25-45"

    return errors


def validate_weights(weights: list[dict]) -> list[str]:
    """Validate weight assignments.

    Args:
        weights: List of weight assignment dicts.

    Returns:
        List of error messages.
    """
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd extraction && python -m pytest tests/test_validators.py -v`
Expected: All 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add extraction/validators.py extraction/tests/test_validators.py
git commit -m "feat: add automated validators for extraction quality checks"
```

---

### Task 11: Phase 4 — Deep Extraction + Writer

**Files:**
- Create: `extraction/pipeline/phase4_deep_extract.py`
- Create: `extraction/writer.py`

- [ ] **Step 1: Write the writer module**

```python
# extraction/writer.py
"""Write extraction results to prototype.md and feature-mapping.json.

Reads the prototype template format from templates/prototype-template.md
and generates filled prototype.md files with YAML frontmatter + markdown body.
"""

import json
from pathlib import Path
from datetime import date

from config import PROJECT_DIR


def generate_prototype_md(prototype_id: str, performance: dict, narrative: dict, applicability: dict) -> str:
    """Generate a filled prototype.md file from extraction results.

    Args:
        prototype_id: The prototype identifier.
        performance: Extracted performance data dict.
        narrative: Extracted biomimetic narrative dict.
        applicability: Extracted applicability data dict.

    Returns:
        Complete prototype.md content as a string.
    """
    # Build YAML frontmatter
    fm_fields = {
        "id": prototype_id,
        "name": prototype_id.replace("-", " ").title(),
        "category": "biomimetic_adsorbent",
        "features": performance.get("mechanisms_identified", []),
        "pollutants": performance.get("target_pollutants", []),
        "adsorption_mechanisms": performance.get("mechanisms_identified", []),
        "qmax_range": performance.get("qmax", {}).get("value"),
        "removal_rate": performance.get("removal_rate", {}).get("value"),
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

    # Build markdown body
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
        f"qmax: {performance.get('qmax', {}).get('value', '[待补充]')} mg/g",
        f"Removal rate: {performance.get('removal_rate', {}).get('value', '[待补充]')}%",
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
        "\n## 6. Applicable Scenarios\n",
        "[待补充]",
        "\n## 7. Related Prototypes\n",
        "[待补充]",
        "\n## 8. References\n",
        "[待补充]",
    ]

    return "\n".join(yaml_lines) + "\n".join(body_lines)


def write_prototype_file(prototype_id: str, content: str, project_dir: Path = None) -> Path:
    """Write a prototype.md file to the correct directory.

    Args:
        prototype_id: The prototype identifier.
        content: The markdown content.
        project_dir: Project root directory.

    Returns:
        Path to the written file.
    """
    project_dir = project_dir or PROJECT_DIR
    proto_dir = project_dir / "prototypes" / prototype_id
    proto_dir.mkdir(parents=True, exist_ok=True)

    output_path = proto_dir / "prototype.md"
    output_path.write_text(content, encoding="utf-8")
    return output_path


def update_feature_mapping(prototype_id: str, weight_assignments: list[dict], project_dir: Path = None) -> None:
    """Update feature-mapping.json with new weight assignments.

    Args:
        prototype_id: The prototype identifier.
        weight_assignments: List of weight assignment dicts from LLM.
        project_dir: Project root directory.
    """
    project_dir = project_dir or PROJECT_DIR
    mapping_path = project_dir / "feature-mapping.json"

    with open(mapping_path, encoding="utf-8") as f:
        mapping = json.load(f)

    for wa in weight_assignments:
        mapping_type = wa.get("mapping_type")
        entry_key = wa.get("entry_key")
        weight = wa.get("weight")

        if mapping_type == "pollutant_prototype_map" and entry_key in mapping.get("pollutant_prototype_map", {}):
            pollutant_entries = mapping["pollutant_prototype_map"][entry_key]
            if isinstance(pollutant_entries, dict):
                for sub_key, entries in pollutant_entries.items():
                    if isinstance(entries, list):
                        for entry in entries:
                            if entry.get("id") == prototype_id:
                                entry["weight"] = weight
                                if wa.get("mechanism_summary"):
                                    entry["mechanism_summary"] = wa["mechanism_summary"]
                                if wa.get("design_hint"):
                                    entry["design_hint"] = wa["design_hint"]

        elif mapping_type == "feature_prototype_map" and entry_key in mapping.get("feature_prototype_map", {}):
            feature_entries = mapping["feature_prototype_map"][entry_key]
            if isinstance(feature_entries, list):
                for entry in feature_entries:
                    if entry.get("id") == prototype_id:
                        entry["weight"] = weight

    with open(mapping_path, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=2)
```

- [ ] **Step 2: Write Phase 4 implementation**

```python
# extraction/pipeline/phase4_deep_extract.py
"""Phase 4: Deep Extraction — full extraction + weight assignment.

Three task types:
1. Performance data extraction (qwen3.6-plus)
2. Biomimetic narrative extraction (qwen3.7-max)
3. Weight assignment (qwen3.7-max)

Produces:
- prototypes/<id>/prototype.md for each prototype
- Updated feature-mapping.json with refined weights
"""

import json
from pathlib import Path

from config import OUTPUT_DIR, PROJECT_DIR
from llm_client import LLMClient
from pdf_utils import extract_full_text
from validators import validate_performance_data, validate_applicability, validate_weights
from writer import generate_prototype_md, write_prototype_file, update_feature_mapping
from jinja2 import Environment, FileSystemLoader


_env = Environment(loader=FileSystemLoader(str(Path(__file__).parent.parent / "prompts")))
_perf_prompt = _env.get_template("deep_performance.j2")
_narr_prompt = _env.get_template("biomimetic_narrative.j2")
_weight_prompt = _env.get_template("weight_assign.j2")


def extract_performance(prototype_id: str, paper_paths: list[str], llm: LLMClient) -> dict:
    """Extract performance data from papers for one prototype.

    Args:
        prototype_id: The prototype identifier.
        paper_paths: List of PDF file paths.
        llm: LLMClient for performance_extract task.

    Returns:
        Aggregated performance data dict.
    """
    all_results = []
    for path_str in paper_paths:
        full_text = extract_full_text(Path(path_str))
        if not full_text or len(full_text.strip()) < 200:
            continue

        prompt = _perf_prompt.render(
            paper_meta=Path(path_str).stem,
            prototype_id=prototype_id,
            full_text=full_text[:8000],
        )
        try:
            result = llm.chat_json(prompt)
            all_results.append(result)
        except Exception as e:
            all_results.append({"_error": str(e), "_source": path_str})

    # Merge results: take best qmax, aggregate mechanisms, etc.
    merged = {"_source_count": len(all_results), "_sources": []}
    for r in all_results:
        if "_error" not in r:
            merged["_sources"].append(r)

    if merged["_sources"]:
        # Take best values
        best_qmax = max(
            (s.get("performance_data", {}).get("qmax", {}) for s in merged["_sources"]),
            key=lambda x: float(x.get("value", 0) or 0),
            default={},
        )
        merged["qmax"] = best_qmax

        all_mechanisms = set()
        for s in merged["_sources"]:
            mechanisms = s.get("mechanisms_identified", [])
            if mechanisms:
                all_mechanisms.update(mechanisms)
        merged["mechanisms_identified"] = list(all_mechanisms)

        # Merge applicability
        for s in merged["_sources"]:
            if s.get("applicability"):
                merged.setdefault("applicability", {}).update(s["applicability"])

        # Merge characterization
        for s in merged["_sources"]:
            if s.get("material_characterization"):
                merged.setdefault("material_characterization", {}).update(s["material_characterization"])

    return merged


def extract_narrative(prototype_id: str, paper_paths: list[str], llm: LLMClient) -> dict:
    """Extract biomimetic design narrative from supplemented papers.

    Args:
        prototype_id: The prototype identifier.
        paper_paths: List of PDF file paths (supplemented biomimetic papers).
        llm: LLMClient for biomimetic_extract task.

    Returns:
        Aggregated biomimetic narrative dict.
    """
    all_results = []
    for path_str in paper_paths:
        full_text = extract_full_text(Path(path_str))
        if not full_text or len(full_text.strip()) < 200:
            continue

        prompt = _narr_prompt.render(
            paper_meta=Path(path_str).stem,
            prototype_id=prototype_id,
            prototype_name=prototype_id.replace("-", " ").title(),
            full_text=full_text[:8000],
        )
        try:
            result = llm.chat_json(prompt, max_tokens=8192)
            all_results.append(result)
        except Exception as e:
            all_results.append({"_error": str(e)})

    # Merge narratives: prefer most complete entries
    merged = {}
    for key in ["problem_definition", "biological_solution", "key_feature_extraction",
                 "design_mapping", "explainability_anchors", "engineering_constraints"]:
        for r in all_results:
            if key in r and r[key]:
                merged[key] = r[key]
                break  # Take first non-null

    return merged


def assign_weights(prototype_id: str, coarse_profile: dict,
                   extraction_results: list[dict], mapping_entries: list[dict],
                   llm: LLMClient) -> list[dict]:
    """Assign weights to feature-mapping entries for one prototype.

    Args:
        prototype_id: The prototype identifier.
        coarse_profile: The coarse profile from Phase 1.
        extraction_results: Combined extraction results.
        mapping_entries: Current mapping entries from feature-mapping.json.
        llm: LLMClient for weight_assign task.

    Returns:
        List of weight assignment dicts.
    """
    prompt = _weight_prompt.render(
        prototype_id=prototype_id,
        prototype_name=prototype_id.replace("-", " ").title(),
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
    """Execute Phase 4: Deep Extraction.

    Args:
        output_dir: Path to read Phase 1-3 outputs from.
        project_dir: Path to the Biomimetic Design Library project root.
    """
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

        # Collect paper paths from coarse profile
        paper_paths = [
            p["path"] for p in coarse_profile.get("direct_papers", []) + coarse_profile.get("indirect_papers", [])[:5]
        ]

        # Task 1: Performance extraction
        print(f"    Extracting performance data from {len(paper_paths)} papers...")
        performance = extract_performance(prototype_id, paper_paths, perf_llm)

        # Task 2: Biomimetic narrative (if supplemented papers exist)
        supplement_dir = Path(output_dir) / "supplemented-papers" / prototype_id
        supplement_paths = []
        if supplement_dir.exists():
            supplement_paths = [str(p) for p in supplement_dir.glob("*.pdf")]

        narrative = {}
        if supplement_paths:
            print(f"    Extracting biomimetic narrative from {len(supplement_paths)} supplemented papers...")
            narrative = extract_narrative(prototype_id, supplement_paths, narr_llm)

        # Task 3: Weight assignment
        # Load current mapping entries for this prototype
        mapping_path = project_dir / "feature-mapping.json"
        with open(mapping_path, encoding="utf-8") as f:
            full_mapping = json.load(f)

        relevant_entries = []
        for section in ["pollutant_prototype_map", "feature_prototype_map"]:
            section_data = full_mapping.get(section, {})
            relevant_entries.append({"section": section, "entries": section_data})

        print(f"    Assigning weights...")
        extraction_results = [performance] + ([narrative] if narrative else [])
        weight_assignments = assign_weights(
            prototype_id, coarse_profile, extraction_results, relevant_entries, weight_llm
        )

        # Validate
        perf_errors = validate_performance_data(performance)
        weight_errors = validate_weights(weight_assignments)
        all_errors = perf_errors + weight_errors

        if all_errors:
            print(f"    WARNING: {len(all_errors)} validation errors for {prototype_id}:")
            for err in all_errors:
                print(f"      - {err}")

        # Write prototype.md
        applicability = performance.get("applicability", {})
        content = generate_prototype_md(prototype_id, performance, narrative, applicability)
        out_path = write_prototype_file(prototype_id, content, project_dir)
        print(f"    Written {out_path}")

        # Update feature-mapping.json
        if weight_assignments and not any("_error" in wa for wa in weight_assignments):
            update_feature_mapping(prototype_id, weight_assignments, project_dir)
            print(f"    Updated feature-mapping.json weights for {prototype_id}")

    print("Phase 4 complete.")
```

- [ ] **Step 3: Commit**

```bash
git add extraction/pipeline/phase4_deep_extract.py extraction/writer.py
git commit -m "feat: implement Phase 4 deep extraction, writer, and weight assignment"
```

---

### Task 12: CLI Entry Point

**Files:**
- Create: `extraction/run_pipeline.py`

- [ ] **Step 1: Write the CLI entry point**

```python
# extraction/run_pipeline.py
"""CLI entry point for the biomimetic extraction pipeline.

Usage:
    python run_pipeline.py phase1          # Coarse scan
    python run_pipeline.py phase2          # Gap analysis
    python run_pipeline.py phase3          # Supplementation planning
    python run_pipeline.py phase4          # Deep extraction
    python run_pipeline.py all             # Run all phases sequentially
    python run_pipeline.py phase1 phase2   # Run specific phases
"""

import sys
from pathlib import Path

# Add extraction dir to path
sys.path.insert(0, str(Path(__file__).parent))

from config import OUTPUT_DIR, LITERATURE_DIR, PROJECT_DIR


PHASES = {
    "phase1": ("Phase 1: Coarse Scan", "pipeline.phase1_coarse_scan", "run_phase1"),
    "phase2": ("Phase 2: Gap Analysis", "pipeline.phase2_gap_analysis", "run_phase2"),
    "phase3": ("Phase 3: Supplementation Planning", "pipeline.phase3_supplement_plan", "run_phase3"),
    "phase4": ("Phase 4: Deep Extraction", "pipeline.phase4_deep_extract", "run_phase4"),
}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    phases_to_run = sys.argv[1:]
    if "all" in phases_to_run:
        phases_to_run = list(PHASES.keys())

    for phase_key in phases_to_run:
        if phase_key not in PHASES:
            print(f"Unknown phase: {phase_key}. Available: {list(PHASES.keys())}")
            sys.exit(1)

    for phase_key in phases_to_run:
        name, module_name, func_name = PHASES[phase_key]
        print(f"\n{'='*60}")
        print(f"  {name}")
        print(f"{'='*60}\n")

        module = __import__(module_name, fromlist=[func_name])
        func = getattr(module, func_name)

        if phase_key == "phase1":
            func(literature_dir=LITERATURE_DIR, output_dir=OUTPUT_DIR)
        elif phase_key == "phase4":
            func(output_dir=OUTPUT_DIR, project_dir=PROJECT_DIR)
        else:
            func(output_dir=OUTPUT_DIR)

    print(f"\nAll requested phases complete. Output: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Commit**

```bash
git add extraction/run_pipeline.py
git commit -m "feat: add CLI entry point for pipeline phase selection"
```

---

### Task 13: Integration Smoke Test

**Files:**
- Create: `extraction/tests/test_integration.py`

- [ ] **Step 1: Write integration test**

```python
# extraction/tests/test_integration.py
"""Integration smoke test — verifies all modules can be imported and basic flows work."""

import json
from pathlib import Path
import pytest

from filename_parser import parse_filename
from prototype_mapper import PrototypeMapper
from validators import validate_performance_data, validate_weights
from writer import generate_prototype_md


class TestIntegration:
    def test_end_to_end_filename_to_prototype(self):
        """Verify the flow: filename → parse → map to prototype."""
        meta = parse_filename("2022-Eltaweil-alginate-bone-magnetic-adsorption-review.pdf")
        mapper = PrototypeMapper()
        results = mapper.map_paper(meta, group="coordination_chelation")
        assert len(results) > 0
        # alginate should match alginate-adsorbent
        proto_ids = [r["prototype_id"] for r in results]
        assert "alginate-adsorbent" in proto_ids

    def test_generate_prototype_md_produces_valid_output(self):
        """Verify prototype.md generation produces valid YAML frontmatter + markdown."""
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
                "problem_definition": {
                    "nature_challenge": "Mussels adhere to wet surfaces underwater",
                    "water_treatment_mapping": "Wet adhesion enables coating of adsorbent substrates",
                },
                "biological_solution": {"evolutionary_strategy": "Catechol-rich adhesive proteins"},
                "key_feature_extraction": {
                    "must_keep_features": ["catechol groups", "amine functionality"],
                    "adjustable_features": ["polymer backbone", "crosslinking density"],
                },
                "design_mapping": {"bio_to_material": "Dopamine as catechol analogue for surface coating"},
                "explainability_anchors": {"one_line_story": "Inspired by mussel foot proteins"},
            },
            applicability={"ph_range": "4-9", "temperature_range": "20-40°C"},
        )
        assert "---" in content  # Has YAML frontmatter
        assert "mussel-foot-adhesion" in content
        assert "Biomimetic Design Narrative" in content

    def test_validators_catch_bad_data(self):
        """Verify validators catch clearly invalid data."""
        perf_errors = validate_performance_data({"qmax": -5, "removal_rate": 150})
        assert len(perf_errors) == 2

        weight_errors = validate_weights([{"weight": 2.0}])
        assert len(weight_errors) == 1
```

- [ ] **Step 2: Run integration test**

Run: `cd extraction && python -m pytest tests/test_integration.py -v`
Expected: All 3 tests PASS

- [ ] **Step 3: Commit**

```bash
git add extraction/tests/test_integration.py
git commit -m "test: add integration smoke test for extraction pipeline"
```
