#!/usr/bin/env python3
"""
Merge all existing extraction results into a unified directory structure
that mirrors the source literature folders:
  outputs/extractions/
  ├── 英文文献/
  ├── 中文文献/
  ├── 专利/
  ├── 书本/
  └── manifests/

Also builds a unified progress tracker and remaining-queue file.
"""
import json
import os
import shutil
from collections import Counter
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SRC_ROOT = REPO / "workspace" / "近海油气田污染物相关文献"
OUT_ROOT = REPO / "outputs" / "extractions"

# Source category directories (relative to SRC_ROOT)
CATEGORIES = {
    "英文文献": "英文文献",
    "中文文献": "中文文献",
    "专利": "专利",
    "书本": "书本",
}

# Existing output directories to scan for JSONs
EXISTING_OUTPUTS = [
    REPO / "outputs" / "en_literature_batch",
    REPO / "outputs" / "en_literature_multi",
    REPO / "outputs" / "book_test_en_ch21",
    REPO / "outputs" / "book_test_workspace",
]

# Workspace extracted results
WORKSPACE_RESULTS = REPO / "workspace" / "提取结果"


def sha1(text: str) -> str:
    return hashlib.sha1(text.encode("utf-8")).hexdigest()


def is_v2_json(path: Path) -> bool:
    """Check if a JSON file has the full jjj-v2 schema."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            obj = json.load(f)
        return "schema_version" in obj or "knowledge_items" in obj
    except (json.JSONDecodeError, OSError):
        return False


def json_size(path: Path) -> int:
    try:
        return path.stat().st_size
    except OSError:
        return 0


def scan_existing_outputs():
    """Scan all existing output dirs and return {source_pdf_name: best_json_path}."""
    candidates = {}  # source_pdf_name -> [(size, json_path, source_dir)]

    for out_dir in EXISTING_OUTPUTS:
        json_dir = out_dir / "json"
        if not json_dir.is_dir():
            continue

        # Try to read success.tsv to map record_id -> pdf_path
        success_tsv = out_dir / "manifests" / "success.tsv"
        id_to_pdf = {}
        id_to_model = {}
        if success_tsv.is_file():
            with open(success_tsv, "r") as f:
                for line in f:
                    if line.startswith("timestamp"):
                        continue
                    parts = line.strip().split("\t")
                    if len(parts) >= 4:
                        pdf_path = parts[1]
                        record_id = parts[2]
                        model = parts[3] if len(parts) > 3 else "unknown"
                        pdf_name = os.path.basename(pdf_path)
                        id_to_pdf[record_id] = pdf_name
                        id_to_model[record_id] = model

        # Also check batch1 success if exists
        success_batch1 = out_dir / "manifests" / "success.tsv.batch1"
        if success_batch1.is_file():
            with open(success_batch1, "r") as f:
                for line in f:
                    if line.startswith("timestamp"):
                        continue
                    parts = line.strip().split("\t")
                    if len(parts) >= 4:
                        pdf_path = parts[1]
                        record_id = parts[2]
                        model = parts[3] if len(parts) > 3 else "unknown"
                        pdf_name = os.path.basename(pdf_path)
                        id_to_pdf[record_id] = pdf_name
                        id_to_model[record_id] = model

        for jf in json_dir.glob("*.json"):
            if not is_v2_json(jf):
                continue

            # Try to match by record_id (hash in filename)
            record_id = jf.stem
            pdf_name = id_to_pdf.get(record_id)

            # If no manifest match, try to extract from JSON
            if not pdf_name:
                try:
                    with open(jf) as f:
                        obj = json.load(f)
                    meta = obj.get("bibliographic_metadata", {})
                    pdf_name = meta.get("file_name", "")
                except:
                    pass

            if not pdf_name:
                continue

            model = id_to_model.get(record_id, "unknown")
            size = json_size(jf)
            if pdf_name not in candidates:
                candidates[pdf_name] = []
            candidates[pdf_name].append((size, jf, str(out_dir), model))

    # Pick the best (largest = most complete) JSON for each PDF
    best = {}
    for pdf_name, opts in candidates.items():
        opts.sort(key=lambda x: x[0], reverse=True)
        size, path, source, model = opts[0]
        best[pdf_name] = {
            "json_path": path,
            "size": size,
            "source_dir": source,
            "model": model,
            "alternatives": len(opts),
        }

    return best


def scan_workspace_results():
    """Scan workspace/提取结果/ for manually extracted JSONs."""
    results = {}
    if not WORKSPACE_RESULTS.is_dir():
        return results
    for jf in WORKSPACE_RESULTS.glob("*.json"):
        if not is_v2_json(jf):
            continue
        try:
            with open(jf) as f:
                obj = json.load(f)
            meta = obj.get("bibliographic_metadata", {})
            pdf_name = meta.get("file_name", "")
            if pdf_name:
                results[pdf_name] = {
                    "json_path": jf,
                    "size": json_size(jf),
                    "source_dir": str(WORKSPACE_RESULTS),
                    "model": "manual",
                    "alternatives": 1,
                }
        except:
            pass
    return results


def scan_unified_outputs():
    """Scan outputs/extractions/ so old batch folders can be safely removed."""
    results = {}
    manifest_models = {}
    manifest_path = OUT_ROOT / "manifests" / "success.tsv"
    if manifest_path.is_file():
        with open(manifest_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("timestamp"):
                    continue
                parts = line.rstrip("\n").split("\t")
                if len(parts) >= 4:
                    manifest_models[parts[1]] = parts[3]

    for cat in ["英文文献", "中文文献", "专利", "书本/中文", "书本/英文"]:
        json_dir = OUT_ROOT / cat / "json"
        if not json_dir.is_dir():
            continue
        for jf in json_dir.glob("*.json"):
            if not is_v2_json(jf):
                continue
            pdf_name = f"{jf.stem}.pdf"
            results[pdf_name] = {
                "json_path": jf,
                "size": json_size(jf),
                "source_dir": str(OUT_ROOT),
                "model": manifest_models.get(pdf_name, "unified"),
                "category": cat,
                "alternatives": 1,
            }
    return results


def categorize_pdf(pdf_name: str) -> str:
    """Determine which category a PDF belongs to by checking source dirs."""
    for cat_name, cat_dir in CATEGORIES.items():
        cat_path = SRC_ROOT / cat_dir
        if not cat_path.is_dir():
            continue
        # Search recursively
        for root, dirs, files in os.walk(cat_path):
            if pdf_name in files:
                # For 书本, check subdirectory
                if cat_name == "书本":
                    rel = os.path.relpath(root, cat_path)
                    if rel.startswith("中文"):
                        return "书本/中文"
                    elif rel.startswith("英文"):
                        return "书本/英文"
                return cat_name
    return "未知"


def build_pdf_index():
    """Build a complete index of all PDFs in source directories."""
    index = {}  # pdf_name -> {"category": str, "full_path": str}
    for cat_name, cat_dir in CATEGORIES.items():
        cat_path = SRC_ROOT / cat_dir
        if not cat_path.is_dir():
            continue
        for root, dirs, files in os.walk(cat_path):
            for fn in files:
                if fn.lower().endswith(".pdf"):
                    full_path = os.path.join(root, fn)
                    rel = os.path.relpath(root, cat_path)
                    if cat_name == "书本":
                        if rel.startswith("中文"):
                            category = "书本/中文"
                        elif rel.startswith("英文"):
                            category = "书本/英文"
                        else:
                            category = "书本"
                    else:
                        category = cat_name
                    index[fn] = {"category": category, "full_path": full_path}
    return index


def main():
    print("=" * 60)
    print("LitExtract 结果合并工具")
    print("=" * 60)

    # Step 1: Create unified output structure
    print("\n[1/5] 创建统一输出目录...")
    for cat in ["英文文献", "中文文献", "专利", "书本/中文", "书本/英文"]:
        (OUT_ROOT / cat / "json").mkdir(parents=True, exist_ok=True)
    (OUT_ROOT / "manifests").mkdir(parents=True, exist_ok=True)
    print(f"  输出目录: {OUT_ROOT}")

    # Step 2: Scan existing results
    print("\n[2/5] 扫描已有提参结果...")
    existing = scan_existing_outputs()
    workspace = scan_workspace_results()
    unified = scan_unified_outputs()
    # Merge (workspace results take lower priority unless they're the only option)
    for k, v in unified.items():
        if k not in existing:
            existing[k] = v
    for k, v in workspace.items():
        if k not in existing:
            existing[k] = v
    print(f"  找到 {len(existing)} 个有效的 v2 JSON")

    # Step 3: Copy JSONs to unified structure
    print("\n[3/5] 归类 JSON 到对应子目录...")
    success_entries = []
    copied = 0
    for pdf_name, info in sorted(existing.items()):
        category = info.get("category") or categorize_pdf(pdf_name)
        if category == "未知":
            # Try to infer from the en_pdfs hardlink
            en_pdf = REPO / "workspace" / "en_pdfs" / pdf_name
            if en_pdf.exists():
                category = "英文文献"

        if category == "未知":
            print(f"  ⚠ 无法分类: {pdf_name}")
            continue

        dest_json = OUT_ROOT / category / "json" / f"{os.path.splitext(pdf_name)[0]}.json"

        # Don't overwrite if existing is larger or the source is already the
        # unified destination.
        if dest_json.exists() and json_size(dest_json) >= info["size"]:
            pass
        elif Path(info["json_path"]).resolve() != dest_json.resolve():
            shutil.copy2(info["json_path"], dest_json)
            copied += 1

        success_entries.append({
            "pdf_name": pdf_name,
            "category": category,
            "json_path": str(dest_json),
            "size": info["size"],
            "model": info["model"],
            "source_dir": info["source_dir"],
        })

    print(f"  复制了 {copied} 个 JSON 文件")

    # Step 4: Count JSON files per output directory
    print("\n[4/5] 统计各分类...")
    cat_counts = {}
    for cat in ["英文文献", "中文文献", "专利", "书本/中文", "书本/英文"]:
        json_dir = OUT_ROOT / cat / "json"
        count = len(list(json_dir.glob("*.json"))) if json_dir.is_dir() else 0
        cat_counts[cat] = count
        print(f"  {cat}: {count} 个 JSON")

    # Step 5: Build unified manifest and remaining queue
    print("\n[5/5] 生成统一 manifest 和剩余队列...")

    # Write success manifest
    manifest_path = OUT_ROOT / "manifests" / "success.tsv"
    with open(manifest_path, "w") as f:
        f.write("timestamp\tpdf_name\tcategory\tmodel\tjson_path\tsize\n")
        for entry in success_entries:
            ts = datetime.now().isoformat(timespec="seconds")
            f.write(f"{ts}\t{entry['pdf_name']}\t{entry['category']}\t{entry['model']}\t{entry['json_path']}\t{entry['size']}\n")

    # Build PDF index and remaining queue
    pdf_index = build_pdf_index()
    extracted_names = set()
    for cat in ["英文文献", "中文文献", "专利", "书本/中文", "书本/英文"]:
        json_dir = OUT_ROOT / cat / "json"
        if json_dir.is_dir():
            for jf in json_dir.glob("*.json"):
                extracted_names.add(jf.stem + ".pdf")

    indexed_names = set(pdf_index)
    extracted_indexed_names = extracted_names & indexed_names
    orphan_json_names = sorted(extracted_names - indexed_names)
    done_by_category = Counter()
    for pdf_name in extracted_indexed_names:
        done_by_category[pdf_index[pdf_name]["category"]] += 1

    remaining = []
    for pdf_name, info in sorted(pdf_index.items()):
        if pdf_name not in extracted_names:
            remaining.append({"pdf_name": pdf_name, "category": info["category"], "full_path": info["full_path"]})

    # Write remaining queue
    queue_path = OUT_ROOT / "manifests" / "remaining_queue.tsv"
    with open(queue_path, "w") as f:
        f.write("pdf_name\tcategory\tfull_path\n")
        for item in remaining:
            f.write(f"{item['pdf_name']}\t{item['category']}\t{item['full_path']}\n")

    # Write progress summary
    progress = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "total_pdfs_in_library": len(pdf_index),
        "total_extracted": len(extracted_indexed_names),
        "total_remaining": len(remaining),
        "orphan_json_count": len(orphan_json_names),
        "by_category": {},
    }
    for cat in ["英文文献", "中文文献", "专利", "书本/中文", "书本/英文"]:
        cat_total = sum(1 for v in pdf_index.values() if v["category"] == cat)
        cat_done = done_by_category.get(cat, 0)
        progress["by_category"][cat] = {
            "total": cat_total,
            "extracted": cat_done,
            "remaining": cat_total - cat_done,
            "json_files": cat_counts.get(cat, 0),
        }

    progress_path = OUT_ROOT / "manifests" / "progress.json"
    with open(progress_path, "w", encoding="utf-8") as f:
        json.dump(progress, f, ensure_ascii=False, indent=2)

    # Summary
    print("\n" + "=" * 60)
    print("合并完成!")
    print("=" * 60)
    print(f"\n统一输出: {OUT_ROOT}")
    print(f"\n各分类已提参数量:")
    for cat in cat_counts:
        total = progress["by_category"].get(cat, {}).get("total", 0)
        done = progress["by_category"].get(cat, {}).get("extracted", 0)
        print(f"  {cat}: {done}/{total}")
    if orphan_json_names:
        print(f"\n注意: 发现 {len(orphan_json_names)} 个不在源文献库索引中的 JSON，未计入进度。")
    print(f"\n总计: {len(extracted_indexed_names)} 已提参 / {len(pdf_index)} 总文献")
    print(f"剩余: {len(remaining)} 篇待提参")
    print(f"\nManifest: {manifest_path}")
    print(f"剩余队列: {queue_path}")
    print(f"进度文件: {progress_path}")


if __name__ == "__main__":
    main()
