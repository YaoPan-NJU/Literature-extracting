#!/usr/bin/env bash
# Multi-worker concurrent PDF extraction for Biomimetic Design Library.
# Selects 1/2/3 workers explicitly before each run.
# Uses Python queue_helper.py for cross-platform atomic locking (macOS compatible).

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPT_FILE="$REPO_DIR/prompts/biomimetic_extraction_prompt_v2.md"
DEFAULT_OUT_DIR="$REPO_DIR/outputs/extractions"
PID_DIR="/tmp/openclaw/multi_extract_pids"
QH="$REPO_DIR/scripts/queue_helper.py"
PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv/bin/python}"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

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
  "$PYTHON_BIN" -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).astimezone().isoformat(timespec='seconds'))"
}

hash_path() {
  printf '%s' "$1" | shasum -a 1 2>/dev/null | awk '{print $1}' || \
  "$PYTHON_BIN" -c "import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode()).hexdigest())" "$1"
}

is_valid_extraction_json() {
  local json_file="$1"
  [[ -s "$json_file" ]] && \
    "$PYTHON_BIN" -c "import json,sys; d=json.load(open(sys.argv[1])); assert 'schema_version' in d or 'knowledge_items' in d" "$json_file" 2>/dev/null
}

unified_json_path() {
  local pdf="$1" base stem
  base="$(basename "$pdf")"
  stem="${base%.[Pp][Dd][Ff]}"
  case "$pdf" in
    *"/英文文献/"*) echo "$OUT_DIR/英文文献/json/$stem.json" ;;
    *"/en_pdfs/"*) echo "$OUT_DIR/英文文献/json/$stem.json" ;;
    *"/中文文献/"*) echo "$OUT_DIR/中文文献/json/$stem.json" ;;
    *"/专利/"*) echo "$OUT_DIR/专利/json/$stem.json" ;;
    *"/书本/中文/"*) echo "$OUT_DIR/书本/中文/json/$stem.json" ;;
    *"/书本/英文/"*) echo "$OUT_DIR/书本/英文/json/$stem.json" ;;
    *"/论文/"*) echo "$OUT_DIR/论文/json/$stem.json" ;;
    *"/missing_26_pdf_dir/"*) echo "$OUT_DIR/论文/json/$stem.json" ;;
    *"/第二波/"*) echo "$OUT_DIR/第二波/json/$stem.json" ;;
    *"/3rd/"*) echo "$OUT_DIR/第三波/json/$stem.json" ;;
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
  "$PYTHON_BIN" - "$timeout_seconds" "$@" <<'PY'
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
WORKERS=1; PER_WORKER_LIMIT=0; MODE="multimodal"
PREPROCESS_WORKERS=4

usage() {
  cat <<'USAGE'
Usage: scripts/multi_worker_extract.sh --pdf-dir <DIR> [options]
  --out-dir DIR    --limit N    --timeout-seconds N    --sleep-seconds N
  --per-worker-limit N
  --mode multimodal|text-only
  --preprocess-workers N
  --workers 1|2|3
  --include-bailian    Legacy alias for --workers 3.
  --force    --dry-run    -h/--help
Worker mapping:
  1 = bailian/qwen3.6-plus (多模态)
  2 = bailian/qwen3.6-plus + mimo/mimo-v2.5 (双路多模态)
  3 = dashscope/qwen3.7-max + bailian/qwen3.6-plus + mimo/mimo-v2.5 (三路)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf-dir)         PDF_DIR="${2:-}"; shift 2 ;;
    --out-dir)         OUT_DIR="${2:-}"; shift 2 ;;
    --limit)           LIMIT="${2:-0}"; shift 2 ;;
    --per-worker-limit) PER_WORKER_LIMIT="${2:-0}"; shift 2 ;;
    --timeout-seconds) TIMEOUT_SECONDS="${2:-1800}"; shift 2 ;;
    --sleep-seconds)   SLEEP_SECONDS="${2:-2}"; shift 2 ;;
    --mode)            MODE="${2:-multimodal}"; shift 2 ;;
    --preprocess-workers) PREPROCESS_WORKERS="${2:-4}"; shift 2 ;;
    --workers)         WORKERS="${2:-1}"; shift 2 ;;
    --include-bailian) WORKERS=3; shift ;;
    --force)           FORCE=1; shift ;;
    --dry-run)         DRY_RUN=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)                 echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$PDF_DIR" ]] && { echo "ERROR: --pdf-dir required" >&2; exit 2; }
