#!/usr/bin/env bash
# Batch PDF extraction runner for the JJJ offshore oil/gas pollution project.
#
# It scans a PDF folder, calls `openclaw agent` once per PDF, saves raw output,
# extracts the first valid JSON object, records logs, and supports resume.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_PROMPT_FILE="$REPO_DIR/prompts/jjj_single_agent_extraction_prompt.md"
DEFAULT_OUT_DIR="$REPO_DIR/outputs/litextract_batch"

load_dotenv() {
  local env_file="$1"
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* || "$line" != *=* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    export "$key=$value"
  done < "$env_file"
}

timestamp() {
  python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"))
PY
}

hash_path() {
  local value="$1"
  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$value" | sha1sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$value" | shasum -a 1 | awk '{print $1}'
  else
    python3 - "$value" <<'PY'
import hashlib
import sys
print(hashlib.sha1(sys.argv[1].encode("utf-8")).hexdigest())
PY
  fi
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_seconds" "$@"
  else
    python3 - "$timeout_seconds" "$@" <<'PY'
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
cmd = sys.argv[2:]
try:
    completed = subprocess.run(cmd, timeout=timeout_seconds)
except subprocess.TimeoutExpired:
    sys.exit(124)
sys.exit(completed.returncode)
PY
  fi
}

if [[ -f "$REPO_DIR/.env" ]]; then
  load_dotenv "$REPO_DIR/.env"
fi

export OPENCLAW_CONFIG_PATH="$REPO_DIR/openclaw.json"

PDF_DIR=""
OUT_DIR="$DEFAULT_OUT_DIR"
PROMPT_FILE="$DEFAULT_PROMPT_FILE"
LIMIT=0
TIMEOUT_SECONDS=1800
SLEEP_SECONDS=2
RUN_PREPROCESS=0
MAX_WORKERS=4
MODEL_OVERRIDE=""
FORCE=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/batch_extract_pdfs.sh --pdf-dir <PDF_DIR> [options]

Required:
  --pdf-dir DIR              Folder containing PDF files.

Options:
  --out-dir DIR              Output folder. Default: outputs/litextract_batch
  --prompt-file FILE         Prompt file. Default: prompts/jjj_single_agent_extraction_prompt.md
  --limit N                  Process only first N PDFs. Use 20-50 for pilot runs.
  --timeout-seconds N        Timeout per PDF. Default: 1800
  --sleep-seconds N          Pause between PDFs. Default: 2
  --preprocess               Run scripts/preprocess.py before extraction.
  --max-workers N            Visual preprocessing workers. Default: 4
  --model MODEL              Model override, e.g. bailian/qwen3.6-plus or mimo/mimo-v2.5-pro.
  --force                    Re-run even when a valid JSON already exists.
  --dry-run                  Only list PDFs and planned outputs.
  -h, --help                 Show this help.

Environment:
  BAILIAN_CODING_PLAN_API_KEY          Required for Bailian/Qwen models.
  MIMO_API_KEY                         Required when using the Mimo provider.

Outputs:
  json/                      Parsed JSON per PDF.
  raw/                       Raw OpenClaw stdout per PDF.
  logs/                      OpenClaw stderr and batch logs.
  prompts/                   Per-PDF prompt copies sent to OpenClaw.
  manifests/success.tsv      Successful extractions.
  manifests/failures.tsv     Failed extractions and reasons.
  manifests/pdf_list.txt     PDF list captured at run start.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf-dir)
      PDF_DIR="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --prompt-file)
      PROMPT_FILE="${2:-}"
      shift 2
      ;;
    --limit)
      LIMIT="${2:-0}"
      shift 2
      ;;
    --timeout-seconds)
      TIMEOUT_SECONDS="${2:-1800}"
      shift 2
      ;;
    --sleep-seconds)
      SLEEP_SECONDS="${2:-2}"
      shift 2
      ;;
    --preprocess)
      RUN_PREPROCESS=1
      shift
      ;;
    --max-workers)
      MAX_WORKERS="${2:-4}"
      shift 2
      ;;
    --model)
      MODEL_OVERRIDE="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PDF_DIR" ]]; then
  echo "ERROR: --pdf-dir is required." >&2
  usage >&2
  exit 2
fi

