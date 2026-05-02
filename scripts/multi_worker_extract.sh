#!/usr/bin/env bash
# Multi-worker concurrent PDF extraction for JJJ Literature.
# Runs two workers by default, with optional bailian as the third worker.
# Uses Python queue_helper.py for cross-platform atomic locking (macOS compatible).

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPT_FILE="$REPO_DIR/prompts/jjj_single_agent_extraction_prompt.md"
DEFAULT_OUT_DIR="$REPO_DIR/outputs/extractions"
PID_DIR="/tmp/openclaw/multi_extract_pids"
QH="$REPO_DIR/scripts/queue_helper.py"

NOTIFY_PHONE="+8615895848729"
LAST_NOTIFY_FILE="/tmp/openclaw/multi_extract_last_notify"
NOTIFY_COOLDOWN=300

RUN_ID="${MULTI_EXTRACT_RUN_ID:-$(date +%Y%m%d%H%M%S)-$$}"
RUN_DIR="${MULTI_EXTRACT_RUN_DIR:-/tmp/openclaw/litextract_runs/$RUN_ID}"
QUEUE_FILE="${MULTI_EXTRACT_QUEUE_FILE:-/tmp/openclaw/multi_extract_queue_${RUN_ID}.txt}"

# ── helpers ─────────────────────────────────────────────────────────
load_dotenv() {
  local env_file="$1" line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* || "$line" != *=* ]] && continue
    key="${line%%=*}"; value="${line#*=}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    export "$key=$value"
  done < "$env_file"
}

timestamp() {
  python3 -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).astimezone().isoformat(timespec='seconds'))"
}

hash_path() {
  printf '%s' "$1" | shasum -a 1 2>/dev/null | awk '{print $1}' || \
  python3 -c "import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode()).hexdigest())" "$1"
}

is_valid_extraction_json() {
  local json_file="$1"
  [[ -s "$json_file" ]] && \
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert 'schema_version' in d or 'knowledge_items' in d" "$json_file" 2>/dev/null
}

unified_json_path() {
  local pdf="$1" base stem
  base="$(basename "$pdf")"
  stem="${base%.[Pp][Dd][Ff]}"
  case "$pdf" in
    *"/英文文献/"*) echo "$OUT_DIR/英文文献/json/$stem.json" ;;
    *"/中文文献/"*) echo "$OUT_DIR/中文文献/json/$stem.json" ;;
    *"/专利/"*) echo "$OUT_DIR/专利/json/$stem.json" ;;
    *"/书本/中文/"*) echo "$OUT_DIR/书本/中文/json/$stem.json" ;;
    *"/书本/英文/"*) echo "$OUT_DIR/书本/英文/json/$stem.json" ;;
    *) echo "" ;;
  esac
}

notify_imsg() {
  local msg="$1"
  if command -v imsg >/dev/null 2>&1; then
    imsg send --to "$NOTIFY_PHONE" --text "$msg" 2>/dev/null || true
  fi
}

notify_failure() {
  local worker_id="$1" model="$2" pdf_name="$3" reason="$4"
  local now; now="$(date +%s)"
  local last=0
  [[ -f "$LAST_NOTIFY_FILE" ]] && last="$(cat "$LAST_NOTIFY_FILE" | tr -d ' ')"
  local diff=$(( now - last ))
  if [[ "$diff" -ge "$NOTIFY_COOLDOWN" ]]; then
    notify_imsg "⚠️ 提参故障 [Worker $worker_id $model]
文件: $pdf_name
原因: $reason"
    echo "$now" > "$LAST_NOTIFY_FILE"
  fi
}

# macOS-compatible timeout wrapper
run_with_timeout() {
  local timeout_seconds="$1"; shift
  python3 - "$timeout_seconds" "$@" <<'PY'
import subprocess, sys
timeout_seconds = int(sys.argv[1])
cmd = sys.argv[2:]
try:
    completed = subprocess.run(cmd, timeout=timeout_seconds)
except subprocess.TimeoutExpired:
    sys.exit(124)
sys.exit(completed.returncode)
PY
}

# ── args ────────────────────────────────────────────────────────────
PDF_DIR=""; OUT_DIR="$DEFAULT_OUT_DIR"; LIMIT=0
TIMEOUT_SECONDS=1800; SLEEP_SECONDS=2; FORCE=0; DRY_RUN=0
INCLUDE_BAILIAN=0

