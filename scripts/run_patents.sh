#!/usr/bin/env bash
# 专利提取 - 单路 bailian
set -euo pipefail

REPO_DIR="/Users/panyao/Qoder/JJJ_Literature"
SCRIPT="$REPO_DIR/scripts/single_worker_extract.sh"
OUT_DIR="$REPO_DIR/outputs/extractions"
PDF_DIR="$REPO_DIR/workspace/近海油气田污染物相关文献"

# Source .env
if [[ -f "$REPO_DIR/.env" ]]; then
  set -a; source "$REPO_DIR/.env"; set +a
fi

RUN_ID="patent_$(date +%Y%m%d_%H%M%S)"
RUN_DIR="/tmp/openclaw/litextract_runs/$RUN_ID"
mkdir -p "$RUN_DIR"/{logs,raw,text,prompts,json,manifests}

echo "============================================================"
echo "专利提取 - bailian 单路"
echo "============================================================"
echo "Run ID: $RUN_ID"
echo "Run Dir: $RUN_DIR"
echo ""

# Create patent queue from remaining_queue.tsv
QUEUE_FILE="$RUN_DIR/queue.txt"
cat "$REPO_DIR/outputs/extractions/manifests/remaining_queue.tsv" | tail -n +2 | grep "专利" | cut -f3 > "$QUEUE_FILE"

TOTAL=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
echo "专利总数: $TOTAL"
echo ""

if [[ "$TOTAL" -eq 0 ]]; then
  echo "没有待处理的专利，退出"
  exit 0
fi

# Show first few items
echo "前5个文件:"
head -5 "$QUEUE_FILE" | while read f; do echo "  $(basename "$f")"; done
echo ""

# Launch worker
echo "启动 bailian worker..."
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export TIMEOUT_SECONDS=1800

bash "$SCRIPT" "patent-bailian" "bailian/qwen3.6-plus" "patent" "$RUN_ID" "$QUEUE_FILE" "$RUN_DIR" "$PDF_DIR" "$OUT_DIR"

echo ""
echo "============================================================"
echo "专利提取完成！"
echo "============================================================"
echo "成功: $(wc -l < "$RUN_DIR/manifests/success.tsv" 2>/dev/null | tr -d ' ')"
echo "失败: $(tail -n +2 "$RUN_DIR/manifests/failures.tsv" 2>/dev/null | wc -l | tr -d ' ')"
echo "结果目录: $RUN_DIR"
