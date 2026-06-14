#!/usr/bin/env bash
# 专利提取 - 双路并行 (bailian + mimo)
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
echo "专利提取 - 双路并行"
echo "============================================================"
echo "Run ID: $RUN_ID"
echo "Run Dir: $RUN_DIR"
echo ""

# Create patent queue from remaining_queue.tsv
ALL_QUEUE="$RUN_DIR/queue_all.txt"
cat "$REPO_DIR/outputs/extractions/manifests/remaining_queue.tsv" | tail -n +2 | grep "专利" | cut -f3 > "$ALL_QUEUE"

TOTAL=$(wc -l < "$ALL_QUEUE" | tr -d ' ')
echo "专利总数: $TOTAL"
echo ""

if [[ "$TOTAL" -eq 0 ]]; then
  echo "没有待处理的专利，退出"
  exit 0
fi

# Split queue into two halves for parallel processing
BAILIAN_QUEUE="$RUN_DIR/queue_bailian.txt"
MIMO_QUEUE="$RUN_DIR/queue_mimo.txt"

# Odd lines to bailian, even lines to mimo
awk 'NR%2==1' "$ALL_QUEUE" > "$BAILIAN_QUEUE"
awk 'NR%2==0' "$ALL_QUEUE" > "$MIMO_QUEUE"

BAILIAN_COUNT=$(wc -l < "$BAILIAN_QUEUE" | tr -d ' ')
MIMO_COUNT=$(wc -l < "$MIMO_QUEUE" | tr -d ' ')

echo "分配队列:"
echo "  bailian/qwen3.6-plus: $BAILIAN_COUNT 篇"
echo "  mimo/mimo-v2.5-pro: $MIMO_COUNT 篇"
echo ""

# Show first few items
echo "前5个文件:"
head -5 "$ALL_QUEUE" | while read f; do echo "  $(basename "$f")"; done
echo ""

# Launch workers
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export TIMEOUT_SECONDS=1800

PIDS=()

echo "启动 bailian worker ($BAILIAN_COUNT 篇)..."
bash "$SCRIPT" "patent-bailian" "bailian/qwen3.6-plus" "patent-bailian" "$RUN_ID" "$BAILIAN_QUEUE" "$RUN_DIR" "$PDF_DIR" "$OUT_DIR" &
PIDS+=($!)

echo "启动 mimo worker ($MIMO_COUNT 篇)..."
bash "$SCRIPT" "patent-mimo" "mimo/mimo-v2.5-pro" "patent-mimo" "$RUN_ID" "$MIMO_QUEUE" "$RUN_DIR" "$PDF_DIR" "$OUT_DIR" &
PIDS+=($!)

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
echo "专利提取完成！"
echo "============================================================"
echo "成功: $(wc -l < "$RUN_DIR/manifests/success.tsv" 2>/dev/null | tr -d ' ')"
echo "失败: $(tail -n +2 "$RUN_DIR/manifests/failures.tsv" 2>/dev/null | wc -l | tr -d ' ')"
echo "结果目录: $RUN_DIR"
