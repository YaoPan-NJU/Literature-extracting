#!/usr/bin/env bash
# Retry failed extractions with swapped models
# mimo failures → bailian, bailian failures → mimo

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/single_worker_extract.sh"
QUEUE_HELPER="$REPO_DIR/scripts/queue_helper.py"
PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv/bin/python}"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

OUT_DIR="/Users/panyao/Qoder/JJJ_Literature/outputs/extractions"
PDF_DIR="/Users/panyao/Qoder/JJJ_Literature/workspace/近海油气田污染物相关文献"

RUN_ID="retry_$(date +%Y%m%d_%H%M%S)"
RUN_DIR="/tmp/openclaw/litextract_runs/$RUN_ID"
mkdir -p "$RUN_DIR"/{logs,raw,text,prompts,json,manifests}

# Source .env
if [[ -f "$REPO_DIR/.env" ]]; then
  set -a; source "$REPO_DIR/.env"; set +a
fi

echo "============================================================"
echo "失败重试 - 模型互换"
echo "============================================================"
echo "Run ID: $RUN_ID"
echo "Run Dir: $RUN_DIR"
echo ""

# Collect all failures from recent runs, skip those already extracted
FAILURES_FILE="$RUN_DIR/all_failures.txt"
> "$FAILURES_FILE"

# Latest run failures
LATEST_RUN="/tmp/openclaw/litextract_runs/remaining_20260523_233941"
if [[ -f "$LATEST_RUN/manifests/failures.tsv" ]]; then
  echo "收集最新 run 失败记录..."
  tail -n +2 "$LATEST_RUN/manifests/failures.tsv" | cut -f2 >> "$FAILURES_FILE"
fi

# Old run failures
OLD_RUN="/tmp/openclaw/litextract_runs/20260519130304-32266"
if [[ -f "$OLD_RUN/manifests/failures.tsv" ]]; then
  echo "收集旧 run 失败记录..."
  tail -n +2 "$OLD_RUN/manifests/failures.tsv" | cut -f2 >> "$FAILURES_FILE"
fi

# Deduplicate
sort -u "$FAILURES_FILE" -o "$FAILURES_FILE"

# Filter out already extracted
echo "检查已提取结果，跳过已成功的..."
FILTERED_FILE="$RUN_DIR/failures_filtered.txt"
> "$FILTERED_FILE"
while IFS= read -r pdf_path; do
  [[ -z "$pdf_path" ]] && continue
  base=$(basename "$pdf_path" .pdf)
  # Search for matching JSON in all extraction dirs
  found=$(find "$OUT_DIR" -name "${base}*.json" -type f 2>/dev/null | head -1)
  if [[ -n "$found" ]]; then
    echo "跳过（已有结果）: $base"
  else
    echo "$pdf_path" >> "$FILTERED_FILE"
  fi
done < "$FAILURES_FILE"
mv "$FILTERED_FILE" "$FAILURES_FILE"

TOTAL=$(wc -l < "$FAILURES_FILE" | tr -d ' ')
echo "共 $TOTAL 个失败文件待重试"
echo ""

# For each failure, determine original model and assign swapped model
RETRY_QUEUE="$RUN_DIR/queue.txt"
> "$RETRY_QUEUE"

while IFS= read -r pdf_path; do
  [[ -z "$pdf_path" ]] && continue
  
  # Check if file exists
  if [[ ! -f "$pdf_path" ]]; then
    echo "跳过（文件不存在）: $pdf_path"
    continue
  fi
  
  # Determine original model from failure records
  orig_model=""
  if [[ -f "$LATEST_RUN/manifests/failures.tsv" ]]; then
    orig_model=$(grep "$pdf_path" "$LATEST_RUN/manifests/failures.tsv" | cut -f4 | head -1)
  fi
  if [[ -z "$orig_model" && -f "$OLD_RUN/manifests/failures.tsv" ]]; then
    orig_model=$(grep "$pdf_path" "$OLD_RUN/manifests/failures.tsv" | cut -f4 | head -1)
  fi
  
  # Swap model
  if [[ "$orig_model" == mimo/* ]]; then
    new_model="bailian/qwen3.6-plus"
  elif [[ "$orig_model" == bailian/* ]]; then
    new_model="mimo/mimo-v2.5-pro"
  else
    # Default to bailian if can't determine
    new_model="bailian/qwen3.6-plus"
  fi
  
  echo "$pdf_path	$new_model" >> "$RETRY_QUEUE"
done < "$FAILURES_FILE"

RETRY_COUNT=$(wc -l < "$RETRY_QUEUE" | tr -d ' ')
echo ""
echo "============================================================"
echo "准备重试 $RETRY_COUNT 个文件"
echo "============================================================"
cat "$RETRY_QUEUE" | while IFS=$'\t' read -r pdf model; do
  echo "  $(basename "$pdf") → $model"
done
echo ""

if [[ "$RETRY_COUNT" -eq 0 ]]; then
  echo "没有可重试的文件，退出"
  exit 0
fi

# Launch workers - one for each model type
echo "启动 worker..."

# Group by model
BAILIAN_QUEUE="$RUN_DIR/queue_bailian.txt"
MIMO_QUEUE="$RUN_DIR/queue_mimo.txt"
> "$BAILIAN_QUEUE"
> "$MIMO_QUEUE"

while IFS=$'\t' read -r pdf model; do
  if [[ "$model" == bailian/* ]]; then
    echo "$pdf" >> "$BAILIAN_QUEUE"
  else
    echo "$pdf" >> "$MIMO_QUEUE"
  fi
done < "$RETRY_QUEUE"

PIDS=()

# Launch bailian worker if needed
BAILIAN_COUNT=$(wc -l < "$BAILIAN_QUEUE" | tr -d ' ')
if [[ "$BAILIAN_COUNT" -gt 0 ]]; then
  echo "启动 bailian worker ($BAILIAN_COUNT 个文件)..."
  bash "$SCRIPT" "retry-bailian" "bailian/qwen3.6-plus" "retry-bailian" "$RUN_ID" "$BAILIAN_QUEUE" "$RUN_DIR" "$PDF_DIR" "$OUT_DIR" &
  PIDS+=($!)
fi

# Launch mimo worker if needed
MIMO_COUNT=$(wc -l < "$MIMO_QUEUE" | tr -d ' ')
if [[ "$MIMO_COUNT" -gt 0 ]]; then
  echo "启动 mimo worker ($MIMO_COUNT 个文件)..."
  bash "$SCRIPT" "retry-mimo" "mimo/mimo-v2.5-pro" "retry-mimo" "$RUN_ID" "$MIMO_QUEUE" "$RUN_DIR" "$PDF_DIR" "$OUT_DIR" &
  PIDS+=($!)
fi

echo ""
echo "Worker PIDs: ${PIDS[*]}"
echo "监控日志: tail -f $RUN_DIR/logs/*.log"
echo ""

# Wait for all workers
for pid in "${PIDS[@]}"; do
  wait "$pid" 2>/dev/null || true
done

echo ""
echo "============================================================"
echo "重试完成！"
echo "============================================================"
echo "成功: $(wc -l < "$RUN_DIR/manifests/success.tsv" 2>/dev/null | tr -d ' ')"
echo "失败: $(tail -n +2 "$RUN_DIR/manifests/failures.tsv" 2>/dev/null | wc -l | tr -d ' ')"
echo "结果目录: $RUN_DIR"