[[ -f "$REPO_DIR/.env" ]] && load_dotenv "$REPO_DIR/.env"
export OPENCLAW_CONFIG_PATH="$REPO_DIR/openclaw.json"

case "$WORKERS" in
  1)
    MODELS=("mimo/mimo-v2.5")
    MODEL_LABELS=("mimo-v25pro")
    ;;
  2)
    MODELS=("bailian/qwen3.6-plus" "mimo/mimo-v2.5")
    MODEL_LABELS=("bailian-qwen36" "mimo-v25pro")
    ;;
  3)
    MODELS=("dashscope/qwen3.7-max" "bailian/qwen3.6-plus" "mimo/mimo-v2.5")
    MODEL_LABELS=("dashscope-qwen37max" "bailian-qwen36" "mimo-v25pro")
    ;;
  *)
    echo "ERROR: --workers must be 1, 2, or 3" >&2
    exit 2
    ;;
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

QUEUE_LIMIT="$LIMIT"
if [[ "$PER_WORKER_LIMIT" -gt 0 ]]; then
  QUEUE_LIMIT=$((PER_WORKER_LIMIT * ${#MODELS[@]}))
fi

# ── dirs ────────────────────────────────────────────────────────────
RUN_JSON_DIR="$RUN_DIR/json"
RAW_DIR="$RUN_DIR/raw"
LOG_DIR="$RUN_DIR/logs"
PROMPT_DIR="$RUN_DIR/prompts"
TEXT_DIR="$RUN_DIR/text"
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
  mkdir -p "$RUN_JSON_DIR" "$RAW_DIR" "$LOG_DIR" "$PROMPT_DIR" "$TEXT_DIR" "$RUN_DIR/manifests" "$PID_DIR"

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
"$PYTHON_BIN" - "$PDF_DIR" > "$PDF_LIST" <<'PY'
import os, sys
root = sys.argv[1]
paths = []
for dp, _, fns in os.walk(root):
    for fn in fns:
        if fn.lower().endswith(".pdf"):
            base = fn[:-4]
            # 跳过 macOS Finder 重复文件 (如 "file 2.pdf")，但如果原始文件不存在则保留
            if base.endswith(" 2"):
                original = os.path.join(dp, base[:-2] + ".pdf")
                if os.path.exists(original):
                    continue  # 原始文件存在，跳过重复
                # 原始文件不存在，保留这个文件
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
  if [[ "$QUEUE_LIMIT" -gt 0 && "$queued_count" -ge "$QUEUE_LIMIT" ]]; then
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
echo "Mode:         $MODE"
[[ "$MODE" == "multimodal" ]] && echo "Preprocess:   $PREPROCESS_WORKERS visual workers"
[[ "$PER_WORKER_LIMIT" -gt 0 ]] && echo "Per worker:   $PER_WORKER_LIMIT PDFs"
echo "Timeout:      ${TIMEOUT_SECONDS}s per PDF"
echo ""

if [[ "$DRY_RUN" -eq 1 || "$TOTAL_QUEUED" -eq 0 ]]; then
  [[ "$TOTAL_QUEUED" -eq 0 ]] && echo "Nothing to do."
  exit 0
fi

# ── JSON extraction ─────────────────────────────────────────────────
extract_first_json() {
  "$PYTHON_BIN" - "$1" "$2" <<'PYEOF'
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

def reconstruct_from_parts(t):
    """Fallback: extract each top-level component via regex and rebuild."""
    s = t.find('{')
    if s < 0: return None
    c = t[s:]
    sm = re.search(r'"schema_version"\s*:\s*"([^"]*)"', c)
    pm = re.search(r'"paper_id"\s*:\s*"([^"]*)"', c)
    if not sm or not pm: return None

    def extract_obj(key):
        pos = c.find(f'"{key}"')
        if pos < 0: return None
        ob = c.find('{', pos)
        if ob < 0: return None
        d = 0
        for j in range(ob, len(c)):
            if c[j] == '{': d += 1
            elif c[j] == '}':
                d -= 1
                if d == 0:
                    try: return json.loads(c[ob:j+1])
                    except: return None
        return None

    def extract_arr(key):
        pos = c.find(f'"{key}"')
        if pos < 0: return []
        lb = c.find('[', pos)
        if lb < 0: return []
        items = []
        for m in re.finditer(r'\{', c[lb:]):
            d = 0
            s2 = lb + m.start()
            for j in range(s2, len(c)):
                if c[j] == '{': d += 1
                elif c[j] == '}':
                    d -= 1
                    if d == 0:
                        try: items.append(json.loads(c[s2:j+1]))
                        except: pass
                        break
        return items

    result = {
        "schema_version": sm.group(1),
        "paper_id": pm.group(1),
        "bibliographic_metadata": extract_obj("bibliographic_metadata") or {},
        "routing": extract_obj("routing") or {},
        "decision_summary": extract_obj("decision_summary") or {},
        "knowledge_items": extract_arr("knowledge_items"),
        "vector_index_records": extract_arr("vector_index_records"),
        "quality_control": extract_obj("quality_control") or {},
        "processing_notes": [],
    }
    if not result["knowledge_items"]: return None
    return result

obj = try_parse(text)
if obj is None:
    print("No valid JSON found", file=sys.stderr); sys.exit(1)
# Validate required fields
required = ['schema_version', 'paper_id', 'knowledge_items']
for field in required:
    if field not in obj:
        print(f"Missing required field: {field}", file=sys.stderr); sys.exit(1)
if not obj['knowledge_items']:
    print("Empty knowledge_items", file=sys.stderr); sys.exit(1)
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(obj, f, ensure_ascii=False, indent=2); f.write("\n")
print(f"ok chars={len(json.dumps(obj))}")
PYEOF
}

extract_pdf_text() {
  "$PYTHON_BIN" - "$1" "$2" <<'PYEOF'
from pathlib import Path
import sys

import fitz

pdf_path = Path(sys.argv[1])
text_path = Path(sys.argv[2])
doc = fitz.open(pdf_path)
char_count = 0

with text_path.open("w", encoding="utf-8") as out:
    out.write(f"PDF file: {pdf_path.name}\n")
    out.write(f"Total pages: {doc.page_count}\n\n")
    for page_no, page in enumerate(doc, 1):
        text = page.get_text("text") or ""
        char_count += len(text.strip())
        out.write(f"\n[Page {page_no}]\n")
        out.write(text)
        out.write("\n")

if char_count < 100:
    print(f"too little text extracted: {char_count} chars", file=sys.stderr)
    sys.exit(1)
print(f"ok pages={doc.page_count} chars={char_count}")
PYEOF
}

visual_cache_path() {
  "$PYTHON_BIN" - "$1" <<'PYEOF'
from pathlib import Path
import sys

p = Path(sys.argv[1])
print(p.with_name(p.stem + "_visual_cache.json"))
PYEOF
}

is_valid_visual_cache() {
  "$PYTHON_BIN" - "$1" <<'PYEOF'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        cache = json.load(f)
    stage0 = cache["stage0"]
    visual = cache.get("visual_markdown", {})
    data_pages = [str(p) for p in stage0.get("data_page_nums", [])]
    missing = [p for p in data_pages if p not in visual]
    if missing:
        raise ValueError(f"missing visual pages: {missing[:5]}")
except Exception as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)
PYEOF
}

compose_multimodal_context() {
  "$PYTHON_BIN" - "$1" "$2" "$3" <<'PYEOF'
import json
import sys
from pathlib import Path

pdf_path = Path(sys.argv[1])
cache_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])

with cache_path.open("r", encoding="utf-8") as f:
    cache = json.load(f)

stage0 = cache["stage0"]
visual = {str(k): v for k, v in cache.get("visual_markdown", {}).items()}
page_types = {int(p["page"]): p.get("type", "text_page") for p in stage0.get("page_types", [])}
pages_text = {int(p["page"]): p.get("text", "") for p in stage0.get("pages_text", [])}
total_pages = int(stage0.get("total_pages") or len(pages_text))

with out_path.open("w", encoding="utf-8") as out:
    out.write("PDF file: " + str(pdf_path) + "\n")
    out.write("Multimodal source: local text anchors + visual page cache\n\n")
    out.write("## Hard metadata anchors\n")
    out.write(f"- Title: {stage0.get('anchor_title') or ''}\n")
    out.write(f"- DOI: {stage0.get('anchor_doi') or ''}\n")
    keywords = stage0.get("anchor_keywords") or []
    out.write("- Keywords: " + ", ".join(str(k) for k in keywords) + "\n")
    out.write(f"- Total pages: {total_pages}\n")
    out.write("- Data pages read visually: " + ", ".join(str(p) for p in stage0.get("data_page_nums", [])) + "\n\n")
    out.write("## Page content\n")

    for page_no in range(1, total_pages + 1):
        page_type = page_types.get(page_no, "text_page")
        if page_type == "skip_page":
            continue
        if page_type == "data_page" and str(page_no) in visual:
            out.write(f"\n[Page {page_no} - visual]\n")
            out.write(visual[str(page_no)].strip())
            out.write("\n")
        else:
            text = pages_text.get(page_no, "").strip()
            if not text:
                continue
            label = "text"
            if page_type == "data_page":
                label = "text fallback; visual cache missing"
            out.write(f"\n[Page {page_no} - {label}]\n")
            out.write(text)
            out.write("\n")
PYEOF
}

