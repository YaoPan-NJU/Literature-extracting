#!/usr/bin/env bash
# Stop all running extraction processes (single-worker and multi-worker).

echo "Stopping extraction processes..."

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# kill single-worker batch
for f in /tmp/openclaw/batch_extract.pid; do
  if [[ -f "$f" ]]; then
    while read -r pid; do
      pid="$(echo "$pid" | tr -d ' ')"
      [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && kill "$pid" && echo "  Killed PID $pid (batch)"
    done < "$f"
    rm -f "$f"
  fi
done

# kill multi-worker
PID_DIR="/tmp/openclaw/multi_extract_pids"
if [[ -d "$PID_DIR" ]]; then
  for pidf in "$PID_DIR"/*.pid; do
    [[ -f "$pidf" ]] || continue
    while read -r pid; do
      pid="$(echo "$pid" | tr -d ' ')"
      [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && kill "$pid" && echo "  Killed PID $pid"
    done < "$pidf"
  done
  rm -rf "$PID_DIR"
fi

# kill wrappers that may have outlived or lost the pid directory
pkill -f "$REPO_DIR/scripts/single_worker_extract.sh" 2>/dev/null && echo "  Killed remaining single-worker wrappers"
pkill -f "$REPO_DIR/scripts/multi_worker_extract.sh" 2>/dev/null && echo "  Killed remaining multi-worker wrappers"
pkill -f "$REPO_DIR/scripts/progress_monitor_multi.sh" 2>/dev/null && echo "  Killed remaining progress monitors"
pkill -f "$REPO_DIR/scripts/notify_progress.sh" 2>/dev/null && echo "  Killed remaining progress notifiers"

# kill any remaining openclaw agent processes
# Use a longer grace period to allow agents to finish current extraction
# before force-killing them.
pkill -f "openclaw agent.*lit-extract" 2>/dev/null && echo "  Sent SIGTERM to openclaw agents" && sleep 10
# force kill any that didn't exit gracefully
pkill -9 -f "openclaw agent.*lit-extract" 2>/dev/null && echo "  Force-killed remaining openclaw agents"

# clean up temp files
rm -f /tmp/openclaw/batch_extract.pid
rm -f /tmp/openclaw/multi_extract.lock
rm -f /tmp/openclaw/multi_extract_queue_*.txt /tmp/openclaw/multi_extract_queue_*.txt.lock

echo "Done."
