#!/usr/bin/env python3
"""
分层抽样脚本：从各类型文献中选出代表性样本，用于 timing 性能分析。
按 (类型 × 页数分段) 分层，确保各类别均有覆盖。
"""

import os
import sys
import json
import random
import fitz  # PyMuPDF
from pathlib import Path
from collections import defaultdict

REPO_DIR = Path("/Users/panyao/Qoder/JJJ_Literature")
BASE_DIR = REPO_DIR / "近海油气田污染物相关文献"

# ── 抽样配额 ──────────────────────────────────────────────
# 每个类型的目标抽样数
QUOTAS = {
    "英文论文": 50,
    "中文论文": 30,
    "专利":     30,
    "书本":     20,
}

# 页数分段边界
PAGE_BINS = [
    ("short",   1,  10),
    ("medium", 11,  20),
    ("long",   21,  40),
    ("xlong",  41, 9999),
]

def get_page_count(pdf_path: str, timeout: int = 5) -> int:
    """快速读取 PDF 页数"""
    try:
        doc = fitz.open(pdf_path)
        n = doc.page_count
        doc.close()
        return n
    except Exception:
        return 0

def bin_for_pages(n: int) -> str:
    for label, lo, hi in PAGE_BINS:
        if lo <= n <= hi:
            return label
    return "unknown"

def scan_pdfs(directory: Path, category: str) -> list[dict]:
    """扫描目录下所有 PDF，返回 [{path, pages, bin, category, size_mb}]"""
    results = []
    if not directory.exists():
        print(f"  [WARN] 目录不存在: {directory}")
        return results

    pdf_files = sorted(directory.glob("*.pdf"))
    print(f"  扫描 {category}: {len(pdf_files)} 篇...", end=" ", flush=True)

    for i, pdf in enumerate(pdf_files):
        if (i + 1) % 500 == 0:
            print(f"({i+1})", end=" ", flush=True)
        pages = get_page_count(str(pdf))
        if pages == 0:
            continue
        results.append({
            "path": str(pdf),
            "name": pdf.name,
            "pages": pages,
            "bin": bin_for_pages(pages),
            "category": category,
            "size_mb": round(pdf.stat().st_size / 1024 / 1024, 1),
        })

    print(f"完成 ({len(results)} 可读)")
    return results

def stratified_sample(all_pdfs: list[dict], quota: int) -> list[dict]:
    """按页数分段分层抽样"""
    by_bin = defaultdict(list)
    for p in all_pdfs:
        by_bin[p["bin"]].append(p)

    # 计算每个 bin 的配额（按比例分配，至少 1 篇）
    total = len(all_pdfs)
    if total == 0:
        return []
    if total <= quota:
        return all_pdfs

    selected = []
    bin_quotas = {}
    remaining = quota

    for label, lo, hi in PAGE_BINS:
        n_in_bin = len(by_bin.get(label, []))
        if n_in_bin == 0:
            bin_quotas[label] = 0
            continue
        # 按比例分配，至少 1
        q = max(1, round(n_in_bin / total * quota))
        bin_quotas[label] = min(q, n_in_bin)

    # 调整使总数等于 quota
    while sum(bin_quotas.values()) > quota:
        # 减少最大的 bin
        largest = max(bin_quotas, key=bin_quotas.get)
        bin_quotas[largest] -= 1
    while sum(bin_quotas.values()) < quota:
        # 增加最大的 bin
        for label, _, _ in PAGE_BINS:
            n_in_bin = len(by_bin.get(label, []))
            if bin_quotas.get(label, 0) < n_in_bin:
                bin_quotas[label] = bin_quotas.get(label, 0) + 1
                break

    # 从每个 bin 中随机抽样
    random.seed(42)  # 可复现
    for label, lo, hi in PAGE_BINS:
        pool = by_bin.get(label, [])
        q = bin_quotas.get(label, 0)
        if q >= len(pool):
            selected.extend(pool)
        else:
            selected.extend(random.sample(pool, q))

    return selected

