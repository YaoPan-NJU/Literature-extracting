#!/usr/bin/env bash
# Near-immediate failure alerts via iMessage, with optional hourly progress.
set -u

PHONE="+8615895848729"
CHECK_INTERVAL=60
SEND_HOURLY_PROGRESS="${SEND_HOURLY_PROGRESS:-0}"
PROJECT_LABEL="${PROJECT_LABEL:-}"  # 项目标签，如 "JJJ提参时间测试"

# 项目前缀：有标签时加方括号，无标签时为空
label_prefix() {
  if [[ -n "$PROJECT_LABEL" ]]; then
    echo "[$PROJECT_LABEL] "
  fi
}

# 安全提示：只显示 key 前缀，不泄露完整 key
active_key_id() {
  local key="${BAILIAN_CODING_PLAN_API_KEY:-${DASHSCOPE_API_KEY:-none}}"
  if [[ "$key" == sk-sp-* ]]; then
    echo "✅ coding plan key (sk-sp-${key:8:4}...)"
  elif [[ "$key" == sk-c4d-* || "$key" == sk-* ]]; then
    echo "⚠️  标准 key (sk-...)"
  else
    echo "❌ 未设置 API key"
  fi
}

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <RUN_DIR> <TOTAL>" >&2
  exit 1
fi

RUN_DIR="$1"
TOTAL="$2"
SUCCESS_TSV="$RUN_DIR/manifests/success.tsv"
FAILURES_TSV="$RUN_DIR/manifests/failures.tsv"
QUEUE_FILE="${3:-}"
PID_DIR="/tmp/openclaw/multi_extract_pids"
QUEUE_TOTAL_FILE="$RUN_DIR/manifests/queue_total.txt"

notify() {
  local msg="$1"
  if command -v imsg >/dev/null 2>&1; then
    imsg send --to "$PHONE" --text "$msg" 2>/dev/null || true
  fi
}

