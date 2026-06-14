#!/usr/bin/env bash
# Single worker extraction script - launched as a separate process (no fork).
# Usage: bash single_worker_extract.sh <worker_id> <model> <label> <run_id> <queue_file> <run_dir> <pdf_dir> <out_dir>

set -u

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

WORKER_ID="${1:?}"
MODEL="${2:?}"
LABEL="${3:?}"
RUN_ID="${4:?}"
QUEUE_FILE="${5:?}"
RUN_DIR="${6:?}"
PDF_DIR="${7:-}"
OUT_DIR="${8:?}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QH="$REPO_DIR/scripts/queue_helper.py"
PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv/bin/python}"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

PROMPT_FILE="$REPO_DIR/prompts/jjj_single_agent_extraction_prompt.md"
LOG_DIR="$RUN_DIR/logs"
RAW_DIR="$RUN_DIR/raw"
TEXT_DIR="$RUN_DIR/text"
PROMPT_DIR="$RUN_DIR/prompts"
RUN_JSON_DIR="$RUN_DIR/json"
STATUS_DIR="/tmp/openclaw/worker_status"
SUCCESS_TSV="$RUN_DIR/manifests/success.tsv"
FAILURES_TSV="$RUN_DIR/manifests/failures.tsv"
TIMING_TSV="$RUN_DIR/manifests/timing.tsv"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"
PREPROCESS_WORKERS="${PREPROCESS_WORKERS:-2}"
PREPROCESS_RETRY_ATTEMPTS="${PREPROCESS_RETRY_ATTEMPTS:-6}"
PREPROCESS_RETRY_DELAY="${PREPROCESS_RETRY_DELAY:-30}"
PREPROCESS_MAX_VISUAL_PAGES="${PREPROCESS_MAX_VISUAL_PAGES:-0}"
PREPROCESS_TIMEOUT_SECONDS="${PREPROCESS_TIMEOUT_SECONDS:-1800}"
FORCE="${FORCE:-0}"
MIN_FREE_GB="${MIN_FREE_GB:-10}"

# Source helpers
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
    "$PYTHON_BIN" - "$json_file" <<'PY' 2>/dev/null
import json, re, sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
d = json.loads(text)
assert "schema_version" in d or "knowledge_items" in d
assert d.get("knowledge_items"), "empty knowledge_items"
bad_markers = [
    "多模态预处理未提取到任何页面内容",
    "多模态预处理未提取到任何内容",
    "无法判断文献具体内容和价值",
    "Total pages: ?",
    "Total pages 显示为 '?'",
    "无视觉页缓存",
    "Multimodal pre-processing extracted zero content",
    "MULTIMODAL_CONTEXT_BLOCK为空",
    "Total pages displayed as",
    "zero pages of content",
    "强烈建议重新运行视觉预处理",
    "重新运行视觉预处理",
    "视觉预处理失败",
    "OCR失败",
    "正文不可读",
]
assert not any(marker in text for marker in bad_markers)
bad_patterns = [
    r"当前仅第\s*\d+\s*页.*被加载",
    r"正文\s*\d+\s*页完全缺失",
    r"正文.*完全缺失",
    r"视觉页.*缺失",
    r"多模态.*缺失",
]
assert not any(re.search(pattern, text) for pattern in bad_patterns)
PY
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
    *) echo "" ;;
  esac
}

visual_cache_path() {
  local pdf="$1"
  echo "${pdf%.[Pp][Dd][Ff]}_visual_cache.json"
}

is_valid_visual_cache() {
  local cache="$1"
  [[ -s "$cache" ]] && \
    "$PYTHON_BIN" - "$cache" <<'PY' 2>/dev/null
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    d = json.load(f)
stage0 = d["stage0"]
visual = d.get("visual_markdown", {})
data_pages = [str(p) for p in stage0.get("data_page_nums", [])]
missing = [p for p in data_pages if not str(visual.get(p, "")).strip()]
if missing:
    raise ValueError(f"missing visual pages: {missing[:5]}")
text_chars = sum(len(str(p.get("text", "")).strip()) for p in stage0.get("pages_text", []))
visual_chars = sum(len(str(v).strip()) for v in visual.values())
total_pages = int(stage0.get("total_pages") or len(stage0.get("pages_text", [])) or 0)
if total_pages >= 20 and text_chars / max(1, total_pages) < 30 and not data_pages:
    raise ValueError("sparse long document has no visual pages")
if text_chars + visual_chars < 100:
    raise ValueError("visual cache has no usable text or visual content")
PY
}

