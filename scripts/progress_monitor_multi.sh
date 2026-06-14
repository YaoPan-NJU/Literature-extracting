#!/usr/bin/env bash
# Progress monitor for multi-worker extraction.
# Reads manifests and writes JSON summary to /tmp/openclaw/extraction_progress.json

set -u

PROGRESS_FILE="/tmp/openclaw/extraction_progress.json"
INTERVAL=30
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv/bin/python}"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <RUN_DIR> <TOTAL_PDFS> [QUEUE_FILE]" >&2
  exit 1
fi

RUN_DIR="$1"
TOTAL_PDFS="$2"
QUEUE_FILE="${3:-/tmp/openclaw/multi_extract_queue.txt}"

SUCCESS_TSV="$RUN_DIR/manifests/success.tsv"
FAILURES_TSV="$RUN_DIR/manifests/failures.tsv"
QUEUE_TOTAL_FILE="$RUN_DIR/manifests/queue_total.txt"

mkdir -p "$(dirname "$PROGRESS_FILE")"
START_TIME="$("$PYTHON_BIN" - "$RUN_DIR" <<'PY'
import re
import sys
import time
from datetime import datetime
from pathlib import Path

name = Path(sys.argv[1]).name
match = re.match(r"(\d{14})-", name)
if match:
    try:
        print(int(datetime.strptime(match.group(1), "%Y%m%d%H%M%S").timestamp()))
        raise SystemExit
    except Exception:
        pass
print(int(time.time()))
PY
)"

while true; do
  success_count=0; failure_count=0; queued=0
  if [[ -f "$QUEUE_TOTAL_FILE" ]]; then
    total_from_file="$(tr -d ' ' < "$QUEUE_TOTAL_FILE")"
    [[ "$total_from_file" =~ ^[0-9]+$ ]] && TOTAL_PDFS="$total_from_file"
  fi
  [[ -f "$SUCCESS_TSV" ]] && success_count=$(( $(wc -l < "$SUCCESS_TSV" | tr -d ' ') - 1 ))
  [[ -f "$FAILURES_TSV" ]] && failure_count=$(( $(wc -l < "$FAILURES_TSV" | tr -d ' ') - 1 ))
  [[ -f "$QUEUE_FILE" ]] && queued=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
  [[ "$success_count" -lt 0 ]] && success_count=0
  [[ "$failure_count" -lt 0 ]] && failure_count=0

  processed=$((success_count + failure_count))
  elapsed=$(( $(date +%s) - START_TIME ))

  # active workers — check wrapper PIDs first, then fall back to
  # openclaw agent processes for this run (handles case where
  # stop_extraction.sh killed wrappers but agents are still finishing).
  active_workers=0
  for pidf in /tmp/openclaw/multi_extract_pids/worker_*.pid; do
    [[ -f "$pidf" ]] || continue
    pid=$(cat "$pidf" | tr -d ' ')
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      active_workers=$((active_workers + 1))
    else
      if pgrep -f "openclaw agent.*${RUN_DIR##*/}" >/dev/null 2>&1; then
        active_workers=$((active_workers + 1))
      fi
    fi
  done
  if [[ "$active_workers" -eq 0 ]]; then
    agent_count=$(pgrep -cf "openclaw agent.*${RUN_DIR##*/}" 2>/dev/null || echo 0)
    [[ "$agent_count" -gt 0 ]] && active_workers=$agent_count
  fi
  free_repo_gb=$(df -Pk "$REPO_DIR" | awk 'NR==2 {print int($4/1024/1024)}')
  free_tmp_gb=$(df -Pk /tmp | awk 'NR==2 {print int($4/1024/1024)}')

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
      "$PYTHON_BIN" -c "
import sys, json
d = {}
for line in sys.stdin:
    parts = line.strip().split()
    if len(parts) == 2:
        d[parts[1]] = int(parts[0])