# ── worker ──────────────────────────────────────────────────────────
worker() {
  export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
  local worker_id="$1" model="$2" label="$3"
  local worker_log="$LOG_DIR/worker_${worker_id}_${label}.log"
  local processed=0 skipped=0

  echo "[worker $worker_id] started  model=$model" | tee "$worker_log"

  while true; do
    if [[ "$PER_WORKER_LIMIT" -gt 0 && "$processed" -ge "$PER_WORKER_LIMIT" ]]; then
      break
    fi

    local pdf
    pdf="$("$PYTHON_BIN" "$QH" pop "$QUEUE_FILE")"
    [[ -z "$pdf" ]] && break

    local record_id; record_id="$(hash_path "$pdf")"
    local raw_path="$RAW_DIR/$record_id.raw.txt"
    local log_path="$LOG_DIR/$record_id.log"
    local prompt_path="$PROMPT_DIR/$record_id.prompt.txt"
    local text_path="$TEXT_DIR/$record_id.txt"
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

    if [[ "$MODE" == "text-only" ]]; then
      if ! extract_pdf_text "$pdf" "$text_path" >> "$log_path" 2>&1; then
        "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$model" "pdf_text_extract" "1" "local_text_extract_failed" "$log_path"
        echo "[worker $worker_id]   FAIL text_extract" | tee -a "$worker_log"
        notify_failure "$worker_id" "$label" "$basename_pdf" "本地PDF文本抽取失败"
        continue
      fi

      {
        echo "你不需要也不要调用 PDF 工具；以下已经是从 PDF 本地抽取出的文本。"
        echo "请只依据这份文本提取结构化 JSON。"
        echo "PDF路径：$pdf"
        echo
        echo "----- PDF_TEXT_BEGIN -----"
        cat "$text_path"
        echo "----- PDF_TEXT_END -----"
        echo
        echo "【重要约束】不要使用任何工具，不要写文件，不要创建文件。你必须直接在回复中输出完整 JSON 字符串。回复以 { 开头，以 } 结尾。"
        echo
        echo "请严格遵循下面的项目提示词。最终只输出一个 JSON 对象。"; echo
        cat "$PROMPT_FILE"
        echo
        echo "【再次提醒】不要使用工具写文件。直接输出 JSON，不要用代码块包裹。"
      } > "$prompt_path"
    else
      local cache_path
      cache_path="$(visual_cache_path "$pdf")"
      if [[ "$FORCE" -eq 1 || ! -s "$cache_path" ]] || ! is_valid_visual_cache "$cache_path" >> "$log_path" 2>&1; then
        echo "[worker $worker_id]   preprocess visual cache" | tee -a "$worker_log"
        if ! "$PYTHON_BIN" "$REPO_DIR/scripts/preprocess.py" "$pdf" \
            --max-workers "$PREPROCESS_WORKERS" \
            -o "$cache_path" >> "$log_path" 2>&1; then
          "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
            "$(timestamp)" "$pdf" "$record_id" "$model" "preprocess" "1" "visual_preprocess_failed" "$log_path"
          echo "[worker $worker_id]   FAIL preprocess" | tee -a "$worker_log"
          notify_failure "$worker_id" "$label" "$basename_pdf" "视觉预处理失败"
          continue
        fi
      fi

      if ! compose_multimodal_context "$pdf" "$cache_path" "$text_path" >> "$log_path" 2>&1; then
        "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$model" "compose_context" "1" "multimodal_context_failed" "$log_path"
        echo "[worker $worker_id]   FAIL compose_context" | tee -a "$worker_log"
        notify_failure "$worker_id" "$label" "$basename_pdf" "多模态上下文合并失败"
        continue
      fi

      {
        echo "以下内容来自同一篇 PDF 的多模态预处理结果：文本页来自本地 PDF 文本层，数据页/图表页来自视觉模型读取后的 Markdown 缓存。"
        echo "请不要重新调用 PDF 工具；请依据下面的多模态合并上下文提取结构化 JSON。"
        echo "$pdf"
        echo
        echo "----- MULTIMODAL_CONTEXT_BEGIN -----"
        cat "$text_path"
        echo "----- MULTIMODAL_CONTEXT_END -----"
        echo
        echo "图表、表格、公式、流程图、化学结构式和页面布局中包含的信息已经在 [Page N - visual] 段落中转写；这些信息必须纳入判断。"
        echo
        echo "【重要约束】不要使用任何工具，不要写文件，不要创建文件。你必须直接在回复中输出完整 JSON 字符串。回复以 { 开头，以 } 结尾。"
        echo
        echo "请严格遵循下面的项目提示词。最终只输出一个 JSON 对象。"; echo
        cat "$PROMPT_FILE"
        echo
        echo "【再次提醒】不要使用工具写文件。直接输出 JSON，不要用代码块包裹。"
      } > "$prompt_path"
    fi

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
         "$PYTHON_BIN" -c "import json,sys; json.load(open(sys.argv[1]))" "$json_path" 2>/dev/null; then
        end_ts="$(date +%s)"; elapsed_s=$((end_ts-start_ts))
        "$PYTHON_BIN" "$QH" append "$SUCCESS_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$model" "$json_path" "$raw_path" "$elapsed_s"
        echo "[worker $worker_id]   OK ${elapsed_s}s" | tee -a "$worker_log"
      else
        end_ts="$(date +%s)"; elapsed_s=$((end_ts-start_ts))
        "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$model" "json_extract" "1" "no_valid_json" "$log_path"
        echo "[worker $worker_id]   FAIL json ${elapsed_s}s" | tee -a "$worker_log"
        notify_failure "$worker_id" "$label" "$basename_pdf" "JSON提取失败"
      fi
    else
      local exit_code=$?
      end_ts="$(date +%s)"; elapsed_s=$((end_ts-start_ts))
      "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
        "$(timestamp)" "$pdf" "$record_id" "$model" "openclaw_agent" "$exit_code" "timeout_or_error" "$log_path"
      echo "[worker $worker_id]   FAIL exit=$exit_code ${elapsed_s}s" | tee -a "$worker_log"
      notify_failure "$worker_id" "$label" "$basename_pdf" "openclaw超时或错误(exit=$exit_code)"
    fi
    sleep "$SLEEP_SECONDS"
  done

  echo "[worker $worker_id] done  processed=$processed  skipped=$skipped" | tee -a "$worker_log"
}

