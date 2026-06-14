#!/usr/bin/env python3
"""
LitExtract 并行预处理器 — Stage 0 + 并行 Stage 1
将 17 次串行视觉 API 调用变为并发执行，12 分钟 → ~1 分钟

用法:
  python3 scripts/preprocess.py paper.pdf [--max-workers 17]

输出:
  paper_visual_cache.json  — Stage 0 锚点 + Stage 1 视觉精读缓存
"""

import argparse
import base64
import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date

# Fix macOS CoreFoundation fork safety issue
os.environ['OBJC_DISABLE_INITIALIZE_FORK_SAFETY'] = 'YES'

import fitz  # PyMuPDF
from openai import OpenAI

# ═══════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════

PROVIDERS = {
    "dashscope": {
        "base_url": "https://coding.dashscope.aliyuncs.com/v1",
        "model": "qwen3.6-plus",
        "api_key_envs": ["BAILIAN_CODING_PLAN_API_KEY", "DASHSCOPE_API_KEY"],
    },
    "mimo": {
        "base_url": "https://token-plan-cn.xiaomimimo.com/v1",
        "model": "mimo-v2.5",
        "api_key_envs": ["MIMO_API_KEY", "XIAOMI_API_KEY"],
    },
}

VISUAL_READING_PROMPT = """你是一个学术文献视觉读取专家。请仔细观察这一页PDF图片，将页面上所有可见信息转录为结构化Markdown。

重要约束：
- 只转录你在图片中实际看到的内容，不要添加任何你"知道"但图片中没有的信息
- 如果某个数值看不清楚，用 [unclear] 标记，不要猜测
- 不要从你的训练知识中补充任何数据

转录要求：
1. 正文文字完整转录，保留标题层级（#/##/###）
2. 表格转为Markdown表格，确保表头与数据行严格对齐
3. Figure/图表：描述图中内容，尽量读出具体数值
4. 图注（Caption）完整转录
5. 公式转为LaTeX格式
6. 脚注完整保留
7. 在每个内容块前标注类型标签：[TEXT]、[TABLE]、[FIGURE]、[CAPTION]、[EQUATION]、[FOOTNOTE]

输出纯Markdown，不要添加任何解释性文字。"""

# ═══════════════════════════════════════════════════════════
# Stage 0: Text anchoring
# ═══════════════════════════════════════════════════════════

SKIP_KEYWORDS = ["References", "Bibliography", "REFERENCES", "BIBLIOGRAPHY",
                 "Supporting Information", "Electronic Supplementary Material",
                 "参考文献", "参考资料", "引用文献"]
CRYSTAL_KEYWORDS = ["CCDC number", "CCDC ", "R1 =", "wR2 =", "Crystal system",
                    "Crystal data", "space group", "Rint", "Goodness-of-fit",
                    "Flack parameter", "Residual density"]
NMR_SKIP_MARKERS = [r"δ\s*/\s*ppm", r"δ\(ppm\)", r"chemical shift.*\(ppm\)",
                    r"\d+\.\d+\s*\([dtsm]\)", r"Hz,\s*\d+H"]
META_NOISE = {"Angewandte Chemie", "International Edition", "Downloaded",
              "Wiley", "Online Library", "Terms", "Conditions"}


def is_skip_page(text: str) -> bool:
    stripped = text.strip()
    for kw in SKIP_KEYWORDS:
        if stripped.startswith(kw):
            return True
    crystal_score = sum(1 for kw in CRYSTAL_KEYWORDS if kw in text)
    if crystal_score >= 3:
        return True
    nmr_matches = sum(1 for pat in NMR_SKIP_MARKERS if re.search(pat, text, re.IGNORECASE))
    many_numbers = len(re.findall(r"\d+\.\d+", text)) > 15
    many_nmr_lines = len(re.findall(r"^\s*\d+\.\d+", text, re.MULTILINE)) > 5
    if (nmr_matches >= 2 and many_numbers) or many_nmr_lines:
        return True
    return False