runtime_context() {
  python3 - <<'PY' 2>/dev/null || true
import json
from pathlib import Path

p = Path("/tmp/openclaw/extraction_progress.json")
if not p.exists():
    raise SystemExit
try:
    d = json.loads(p.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit

workers = d.get("workers") or []
if workers:
    w = workers[0]
    worker = f"worker{w.get('worker_id')}"
    label = w.get("label")
    model = w.get("model")
    api = w.get("api_base_url") or w.get("provider") or "unknown"
    api_type = w.get("api_type")
    token_total = w.get("estimated_total_tokens")
    token_input = w.get("estimated_input_tokens")
    token_output = w.get("max_output_tokens")
    print(f"Worker/API: {worker} {label or ''} | {model or 'unknown'} | {api_type or 'api'} {api}")
    
    # API key 标识
    import os
    key = os.environ.get("BAILIAN_CODING_PLAN_API_KEY") or os.environ.get("DASHSCOPE_API_KEY") or "none"
    if key.startswith("sk-sp-"):
        print(f"API Key: ✅ coding plan (sk-sp-{key[8:12]}...)")
    elif key.startswith("sk-"):
        print(f"API Key: ⚠️  标准 key (sk-{key[3:7]}...)")
    else:
        print(f"API Key: ❌ 未设置")
    if token_total:
        print(f"预计token: 本次约 {token_total:,} (输入约 {token_input:,}, 输出预算 {token_output:,})")

token = d.get("token_estimate") or {}
remaining = token.get("remaining_total_tokens_estimate")
if remaining:
    print(f"剩余token粗估: 约 {remaining:,}")
PY
}

next_hour_epoch() {
  python3 - <<'PY'
import time
now = int(time.time())
print(((now // 3600) + 1) * 3600)
PY
}

last_failure_count=0
next_report_at="$(next_hour_epoch)"
paused_alerted=0

while true; do
  if [[ -f "$QUEUE_TOTAL_FILE" ]]; then
    total_from_file="$(tr -d ' ' < "$QUEUE_TOTAL_FILE")"
    [[ "$total_from_file" =~ ^[0-9]+$ ]] && TOTAL="$total_from_file"
  fi

  now="$(date +%s)"
  success=$(tail -n +2 "$SUCCESS_TSV" 2>/dev/null | wc -l | tr -d ' ')
  failed=$(tail -n +2 "$FAILURES_TSV" 2>/dev/null | wc -l | tr -d ' ')
  [[ "$success" -lt 0 ]] && success=0
  [[ "$failed" -lt 0 ]] && failed=0
  processed=$((success + failed))

  # Check if worker wrapper processes are still alive.
  # Also check for openclaw agent child processes as a fallback, since
  # the wrapper PID may exit while the agent is still running.
  alive=0
  expected=0
  for pidf in "$PID_DIR"/worker_*.pid; do
    [[ -f "$pidf" ]] || continue
    expected=$((expected + 1))
    pid="$(cat "$pidf" | tr -d ' ')"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      alive=$((alive + 1))
    else
      # Wrapper exited — check if an openclaw agent child is still running
      # for this run. This handles the case where stop_extraction.sh killed
      # the wrapper but the agent process is still finishing.
      if pgrep -f "openclaw agent.*${RUN_DIR##*/}" >/dev/null 2>&1; then
        alive=$((alive + 1))
      fi
    fi
  done
  # Also check if any openclaw agent processes exist for this run (covers
  # cases where PID files were cleaned up but agents are still running).
  if [[ "$alive" -eq 0 ]]; then
    agent_alive=$(pgrep -cf "openclaw agent.*${RUN_DIR##*/}" 2>/dev/null || echo 0)
    [[ "$agent_alive" -gt 0 ]] && alive=$agent_alive
  fi

  # Check queue remaining
  remaining="?"
  if [[ -n "$QUEUE_FILE" && -f "$QUEUE_FILE" ]]; then
    remaining=$(python3 -c "
import sys
try:
    with open('$QUEUE_FILE') as f:
        print(sum(1 for l in f if l.strip()))
except: print('?')
" 2>/dev/null)
  fi

  # Detect new failures
  if [[ "$failed" -gt "$last_failure_count" ]]; then
    # New failures since last check
    new_failures=$(tail -n +2 "$FAILURES_TSV" | tail -n +$((last_failure_count + 1)) | cut -f2,4,7 | head -5)
    context="$(runtime_context)"
    api_key_info="$(active_key_id)"
    notify "$(label_prefix)⚠️ 新增失败 ($last_failure_count → $failed)
$new_failures

当前进度: $processed/$TOTAL (成功 $success, 失败 $failed)
Worker: $alive/$expected 存活
API: $api_key_info
$context"
    last_failure_count=$failed
  fi

  # Optional progress report on the clock hour. Keep disabled by default to
  # avoid duplicating the main hourly status notifier.
  if [[ "$SEND_HOURLY_PROGRESS" == "1" && "$now" -ge "$next_report_at" ]]; then
    pct=0
    [[ "$TOTAL" -gt 0 ]] && pct=$((processed * 100 / TOTAL))
    context="$(runtime_context)"
    api_key_info="$(active_key_id)"
    notify "$(label_prefix)📊 提参进度 ($pct%)
成功: $success | 失败: $failed | 剩余: $remaining
Worker: $alive/$expected 存活
API: $api_key_info
Run: $(basename "$RUN_DIR")
$context"
    next_report_at="$(next_hour_epoch)"
  fi

  # Exit if all done.
  # IMPORTANT: Only report completion/pause when there are NO openclaw agent
  # processes still running for this run. This prevents false alerts when
  # stop_extraction.sh kills the wrapper PIDs but agents are still finishing.
  agent_alive=0
  if [[ "$alive" -eq 0 ]]; then
    agent_alive=$(pgrep -cf "openclaw agent.*${RUN_DIR##*/}" 2>/dev/null || echo 0)
  fi

  if [[ "$agent_alive" -eq 0 && "$alive" -eq 0 && "$remaining" != "?" && "$remaining" -eq 0 && "$processed" -gt 0 ]]; then
    context="$(runtime_context)"
    notify "$(label_prefix)✅ 提参任务完成
成功: $success | 失败: $failed | 总计: $TOTAL
$context"
    exit 0
  fi

  if [[ "$agent_alive" -eq 0 && "$alive" -eq 0 && "$remaining" != "?" && "$remaining" -gt 0 && "$processed" -gt 0 ]]; then
    if [[ "$paused_alerted" -eq 0 ]]; then
      context="$(runtime_context)"
      notify "$(label_prefix)⏸️ 提参已暂停或停止
成功: $success | 失败: $failed | 剩余: $remaining
Worker: $alive/$expected 存活
Run: $(basename "$RUN_DIR")
$context"
      paused_alerted=1
    fi
    exit 0
  fi

  sleep "$CHECK_INTERVAL"
done