# ── heartbeat: hourly iMessage status report ────────────────────────
heartbeat_loop() {
  local run_start_iso; run_start_iso="$(timestamp)"
  local last_report_iso="$run_start_iso"

  while true; do
    # Sleep until the next hour mark (or 60s if already past)
    local now_s; now_s="$(date +%s)"
    local next_hour_s=$(( (now_s / 3600 + 1) * 3600 ))
    local sleep_s=$(( next_hour_s - now_s ))
    [[ "$sleep_s" -lt 5 ]] && sleep_s=3600
    sleep "$sleep_s"

    local report_ts; report_ts="$(date '+%Y-%m-%d %H:%M')"
    local now_iso; now_iso="$(timestamp)"

    # Count totals from TSVs
    local total_success total_failure recent_success recent_failure
    total_success=$(awk -F'\t' 'NR>1' "$SUCCESS_TSV" 2>/dev/null | wc -l | tr -d ' ')
    total_failure=$(awk -F'\t' 'NR>1' "$FAILURES_TSV" 2>/dev/null | wc -l | tr -d ' ')

    # Recent = entries with ISO timestamp >= last_report_iso
    recent_success=$(awk -F'\t' -v cutoff="$last_report_iso" 'NR>1 && $1 >= cutoff' "$SUCCESS_TSV" 2>/dev/null | wc -l | tr -d ' ')
    recent_failure=$(awk -F'\t' -v cutoff="$last_report_iso" 'NR>1 && $1 >= cutoff' "$FAILURES_TSV" 2>/dev/null | wc -l | tr -d ' ')

    # Remaining queue
    local remaining=0
    [[ -f "$QUEUE_FILE" ]] && remaining=$(wc -l < "$QUEUE_FILE" | tr -d ' ')

    # Recent error reasons (last hour, max 3)
    local recent_errors=""
    if [[ -f "$FAILURES_TSV" ]]; then
      recent_errors=$(awk -F'\t' -v cutoff="$last_report_iso" 'NR>1 && $1 >= cutoff {print $7}' "$FAILURES_TSV" 2>/dev/null | sort | uniq -c | sort -rn | head -3)
    fi

    # Worker status (check if PIDs are alive)
    local worker_status=""
    for i in "${!MODELS[@]}"; do
      local pid_file="$PID_DIR/worker_$((i+1)).pid"
      local pid_val; [[ -f "$pid_file" ]] && pid_val="$(cat "$pid_file")"
      if [[ -n "$pid_val" ]] && kill -0 "$pid_val" 2>/dev/null; then
        worker_status+="  ✅ W$((i+1)) ${MODEL_LABELS[$i]} (PID $pid_val)\n"
      else
        worker_status+="  ⏹ W$((i+1)) ${MODEL_LABELS[$i]} (已结束)\n"
      fi
    done

    local msg="📊 提参心跳汇报 [$report_ts]
Workers:
${worker_status}
近1小时进展:
  成功: ${recent_success} 篇
  失败: ${recent_failure} 篇
累计:
  成功: ${total_success} 篇
  失败: ${total_failure} 篇
剩余队列: ${remaining} 篇"

    if [[ -n "$recent_errors" ]]; then
      msg+="
近1小时错误:
${recent_errors}"
    fi

    notify_imsg "$msg"
    last_report_iso="$now_iso"
    echo "[heartbeat] report sent at $report_ts  success=$total_success failure=$total_failure remaining=$remaining" | tee -a "$LOG_DIR/heartbeat.log"
  done
}

