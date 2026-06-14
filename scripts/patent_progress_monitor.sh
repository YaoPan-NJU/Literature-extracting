#!/usr/bin/env bash
# 专利提取进度监控脚本 - 双路并行版

# Find latest patent run
RUN_DIR=$(ls -td /tmp/openclaw/litextract_runs/patent_* 2>/dev/null | head -1)
OUT_DIR="/Users/panyao/Qoder/JJJ_Literature/outputs/extractions"

if [[ -z "$RUN_DIR" || ! -d "$RUN_DIR" ]]; then
  echo "❌ 专利提取任务不存在"
  exit 1
fi

echo "📊 专利提取进度报告"
echo "===================="
echo "Run ID: $(basename "$RUN_DIR")"
echo ""

# Count progress for each worker
for worker in patent-bailian patent-mimo; do
  SUCCESS=$(grep -c "$worker" "$RUN_DIR/manifests/success.tsv" 2>/dev/null || true)
  SUCCESS=${SUCCESS:-0}
  FAILURES=$(grep -c "$worker" "$RUN_DIR/manifests/failures.tsv" 2>/dev/null || true)
  FAILURES=${FAILURES:-0}
  TOTAL=$((SUCCESS + FAILURES))
  
  # Get queue remaining
  if [[ "$worker" == "patent-bailian" ]]; then
    QUEUE_FILE="$RUN_DIR/queue_bailian.txt"
  else
    QUEUE_FILE="$RUN_DIR/queue_mimo.txt"
  fi
  REMAINING=$(wc -l < "$QUEUE_FILE" 2>/dev/null | tr -d ' ')
  
  # Check if worker is alive
  WORKER_ALIVE=$(ps aux | grep "$worker" | grep -v grep | wc -l | tr -d ' ')
  
  echo "🔧 $worker:"
  echo "   ✅ 成功: $SUCCESS"
  echo "   ❌ 失败: $FAILURES"
  echo "   ⏳ 剩余: $REMAINING"
  echo "   🔄 状态: $(if [[ $WORKER_ALIVE -gt 0 ]]; then echo "运行中"; else echo "已停止"; fi)"
  echo ""
done

# Total
TOTAL_SUCCESS=$(wc -l < "$RUN_DIR/manifests/success.tsv" 2>/dev/null | tr -d ' ')
TOTAL_FAILURES=$(tail -n +2 "$RUN_DIR/manifests/failures.tsv" 2>/dev/null | wc -l | tr -d ' ')
TOTAL=$((TOTAL_SUCCESS + TOTAL_FAILURES))
PROGRESS=$((TOTAL_SUCCESS * 100 / 89))

echo "📈 总计: $PROGRESS% ($TOTAL_SUCCESS/89)"
echo ""

# Show recent failures if any
if [[ $TOTAL_FAILURES -gt 0 ]]; then
  echo "最近失败:"
  tail -3 "$RUN_DIR/manifests/failures.tsv" 2>/dev/null | while IFS=$'\t' read -r ts pdf model stage code reason; do
    echo "  - $(basename "$pdf"): $reason"
  done
fi