if [[ ! -d "$PDF_DIR" ]]; then
  echo "ERROR: PDF folder not found: $PDF_DIR" >&2
  exit 2
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: Prompt file not found: $PROMPT_FILE" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 0 ]] && ! command -v openclaw >/dev/null 2>&1; then
  echo "ERROR: openclaw command not found. Install with: npm install -g openclaw" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  missing_env=()
  for var_name in BAILIAN_CODING_PLAN_API_KEY MIMO_API_KEY; do
    var_value="${!var_name:-}"
    if [[ -z "$var_value" || "$var_value" == your_*_api_key_here ]]; then
      missing_env+=("$var_name")
    fi
  done
  if [[ "${#missing_env[@]}" -gt 0 ]]; then
    echo "ERROR: Missing required environment variable(s): ${missing_env[*]}" >&2
    echo "Create $REPO_DIR/.env or export the variables before running batch extraction." >&2
    exit 2
  fi
fi

if [[ "$RUN_PREPROCESS" -eq 1 ]] && [[ -z "${BAILIAN_CODING_PLAN_API_KEY:-}" ]]; then
  echo "ERROR: --preprocess requires BAILIAN_CODING_PLAN_API_KEY in the environment." >&2
  exit 2
fi

JSON_DIR="$OUT_DIR/json"
RAW_DIR="$OUT_DIR/raw"
LOG_DIR="$OUT_DIR/logs"
PROMPT_DIR="$OUT_DIR/prompts"
MANIFEST_DIR="$OUT_DIR/manifests"

mkdir -p "$JSON_DIR" "$RAW_DIR" "$LOG_DIR" "$PROMPT_DIR" "$MANIFEST_DIR"

SUCCESS_TSV="$MANIFEST_DIR/success.tsv"
FAILURES_TSV="$MANIFEST_DIR/failures.tsv"
PDF_LIST="$MANIFEST_DIR/pdf_list.txt"

if [[ ! -f "$SUCCESS_TSV" ]]; then
  printf 'timestamp\tpdf_path\trecord_id\tjson_path\traw_path\n' > "$SUCCESS_TSV"
fi

if [[ ! -f "$FAILURES_TSV" ]]; then
  printf 'timestamp\tpdf_path\tstage\texit_code\treason\traw_path\tlog_path\n' > "$FAILURES_TSV"
fi

make_record_id() {
  local pdf="$1"
  local base safe hash
  base="$(basename "$pdf")"
  base="${base%.*}"
  safe="$(printf '%s' "$base" | tr -cs '[:alnum:]_.-' '_' | sed 's/^_//; s/_$//' | cut -c1-80)"
  if [[ -z "$safe" ]]; then
    safe="paper"
  fi
  hash="$(hash_path "$pdf")"
  printf '%s_%s' "$safe" "${hash:0:10}"
}

is_valid_json() {
  local json_path="$1"
  python3 -m json.tool "$json_path" >/dev/null 2>&1
}

