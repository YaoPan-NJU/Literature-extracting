#!/usr/bin/env bash
# Clean stale visual caches for Chinese documents affected by the
# is_data_page bug (Chinese 图/表 patterns were not detected).
# After cleanup, these documents will be re-preprocessed with the fixed code.
#
# Usage: bash scripts/clean_stale_chinese_caches.sh [--dry-run]

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIT_DIR="$REPO_DIR/近海油气田污染物相关文献"

PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv/bin/python}"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

# ── Step 1: Find all visual caches with visual_markdown=0 ──

echo "Scanning for stale Chinese visual caches..."

STALE_FILES=$("$PYTHON_BIN" -c "
import json, glob, os, re, sys

lit_dir = '$LIT_DIR'
dirs = [
    f'{lit_dir}/中文文献/',
    f'{lit_dir}/专利/中文/',
]

stale = []
for d in dirs:
    caches = glob.glob(f'{d}*_visual_cache.json')
    for c in caches:
        try:
            data = json.load(open(c))
            vm = data.get('visual_markdown', {})
            stage0 = data.get('stage0', {})
            total_pages = stage0.get('total_pages', 0)
            data_pages = stage0.get('data_page_nums', [])

            # Stale if: visual_markdown is empty AND total_pages > 0
            # (meaning the document was processed but no visual reading happened)
            if len(vm) == 0 and total_pages > 0:
                # Check if this is genuinely affected (has pages that might contain figures)
                stale.append(c)
        except Exception as e:
            print(f'WARN: {c}: {e}', file=sys.stderr)

for f in stale:
    print(f)
")

COUNT=$(echo "$STALE_FILES" | grep -c . || true)
echo "Found $COUNT stale visual caches."

if [[ "$COUNT" -eq 0 ]]; then
    echo "Nothing to clean."
    exit 0
fi

# ── Step 2: Delete stale caches (and timing JSONs) ──

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo ""
    echo "[DRY RUN] Would delete $COUNT files:"
    echo "$STALE_FILES" | head -20
    [[ "$COUNT" -gt 20 ]] && echo "... and $((COUNT - 20)) more"
    exit 0
fi

DELETED=0
while IFS= read -r cache; do
    [[ -z "$cache" ]] && continue

    # Remove visual cache
    rm -f "$cache"
    DELETED=$((DELETED + 1))

    # Remove associated timing JSON
    timing_json="${cache}.timing.json"
    [[ -f "$timing_json" ]] && rm -f "$timing_json"

done <<< "$STALE_FILES"

echo "Deleted $DELETED stale visual caches (+ timing JSONs)."

# ── Step 3: Also clean timing sample PDFs ──

TIMING_PDF_DIR="/tmp/openclaw/timing_sample_pdfs"
if [[ -d "$TIMING_PDF_DIR" ]]; then
    echo ""
    echo "Scanning timing sample PDFs..."
    TIMING_STALE=$("$PYTHON_BIN" -c "
import json, glob, os

pdf_dir = '$TIMING_PDF_DIR'
caches = glob.glob(f'{pdf_dir}/*_visual_cache.json')
stale = []
for c in caches:
    try:
        data = json.load(open(c))
        vm = data.get('visual_markdown', {})
        s0 = data.get('stage0', {})
        if len(vm) == 0 and s0.get('total_pages', 0) > 0:
            # Only Chinese docs
            basename = os.path.basename(c)
            if basename.startswith('中文') or (basename.startswith('专利') and any(ord(ch) > 127 for ch in basename)):
                stale.append(c)
    except:
        pass
for f in stale:
    print(f)
")
    TIMING_COUNT=$(echo "$TIMING_STALE" | grep -c . || true)
    if [[ "$TIMING_COUNT" -gt 0 ]]; then
        while IFS= read -r cache; do
            [[ -z "$cache" ]] && continue
            rm -f "$cache"
            rm -f "${cache}.timing.json"
        done <<< "$TIMING_STALE"
        echo "Cleaned $TIMING_COUNT stale timing sample caches."
    else
        echo "No stale timing sample caches found."
    fi
fi

echo ""
echo "Done. Re-run extraction to regenerate visual caches with fixed code."
