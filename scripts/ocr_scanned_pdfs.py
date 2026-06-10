#!/usr/bin/env python3
"""
OCR 处理扫描版 PDF — 使用模型视觉能力替代 tesseract
将扫描版 PDF 每页转为图片，用 qwen3.6-plus 提取文字，生成 visual_cache.json

用法:
  python3 scripts/ocr_scanned_pdfs.py /tmp/retry_pdfs/2021-CN113231014A-polydopamine-activated-carbon.pdf

输出:
  同目录下 _visual_cache.json (覆盖原文件)
"""

import argparse
import base64
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import fitz  # PyMuPDF
from openai import OpenAI

BAILIAN_BASE = "https://coding.dashscope.aliyuncs.com/v1"

OCR_PROMPT = """你是一个中文专利文献 OCR 专家。请仔细观察这一页 PDF 图片，将页面上所有可见文字完整转录为结构化 Markdown。

转录要求：
1. 正文文字完整转录，保留标题层级（#/##/###）
2. 表格转为 Markdown 表格
3. 图表描述保留
4. 公式转为 LaTeX 格式
5. 保留所有技术参数、数值、单位
6. 如果看不清楚，用 [unclear] 标记

输出纯 Markdown 文本，不要添加任何解释性文字。"""


def page_to_base64(doc, page_num: int, dpi: int = 200) -> str:
    """将 PDF 页面转为 base64 编码的 PNG 图片"""
    page = doc[page_num]
    pix = page.get_pixmap(dpi=dpi)
    img_bytes = pix.tobytes("png")
    return base64.b64encode(img_bytes).decode("utf-8")


def ocr_page(client: OpenAI, doc, page_num: int, model: str = "qwen3.6-plus",
             max_retries: int = 3) -> tuple:
    """OCR 单页 PDF，返回 (page_num, markdown_text)"""
    b64 = page_to_base64(doc, page_num, dpi=200)

    for attempt in range(max_retries):
        try:
            resp = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "user", "content": [
                        {"type": "text", "text": OCR_PROMPT},
                        {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
                    ]},
                ],
                max_tokens=4096,
                temperature=0.1,
            )
            text = resp.choices[0].message.content or ""
            print(f"  Page {page_num + 1}: {len(text)} chars extracted")
            return (page_num, text)
        except Exception as e:
            if attempt < max_retries - 1:
                wait = 2 ** (attempt + 1)
                print(f"  Page {page_num + 1}: retry {attempt + 1}/{max_retries} after {wait}s ({e})")
                time.sleep(wait)
            else:
                print(f"  Page {page_num + 1}: FAILED after {max_retries} attempts ({e})")
                return (page_num, "")


def ocr_scanned_pdf(pdf_path: str, api_key: str, model: str = "qwen3.6-plus",
                    max_workers: int = 4, dpi: int = 200) -> dict:
    """OCR 处理整个扫描版 PDF，返回 visual_cache 格式的数据"""
    doc = fitz.open(pdf_path)
    total_pages = len(doc)
    print(f"Processing {total_pages} pages from {os.path.basename(pdf_path)}")

    client = OpenAI(base_url=BAILIAN_BASE, api_key=api_key)

    # 并行 OCR 所有页面
    pages_text = {}
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(ocr_page, client, doc, i, model): i
            for i in range(total_pages)
        }
        for future in as_completed(futures):
            page_num, text = future.result()
            pages_text[page_num] = text

    doc.close()

    # 按页码排序
    sorted_pages = [pages_text[i] for i in range(total_pages)]

    # 构建 stage0 数据
    stage0 = {
        "pages_text": [{"page": i + 1, "text": t} for i, t in enumerate(sorted_pages)],
        "page_types": [{"page": i + 1, "type": "data_page"} for i in range(total_pages)],
        "anchor_title": None,
        "anchor_doi": None,
        "anchor_keywords": None,
        "data_page_nums": list(range(1, total_pages + 1)),
        "total_pages": total_pages,
        "preprocess_date": time.strftime("%Y-%m-%d"),
        "ocr_method": "model_vision",
        "ocr_model": model,
    }

    # 构建 visual_markdown (keyed by page number string)
    visual_markdown = {str(i + 1): text for i, text in enumerate(sorted_pages)}

    return {
        "stage0": stage0,
        "visual_markdown": visual_markdown,
    }


def main():
    parser = argparse.ArgumentParser(description="OCR scanned PDFs using model vision")
    parser.add_argument("pdf_path", help="Path to scanned PDF file")
    parser.add_argument("--api-key", help="Bailian API key")
    parser.add_argument("--model", default="qwen3.6-plus", help="Model to use")
    parser.add_argument("--max-workers", type=int, default=4, help="Parallel workers")
    parser.add_argument("--output", help="Output path (default: pdf_path_visual_cache.json)")

    args = parser.parse_args()

    api_key = (
        args.api_key
        or os.environ.get("BAILIAN_CODING_PLAN_API_KEY")
        or os.environ.get("DASHSCOPE_API_KEY")
    )
    if not api_key:
        # Try loading from .env
        env_file = os.path.join(os.path.dirname(__file__), "..", ".env")
        if os.path.exists(env_file):
            with open(env_file) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("BAILIAN_CODING_PLAN_API_KEY="):
                        api_key = line.split("=", 1)[1]
                    elif line.startswith("DASHSCOPE_API_KEY=") and not api_key:
                        api_key = line.split("=", 1)[1]

    if not api_key:
        print("ERROR: Set BAILIAN_CODING_PLAN_API_KEY or DASHSCOPE_API_KEY")
        sys.exit(1)

    result = ocr_scanned_pdf(args.pdf_path, api_key, args.model, args.max_workers)

    output_path = args.output or os.path.splitext(args.pdf_path)[0] + "_visual_cache.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    total_chars = sum(len(v) for v in result["visual_markdown"].values())
    print(f"\nSaved to {output_path}")
    print(f"Total extracted: {total_chars} chars from {result['stage0']['total_pages']} pages")


if __name__ == "__main__":
    main()