usage() {
  cat <<'USAGE'
Usage: scripts/multi_worker_extract.sh --pdf-dir <DIR> [options]
  --out-dir DIR    --limit N    --timeout-seconds N    --sleep-seconds N
  --include-bailian
  --force    --dry-run    -h/--help
Default workers: dashscope/qwen3.6-plus, mimo/mimo-v2.5-pro
Use --include-bailian only after confirming Coding Plan quota is available.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf-dir)         PDF_DIR="${2:-}"; shift 2 ;;
    --out-dir)         OUT_DIR="${2:-}"; shift 2 ;;
    --limit)           LIMIT="${2:-0}"; shift 2 ;;
    --timeout-seconds) TIMEOUT_SECONDS="${2:-1800}"; shift 2 ;;
    --sleep-seconds)   SLEEP_SECONDS="${2:-2}"; shift 2 ;;
    --include-bailian) INCLUDE_BAILIAN=1; shift ;;
    --force)           FORCE=1; shift ;;
    --dry-run)         DRY_RUN=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)                 echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$PDF_DIR" ]] && { echo "ERROR: --pdf-dir required" >&2; exit 2; }
[[ -f "$REPO_DIR/.env" ]] && load_dotenv "$REPO_DIR/.env"
export OPENCLAW_CONFIG_PATH="$REPO_DIR/openclaw.json"

MODELS=(
  "dashscope/qwen3.6-plus"
  "mimo/mimo-v2.5-pro"
)
MODEL_LABELS=(
  "dashscope-qwen36"
  "mimo-v25pro"
)
if [[ "$INCLUDE_BAILIAN" -eq 1 ]]; then
  MODELS=(
    "dashscope/qwen3.6-plus"
    "bailian/qwen3.6-plus"
    "mimo/mimo-v2.5-pro"
  )
  MODEL_LABELS=(
    "dashscope-qwen36"
    "bailian-qwen36"
    "mimo-v25pro"
  )
fi

# ── dirs ────────────────────────────────────────────────────────────
RUN_JSON_DIR="$RUN_DIR/json"
RAW_DIR="$RUN_DIR/raw"
LOG_DIR="$RUN_DIR/logs"
PROMPT_DIR="$RUN_DIR/prompts"
SUCCESS_TSV="$RUN_DIR/manifests/success.tsv"
FAILURES_TSV="$RUN_DIR/manifests/failures.tsv"
PDF_LIST="$RUN_DIR/manifests/pdf_list.txt"

if [[ "$DRY_RUN" -eq 1 ]]; then
  mkdir -p /tmp/openclaw
  PDF_LIST="/tmp/openclaw/multi_extract_${RUN_ID}_pdf_list.txt"
