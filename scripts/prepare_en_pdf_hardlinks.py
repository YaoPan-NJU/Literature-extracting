#!/usr/bin/env python3
"""Prepare English PDF hardlinks inside the OpenClaw workspace.

OpenClaw rejects PDFs reached through symlinks because it resolves them outside
the agent workspace. This helper hardlinks the next remaining English PDFs into
workspace/en_pdfs, which stays inside the allowed workspace tree.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
REMAINING_TSV = REPO / "outputs" / "extractions" / "manifests" / "remaining_queue.tsv"
DEST_DIR = REPO / "workspace" / "en_pdfs"


def main() -> int:
    parser = argparse.ArgumentParser(description="Hardlink remaining English PDFs into workspace/en_pdfs.")
    parser.add_argument("--count", type=int, required=True, help="Number of remaining English PDFs to make available.")
    args = parser.parse_args()

    if args.count < 1:
        print("Nothing to prepare.")
        return 0
    if not REMAINING_TSV.is_file():
        print(f"ERROR: remaining queue not found: {REMAINING_TSV}", file=sys.stderr)
        return 2

    DEST_DIR.mkdir(parents=True, exist_ok=True)

    available = 0
    created = 0
    existing = 0
    missing = 0
    conflicts = 0

    with REMAINING_TSV.open("r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            if row.get("category") != "英文文献":
                continue
            pdf_name = row.get("pdf_name") or ""
            src_text = row.get("full_path") or ""
            if not pdf_name or not src_text:
                continue

            src = Path(src_text).resolve()
            target = DEST_DIR / pdf_name

            if target.exists():
                existing += 1
                available += 1
            elif not src.is_file():
                missing += 1
                continue
            else:
                try:
                    os.link(src, target)
                except FileExistsError:
                    existing += 1
                except OSError as exc:
                    conflicts += 1
                    print(f"WARN: failed to link {pdf_name}: {exc}", file=sys.stderr)
                    continue
                created += 1
                available += 1

            if available >= args.count:
                break

    print(
        f"Prepared English PDFs: available={available}, created={created}, "
        f"existing={existing}, missing={missing}, conflicts={conflicts}, dest={DEST_DIR}"
    )
    if available < args.count:
        print(f"ERROR: only {available} English PDFs available, requested {args.count}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