def is_data_page(text: str, page_obj, page_num: int) -> bool:
    # English: Figure 1, Table 2, Fig. 3, Scheme S1, etc.
    # Chinese: 图1, 表2, 图 3, 附图1, 图一, 表十二, etc.
    has_ft = bool(re.search(
        r"\b(?:Figure|Table|Fig\.|Tab\.|Scheme)\b[\s]*[S]?\d+"
        r"|(?:附?图|表)\s*[〇零一二三四五六七八九十百\d]+",
        text, re.IGNORECASE))
    number_count = len(re.findall(r"\b\d+\.?\d*\b", text))
    try:
        images = page_obj.get_images(full=True)
        total_img_size = sum(img[2] for img in images if len(img) > 2)
    except Exception:
        total_img_size = 0
    if page_num <= 10:
        return has_ft
    if total_img_size > 50000 and has_ft and number_count > 2:
        return True
    return False


def run_stage0(pdf_path: str) -> dict:
    doc = fitz.open(pdf_path)
    if doc.page_count < 1:
        doc.close()
        raise ValueError(f"PDF has no readable pages: {pdf_path}")

    pages_text, page_types = [], []
    for i, page in enumerate(doc):
        text = page.get_text()
        pages_text.append({"page": i + 1, "text": text})
        if is_skip_page(text):
            page_types.append({"page": i + 1, "type": "skip_page"})
        elif is_data_page(text, page, i + 1):
            page_types.append({"page": i + 1, "type": "data_page"})
        else:
            page_types.append({"page": i + 1, "type": "text_page"})

    total_text_chars = sum(len(p["text"].strip()) for p in pages_text)
    nonempty_text_pages = sum(1 for p in pages_text if len(p["text"].strip()) >= 20)
    avg_text_chars_per_page = total_text_chars / max(1, len(pages_text))
    sparse_long_document = (
        len(pages_text) >= 20
        and avg_text_chars_per_page < 30
        and nonempty_text_pages <= max(3, int(len(pages_text) * 0.25))
    )
    if total_text_chars < 100 or sparse_long_document:
        # Image-only/scanned PDFs need visual reading even if no Figure/Table
        # anchors can be detected from the missing text layer.
        page_types = [{"page": p["page"], "type": "data_page"} for p in pages_text]

    front_text = " ".join(p["text"] for p in pages_text[:3])
    doi_match = re.search(r"10\.\d{4,}/[^\s]+", front_text)
    anchor_doi = doi_match.group(0) if doi_match else None
    page1_lines = [l.strip() for l in pages_text[0]["text"].split("\n")
                   if l.strip() and len(l.strip()) > 10]
    anchor_title = max(page1_lines[:10], key=len) if page1_lines else ""
    kw_match = re.search(r"(?:Keywords|KEYWORDS|关键词)[:：]\s*(.+)", front_text, re.IGNORECASE)
    anchor_keywords = [k.strip() for k in re.split(r"[,，;；]", kw_match.group(1))] if kw_match else []

    data_pages = [pt for pt in page_types if pt["type"] == "data_page"]
    text_count = sum(1 for pt in page_types if pt["type"] == "text_page")
    skip_count = sum(1 for pt in page_types if pt["type"] == "skip_page")
    print(f"Stage 0: {len(doc)} pages → {len(data_pages)} data, "
          f"{text_count} text, {skip_count} skip")
    print(f"  Title: {anchor_title[:80]}...")
    print(f"  DOI: {anchor_doi}")
    doc.close()
    return {
        "pages_text": pages_text,
        "page_types": page_types,
        "anchor_title": anchor_title,
        "anchor_doi": anchor_doi,
        "anchor_keywords": anchor_keywords,
        "data_page_nums": [dp["page"] for dp in data_pages],
        "total_pages": len(pages_text),
        "preprocess_date": date.today().isoformat(),
    }


