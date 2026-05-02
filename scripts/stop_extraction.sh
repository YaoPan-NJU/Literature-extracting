#!/usr/bin/env bash
# Stop all running extraction processes (single-worker and multi-worker).

echo "Stopping extraction processes..."

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

# kill any remaining openclaw agent processes
pkill -f "openclaw agent.*lit-extract" 2>/dev/null && echo "  Killed remaining openclaw agents"

# clean up temp files
rm -f /tmp/openclaw/batch_extract.pid
rm -f /tmp/openclaw/multi_extract.lock
rm -f /tmp/openclaw/multi_extract_queue_*.txt /tmp/openclaw/multi_extract_queue_*.txt.lock

echo "Done."
