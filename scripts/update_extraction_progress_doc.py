#!/usr/bin/env python3
"""Generate the extraction progress entry document from unified manifests."""

from __future__ import annotations

import csv
import json
from collections import Counter
from datetime import datetime
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
MANIFEST_DIR = REPO / "outputs" / "extractions" / "manifests"
SUCCESS_TSV = MANIFEST_DIR / "success.tsv"
REMAINING_TSV = MANIFEST_DIR / "remaining_queue.tsv"
PROGRESS_JSON = MANIFEST_DIR / "progress.json"
OUT_DOC = REPO / "docs" / "extraction-progress-tracker.md"
EXTRACTIONS_DIR = REPO / "outputs" / "extractions"


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def read_progress() -> dict:
    if not PROGRESS_JSON.is_file():
        return {}
    with PROGRESS_JSON.open("r", encoding="utf-8") as f:
        return json.load(f)


def rel(path: str | Path) -> str:
    p = Path(path)
    try:
        return str(p.relative_to(REPO))
    except ValueError:
        return str(p)


def table(rows: list[list[str]]) -> str:
    if not rows:
        return ""
    header = rows[0]
    sep = ["---"] * len(header)
    lines = [
        "| " + " | ".join(header) + " |",
        "| " + " | ".join(sep) + " |",
    ]
    for row in rows[1:]:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def category_rows(progress: dict, success_rows: list[dict[str, str]], remaining_rows: list[dict[str, str]]) -> list[list[str]]:
    categories = progress.get("by_category") or {}
    success_counter = Counter(r.get("category", "unknown") for r in success_rows)
    remaining_counter = Counter(r.get("category", "unknown") for r in remaining_rows)

    names = list(categories)
    for name in sorted(set(success_counter) | set(remaining_counter)):
        if name not in names and name:
            names.append(name)

    rows = [["分类", "总数", "已提参", "剩余", "进度"]]
    for name in names:
        item = categories.get(name, {})
        if name in categories:
            total = int(item.get("total", 0))
            extracted = int(item.get("extracted", 0))
            remaining = int(item.get("remaining", 0))
        else:
            total = success_counter[name] + remaining_counter[name]
            extracted = success_counter[name]
            remaining = remaining_counter[name]
        pct = f"{(extracted / total * 100):.2f}%" if total else "n/a"
        rows.append([name, str(total), str(extracted), str(remaining), pct])
    return rows


def compact_success_rows(rows: list[dict[str, str]], count: int = 20) -> list[list[str]]:
    selected = rows[-count:]
    out = [["时间", "分类", "模型", "文献"]]
    for r in selected:
        out.append([
            r.get("timestamp", ""),
            r.get("category", ""),
            r.get("model", ""),
            r.get("pdf_name", ""),
        ])
    return out


def next_queue_rows(rows: list[dict[str, str]], count: int = 50) -> list[list[str]]:
    selected = rows[:count]
    out = [["序号", "分类", "待提文献"]]
    for i, r in enumerate(selected, 1):
        out.append([str(i), r.get("category", ""), r.get("pdf_name", "")])
    return out


def json_counts() -> list[list[str]]:
    rows = [["输出目录", "JSON 数量"]]
    for cat in ["英文文献", "中文文献", "专利", "书本/中文", "书本/英文"]:
        json_dir = EXTRACTIONS_DIR / cat / "json"
        if not json_dir.is_dir():
            continue
        rows.append([rel(json_dir), str(sum(1 for _ in json_dir.glob("*.json")))])
    return rows


def main() -> None:
    progress = read_progress()
    success_rows = read_tsv(SUCCESS_TSV)
    remaining_rows = read_tsv(REMAINING_TSV)

    total = progress.get("total_pdfs_in_library") or len(success_rows) + len(remaining_rows)
    extracted = progress.get("total_extracted") or len(success_rows)
    remaining = progress.get("total_remaining") or len(remaining_rows)
    pct = f"{(int(extracted) / int(total) * 100):.2f}%" if total else "n/a"

    generated_at = datetime.now().astimezone().isoformat(timespec="seconds")
    progress_generated = progress.get("generated_at", "unknown")

    content = f"""# 提参进度记录

> 每次开始新批次前先读这份文档。它由 `scripts/update_extraction_progress_doc.py` 从统一 manifest 生成。

## 当前摘要

| 项目 | 值 |
| --- | --- |
| 文档更新时间 | {generated_at} |
| manifest 生成时间 | {progress_generated} |
| 文献库总量 | {total} |
| 已提参 | {extracted} |
| 剩余 | {remaining} |
| 总进度 | {pct} |

## 权威文件

| 用途 | 文件 |
| --- | --- |
| 统一成功清单 | `{rel(SUCCESS_TSV)}` |
| 统一剩余队列 | `{rel(REMAINING_TSV)}` |
| 统计摘要 | `{rel(PROGRESS_JSON)}` |
| 统一输出根目录 | `outputs/extractions/` |
| 批次运行目录 | `/tmp/openclaw/litextract_runs/<run_id>/`，保存 raw、logs、prompts 和本批 manifest |

## 分类进度

{table(category_rows(progress, success_rows, remaining_rows))}

## 输出 JSON 计数

{table(json_counts())}

## 最近已提文献

{table(compact_success_rows(success_rows))}

## 下一批候选

下面是 `remaining_queue.tsv` 当前队首的 50 篇。每批只跑几十篇时，优先从这里取，避免跳号和重复。

{table(next_queue_rows(remaining_rows))}

## 开工流程

1. 先合并最新批次结果：`python3 scripts/merge_results.py`
2. 再刷新本文档：`python3 scripts/update_extraction_progress_doc.py`
3. 阅读本文档的“当前摘要”“最近已提文献”“下一批候选”。
4. 启动新批次时用 `--limit N` 控制几十篇规模。
5. 批次结束后重复第 1 步和第 2 步，让下一次开工看到最新状态。

## 注意事项

- `success.tsv` 和 `remaining_queue.tsv` 是避免遗漏、重复的主依据。
- 启动新任务前用 `--workers 1|2|3` 选择并发路数。
- `--workers 1` 只用 `mimo/mimo-v2.5`；`--workers 2` 用 `bailian/qwen3.6-plus` + `mimo/mimo-v2.5`；`--workers 3` 用 dashscope + bailian + mimo。
- 需要每路固定篇数时，用 `--per-worker-limit N`，例如三路各 99 篇：`bash scripts/launch_multi_extract.sh --workers 3 --per-worker-limit 99`。
- 英文批量提参默认读取 `workspace/en_pdfs/` hardlink 目录；不要直接用 symlink 目录喂给 OpenClaw。
- `scripts/multi_worker_extract.sh` 会跳过 `outputs/extractions/` 中已存在的有效 JSON。
- `outputs/extractions/` 是长期保留目录；批次运行目录可在合并后清理。
- 多 worker 并发必须使用独立 `--session-id`，当前脚本已按 worker 和批次号隔离。
"""
    OUT_DOC.write_text(content, encoding="utf-8")
    print(OUT_DOC)


if __name__ == "__main__":
    main()