def limit_visual_pages(stage0: dict, max_visual_pages: int) -> dict:
    """Limit expensive visual reads while keeping front matter and broad coverage."""
    if max_visual_pages <= 0:
        return stage0

    data_page_nums = list(stage0.get("data_page_nums", []))
    if len(data_page_nums) <= max_visual_pages:
        return stage0

    total_pages = int(stage0.get("total_pages") or 0)
    selected: set[int] = set()

    front_limit = min(total_pages or 20, 20)
    front_pages = [p for p in data_page_nums if p <= front_limit]
    selected.update(front_pages[:min(12, max_visual_pages)])

    remaining_slots = max_visual_pages - len(selected)
    remaining_pages = [p for p in data_page_nums if p not in selected]
    if remaining_slots > 0:
        if len(remaining_pages) <= remaining_slots:
            selected.update(remaining_pages)
        elif remaining_slots == 1:
            selected.add(remaining_pages[len(remaining_pages) // 2])
        else:
            last_idx = len(remaining_pages) - 1
            for i in range(remaining_slots):
                idx = round(i * last_idx / (remaining_slots - 1))
                selected.add(remaining_pages[idx])

    limited_page_nums = sorted(selected)
    stage0["original_data_page_nums"] = data_page_nums
    stage0["data_page_nums"] = limited_page_nums
    stage0["visual_page_selection"] = {
        "reason": "limited_by_max_visual_pages",
        "max_visual_pages": max_visual_pages,
        "original_data_pages": len(data_page_nums),
        "selected_data_pages": len(limited_page_nums),
        "strategy": "front_matter_then_even_sampling",
    }
    print(
        f"Stage 0: visual pages limited {len(data_page_nums)} → "
        f"{len(limited_page_nums)} (max={max_visual_pages})"
    )
    return stage0


# ═══════════════════════════════════════════════════════════
# Stage 1: Parallel visual reading
# ═══════════════════════════════════════════════════════════

def is_retryable_api_error(exc: Exception) -> bool:
    status_code = getattr(exc, "status_code", None)
    message = str(exc).lower()
    retry_markers = (
        "rate limit",
        "ratelimit",
        "throttling",
        "quota exceeded",
        "temporarily unavailable",
        "timeout",
        "connection",
    )
    return status_code in {408, 409, 429, 500, 502, 503, 504} or any(
        marker in message for marker in retry_markers
    )


def read_page_visual(client: OpenAI, pdf_path: str, page_num: int, model: str,
                     dpi: int = 150, retry_attempts: int = 6, retry_delay: int = 30,
                     http_timeout: float = 180) -> tuple:
    """Read a single page visually. Returns (page_num, markdown_text)."""
    doc = fitz.open(pdf_path)
    page = doc[page_num - 1]
    pix = page.get_pixmap(dpi=dpi)
    img_bytes = pix.tobytes("png")
    b64 = base64.b64encode(img_bytes).decode("utf-8")
    doc.close()

    messages = [{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
            {"type": "text", "text": VISUAL_READING_PROMPT},
        ],
    }]

    attempts = max(1, retry_attempts)
    for attempt in range(1, attempts + 1):
        try:
            resp = client.chat.completions.create(
                model=model,
                messages=messages,
                max_tokens=16384,
                timeout=http_timeout,
            )
            return page_num, resp.choices[0].message.content or ""
        except Exception as exc:
            if attempt >= attempts or not is_retryable_api_error(exc):
                raise
            wait_seconds = retry_delay * (2 ** (attempt - 1))
            print(
                f"  Page {page_num:>3} retry {attempt}/{attempts - 1} "
                f"after {wait_seconds}s: {exc}",
                file=sys.stderr,
            )
            time.sleep(wait_seconds)


def run_stage1_parallel(stage0: dict, pdf_path: str, api_key: str,
                        provider_cfg: dict,
                        max_workers: int = 17, retry_attempts: int = 6,
                        retry_delay: int = 30) -> tuple[dict[int, str], float]:
    """Run all data page visual reads in parallel. Returns (results, elapsed_seconds)."""
    client = OpenAI(base_url=provider_cfg["base_url"], api_key=api_key, timeout=180, max_retries=0)
    model = provider_cfg["model"]
    page_nums = stage0["data_page_nums"]

    print(f"\nStage 1: {len(page_nums)} pages in parallel (max_workers={max_workers}, model={model})...")
    t0 = time.time()
    results: dict[int, str] = {}

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(
                read_page_visual,
                client,
                pdf_path,
                pg,
                model=model,
                retry_attempts=retry_attempts,
                retry_delay=retry_delay,
            ): pg
            for pg in page_nums
        }
        for future in as_completed(futures):
            pg_num, md = future.result()
            results[pg_num] = md
            elapsed = time.time() - t0
            print(f"  Page {pg_num:>3} OK ({len(md)} chars) [{elapsed:.0f}s]")

    stage1_elapsed = time.time() - t0
    print(f"  Done in {stage1_elapsed:.1f}s ({len(results)} pages)")
    return results, stage1_elapsed


