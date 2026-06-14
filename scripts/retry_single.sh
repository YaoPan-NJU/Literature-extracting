#!/usr/bin/env bash
# Retry a single failed PDF with a different model
# Usage: bash retry_single.sh <pdf_path> <model>

set -euo pipefail

PDF_PATH="${1:?需要提供 PDF 路径}"
MODEL="${2:?需要提供模型名称}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/single_worker_extract.sh"
OUT_DIR="/Users/panyao/Qoder/JJJ_Literature/outputs/extractions"
PDF_DIR="/Users/panyao/Qoder/JJJ_Literature/workspace/近海油气田污染物相关文献"

# Source .env
if [[ -f "$REPO_DIR/.env" ]]; then
  set -a; source "$REPO_DIR/.env"; set +a
fi

RUN_ID="single_retry_$(date +%Y%m%d_%H%M%S)"
RUN_DIR="/tmp/openclaw/litextract_runs/$RUN_ID"
mkdir -p "$RUN_DIR"/{logs,raw,text,prompts,json,manifests}

# Create queue with single item
QUEUE_FILE="$RUN_DIR/queue.txt"
echo "$PDF_PATH" > "$QUEUE_FILE"

echo "============================================================"
echo "单文件重试"
echo "============================================================"
echo "PDF: $(basename "$PDF_PATH")"
echo "模型: $MODEL"
echo "Run ID: $RUN_ID"
echo ""

# Run the worker
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export TIMEOUT_SECONDS=1800

bash "$SCRIPT" "single" "$MODEL" "single" "$RUN_ID" "$QUEUE_FILE" "$RUN_DIR" "$PDF_DIR" "$OUT_DIR"

echo ""
echo "============================================================"
echo "完成！"
echo "============================================================"
if [[ -f "$RUN_DIR/manifests/success.tsv" ]]; then
  echo "✅ 成功"
elif [[ -f "$RUN_DIR/manifests/failures.tsv" ]]; then
  echo "❌ 失败"
  cat "$RUN_DIR/manifests/failures.tsv"
fi
