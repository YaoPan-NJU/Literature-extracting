#!/usr/bin/env python3
"""Continuously quarantine low-quality extraction outputs from a running batch."""

from __future__ import annotations

import argparse
import fcntl
import json
import re
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path


BAD_MARKERS = [
    "多模态预处理未提取到任何页面内容",
    "多模态预处理未提取到任何内容",
    "无法判断文献具体内容和价值",
    "Total pages: ?",
    "Total pages 显示为 '?'",
    "无视觉页缓存",
    "Multimodal pre-processing extracted zero content",
    "MULTIMODAL_CONTEXT_BLOCK为空",
    "Total pages displayed as",
    "zero pages of content",
    "强烈建议重新运行视觉预处理",
    "重新运行视觉预处理",
    "视觉预处理失败",
    "OCR失败",
    "正文不可读",
]

BAD_PATTERNS = [
    re.compile(pattern)
    for pattern in [
        r"当前仅第\s*\d+\s*页.*被加载",
        r"正文\s*\d+\s*页完全缺失",
        r"正文.*完全缺失",
        r"视觉页.*缺失",
        r"多模态.*缺失",
    ]
]


def locked_read_lines(path: Path) -> list[str]:
    lock_path = Path(str(path) + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
        fcntl.flock(lock, fcntl.LOCK_UN)
    return lines


def locked_write_lines(path: Path, lines: list[str]) -> None:
    lock_path = Path(str(path) + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
        fcntl.flock(lock, fcntl.LOCK_UN)


def append_unique(path: Path, line: str, header: str) -> None:
    lines = locked_read_lines(path)
    if not lines:
        lines = [header]
    if line not in lines:
        lines.append(line)
        locked_write_lines(path, lines)


def append_queue_unique(queue_file: Path, pdf_path: str) -> None:
    lock_path = Path(str(queue_file) + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        lines = queue_file.read_text(encoding="utf-8").splitlines() if queue_file.exists() else []
        if pdf_path not in {line.strip() for line in lines if line.strip()}:
            with queue_file.open("a", encoding="utf-8") as out:
                out.write(pdf_path + "\n")
        fcntl.flock(lock, fcntl.LOCK_UN)


def invalid_reason(json_path: Path) -> str | None:
    if not json_path.is_file():
        return "missing_json"
    try:
        text = json_path.read_text(encoding="utf-8")
        obj = json.loads(text)
    except Exception:
        return "bad_json"
    if not obj.get("knowledge_items"):
        return "empty_knowledge_items"
    if any(marker in text for marker in BAD_MARKERS):
        return "visual_preprocess_warning"
    if any(pattern.search(text) for pattern in BAD_PATTERNS):
        return "visual_preprocess_warning"
    return None


def move_if_exists(src: Path, dst_dir: Path, name: str) -> None:
    if not src.exists():
        return
    dst_dir.mkdir(parents=True, exist_ok=True)
    dst = dst_dir / name
    if dst.exists():
        dst = dst_dir / f"{src.stem}.{int(time.time())}{src.suffix}"
    shutil.move(str(src), str(dst))


def audit_once(run_dir: Path, queue_file: Path) -> int:
    success_tsv = run_dir / "manifests" / "success.tsv"
    quality_tsv = run_dir / "manifests" / "quality_requeue.tsv"
    failures_tsv = run_dir / "manifests" / "failures.tsv"
    rejected_dir = run_dir / "rejected_json"
    rejected_cache_dir = run_dir / "rejected_visual_cache"

    lines = locked_read_lines(success_tsv)
    if len(lines) <= 1:
        return 0

    header, rows = lines[0], lines[1:]
    kept = [header]
    moved = 0

    for row in rows:
        cols = row.split("\t")
        if len(cols) < 7:
            kept.append(row)
            continue

        timestamp, pdf_path, record_id, model, json_path, _raw_path, _seconds = cols[:7]
        reason = invalid_reason(Path(json_path))
        if reason is None:
            kept.append(row)
            continue

        moved += 1
        move_if_exists(Path(json_path), rejected_dir, f"{record_id}.json")
        pdf = Path(pdf_path)
        cache = pdf.with_name(pdf.stem + "_visual_cache.json")
        move_if_exists(cache, rejected_cache_dir, f"{record_id}_visual_cache.json")

        now = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
        log_path = str(run_dir / "logs" / f"{record_id}.log")
        tsv_line = "\t".join([now, pdf_path, record_id, model, "quality_gate", "1", reason, log_path])
        if reason == "visual_preprocess_warning" or reason == "empty_knowledge_items":
            append_unique(
                quality_tsv,
                tsv_line,
                "timestamp\tpdf_path\trecord_id\tmodel\tstage\texit_code\treason\tlog_path",
            )
            append_queue_unique(queue_file, pdf_path)
        else:
            append_unique(
                failures_tsv,
                tsv_line,
                "timestamp\tpdf_path\trecord_id\tmodel\tstage\texit_code\treason\tlog_path",
            )

    if moved:
        locked_write_lines(success_tsv, kept)
    return moved


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("queue_file", type=Path)
    parser.add_argument("--interval", type=int, default=30)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()

    while True:
        moved = audit_once(args.run_dir, args.queue_file)
        if moved:
            print(f"quality gate moved {moved} invalid result(s)", flush=True)
        if args.once:
            break
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