def main():
    print("=" * 60)
    print("分层抽样 — 提参 Timing 性能分析样本选取")
    print("=" * 60)

    # 1. 扫描所有类型
    print("\n[1/3] 扫描 PDF 文件...")
    all_by_category = {}

    all_by_category["英文论文"] = scan_pdfs(BASE_DIR / "英文文献", "英文论文")
    all_by_category["中文论文"] = scan_pdfs(BASE_DIR / "中文文献", "中文论文")

    # 专利可能有子目录
    patent_pdfs = []
    patent_dir = BASE_DIR / "专利"
    if patent_dir.exists():
        for sub in patent_dir.iterdir():
            if sub.is_dir():
                patent_pdfs.extend(scan_pdfs(sub, "专利"))
            elif sub.suffix.lower() == ".pdf":
                pages = get_page_count(str(sub))
                if pages > 0:
                    patent_pdfs.append({
                        "path": str(sub), "name": sub.name,
                        "pages": pages, "bin": bin_for_pages(pages),
                        "category": "专利",
                        "size_mb": round(sub.stat().st_size / 1024 / 1024, 1),
                    })
    all_by_category["专利"] = patent_pdfs
    print(f"  扫描 专利: {len(patent_pdfs)} 篇 完成")

    # 书本合并中英文
    book_pdfs = scan_pdfs(BASE_DIR / "书本" / "中文", "书本")
    book_pdfs.extend(scan_pdfs(BASE_DIR / "书本" / "英文", "书本"))
    all_by_category["书本"] = book_pdfs

    # 2. 分层抽样
    print("\n[2/3] 分层抽样...")
    selected_all = []
    stats = {}

    for cat, quota in QUOTAS.items():
        pool = all_by_category.get(cat, [])
        selected = stratified_sample(pool, quota)
        selected_all.extend(selected)

        # 统计
        bin_counts = defaultdict(int)
        for p in selected:
            bin_counts[p["bin"]] += 1
        stats[cat] = {
            "total": len(pool),
            "selected": len(selected),
            "by_bin": dict(bin_counts),
            "avg_pages": round(sum(p["pages"] for p in selected) / max(1, len(selected)), 1),
            "avg_size_mb": round(sum(p["size_mb"] for p in selected) / max(1, len(selected)), 1),
        }
        print(f"  {cat}: {len(pool)} → {len(selected)} 篇 "
              f"(avg {stats[cat]['avg_pages']}页, {stats[cat]['avg_size_mb']}MB)")

    # 3. 输出结果
    print("\n[3/3] 输出结果...")
    out_dir = REPO_DIR / "outputs" / "timing_sample"
    out_dir.mkdir(parents=True, exist_ok=True)

    # 按类型输出文件列表
    for cat in QUOTAS:
        cat_pdfs = [p for p in selected_all if p["category"] == cat]
        list_file = out_dir / f"{cat}_sample.txt"
        with open(list_file, "w", encoding="utf-8") as f:
            for p in cat_pdfs:
                f.write(p["path"] + "\n")
        print(f"  {list_file.name}: {len(cat_pdfs)} 篇")

    # 输出合并的抽样清单（JSON）
    manifest = {
        "total_selected": len(selected_all),
        "stats": stats,
        "samples": selected_all,
    }
    manifest_file = out_dir / "timing_sample_manifest.json"
    with open(manifest_file, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    # 输出汇总表
    print(f"\n{'=' * 60}")
    print(f"抽样汇总")
    print(f"{'=' * 60}")
    print(f"{'类型':<10} {'总数':>6} {'选中':>6} {'短篇':>6} {'中篇':>6} {'长篇':>6} {'超长':>6} {'均页':>6} {'均MB':>6}")
    print("-" * 60)
    total_selected = 0
    for cat in QUOTAS:
        s = stats[cat]
        b = s["by_bin"]
        total_selected += s["selected"]
        print(f"{cat:<10} {s['total']:>6} {s['selected']:>6} "
              f"{b.get('short',0):>6} {b.get('medium',0):>6} "
              f"{b.get('long',0):>6} {b.get('xlong',0):>6} "
              f"{s['avg_pages']:>6.1f} {s['avg_size_mb']:>6.1f}")
    print("-" * 60)
    print(f"{'合计':<10} {'':<6} {total_selected:>6}")
    print(f"\nManifest: {manifest_file}")

if __name__ == "__main__":
    main()
