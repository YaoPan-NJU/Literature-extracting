#!/usr/bin/env bash
# Progress monitor for multi-worker extraction.
# Reads manifests and writes JSON summary to /tmp/openclaw/extraction_progress.json

set -u

PROGRESS_FILE="/tmp/openclaw/extraction_progress.json"
INTERVAL=30

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <RUN_DIR> <TOTAL_PDFS> [QUEUE_FILE]" >&2
  exit 1
fi

RUN_DIR="$1"
TOTAL_PDFS="$2"
QUEUE_FILE="${3:-/tmp/openclaw/multi_extract_queue.txt}"

SUCCESS_TSV="$RUN_DIR/manifests/success.tsv"
FAILURES_TSV="$RUN_DIR/manifests/failures.tsv"

mkdir -p "$(dirname "$PROGRESS_FILE")"
START_TIME="$(date +%s)"

while true; do
  success_count=0; failure_count=0; queued=0
  [[ -f "$SUCCESS_TSV" ]] && success_count=$(( $(wc -l < "$SUCCESS_TSV" | tr -d ' ') - 1 ))
  [[ -f "$FAILURES_TSV" ]] && failure_count=$(( $(wc -l < "$FAILURES_TSV" | tr -d ' ') - 1 ))
  [[ -f "$QUEUE_FILE" ]] && queued=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
  [[ "$success_count" -lt 0 ]] && success_count=0
  [[ "$failure_count" -lt 0 ]] && failure_count=0

  processed=$((success_count + failure_count))
  elapsed=$(( $(date +%s) - START_TIME ))

  # active workers
  active_workers=0
  for pidf in /tmp/openclaw/multi_extract_pids/worker_*.pid; do
    [[ -f "$pidf" ]] && kill -0 "$(cat "$pidf")" 2>/dev/null && active_workers=$((active_workers + 1))
  done

  eta_str="unknown"
  if [[ "$processed" -gt 0 && "$queued" -gt 0 ]]; then
    avg=$((elapsed / processed))
    eta_workers="$active_workers"
    [[ "$eta_workers" -lt 1 ]] && eta_workers=1
    eta_s=$((avg * queued / eta_workers))
    eta_str="$((eta_s/3600))h$(( (eta_s%3600)/60 ))m"
  fi

  elapsed_str="$((elapsed/3600))h$(( (elapsed%3600)/60 ))m"

  # per-model breakdown
  model_stats=""
  if [[ -f "$SUCCESS_TSV" ]]; then
    model_stats=$(tail -n +2 "$SUCCESS_TSV" | cut -f4 | sort | uniq -c | sort -rn | \
      python3 -c "
import sys, json
d = {}
for line in sys.stdin:
    parts = line.strip().split()
    if len(parts) == 2:
        d[parts[1]] = int(parts[0])
print(json.dumps(d))
" 2>/dev/null || echo "{}")
  fi

  status="running"
  [[ "$queued" -eq 0 && ( "$processed" -gt 0 || "$active_workers" -eq 0 ) ]] && status="completed"

  python3 -c "
import json
progress = {
    'status': '$status',
    'total': $TOTAL_PDFS,
    'queued': $queued,
    'processed': $processed,
    'success': $success_count,
    'failed': $failure_count,
    'elapsed': '$elapsed_str',
    'eta': '$eta_str',
    'active_workers': $active_workers,
    'per_model': $model_stats,
    'updated_at': '$(date '+%Y-%m-%d %H:%M:%S')'
}
with open('$PROGRESS_FILE', 'w', encoding='utf-8') as f:
    json.dump(progress, f, ensure_ascii=False, indent=2)
"

  [[ "$status" == "completed" ]] && exit 0

  sleep "$INTERVAL"
done
