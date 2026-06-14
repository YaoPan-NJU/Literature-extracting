#!/usr/bin/env bash
# Quick monitoring check for batch extraction progress
set -u

RUN_ID="20260502111946-33077"
RUN_DIR="/tmp/openclaw/litextract_runs/$RUN_ID"
QUEUE_FILE="/tmp/openclaw/multi_extract_queue_${RUN_ID}.txt"
SUCCESS_TSV="$RUN_DIR/manifests/success.tsv"
FAILURES_TSV="$RUN_DIR/manifests/failures.tsv"

echo "=== Extraction Monitor Check $(date '+%Y-%m-%d %H:%M:%S') ==="
echo ""

# Queue remaining
queue_remaining=0
[[ -f "$QUEUE_FILE" ]] && queue_remaining=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
echo "Queue remaining: $queue_remaining"

# Success count
success_count=0
if [[ -f "$SUCCESS_TSV" ]]; then
  success_count=$(( $(wc -l < "$SUCCESS_TSV" | tr -d ' ') - 1 ))
  [[ "$success_count" -lt 0 ]] && success_count=0
fi
echo "Successes: $success_count"

# Failure count
failure_count=0
if [[ -f "$FAILURES_TSV" ]]; then
  failure_count=$(( $(wc -l < "$FAILURES_TSV" | tr -d ' ') - 1 ))
  [[ "$failure_count" -lt 0 ]] && failure_count=0
fi
echo "Failures: $failure_count"

# Total processed
total_processed=$((success_count + failure_count))
total_target=300
remaining=$((total_target - total_processed))
[[ "$remaining" -lt 0 ]] && remaining=0
echo "Total processed: $total_processed / $total_target"
echo "Remaining: $remaining"
echo ""

# Worker processes check
echo "--- Worker Processes ---"
worker_pids=$(pgrep -f 'openclaw-agent' 2>/dev/null || true)
if [[ -n "$worker_pids" ]]; then
  echo "Active openclaw-agent PIDs: $worker_pids"
  worker_count=$(echo "$worker_pids" | wc -l | tr -d ' ')
  echo "Active workers: $worker_count"
else
  echo "WARNING: No openclaw-agent processes found!"
fi
echo ""

# Latest worker log entries
echo "--- Latest Worker Logs ---"
for wlog in "$RUN_DIR/logs"/worker_*.log; do
  [[ -f "$wlog" ]] && echo "  $(basename "$wlog"): $(tail -1 "$wlog")"
done
echo ""

# Latest failures if any
if [[ "$failure_count" -gt 0 ]]; then
  echo "--- Latest Failures ---"
  tail -5 "$FAILURES_TSV"
  echo ""
fi

# JSON output count
json_count=$(find "$RUN_DIR/json" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
echo "JSON outputs in run dir: $json_count"

# Check for unified output
unified_json_count=0
for cat_dir in "/Users/panyao/Qoder/JJJ_Literature/outputs/extractions/英文文献/json" \
               "/Users/panyao/Qoder/JJJ_Literature/outputs/extractions/中文文献/json" \
               "/Users/panyao/Qoder/JJJ_Literature/outputs/extractions/专利/json" \
               "/Users/panyao/Qoder/JJJ_Literature/outputs/extractions/书本/中文/json" \
               "/Users/panyao/Qoder/JJJ_Literature/outputs/extractions/书本/英文/json"; do
  if [[ -d "$cat_dir" ]]; then
    cnt=$(find "$cat_dir" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
    unified_json_count=$((unified_json_count + cnt))
  fi
done
echo "JSON outputs in unified dir: $unified_json_count"

echo ""
echo "=== End Monitor Check ==="