print(json.dumps(d))
" 2>/dev/null || echo "{}")
  fi
  [[ -n "$model_stats" ]] || model_stats="{}"

  runtime_info=$("$PYTHON_BIN" - "$REPO_DIR" "$RUN_DIR" <<'PY' 2>/dev/null || echo '{"workers":[],"token_estimate":{}}'
import glob
import json
import math
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

repo = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
pid_dir = Path("/tmp/openclaw/multi_extract_pids")
status_dir = Path("/tmp/openclaw/worker_status")

try:
    config = json.loads((repo / "openclaw.json").read_text(encoding="utf-8"))
except Exception:
    config = {}
providers = config.get("models", {}).get("providers", {})

def estimate_tokens_for_text(text: str) -> int:
    ascii_chars = sum(1 for ch in text if ord(ch) < 128)
    non_ascii_chars = len(text) - ascii_chars
    return int(math.ceil(ascii_chars / 4 + non_ascii_chars * 1.2))

def estimate_prompt_tokens(path: Path):
    try:
        return estimate_tokens_for_text(path.read_text(encoding="utf-8", errors="ignore"))
    except Exception:
        return None

def model_metadata(model: str) -> dict:
    provider_name, _, model_id = model.partition("/")
    provider = providers.get(provider_name, {})
    model_cfg = {}
    for item in provider.get("models", []):
        if item.get("id") == model_id or item.get("name") == model_id:
            model_cfg = item
            break
    return {
        "provider": provider_name or None,
        "api_base_url": provider.get("baseUrl"),
        "api_type": provider.get("api"),
        "model": model,
        "max_output_tokens": model_cfg.get("maxTokens"),
        "context_window": model_cfg.get("contextWindow"),
    }

def command_for_pid(pid: str) -> str:
    try:
        return subprocess.check_output(
            ["ps", "-p", pid, "-o", "command="],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return ""

def is_alive(pid: str) -> bool:
    try:
        subprocess.check_call(["kill", "-0", pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False

def latest_worker_pdf(worker_id: str, label: str):
    log_path = run_dir / "logs" / f"worker_{worker_id}_{label}.log"
    if not log_path.exists():
        return None
    try:
        lines = log_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        return None
    pattern = re.compile(r"^\[worker\s+\S+\]\s+\[\d+\]\s+(.+?\.pdf)\s+\(")
    for line in reversed(lines[-200:]):
        match = pattern.search(line)
        if match:
            return match.group(1)
    return None

def latest_prompt():
    paths = list((run_dir / "prompts").glob("*.prompt.txt"))
    if not paths:
        return None
    return max(paths, key=lambda p: p.stat().st_mtime)

def recent_prompt_average(limit: int = 20):
    paths = sorted((run_dir / "prompts").glob("*.prompt.txt"), key=lambda p: p.stat().st_mtime)[-limit:]
    estimates = [v for v in (estimate_prompt_tokens(p) for p in paths) if v]
    if not estimates:
        return None
    return int(round(sum(estimates) / len(estimates)))

workers = []
status_by_worker = {}
for status_path in status_dir.glob("worker_*.json"):
    try:
        data = json.loads(status_path.read_text(encoding="utf-8"))
        status_run_dir = data.get("run_dir")
        if status_run_dir:
            if Path(status_run_dir) != run_dir:
                continue
        else:
            prompt_path = data.get("prompt_path")
            if not prompt_path:
                continue
            try:
                Path(prompt_path).resolve().relative_to(run_dir.resolve())
            except Exception:
                continue
        status_by_worker[str(data.get("worker_id"))] = data
    except Exception:
        pass

for pid_path in sorted(pid_dir.glob("worker_*.pid")):
    worker_id = pid_path.stem.split("_", 1)[-1]
    try:
        pid = pid_path.read_text().strip()
    except Exception:
        pid = ""
    if not pid or not is_alive(pid):
        continue
    command = command_for_pid(pid)
    model = None
    label = None
    try:
        args = shlex.split(command)
        script_index = next(i for i, arg in enumerate(args) if arg.endswith("single_worker_extract.sh"))
        worker_id = args[script_index + 1]
        model = args[script_index + 2]
        label = args[script_index + 3]
    except Exception:
        pass

    status = status_by_worker.get(str(worker_id), {})
    if not model:
        model = status.get("model")
    if not label:
        label = status.get("label")

    prompt_path = Path(status["prompt_path"]) if status.get("prompt_path") else None
    input_tokens = estimate_prompt_tokens(prompt_path) if prompt_path else None
    metadata = model_metadata(model or "")
    max_output = metadata.get("max_output_tokens")
    total_budget = input_tokens + max_output if input_tokens and max_output else None
    worker = {
        "worker_id": worker_id,
        "pid": int(pid) if pid.isdigit() else pid,
        "label": label,
        "model": model,
        "provider": metadata.get("provider"),
        "api_base_url": metadata.get("api_base_url"),
        "api_type": metadata.get("api_type"),
        "current_pdf": status.get("current_pdf") or latest_worker_pdf(str(worker_id), str(label or "")),
        "estimated_input_tokens": input_tokens,
        "max_output_tokens": max_output,
        "estimated_total_tokens": total_budget,
        "token_estimate_method": "ceil(ascii_chars/4 + non_ascii_chars*1.2) + max_output_tokens",
    }
    workers.append(worker)

avg_input = recent_prompt_average()
max_output_values = [w.get("max_output_tokens") for w in workers if isinstance(w.get("max_output_tokens"), int)]
max_output = max(max_output_values) if max_output_values else None
summary = {
    "current_call_input_tokens": sum(w.get("estimated_input_tokens") or 0 for w in workers) or None,
    "current_call_max_output_tokens": sum(w.get("max_output_tokens") or 0 for w in workers) or None,
    "current_call_total_tokens": sum(w.get("estimated_total_tokens") or 0 for w in workers) or None,
    "average_input_tokens_last_20": avg_input,
    "max_output_tokens_per_call": max_output,
    "estimate_method": "rough prompt-length estimate, not provider billing data",
    "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
}
print(json.dumps({"workers": workers, "token_estimate": summary}, ensure_ascii=False))
PY
)

  # Only report completed/paused when no openclaw agent processes are
  # still running for this run. Prevents false alerts after
  # stop_extraction.sh kills wrapper PIDs but agents are still finishing.
  agent_alive=$(pgrep -cf "openclaw agent.*${RUN_DIR##*/}" 2>/dev/null || echo 0)

  status="running"
  if [[ "$agent_alive" -eq 0 && "$active_workers" -eq 0 && "$remaining" == 0 && "$processed" -gt 0 ]]; then
    status="completed"
  elif [[ "$agent_alive" -eq 0 && "$active_workers" -eq 0 && "$remaining" -gt 0 && "$processed" -gt 0 ]]; then
    status="paused_no_workers"
  elif [[ "$agent_alive" -eq 0 && "$active_workers" -eq 0 && "$remaining" -gt 0 ]]; then
    status="starting"
  fi

  PROGRESS_FILE_ENV="$PROGRESS_FILE" \
  STATUS_ENV="$status" \
  TOTAL_PDFS_ENV="$TOTAL_PDFS" \
  QUEUED_ENV="$queued" \
  PROCESSED_ENV="$processed" \
  SUCCESS_ENV="$success_count" \
  FAILED_ENV="$failure_count" \
  RUN_ID_ENV="$(basename "$RUN_DIR")" \
  RUN_DIR_ENV="$RUN_DIR" \
  ELAPSED_ENV="$elapsed_str" \
  ETA_ENV="$eta_str" \
  ACTIVE_WORKERS_ENV="$active_workers" \
  FREE_REPO_GB_ENV="$free_repo_gb" \
  FREE_TMP_GB_ENV="$free_tmp_gb" \
  MODEL_STATS_JSON="$model_stats" \
  RUNTIME_JSON="$runtime_info" \
  "$PYTHON_BIN" <<'PY'
import json
import os
import time

def int_env(name: str) -> int:
    return int(os.environ.get(name) or 0)

try:
    per_model = json.loads(os.environ.get("MODEL_STATS_JSON") or "{}")
except Exception:
    per_model = {}
try:
    runtime = json.loads(os.environ.get("RUNTIME_JSON") or '{"workers":[],"token_estimate":{}}')
except Exception:
    runtime = {"workers": [], "token_estimate": {}}

progress = {
    'status': os.environ.get('STATUS_ENV') or 'running',
    'scope': 'batch',
    'run_id': os.environ.get('RUN_ID_ENV') or '',
    'run_dir': os.environ.get('RUN_DIR_ENV') or '',
    'total': int_env('TOTAL_PDFS_ENV'),
    'queued': int_env('QUEUED_ENV'),
    'processed': int_env('PROCESSED_ENV'),
    'success': int_env('SUCCESS_ENV'),
    'failed': int_env('FAILED_ENV'),
    'elapsed': os.environ.get('ELAPSED_ENV') or '0h0m',
    'eta': os.environ.get('ETA_ENV') or 'unknown',
    'active_workers': int_env('ACTIVE_WORKERS_ENV'),
    'free_repo_gb': int_env('FREE_REPO_GB_ENV'),
    'free_tmp_gb': int_env('FREE_TMP_GB_ENV'),
    'per_model': per_model,
    'updated_at': time.strftime('%Y-%m-%d %H:%M:%S')
}
progress.update(runtime)
token_estimate = progress.get('token_estimate') or {}
avg_input = token_estimate.get('average_input_tokens_last_20')
max_output = token_estimate.get('max_output_tokens_per_call')
if avg_input and max_output:
    token_estimate['remaining_total_tokens_estimate'] = progress['queued'] * (avg_input + max_output)
progress['token_estimate'] = token_estimate
with open(os.environ['PROGRESS_FILE_ENV'], 'w', encoding='utf-8') as f:
    json.dump(progress, f, ensure_ascii=False, indent=2)
PY

  [[ "$status" == "completed" || "$status" == "paused_no_workers" ]] && exit 0

  sleep "$INTERVAL"
done
