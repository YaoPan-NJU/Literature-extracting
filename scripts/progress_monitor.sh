#!/usr/bin/env bash
# Progress monitor for batch extraction.
# Periodically reads manifests and writes a JSON summary to /tmp/openclaw/extraction_progress.json
# so that any OpenClaw agent (e.g. via iMessage) can query extraction status.

set -u

PROGRESS_FILE="/tmp/openclaw/extraction_progress.json"
INTERVAL=30  # seconds between updates

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <OUT_DIR> <TOTAL_PDFS> [PID_FILE]" >&2
  exit 1
fi

OUT_DIR="$1"
TOTAL_PDFS="$2"
PID_FILE="${3:-}"

SUCCESS_TSV="$OUT_DIR/manifests/success.tsv"
FAILURES_TSV="$OUT_DIR/manifests/failures.tsv"
LOG_DIR="$OUT_DIR/logs"

mkdir -p "$(dirname "$PROGRESS_FILE")"

START_TIME="$(date +%s)"

while true; do
  # Count successes and failures (subtract 1 for header line)
  success_count=0
  failure_count=0
  [[ -f "$SUCCESS_TSV" ]] && success_count=$(( $(wc -l < "$SUCCESS_TSV" | tr -d ' ') - 1 ))
  [[ -f "$FAILURES_TSV" ]] && failure_count=$(( $(wc -l < "$FAILURES_TSV" | tr -d ' ') - 1 ))
  [[ "$success_count" -lt 0 ]] && success_count=0
  [[ "$failure_count" -lt 0 ]] && failure_count=0

  processed=$((success_count + failure_count))
  remaining=$((TOTAL_PDFS - processed))
  [[ "$remaining" -lt 0 ]] && remaining=0

  elapsed=$(( $(date +%s) - START_TIME ))

  # Estimate remaining time
  eta_str="unknown"
  if [[ "$processed" -gt 0 ]]; then
    avg_seconds=$((elapsed / processed))
    eta_seconds=$((avg_seconds * remaining))
    hours=$((eta_seconds / 3600))
    minutes=$(( (eta_seconds % 3600) / 60 ))
    eta_str="${hours}h${minutes}m"
  fi

  # Format elapsed time
  elapsed_hours=$((elapsed / 3600))
  elapsed_minutes=$(( (elapsed % 3600) / 60 ))
  elapsed_str="${elapsed_hours}h${elapsed_minutes}m"

  # Check if batch process is still running
  status="running"
  if [[ -n "$PID_FILE" && -f "$PID_FILE" ]]; then
    batch_pid="$(head -1 "$PID_FILE" | tr -d ' ')"
    if [[ -n "$batch_pid" ]] && ! kill -0 "$batch_pid" 2>/dev/null; then
      status="completed"
    fi
  fi

  # Get last processed PDF name from success/failure manifests
  last_pdf=""
  if [[ -f "$SUCCESS_TSV" ]]; then
    last_success="$(tail -1 "$SUCCESS_TSV" 2>/dev/null)"
    [[ -n "$last_success" ]] && last_pdf="$(echo "$last_success" | cut -f2 | xargs basename 2>/dev/null)"
  fi

  # Get last few errors
  recent_errors="[]"
  if [[ -f "$FAILURES_TSV" && $(wc -l < "$FAILURES_TSV" | tr -d ' ') -gt 1 ]]; then
    recent_errors=$(tail -3 "$FAILURES_TSV" | python3 -c "
import sys, json
errors = []
for line in sys.stdin:
    parts = line.strip().split('\t')
    if len(parts) >= 5:
        errors.append({'pdf': parts[1].split('/')[-1][:60], 'reason': parts[4]})
print(json.dumps(errors, ensure_ascii=False))
" 2>/dev/null || echo "[]")
  fi

  # Write progress JSON
  python3 -c "
import json
progress = {
    'status': '$status',
    'total': $TOTAL_PDFS,
    'processed': $processed,
    'success': $success_count,
    'failed': $failure_count,
    'remaining': $remaining,
    'elapsed': '$elapsed_str',
    'eta': '$eta_str',
    'last_pdf': '$last_pdf',
    'recent_errors': $recent_errors,
    'updated_at': '$(date '+%Y-%m-%d %H:%M:%S')'
}
with open('$PROGRESS_FILE', 'w', encoding='utf-8') as f:
    json.dump(progress, f, ensure_ascii=False, indent=2)
"

  # Exit if batch is done
  if [[ "$status" == "completed" ]]; then
    echo "Batch completed. Progress file finalized."
    exit 0
  fi

  sleep "$INTERVAL"
done