compose_multimodal_context() {
  local pdf="$1" cache="$2" text_path="$3"
  "$PYTHON_BIN" - "$pdf" "$cache" "$text_path" <<'PYEOF'
import json, sys
from pathlib import Path

pdf = Path(sys.argv[1])
cache = Path(sys.argv[2])
text_path = Path(sys.argv[3])

with cache.open(encoding="utf-8") as f:
    data = json.load(f)

stage0 = data["stage0"]
visual = {str(k): v for k, v in data.get("visual_markdown", {}).items()}
page_types = {
    int(p["page"]): p.get("type", "text_page")
    for p in stage0.get("page_types", [])
}
pages_text = {
    int(p["page"]): p.get("text", "")
    for p in stage0.get("pages_text", [])
}
total_pages = int(stage0.get("total_pages") or len(pages_text))
content_chars = 0

with text_path.open("w", encoding="utf-8") as out:
    out.write("PDF file: " + str(pdf) + "\n")
    out.write("Multimodal source: local text anchors + visual page cache\n\n")
    out.write("## Hard metadata anchors\n")
    out.write(f"- Title: {stage0.get('anchor_title') or ''}\n")
    out.write(f"- DOI: {stage0.get('anchor_doi') or ''}\n")
    keywords = stage0.get("anchor_keywords") or []
    out.write("- Keywords: " + ", ".join(str(k) for k in keywords) + "\n")
    out.write(f"- Total pages: {total_pages}\n")
    out.write("- Data pages read visually: " + ", ".join(str(p) for p in stage0.get("data_page_nums", [])) + "\n\n")
    selection = stage0.get("visual_page_selection") or {}
    if selection:
        out.write(
            "- Visual page selection: "
            + f"{selection.get('selected_data_pages')} selected from "
            + f"{selection.get('original_data_pages')} candidate pages; "
            + f"strategy={selection.get('strategy')}\n\n"
        )
    out.write("## Page content\n")

    for page_no in range(1, total_pages + 1):
        page_type = page_types.get(page_no, "text_page")
        if page_type == "skip_page":
            continue
        if page_type == "data_page" and str(page_no) in visual:
            content = visual[str(page_no)].strip()
            out.write(f"\n[Page {page_no} - visual]\n")
            out.write(content)
            out.write("\n")
        else:
            content = pages_text.get(page_no, "").strip()
            if not content:
                continue
            label = "text"
            if page_type == "data_page":
                label = "text fallback; visual cache missing"
            out.write(f"\n[Page {page_no} - {label}]\n")
            out.write(content)
            out.write("\n")
        content_chars += len(content)

if content_chars < 100:
    print(f"multimodal context too small: {content_chars} chars", file=sys.stderr)
    sys.exit(1)
PYEOF
}

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
                    except Exception: return None
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
                        except Exception: pass
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
    obj = reconstruct_from_parts(text)
    if obj is not None:
        print(f"reconstructed from parts: {len(obj.get('knowledge_items',[]))} ki", file=sys.stderr)
if obj is None:
    print("No valid JSON found", file=sys.stderr); sys.exit(1)
if not obj.get("knowledge_items"):
    print("No knowledge_items found", file=sys.stderr); sys.exit(1)
serialized = json.dumps(obj, ensure_ascii=False)
bad_markers = [
    "强烈建议重新运行视觉预处理",
    "重新运行视觉预处理",
    "视觉预处理失败",
    "OCR失败",
    "正文不可读",
]
bad_patterns = [
    r"当前仅第\s*\d+\s*页.*被加载",
    r"正文\s*\d+\s*页完全缺失",
    r"正文.*完全缺失",
    r"视觉页.*缺失",
    r"多模态.*缺失",
]
if any(marker in serialized for marker in bad_markers) or any(
    re.search(pattern, serialized) for pattern in bad_patterns
):
    print("Quality gate failed: visual preprocessing/body coverage warning", file=sys.stderr)
    sys.exit(1)
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(obj, f, ensure_ascii=False, indent=2); f.write("\n")
print(f"ok chars={len(json.dumps(obj))}")
PYEOF
}