# ═══════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════

def main() -> None:
    parser = argparse.ArgumentParser(
        description="LitExtract 并行预处理器 — Stage 0 + 并行 Stage 1"
    )
    parser.add_argument("pdf", help="PDF file path")
    parser.add_argument("--api-key", help="API key (overrides provider default)", default=None)
    parser.add_argument("--provider", choices=["dashscope", "mimo"], default="dashscope",
                        help="Vision API provider (default: dashscope)")
    parser.add_argument("--max-workers", type=int, default=17,
                        help="Max parallel workers (default: 17)")
    parser.add_argument("--retry-attempts", type=int, default=6,
                        help="Attempts per visual page on retryable API errors (default: 6)")
    parser.add_argument("--retry-delay", type=int, default=30,
                        help="Base retry delay in seconds, with exponential backoff (default: 30)")
    parser.add_argument("--max-visual-pages", type=int, default=0,
                        help="Maximum data pages to read visually; 0 means unlimited (default: 0)")
    parser.add_argument("-o", "--output", help="Cache output path", default=None)
    args = parser.parse_args()

    provider_cfg = PROVIDERS[args.provider]
    api_key = args.api_key
    if not api_key:
        for env_var in provider_cfg["api_key_envs"]:
            api_key = os.environ.get(env_var)
            if api_key:
                break
    if not api_key:
        env_list = " or ".join(provider_cfg["api_key_envs"])
        print(f"ERROR: Set {env_list}, or use --api-key")
        sys.exit(1)

    pdf_path = os.path.abspath(args.pdf)
    output_path = args.output or os.path.splitext(pdf_path)[0] + "_visual_cache.json"

    # Stage 0
    stage0_t0 = time.time()
    stage0 = run_stage0(pdf_path)
    stage0 = limit_visual_pages(stage0, args.max_visual_pages)
    stage0_elapsed = time.time() - stage0_t0
    print(f"Stage 0 elapsed: {stage0_elapsed:.1f}s")

    # Stage 1 (parallel)
    visual_results, stage1_elapsed = run_stage1_parallel(
        stage0,
        pdf_path,
        api_key,
        provider_cfg,
        args.max_workers,
        args.retry_attempts,
        args.retry_delay,
    )

    # Combine and save
    cache = {
        "stage0": stage0,
        "visual_markdown": {str(k): v for k, v in visual_results.items()},
    }
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)
    print(f"\nCache saved to: {output_path}")

    # Write timing JSON (for worker scripts to parse)
    timing_path = output_path + ".timing.json"
    timing_data = {
        "stage0_seconds": round(stage0_elapsed, 1),
        "stage1_seconds": round(stage1_elapsed, 1),
        "data_pages": len(stage0.get("data_page_nums", [])),
        "total_pages": stage0.get("total_pages", 0),
        "model": provider_cfg["model"],
    }
    with open(timing_path, "w", encoding="utf-8") as f:
        json.dump(timing_data, f, ensure_ascii=False, indent=2)
    print(f"Timing saved to: {timing_path}")


if __name__ == "__main__":
    main()
