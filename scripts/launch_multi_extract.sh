#!/usr/bin/env bash
# Launch multi-worker extraction.
# Usage: bash scripts/launch_multi_extract.sh [--limit N] [--dry-run] [--workers 1|2|3] [--only-bailian] [--mode multimodal|text-only] [--preprocess-workers N]

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_DIR="/tmp/openclaw/multi_extract_pids"
DEFAULT_EN_DIR="$REPO_DIR/workspace/近海油气田污染物相关文献/英文文献"
if [[ -d "$DEFAULT_EN_DIR" ]]; then
  PDF_DIR="$DEFAULT_EN_DIR"
else
  PDF_DIR="$REPO_DIR/workspace/en_pdfs"
fi
PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv/bin/python}"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

LIMIT=0
DRY_RUN=0
WORKERS=1
PER_WORKER_LIMIT=0
MODE="multimodal"
PREPROCESS_WORKERS=4
ONLY_BAILIAN=0
CLEANUP_OLD_RUNS=1
MIN_FREE_GB="${MIN_FREE_GB:-10}"
EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf-dir) PDF_DIR="${2:-$PDF_DIR}"; EXTRA_ARGS+=("--pdf-dir" "$PDF_DIR"); shift 2 ;;
    --limit)   LIMIT="${2:-0}"; EXTRA_ARGS+=("--limit" "$LIMIT"); shift 2 ;;
    --per-worker-limit) PER_WORKER_LIMIT="${2:-0}"; EXTRA_ARGS+=("--per-worker-limit" "$PER_WORKER_LIMIT"); shift 2 ;;
    --mode)    MODE="${2:-multimodal}"; EXTRA_ARGS+=("--mode" "$MODE"); shift 2 ;;
    --preprocess-workers) PREPROCESS_WORKERS="${2:-4}"; EXTRA_ARGS+=("--preprocess-workers" "$PREPROCESS_WORKERS"); shift 2 ;;
    --dry-run) DRY_RUN=1; EXTRA_ARGS+=("--dry-run"); shift ;;
    --workers) WORKERS="${2:-1}"; EXTRA_ARGS+=("--workers" "$WORKERS"); shift 2 ;;
    --only-bailian) ONLY_BAILIAN=1; EXTRA_ARGS+=("--only-bailian"); shift ;;
    --no-cleanup-old-runs) CLEANUP_OLD_RUNS=0; shift ;;
    --min-free-gb) MIN_FREE_GB="${2:-15}"; shift 2 ;;
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
case "$MIN_FREE_GB" in
  ''|*[!0-9]*) echo "ERROR: --min-free-gb must be a non-negative integer" >&2; exit 2 ;;
esac
case "$MODE" in
  multimodal|text-only) ;;
  *) echo "ERROR: --mode must be multimodal or text-only" >&2; exit 2 ;;
esac
if [[ "$MODE" == "multimodal" && "$PREPROCESS_WORKERS" -lt 1 ]]; then
  echo "ERROR: --preprocess-workers must be at least 1 in multimodal mode" >&2
  exit 2
fi
if [[ "$ONLY_BAILIAN" -eq 1 ]]; then
  WORKERS=1
fi

REQUESTED=0
if [[ "$PER_WORKER_LIMIT" -gt 0 ]]; then
  REQUESTED=$((PER_WORKER_LIMIT * WORKERS))
elif [[ "$LIMIT" -gt 0 ]]; then
  REQUESTED="$LIMIT"
fi

if [[ "$DRY_RUN" -eq 0 && "$REQUESTED" -gt 0 && "$PDF_DIR" == "$REPO_DIR/workspace/en_pdfs" ]]; then
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

free_gb() {
  df -Pk "$1" | awk 'NR==2 {print int($4/1024/1024)}'
}