# ── launch with auto-restart watchdog ─────────────────────────────
echo "Launching ${#MODELS[@]} workers + heartbeat..."
launch_worker() {
  local i="$1"
  worker "$((i+1))" "${MODELS[$i]}" "${MODEL_LABELS[$i]}" &
  echo $! > "$PID_DIR/worker_$((i+1)).pid"
  echo "  Worker $((i+1)): PID $!  ${MODELS[$i]}"
}
for i in "${!MODELS[@]}"; do
  launch_worker "$i"
done
heartbeat_loop &
HEARTBEAT_PID=$!
echo $HEARTBEAT_PID > "$PID_DIR/heartbeat.pid"
echo "  Heartbeat: PID $HEARTBEAT_PID (hourly iMessage reports)"
echo $$ > "$PID_DIR/launcher.pid"
echo ""; echo "Running. Queue: $QUEUE_FILE"; echo ""

# ── watchdog: restart crashed workers ─────────────────────────────
while true; do
  sleep 30
  all_done=true
  for i in "${!MODELS[@]}"; do
    pid_file="$PID_DIR/worker_$((i+1)).pid"
    [[ -f "$pid_file" ]] && pid="$(cat "$pid_file")" || pid=""
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      echo "[watchdog] Worker $((i+1)) (PID $pid) crashed, restarting..."
      launch_worker "$i"
    fi
    # Check if queue still has items
    qh_result="$("$PYTHON_BIN" "$QH" pop "$QUEUE_FILE" 2>/dev/null)"
    if [[ -n "$qh_result" ]]; then
      # Put it back
      "$PYTHON_BIN" "$QH" append "$QUEUE_FILE" "$qh_result" 2>/dev/null || true
      all_done=false
    fi
  done
  # If all workers done and queue empty, exit watchdog
  if $all_done; then
    any_running=false
    for i in "${!MODELS[@]}"; do
      pid_file="$PID_DIR/worker_$((i+1)).pid"
      [[ -f "$pid_file" ]] && pid="$(cat "$pid_file")" || pid=""
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        any_running=true
        break
      fi
    done
    if ! $any_running; then
      break
    fi
  fi