quarantine_invalid_json() {
  local json_file="$1" record_id="$2"
  [[ -s "$json_file" ]] || return 0
  local reject_dir="$RUN_DIR/rejected_json"
  mkdir -p "$reject_dir"
  mv "$json_file" "$reject_dir/${record_id}.json" 2>/dev/null || true
}

run_with_timeout() {
  local timeout_seconds="$1"; shift
  "$@" &
  local pid=$!
  ( sleep "$timeout_seconds" && kill -9 $pid 2>/dev/null ) &
  local watchdog=$!
  wait $pid 2>/dev/null
  local rc=$?
  kill $watchdog 2>/dev/null; wait $watchdog 2>/dev/null
  return $rc
}

[[ -f "$REPO_DIR/.env" ]] && load_dotenv "$REPO_DIR/.env"
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$REPO_DIR/openclaw.json}"

free_gb() {
  df -Pk "$1" | awk 'NR==2 {print int($4/1024/1024)}'
}

disk_guard() {
  local free_repo free_tmp
  free_repo="$(free_gb "$REPO_DIR")"
  free_tmp="$(free_gb /tmp)"
  if [[ "$free_repo" -lt "$MIN_FREE_GB" || "$free_tmp" -lt "$MIN_FREE_GB" ]]; then
    echo "[worker $WORKER_ID] pause: low disk repo=${free_repo}GB /tmp=${free_tmp}GB threshold=${MIN_FREE_GB}GB" | tee -a "$worker_log"
    "$PYTHON_BIN" -c "
import json, pathlib, time
p = pathlib.Path('/tmp/openclaw/extraction_progress.json')
try:
    data = json.loads(p.read_text())
except Exception:
    data = {}
data.update({'status':'paused_low_disk','reason':'free disk below threshold','min_free_gb':$MIN_FREE_GB,'free_repo_gb':$free_repo,'free_tmp_gb':$free_tmp,'updated_at':time.strftime('%Y-%m-%d %H:%M:%S')})
p.write_text(json.dumps(data, ensure_ascii=False, indent=2))
"
    exit 75
  fi
}

write_worker_status() {
  local current_pdf="$1" record_id="$2" prompt_path="$3"
  mkdir -p "$STATUS_DIR"
  "$PYTHON_BIN" - "$STATUS_DIR/worker_${WORKER_ID}.json" "$REPO_DIR/openclaw.json" \
    "$WORKER_ID" "$LABEL" "$MODEL" "$current_pdf" "$record_id" "$prompt_path" "$RUN_ID" "$RUN_DIR" <<'PY'
import json
import math
import sys
import time
from pathlib import Path

status_path = Path(sys.argv[1])
config_path = Path(sys.argv[2])
worker_id, label, model, current_pdf, record_id, prompt_path, run_id, run_dir = sys.argv[3:11]

try:
    config = json.loads(config_path.read_text(encoding="utf-8"))
except Exception:
    config = {}

provider_name, _, model_id = model.partition("/")
provider = config.get("models", {}).get("providers", {}).get(provider_name, {})
model_cfg = {}
for item in provider.get("models", []):
    if item.get("id") == model_id or item.get("name") == model_id:
        model_cfg = item
        break

try:
    text = Path(prompt_path).read_text(encoding="utf-8", errors="ignore")
    ascii_chars = sum(1 for ch in text if ord(ch) < 128)
    non_ascii_chars = len(text) - ascii_chars
    input_tokens = int(math.ceil(ascii_chars / 4 + non_ascii_chars * 1.2))
except Exception:
    input_tokens = None

max_output = model_cfg.get("maxTokens")
status = {
    "worker_id": worker_id,
    "label": label,
    "model": model,
    "provider": provider_name,
    "api_base_url": provider.get("baseUrl"),
    "api_type": provider.get("api"),
    "current_pdf": Path(current_pdf).name,
    "record_id": record_id,
    "prompt_path": prompt_path,
    "run_id": run_id,
    "run_dir": run_dir,
    "estimated_input_tokens": input_tokens,
    "max_output_tokens": max_output,
    "estimated_total_tokens": input_tokens + max_output if input_tokens and max_output else None,
    "token_estimate_method": "ceil(ascii_chars/4 + non_ascii_chars*1.2) + max_output_tokens",
    "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
}
status_path.write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")
PY
}