extract_first_json() {
  local raw_path="$1"
  local json_path="$2"
  python3 - "$raw_path" "$json_path" <<'PY'
import json
import re
import sys

raw_path, json_path = sys.argv[1], sys.argv[2]
text = open(raw_path, "r", encoding="utf-8", errors="replace").read()
text = re.sub(r"```json\s*", "", text)
text = re.sub(r"```\s*", "", text)
text = text.strip()


def fix_quotes(t):
    out, in_s, i = [], False, 0
    while i < len(t):
        c = t[i]
        if not in_s:
            out.append(c)
            if c == '"':
                in_s = True
            i += 1
            continue
        if c == '\\' and i + 1 < len(t):
            out.append(c)
            out.append(t[i + 1])
            i += 2
            continue
        if c == '"':
            rest = t[i + 1:].lstrip()
            if rest and rest[0] in ',:]} \n\r\t':
                out.append(c)
                in_s = False
            else:
                out.append('\\"')
            i += 1
            continue
        if c == '\n':
            out.append('\\n')
            i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def try_parse(t):
    for txt in [t, fix_quotes(t)]:
        start = txt.find('{')
        if start < 0:
            continue
        try:
            return json.loads(txt[start:])
        except json.JSONDecodeError:
            pass
        depth = 0
        in_string = False
        escape = False
        for i in range(start, len(txt)):
            c = txt[i]
            if escape:
                escape = False
                continue
            if c == '\\' and in_string:
                escape = True
                continue
            if c == '"':
                in_string = not in_string
                continue
            if in_string:
                continue
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    try:
                        return json.loads(txt[start:i + 1])
                    except json.JSONDecodeError:
                        break
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
    obj = reconstruct_from_parts(text)
    if obj is not None:
        print(f"reconstructed from parts: {len(obj.get('knowledge_items',[]))} ki", file=sys.stderr)

if obj is None:
    print("No valid JSON object found in raw output.", file=sys.stderr)
    sys.exit(1)

if "schema_version" not in obj and "knowledge_items" not in obj:
    print(f"Parsed JSON is not a full extraction schema: {list(obj)[:5]}", file=sys.stderr)
    sys.exit(1)

with open(json_path, "w", encoding="utf-8") as f:
    json.dump(obj, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(f"extracted_json_chars={len(json.dumps(obj, ensure_ascii=False))}")
sys.exit(0)
PY
}

write_failure() {
  local pdf="$1"
  local stage="$2"
  local exit_code="$3"
  local reason="$4"
  local raw_path="$5"
  local log_path="$6"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(timestamp)" "$pdf" "$stage" "$exit_code" "$reason" "$raw_path" "$log_path" >> "$FAILURES_TSV"
}

write_success() {
  local pdf="$1"
  local record_id="$2"
  local json_path="$3"
  local raw_path="$4"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(timestamp)" "$pdf" "$record_id" "$json_path" "$raw_path" >> "$SUCCESS_TSV"
}

: > "$PDF_LIST"
python3 - "$PDF_DIR" "$LIMIT" > "$PDF_LIST" <<'PY'
import os
import sys

root = sys.argv[1]
limit = int(sys.argv[2])
paths = []
for dirpath, _, filenames in os.walk(root):
    for filename in filenames:
        if filename.lower().endswith(".pdf"):
            paths.append(os.path.join(dirpath, filename))
for index, path in enumerate(sorted(paths), start=1):
    print(path)
    if limit > 0 and index >= limit:
        break
PY

TOTAL="$(wc -l < "$PDF_LIST" | tr -d ' ')"
echo "PDF folder: $PDF_DIR"
echo "Output folder: $OUT_DIR"
echo "Prompt file: $PROMPT_FILE"
echo "PDFs queued: $TOTAL"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "No PDF files found."
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  nl -ba "$PDF_LIST"
  exit 0
fi

index=0
while IFS= read -r pdf; do
  index=$((index + 1))
  record_id="$(make_record_id "$pdf")"
  json_path="$JSON_DIR/$record_id.json"
  raw_path="$RAW_DIR/$record_id.raw.txt"
  log_path="$LOG_DIR/$record_id.log"
  prompt_path="$PROMPT_DIR/$record_id.prompt.txt"

  echo "[$index/$TOTAL] $pdf"

  if [[ "$FORCE" -eq 0 && -s "$json_path" ]] && is_valid_json "$json_path"; then
    echo "  skip: valid JSON exists"
    continue
  fi

  {
    echo "请读取并提取以下 PDF："
    echo "$pdf"
    echo
    echo "请严格遵循下面的项目提示词。最终只输出一个 JSON 对象。"
    echo
    cat "$PROMPT_FILE"
  } > "$prompt_path"

  if [[ "$RUN_PREPROCESS" -eq 1 ]]; then
    echo "  preprocess"
    if python3 "$REPO_DIR/scripts/preprocess.py" "$pdf" --max-workers "$MAX_WORKERS" >> "$log_path" 2>&1; then
      :
    else
      exit_code="$?"
      write_failure "$pdf" "preprocess" "$exit_code" "preprocess_failed" "$raw_path" "$log_path"
      echo "  failed: preprocess"
      sleep "$SLEEP_SECONDS"
      continue
    fi
  fi

  echo "  openclaw agent"
  agent_cmd=(openclaw agent --local --agent lit-extract --timeout "$TIMEOUT_SECONDS")
  if [[ -n "$MODEL_OVERRIDE" ]]; then
    agent_cmd+=(--model "$MODEL_OVERRIDE")
  fi
  agent_cmd+=(--message "$(cat "$prompt_path")")

  if (cd "$REPO_DIR" && run_with_timeout "$TIMEOUT_SECONDS" "${agent_cmd[@]}" > "$raw_path" 2>> "$log_path"); then
    if extract_first_json "$raw_path" "$json_path" >> "$log_path" 2>&1 && is_valid_json "$json_path"; then
      write_success "$pdf" "$record_id" "$json_path" "$raw_path"
      echo "  ok: $json_path"
    else
      write_failure "$pdf" "json_extract" "1" "no_valid_json_in_raw_output" "$raw_path" "$log_path"
      echo "  failed: JSON parse"
    fi
  else
    exit_code="$?"
    write_failure "$pdf" "openclaw_agent" "$exit_code" "openclaw_or_timeout_failed" "$raw_path" "$log_path"
    echo "  failed: openclaw exit $exit_code"
  fi

  sleep "$SLEEP_SECONDS"
done < "$PDF_LIST"

echo "Done."
echo "Success manifest: $SUCCESS_TSV"
echo "Failure manifest: $FAILURES_TSV"
