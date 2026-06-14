#!/usr/bin/env bash
# Re-run extraction for Chinese documents affected by the is_data_page bug.
# This script:
# 1. Cleans stale visual caches (using clean_stale_chinese_caches.sh)
# 2. Builds a queue of affected PDFs
# 3. Launches multi-worker extraction with the fixed preprocess.py
#
# Usage: bash scripts/rerun_affected_chinese.sh [--dry-run]

set -euo pipefail

DRY_RUN="${1:-}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIT_DIR="$REPO_DIR/近海油气田污染物相关文献"

PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv/bin/python}"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

RUN_ID="rerun_chinese_$(date +%Y%m%d_%H%M%S)"
RUN_DIR="/tmp/openclaw/litextract_runs/$RUN_ID"
QUEUE_FILE="/tmp/openclaw/rerun_affected_chinese_queue.txt"

echo "=== Re-run affected Chinese documents ==="
echo "Run ID: $RUN_ID"
echo ""

# ── Step 1: Clean stale caches ──
echo "Step 1: Cleaning stale visual caches..."
bash "$REPO_DIR/scripts/clean_stale_chinese_caches.sh" $DRY_RUN
echo ""

# ── Step 2: Build queue of affected PDFs ──
echo "Step 2: Building queue of affected PDFs..."

"$PYTHON_BIN" -c "
import glob, os, json

lit_dir = '$LIT_DIR'
dirs = {
    '中文文献': f'{lit_dir}/中文文献/',
    '中文专利': f'{lit_dir}/专利/中文/',
}

affected_pdfs = []
for cat, d in dirs.items():
    # Find PDFs whose visual cache was deleted (no longer exists)
    # or whose cache still has visual_markdown=0
    pdfs = glob.glob(f'{d}*.pdf')
    for pdf in pdfs:
        cache = pdf.rsplit('.', 1)[0] + '_visual_cache.json'
        if not os.path.exists(cache):
            # Cache was deleted by cleanup script
            affected_pdfs.append(pdf)
        else:
            try:
                data = json.load(open(cache))
                vm = data.get('visual_markdown', {})
                s0 = data.get('stage0', {})
                if len(vm) == 0 and s0.get('total_pages', 0) > 0:
                    affected_pdfs.append(pdf)
            except:
                affected_pdfs.append(pdf)

for pdf in sorted(affected_pdfs):
    print(pdf)
" > "$QUEUE_FILE"

QUEUE_SIZE=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
echo "Queue: $QUEUE_SIZE affected PDFs → $QUEUE_FILE"

if [[ "$QUEUE_SIZE" -eq 0 ]]; then
    echo "No affected PDFs found. Nothing to re-run."
    exit 0
fi

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo ""
    echo "[DRY RUN] Would re-run extraction on $QUEUE_SIZE PDFs:"
    head -10 "$QUEUE_FILE"
    [[ "$QUEUE_SIZE" -gt 10 ]] && echo "... and $((QUEUE_SIZE - 10)) more"
    exit 0
fi

# ── Step 3: Launch extraction ──
echo ""
echo "Step 3: Launching extraction..."
echo "  Workers: 2 (mimo + mimo2)"
echo "  Preprocess workers: 4"
echo "  Run dir: $RUN_DIR"
echo ""

PROJECT_LABEL="中文文档修复重跑" \
MULTI_EXTRACT_RUN_ID="$RUN_ID" \
nohup bash "$REPO_DIR/scripts/multi_worker_extract.sh" \
  --pdf-list "$QUEUE_FILE" \
  --out-dir outputs/extractions \
  --workers 2 \
  --timeout-seconds 1800 \
  --preprocess-workers 4 \
  --force \
  > /tmp/openclaw/rerun_chinese_launch.log 2>&1 &

LAUNCH_PID=$!
echo "Launched (PID: $LAUNCH_PID)"
echo "Monitor: tail -f /tmp/openclaw/rerun_chinese_launch.log"
echo "Progress: cat /tmp/openclaw/extraction_progress.json | python3 -m json.tool"