worker_log="$LOG_DIR/worker_${WORKER_ID}_${LABEL}.log"
processed=0
skipped=0

echo "[worker $WORKER_ID] started  model=$MODEL" | tee "$worker_log"
echo "[worker $WORKER_ID] queue=$QUEUE_FILE" | tee -a "$worker_log"

while true; do
    disk_guard

    pdf="$("$PYTHON_BIN" "$QH" pop "$QUEUE_FILE")"
    if [[ -z "$pdf" ]]; then
      echo "[worker $WORKER_ID] queue empty or pop failed" | tee -a "$worker_log"
      break
    fi

    record_id="$(hash_path "$pdf")"
    raw_path="$RAW_DIR/$record_id.raw.txt"
    log_path="$LOG_DIR/$record_id.log"
    prompt_path="$PROMPT_DIR/$record_id.prompt.txt"
    text_path="$TEXT_DIR/$record_id.txt"
    basename_pdf="$(basename "$pdf")"

    unified_json_path_for_pdf="$(unified_json_path "$pdf")"
    json_path="$unified_json_path_for_pdf"
    [[ -z "$json_path" ]] && json_path="$RUN_JSON_DIR/$record_id.json"
    mkdir -p "$(dirname "$json_path")"

    if [[ "$FORCE" -eq 0 ]] && is_valid_extraction_json "$json_path"; then
      echo "[worker $WORKER_ID] skip: $basename_pdf" | tee -a "$worker_log"
      skipped=$((skipped+1)); continue
    fi

    processed=$((processed+1))
    echo "[worker $WORKER_ID] [$processed] $basename_pdf  ($LABEL)" | tee -a "$worker_log"

    cache_path="$(visual_cache_path "$pdf")"
    stage0_s=0; stage1_s=0; compose_s=0; data_pages=0; total_pages=0

    # ---- Fix: pre-clean stale worker session state for this worker label ----
    worker_session_glob="/Users/panyao/.openclaw/agents/lit-extract/sessions/multi-${RUN_ID}-w${WORKER_ID}-${LABEL}.*"
    # shellcheck disable=SC2086
    rm -f $worker_session_glob 2>> "$log_path" || true

    if [[ "$FORCE" -eq 1 || ! -s "$cache_path" ]] || ! is_valid_visual_cache "$cache_path" >> "$log_path" 2>&1; then
      echo "[worker $WORKER_ID]   preprocess visual cache" | tee -a "$worker_log"
      preprocess_provider="dashscope"
      case "$MODEL" in
        mimo/*|mimo2/*) preprocess_provider="mimo" ;;
      esac
      if ! PYTHONUNBUFFERED=1 run_with_timeout "$PREPROCESS_TIMEOUT_SECONDS" \
          "$PYTHON_BIN" "$REPO_DIR/scripts/preprocess.py" "$pdf" \
          --provider "$preprocess_provider" \
          --max-workers "$PREPROCESS_WORKERS" \
          --retry-attempts "$PREPROCESS_RETRY_ATTEMPTS" \
          --retry-delay "$PREPROCESS_RETRY_DELAY" \
          --max-visual-pages "$PREPROCESS_MAX_VISUAL_PAGES" \
          -o "$cache_path" >> "$log_path" 2>&1; then
        "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$MODEL" "preprocess" "1" "visual_preprocess_failed" "$log_path"
        echo "[worker $WORKER_ID]   FAIL preprocess" | tee -a "$worker_log"
        continue
      fi
    fi

    # Read timing JSON written by preprocess.py
    timing_json="${cache_path}.timing.json"
    if [[ -f "$timing_json" ]]; then
      timing_vals="$("$PYTHON_BIN" -c "
import json, sys
d = json.load(open(sys.argv[1]))
print(int(d.get('stage0_seconds',0)), int(d.get('stage1_seconds',0)), int(d.get('data_pages',0)), int(d.get('total_pages',0)))
" "$timing_json")"
      stage0_s="$(echo "$timing_vals" | cut -d' ' -f1)"
      stage1_s="$(echo "$timing_vals" | cut -d' ' -f2)"
      data_pages="$(echo "$timing_vals" | cut -d' ' -f3)"
      total_pages="$(echo "$timing_vals" | cut -d' ' -f4)"
    fi

    comp_start_ts="$(date +%s)"
    if ! compose_multimodal_context "$pdf" "$cache_path" "$text_path" >> "$log_path" 2>&1; then
      "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
        "$(timestamp)" "$pdf" "$record_id" "$MODEL" "compose_context" "1" "multimodal_context_failed" "$log_path"
      echo "[worker $WORKER_ID]   FAIL compose_context" | tee -a "$worker_log"
      continue
    fi
    comp_end_ts="$(date +%s)"
    compose_s=$((comp_end_ts - comp_start_ts))

    # ---- Fix: prompt size precheck to avoid context overflow ----
    text_chars="$(wc -c < "$text_path" | tr -d ' ')"
    max_context_chars="${MAX_CONTEXT_CHARS:-700000}"
    if [[ "$text_chars" -gt "$max_context_chars" ]]; then
      echo "[worker $WORKER_ID]   SKIP prompt_too_large chars=$text_chars limit=$max_context_chars" | tee -a "$worker_log"
      "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
        "$(timestamp)" "$pdf" "$record_id" "$MODEL" "precheck" "1" "prompt_too_large" "$log_path"
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
      echo "【重要约束】不要使用任何工具，不要写文件，不要创建文件。你必须直接在回复中输出完整 JSON 字符串。回复以 { 开头，以 } 结尾。"
      echo
      echo "请严格遵循下面的项目提示词。最终只输出一个 JSON 对象。"; echo
      cat "$PROMPT_FILE"
      echo
      echo "【再次提醒】不要使用工具写文件。直接输出 JSON，不要用代码块包裹。"
    } > "$prompt_path"
    write_worker_status "$pdf" "$record_id" "$prompt_path"

    start_ts="$(date +%s)"
    llm_s=0

    if { pushd "$REPO_DIR" > /dev/null && run_with_timeout "$TIMEOUT_SECONDS" \
        openclaw agent --local --agent lit-extract \
          --session-id "multi-${RUN_ID}-w${WORKER_ID}-${LABEL}" \
          --model "$MODEL" \
          --timeout "$TIMEOUT_SECONDS" \
          --message "$(cat "$prompt_path")" \
          > "$raw_path" 2>> "$log_path"; }; then
      popd > /dev/null 2>&1
      if extract_first_json "$raw_path" "$json_path" >> "$log_path" 2>&1 && \
         is_valid_extraction_json "$json_path"; then
        end_ts="$(date +%s)"; elapsed_s=$((end_ts-start_ts))
        llm_s=$elapsed_s
        "$PYTHON_BIN" "$QH" append "$SUCCESS_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$MODEL" "$json_path" "$raw_path" "$elapsed_s"
        # Write timing breakdown
        total_s=$((stage0_s + stage1_s + compose_s + llm_s))
        "$PYTHON_BIN" "$QH" append "$TIMING_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$MODEL" "$stage0_s" "$stage1_s" "$compose_s" "$llm_s" "$total_s" "$data_pages" "$total_pages"
        echo "[worker $WORKER_ID]   OK ${elapsed_s}s  [stage0=${stage0_s}s stage1=${stage1_s}s compose=${compose_s}s llm=${llm_s}s total=${total_s}s]" | tee -a "$worker_log"
      else
        end_ts="$(date +%s)"; elapsed_s=$((end_ts-start_ts))
        quarantine_invalid_json "$json_path" "$record_id"
        "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
          "$(timestamp)" "$pdf" "$record_id" "$MODEL" "json_extract" "1" "no_valid_json" "$log_path"
        echo "[worker $WORKER_ID]   FAIL json ${elapsed_s}s" | tee -a "$worker_log"
      fi
    else
      exit_code=$?
      popd > /dev/null 2>&1
      end_ts="$(date +%s)"; elapsed_s=$((end_ts-start_ts))
      "$PYTHON_BIN" "$QH" append "$FAILURES_TSV" \
        "$(timestamp)" "$pdf" "$record_id" "$MODEL" "openclaw_agent" "$exit_code" "timeout_or_error" "$log_path"
      echo "[worker $WORKER_ID]   FAIL exit=$exit_code ${elapsed_s}s" | tee -a "$worker_log"
    fi
    sleep "$SLEEP_SECONDS"
done

echo "[worker $WORKER_ID] done  processed=$processed  skipped=$skipped" | tee -a "$worker_log"