preflight() {
  local free_data free_tmp
  free_data="$(free_gb "$REPO_DIR")"
  free_tmp="$(free_gb /tmp)"
  if [[ "$free_data" -lt "$MIN_FREE_GB" || "$free_tmp" -lt "$MIN_FREE_GB" ]]; then
    echo "ERROR: free disk below threshold (${MIN_FREE_GB}GB). repo=${free_data}GB /tmp=${free_tmp}GB" >&2
    exit 75
  fi

  export OPENCLAW_CONFIG_PATH="$REPO_DIR/openclaw.json"
  mkdir -p "$HOME/.openclaw/plugin-runtime-deps"
  if ! touch "$HOME/.openclaw/plugin-runtime-deps/.write-test" 2>/dev/null; then
    echo "ERROR: cannot write OpenClaw runtime deps under ~/.openclaw/plugin-runtime-deps" >&2
    exit 74
  fi
  rm -f "$HOME/.openclaw/plugin-runtime-deps/.write-test"

  {
    echo "=== preflight $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "OPENCLAW_CONFIG_PATH=$OPENCLAW_CONFIG_PATH"
    echo "free_gb(repo)=$free_data free_gb(tmp)=$free_tmp min_free_gb=$MIN_FREE_GB"
    command -v openclaw || true
    openclaw --version 2>&1 || true
    openclaw agent --help >/dev/null 2>&1
    echo "openclaw_agent_help_exit=$?"
  } > /tmp/openclaw/preflight.log

  if ! tail -1 /tmp/openclaw/preflight.log | grep -q 'openclaw_agent_help_exit=0'; then
    echo "ERROR: OpenClaw agent preflight failed; see /tmp/openclaw/preflight.log" >&2
    exit 74
  fi
}

# kill any previous run
bash "$REPO_DIR/scripts/stop_extraction.sh" 2>/dev/null
rm -rf "$PID_DIR"
mkdir -p "$PID_DIR" /tmp/openclaw

preflight

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
if [[ "$ONLY_BAILIAN" -eq 1 ]]; then
  echo "Workers: 1 (worker 2, bailian-qwen36)"
else
  case "$WORKERS" in
    1) echo "Workers: 1 (mimo-v25)" ;;
    2) echo "Workers: 2 (bailian-qwen36, mimo-v25)" ;;
    3) echo "Workers: 3 (dashscope-qwen36, bailian-qwen36, mimo-v25)" ;;
  esac
fi
echo "Run ID: $RUN_ID"
echo "Total PDFs: $TOTAL  (limit: ${LIMIT:-none})"
echo "Mode: $MODE"
[[ "$MODE" == "multimodal" ]] && echo "Preprocess workers: $PREPROCESS_WORKERS"
echo "Min free disk: ${MIN_FREE_GB}GB"
echo "Run dir: $RUN_DIR"
echo ""

if [[ "$CLEANUP_OLD_RUNS" -eq 1 ]]; then
  bash "$REPO_DIR/scripts/cleanup_extraction_artifacts.sh" --all-old --keep-run-id "$RUN_ID" \
    >> /tmp/openclaw/preflight.log 2>&1 || true
fi

# init progress
"$PYTHON_BIN" -c "
import json
p = {'status':'starting','scope':'batch','run_id':'$RUN_ID','run_dir':'$RUN_DIR','phase':'building_queue','total':$EFFECTIVE,'queued':0,'processed':0,'success':0,'failed':0,'elapsed':'0h0m','eta':'calculating...','active_workers':0,'per_model':{},'updated_at':'$(date '+%Y-%m-%d %H:%M:%S')'}
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

echo "Waiting for worker startup..."
for _ in $(seq 1 180); do
  if ls "$PID_DIR"/worker_*.pid >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$MAIN_PID" 2>/dev/null; then
    break
  fi
  # If wrapper PIDs are gone, check for openclaw agent processes
  # still running for this run (handles stop_extraction.sh killing
  # wrappers while agents finish).
  if ! ls "$PID_DIR"/worker_*.pid >/dev/null 2>&1; then
    agent_alive=$(pgrep -cf "openclaw agent.*${RUN_ID}" 2>/dev/null || echo 0)
    if [[ "$agent_alive" -gt 0 ]]; then
      break
    fi
  fi
  sleep 1
done

# start progress monitor in background
nohup bash "$REPO_DIR/scripts/progress_monitor_multi.sh" \
  "$RUN_DIR" \
  "$EFFECTIVE" \
  "$QUEUE_FILE" \
  > /tmp/openclaw/multi_monitor.log 2>&1 &
MON_PID=$!
echo "$MON_PID" > "$PID_DIR/monitor.pid"
echo "Monitor PID: $MON_PID"

nohup bash "$REPO_DIR/scripts/notify_progress.sh" \
  "$RUN_DIR" \
  "$EFFECTIVE" \
  "$QUEUE_FILE" \
  > /tmp/openclaw/notify_progress.log 2>&1 &
NOTIFY_PID=$!
echo "$NOTIFY_PID" > "$PID_DIR/notifier.pid"
echo "Notifier PID: $NOTIFY_PID"

echo ""
echo "Launched! Check progress via iMessage:"
echo "  '读一下 /tmp/openclaw/extraction_progress.json'"
echo ""
echo "Logs: /tmp/openclaw/multi_extract_launch.log"
echo "Stop: bash scripts/stop_extraction.sh"
