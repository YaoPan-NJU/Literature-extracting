#!/usr/bin/env bash
# Launch multi-worker extraction.
# Usage: bash scripts/launch_multi_extract.sh [--limit N] [--dry-run] [--workers 1|2|3] [--mode multimodal|text-only] [--preprocess-workers N]

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_DIR="/tmp/openclaw/multi_extract_pids"
PDF_DIR="$REPO_DIR/workspace/en_pdfs"
PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv/bin/python}"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

LIMIT=0
DRY_RUN=0
WORKERS=1
PER_WORKER_LIMIT=0
MODE="multimodal"
PREPROCESS_WORKERS=4
EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)   LIMIT="${2:-0}"; EXTRA_ARGS+=("--limit" "$LIMIT"); shift 2 ;;
    --per-worker-limit) PER_WORKER_LIMIT="${2:-0}"; EXTRA_ARGS+=("--per-worker-limit" "$PER_WORKER_LIMIT"); shift 2 ;;
    --mode)    MODE="${2:-multimodal}"; EXTRA_ARGS+=("--mode" "$MODE"); shift 2 ;;
    --preprocess-workers) PREPROCESS_WORKERS="${2:-4}"; EXTRA_ARGS+=("--preprocess-workers" "$PREPROCESS_WORKERS"); shift 2 ;;
    --dry-run) DRY_RUN=1; EXTRA_ARGS+=("--dry-run"); shift ;;
    --workers) WORKERS="${2:-1}"; EXTRA_ARGS+=("--workers" "$WORKERS"); shift 2 ;;
    --include-bailian) WORKERS=3; EXTRA_ARGS+=("--workers" "3"); shift ;;
    *)         EXTRA_ARGS+=("$1"); shift ;;
  esac
done

case "$WORKERS" in
  1|2|3) ;;
  *) echo "ERROR: --workers must be 1, 2, or 3" >&2; exit 2 ;;
esac
case "$PER_WORKER_LIMIT" in
  ''|*[!0-9]*) echo "ERROR: --per-worker-limit must be a non-negative integer" >&2; exit 2 ;;
esac
case "$PREPROCESS_WORKERS" in
  ''|*[!0-9]*) echo "ERROR: --preprocess-workers must be a non-negative integer" >&2; exit 2 ;;
esac
case "$MODE" in
  multimodal|text-only) ;;
  *) echo "ERROR: --mode must be multimodal or text-only" >&2; exit 2 ;;
esac
if [[ "$MODE" == "multimodal" && "$PREPROCESS_WORKERS" -lt 1 ]]; then
  echo "ERROR: --preprocess-workers must be at least 1 in multimodal mode" >&2
  exit 2
fi

REQUESTED=0
if [[ "$PER_WORKER_LIMIT" -gt 0 ]]; then
  REQUESTED=$((PER_WORKER_LIMIT * WORKERS))
elif [[ "$LIMIT" -gt 0 ]]; then
  REQUESTED="$LIMIT"
fi

if [[ "$DRY_RUN" -eq 0 && "$REQUESTED" -gt 0 ]]; then
  "$PYTHON_BIN" "$REPO_DIR/scripts/prepare_en_pdf_hardlinks.py" --count "$REQUESTED"
fi

RUN_ID="$(date +%Y%m%d%H%M%S)-$$"
QUEUE_FILE="/tmp/openclaw/multi_extract_queue_${RUN_ID}.txt"
RUN_DIR="/tmp/openclaw/litextract_runs/$RUN_ID"
export MULTI_EXTRACT_RUN_ID="$RUN_ID"
export MULTI_EXTRACT_QUEUE_FILE="$QUEUE_FILE"
export MULTI_EXTRACT_RUN_DIR="$RUN_DIR"

if [[ "$DRY_RUN" -eq 1 ]]; then
  bash "$REPO_DIR/scripts/multi_worker_extract.sh" \
    --pdf-dir "$PDF_DIR" \
    --out-dir "$REPO_DIR/outputs/extractions" \
    "${EXTRA_ARGS[@]}"
  exit $?
fi

# kill any previous run
bash "$REPO_DIR/scripts/stop_extraction.sh" 2>/dev/null
rm -rf "$PID_DIR"
mkdir -p "$PID_DIR" /tmp/openclaw

# count PDFs
TOTAL=$(find "$PDF_DIR" -name "*.pdf" -type f | wc -l | tr -d ' ')
EFFECTIVE=$TOTAL
if [[ "$PER_WORKER_LIMIT" -gt 0 ]]; then
  EFFECTIVE=$REQUESTED
elif [[ "$LIMIT" -gt 0 ]]; then
  EFFECTIVE=$LIMIT
fi

echo "=== Multi-Worker Extraction Launcher ==="
WORKER_COUNT="$WORKERS"
case "$WORKERS" in
  1) echo "Workers: 1 (mimo-v25pro)" ;;
  2) echo "Workers: 2 (bailian-qwen36, mimo-v25pro)" ;;
  3) echo "Workers: 3 (dashscope-qwen36, bailian-qwen36, mimo-v25pro)" ;;
esac
echo "Run ID: $RUN_ID"
echo "Total PDFs: $TOTAL  (limit: ${LIMIT:-none})"
echo "Mode: $MODE"
[[ "$MODE" == "multimodal" ]] && echo "Preprocess workers: $PREPROCESS_WORKERS"
echo "Run dir: $RUN_DIR"
echo ""

# init progress
"$PYTHON_BIN" -c "
import json
p = {'status':'starting','total':$EFFECTIVE,'queued':$EFFECTIVE,'processed':0,'success':0,'failed':0,'elapsed':'0h0m','eta':'calculating...','active_workers':$WORKER_COUNT,'per_model':{},'updated_at':'$(date '+%Y-%m-%d %H:%M:%S')'}
with open('/tmp/openclaw/extraction_progress.json','w') as f: json.dump(p,f,indent=2)
"

# start extraction in background
nohup bash "$REPO_DIR/scripts/multi_worker_extract.sh" \
  --pdf-dir "$PDF_DIR" \
  --out-dir "$REPO_DIR/outputs/extractions" \
  "${EXTRA_ARGS[@]}" \
  > /tmp/openclaw/multi_extract_launch.log 2>&1 &
MAIN_PID=$!
echo "$MAIN_PID" > "$PID_DIR/main.pid"
echo "Main process PID: $MAIN_PID"

# start progress monitor in background
nohup bash "$REPO_DIR/scripts/progress_monitor_multi.sh" \
  "$RUN_DIR" \
  "$EFFECTIVE" \
  "$QUEUE_FILE" \
  > /tmp/openclaw/multi_monitor.log 2>&1 &
MON_PID=$!
echo "$MON_PID" > "$PID_DIR/monitor.pid"
echo "Monitor PID: $MON_PID"

echo ""
echo "Launched! Check progress via iMessage:"
echo "  '读一下 /tmp/openclaw/extraction_progress.json'"
echo ""
echo "Logs: /tmp/openclaw/multi_extract_launch.log"
echo "Stop: bash scripts/stop_extraction.sh"