done

# Kill heartbeat after all workers finish
kill $HEARTBEAT_PID 2>/dev/null || true
echo "[heartbeat] stopped (all workers done)" | tee -a "$LOG_DIR/heartbeat.log"

success_count=$(( $(wc -l < "$SUCCESS_TSV" | tr -d ' ') - 1 ))
failure_count=$(( $(wc -l < "$FAILURES_TSV" | tr -d ' ') - 1 ))
[[ "$success_count" -lt 0 ]] && success_count=0
[[ "$failure_count" -lt 0 ]] && failure_count=0

echo ""; echo "=== Complete ==="
echo "Success: $success_count  Failed: $failure_count"

if "$PYTHON_BIN" "$REPO_DIR/scripts/merge_results.py" >> "$RUN_DIR/merge.log" 2>&1 && \
   "$PYTHON_BIN" "$REPO_DIR/scripts/update_extraction_progress_doc.py" >> "$RUN_DIR/merge.log" 2>&1; then
  echo "Unified manifests updated: $OUT_DIR/manifests"
else
  echo "WARN: failed to refresh unified manifests; check $RUN_DIR/merge.log" >&2
fi

notify_imsg "✅ 提参批次完成
成功: $success_count
失败: $failure_count
结果: $OUT_DIR"

"$PYTHON_BIN" -c "
import json
p = {'status':'completed','processed':$((success_count+failure_count)),'success':$success_count,'failed':$failure_count,'remaining':0,'updated_at':'$(date '+%Y-%m-%d %H:%M:%S')'}
with open('/tmp/openclaw/extraction_progress.json','w') as f: json.dump(p,f,indent=2)
"