else
  for cat in "英文文献" "中文文献" "专利" "书本/中文" "书本/英文"; do
    mkdir -p "$OUT_DIR/$cat/json"
  done
  mkdir -p "$RUN_JSON_DIR" "$RAW_DIR" "$LOG_DIR" "$PROMPT_DIR" "$RUN_DIR/manifests" "$PID_DIR"

  # ── init manifests ────────────────────────────────────────────────
  if [[ ! -f "$SUCCESS_TSV" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      timestamp pdf_path record_id model json_path raw_path extraction_seconds > "$SUCCESS_TSV"
  fi
  if [[ ! -f "$FAILURES_TSV" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      timestamp pdf_path record_id model stage exit_code reason log_path > "$FAILURES_TSV"
  fi
fi

# ── build queue ─────────────────────────────────────────────────────
: > "$QUEUE_FILE"
python3 - "$PDF_DIR" > "$PDF_LIST" <<'PY'
import os, sys
root = sys.argv[1]
paths = []
for dp, _, fns in os.walk(root):
    for fn in fns:
        if fn.lower().endswith(".pdf"):
            paths.append(os.path.join(dp, fn))
for p in sorted(paths):
    print(p)
PY

queued_count=0
skipped_existing=0
scanned_count=0
while IFS= read -r pdf; do
  scanned_count=$((scanned_count + 1))
  rid="$(hash_path "$pdf")"
  jf="$RUN_JSON_DIR/$rid.json"
  unified_jf="$(unified_json_path "$pdf")"
  if [[ "$FORCE" -eq 0 ]] && is_valid_extraction_json "$jf"; then
    skipped_existing=$((skipped_existing + 1))
    continue
  fi
  if [[ "$FORCE" -eq 0 && -n "$unified_jf" ]] && is_valid_extraction_json "$unified_jf"; then
    skipped_existing=$((skipped_existing + 1))
    continue
  fi
  echo "$pdf" >> "$QUEUE_FILE"
  queued_count=$((queued_count + 1))
  if [[ "$LIMIT" -gt 0 && "$queued_count" -ge "$LIMIT" ]]; then
    break
  fi
done < "$PDF_LIST"

TOTAL_QUEUED="$(wc -l < "$QUEUE_FILE" | tr -d ' ')"
TOTAL_ALL="$(wc -l < "$PDF_LIST" | tr -d ' ')"

echo "=== Multi-Worker Extraction ==="
echo "PDF dir:      $PDF_DIR"
echo "Output:       $OUT_DIR"
echo "Run dir:      $RUN_DIR"
echo "Run ID:       $RUN_ID"
echo "Total PDFs:   $TOTAL_ALL"
echo "Scanned:      $scanned_count"
echo "Queued:       $TOTAL_QUEUED (skipped $skipped_existing existing)"
echo "Workers:      ${#MODELS[@]} (${MODEL_LABELS[*]})"
echo "Timeout:      ${TIMEOUT_SECONDS}s per PDF"
echo ""

if [[ "$DRY_RUN" -eq 1 || "$TOTAL_QUEUED" -eq 0 ]]; then
  [[ "$TOTAL_QUEUED" -eq 0 ]] && echo "Nothing to do."
  exit 0
fi

# ── JSON extraction ─────────────────────────────────────────────────
extract_first_json() {
  python3 - "$1" "$2" <<'PYEOF'
import json, re, sys
raw_path, json_path = sys.argv[1], sys.argv[2]
with open(raw_path, "r", encoding="utf-8") as f:
    text = f.read()
text = re.sub(r"```json\s*", "", text)
text = re.sub(r"```\s*", "", text)
text = text.strip()

def fix_quotes(t):
    out, in_s, i = [], False, 0
    while i < len(t):
        c = t[i]
        if not in_s:
            out.append(c)
            if c == '"': in_s = True
            i += 1; continue
        if c == '\\' and i+1 < len(t):
            out.append(c); out.append(t[i+1]); i += 2; continue
        if c == '"':
            rest = t[i+1:].lstrip()
            if rest and rest[0] in ',:]} \n\r\t':
                out.append(c); in_s = False
            else:
                out.append('\\"')
            i += 1; continue
        if c == '\n': out.append('\\n'); i += 1; continue
        out.append(c); i += 1
    return ''.join(out)

def try_parse(t):
    for txt in [t, fix_quotes(t)]:
        s = txt.find('{')
        if s < 0: continue
        try: return json.loads(txt[s:])
        except json.JSONDecodeError: pass
        depth = 0
        for j in range(s, len(txt)):
            if txt[j] == '{': depth += 1
            elif txt[j] == '}':
                depth -= 1
                if depth == 0:
                    try: return json.loads(txt[s:j+1])
                    except json.JSONDecodeError: break
    return None

obj = try_parse(text)
if obj is None:
    print("No valid JSON found", file=sys.stderr); sys.exit(1)
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(obj, f, ensure_ascii=False, indent=2); f.write("\n")
print(f"ok chars={len(json.dumps(obj))}")
PYEOF
}

# ── worker ──────────────────────────────────────────────────────────
worker() {
  local worker_id="$1" model="$2" label="$3"
  local worker_log="$LOG_DIR/worker_${worker_id}_${label}.log"
  local processed=0 skipped=0

  echo "[worker $worker_id] started  model=$model" | tee "$worker_log"

  while true; do
    local pdf
    pdf="$(python3 "$QH" pop "$QUEUE_FILE")"
    [[ -z "$pdf" ]] && break

    local record_id; record_id="$(hash_path "$pdf")"
    local raw_path="$RAW_DIR/$record_id.raw.txt"
    local log_path="$LOG_DIR/$record_id.log"
    local prompt_path="$PROMPT_DIR/$record_id.prompt.txt"
    local basename_pdf; basename_pdf="$(basename "$pdf")"

    local unified_json_path_for_pdf
    unified_json_path_for_pdf="$(unified_json_path "$pdf")"
    local json_path="$unified_json_path_for_pdf"
    [[ -z "$json_path" ]] && json_path="$RUN_JSON_DIR/$record_id.json"
    mkdir -p "$(dirname "$json_path")"

    if [[ "$FORCE" -eq 0 ]] && is_valid_extraction_json "$json_path"; then
      echo "[worker $worker_id] skip: $basename_pdf" | tee -a "$worker_log"
      skipped=$((skipped+1)); continue
    fi

    processed=$((processed+1))
    echo "[worker $worker_id] [$processed] $basename_pdf  ($label)" | tee -a "$worker_log"

    {
      echo "请读取并提取以下 PDF："; echo "$pdf"; echo
      echo "请严格遵循下面的项目提示词。最终只输出一个 JSON 对象。"; echo
      cat "$PROMPT_FILE"
    } > "$prompt_path"

    local start_ts end_ts elapsed_s
    start_ts="$(date +%s)"

    if (cd "$REPO_DIR" && run_with_timeout "$TIMEOUT_SECONDS" \
        openclaw agent --local --agent lit-extract \
          --session-id "multi-${RUN_ID}-w${worker_id}-${label}" \
          --model "$model" \
          --timeout "$TIMEOUT_SECONDS" \
          --message "$(cat "$prompt_path")" \
          > "$raw_path" 2>> "$log_path"); then
      if extract_first_json "$raw_path" "$json_path" >> "$log_path" 2>&1 && \
         python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$json_path" 2>/dev/null; then
        end_ts="$(date +%s)"; elapsed_s=$((end_ts-start_ts))
        python3 "$QH" append "$SUCCESS_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$model" "$json_path" "$raw_path" "$elapsed_s"
        echo "[worker $worker_id]   OK ${elapsed_s}s" | tee -a "$worker_log"
      else
        end_ts="$(date +%s)"; elapsed_s=$((end_ts-start_ts))
        python3 "$QH" append "$FAILURES_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$model" "json_extract" "1" "no_valid_json" "$log_path"
        echo "[worker $worker_id]   FAIL json ${elapsed_s}s" | tee -a "$worker_log"
        notify_failure "$worker_id" "$label" "$basename_pdf" "JSON提取失败"
      fi
    else
      local exit_code=$?
      end_ts="$(date +%s)"; elapsed_s=$((end_ts-start_ts))
      python3 "$QH" append "$FAILURES_TSV" \
        "$(timestamp)" "$pdf" "$record_id" "$model" "openclaw_agent" "$exit_code" "timeout_or_error" "$log_path"
      echo "[worker $worker_id]   FAIL exit=$exit_code ${elapsed_s}s" | tee -a "$worker_log"
      notify_failure "$worker_id" "$label" "$basename_pdf" "openclaw超时或错误(exit=$exit_code)"
    fi
    sleep "$SLEEP_SECONDS"
  done

  echo "[worker $worker_id] done  processed=$processed  skipped=$skipped" | tee -a "$worker_log"
}

# ── launch ──────────────────────────────────────────────────────────
echo "Launching ${#MODELS[@]} workers..."
for i in "${!MODELS[@]}"; do
  worker "$((i+1))" "${MODELS[$i]}" "${MODEL_LABELS[$i]}" &
  echo $! > "$PID_DIR/worker_$((i+1)).pid"
  echo "  Worker $((i+1)): PID $!  ${MODELS[$i]}"
done
echo $$ > "$PID_DIR/launcher.pid"
echo ""; echo "Running. Queue: $QUEUE_FILE"; echo ""

# ── wait & summary ──────────────────────────────────────────────────
wait

success_count=$(( $(wc -l < "$SUCCESS_TSV" | tr -d ' ') - 1 ))
failure_count=$(( $(wc -l < "$FAILURES_TSV" | tr -d ' ') - 1 ))
[[ "$success_count" -lt 0 ]] && success_count=0
[[ "$failure_count" -lt 0 ]] && failure_count=0

echo ""; echo "=== Complete ==="
echo "Success: $success_count  Failed: $failure_count"

if python3 "$REPO_DIR/scripts/merge_results.py" >> "$RUN_DIR/merge.log" 2>&1 && \
   python3 "$REPO_DIR/scripts/update_extraction_progress_doc.py" >> "$RUN_DIR/merge.log" 2>&1; then
  echo "Unified manifests updated: $OUT_DIR/manifests"
else
  echo "WARN: failed to refresh unified manifests; check $RUN_DIR/merge.log" >&2
fi

notify_imsg "✅ 提参批次完成
成功: $success_count
失败: $failure_count
结果: $OUT_DIR"

python3 -c "
import json
p = {'status':'completed','processed':$((success_count+failure_count)),'success':$success_count,'failed':$failure_count,'remaining':0,'updated_at':'$(date '+%Y-%m-%d %H:%M:%S')'}
with open('/tmp/openclaw/extraction_progress.json','w') as f: json.dump(p,f,indent=2)
"
