#!/usr/bin/env bash
# 启动中文文献提参任务
# 双路并行: bailian/qwen3.6-plus + mimo/mimo-v2.5
# 汇报机制: 每整点汇报 + 错误立即通知

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=================================================="
echo "  中文文献提参任务启动"
echo "=================================================="
echo ""

# 1. 检查当前是否有任务在运行
echo "📋 检查当前任务状态..."
if [[ -f /tmp/openclaw/extraction_progress.json ]]; then
  status=$(python3 -c "import json; print(json.load(open('/tmp/openclaw/extraction_progress.json'))['status'])")
  if [[ "$status" == "running" ]]; then
    echo "⚠️  当前有任务正在运行!"
    python3 -c "
import json
d = json.load(open('/tmp/openclaw/extraction_progress.json'))
print(f'  状态: {d[\"status\"]}')
print(f'  已处理: {d[\"processed\"]}/{d[\"total\"]}')
print(f'  成功: {d[\"success\"]}, 失败: {d[\"failed\"]}')
"
    echo ""
    echo "请等待当前任务完成，或手动停止当前任务后再启动。"
    exit 1
  fi
fi

# 2. 检查中文文献目录
PDF_DIR="$REPO_DIR/workspace/近海油气田污染物相关文献/中文文献"
OUT_DIR="$REPO_DIR/outputs/extractions"

if [[ ! -d "$PDF_DIR" ]]; then
  echo "❌ 中文文献目录不存在: $PDF_DIR"
  exit 1
fi

TOTAL_PDFS=$(find "$PDF_DIR" -name "*.pdf" -type f | wc -l | tr -d ' ')
echo "📁 中文文献目录: $PDF_DIR"
echo "📄 PDF文件总数: $TOTAL_PDFS"
echo ""

# 3. 检查是否有已提取的JSON文件（避免重复处理）
EXISTING_JSON=$(find "$OUT_DIR/中文文献/json" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "📊 已存在的JSON文件: $EXISTING_JSON"
echo ""

# 4. 启动双路并行提取
echo "🚀 启动双路并行提参任务..."
echo "   Worker 1: bailian/qwen3.6-plus"
echo "   Worker 2: mimo/mimo-v2.5"
echo ""

cd "$REPO_DIR"

# 启动命令（启用整点汇报）
START_CMD="START_MONITORS=1 \
SEND_HOURLY_PROGRESS=1 \
MULTI_EXTRACT_RUN_ID=chinese_$(date +%Y%m%d_%H%M%S) \
bash scripts/multi_worker_extract.sh \
  --pdf-dir \"$PDF_DIR\" \
  --out-dir \"$OUT_DIR\" \
  --workers 2 \
  --timeout-seconds 1800 \
  --preprocess-workers 2"

echo "📝 启动命令:"
echo "   $START_CMD"
echo ""

# 创建日志目录
LOG_DIR="/tmp/openclaw"
mkdir -p "$LOG_DIR"

# 在后台启动，日志输出到文件
nohup bash -c "$START_CMD" > "$LOG_DIR/chinese_extract_2w.log" 2>&1 &
MAIN_PID=$!

echo "✅ 提参任务已启动!"
echo "   PID: $MAIN_PID"
echo "   日志: $LOG_DIR/chinese_extract_2w.log"
echo ""

# 5. 等待任务初始化
echo "⏳ 等待任务初始化..."
sleep 5

# 6. 验证任务是否成功启动
if ps -p $MAIN_PID > /dev/null 2>&1; then
  echo "✅ 主进程运行正常 (PID: $MAIN_PID)"
else
  echo "❌ 主进程启动失败，请检查日志: $LOG_DIR/chinese_extract_2w.log"
  exit 1
fi

# 7. 检查Worker是否启动
sleep 3
WORKER_PIDS=$(ps aux | grep "single_worker_extract" | grep -v grep | wc -l | tr -d ' ')
echo "👷 已启动Worker进程数: $WORKER_PIDS"
echo ""

# 8. 显示汇报机制配置
echo "=================================================="
echo "  📡 汇报机制配置（已优化）"
echo "=================================================="
echo "  ✅ 整点汇报 (SEND_HOURLY_PROGRESS=1):"
echo "     - 每小时整点自动发送进度报告到iMessage"
echo "     - 包含: 进度百分比、成功/失败数、剩余数量"
echo "     - 包含: Worker存活状态、API key信息"
echo "     - 包含: 当前处理文献、Token预估"
echo ""
echo "  ✅ 错误立即通知 (notify_progress.sh):"
echo "     - 每60秒检查一次失败数量变化"
echo "     - 发现新增失败立即发送详细通知"
echo "     - 包含: 失败文献名、失败原因、当前进度"
echo "     - 包含: Worker状态、API信息、上下文"
echo ""
echo "  ✅ 完成通知:"
echo "     - 所有Worker结束且队列为空时发送"
echo "     - 包含: 最终成功/失败统计、总计数量"
echo "     - 包含: Token消耗预估"
echo ""
echo "  📊 监控组件:"
echo "     - progress_monitor_multi.sh: 每30秒更新进度文件"
echo "     - notify_progress.sh: 每60秒检查并发送通知"
echo "     - extraction_progress.json: 实时进度数据"
echo ""

# 9. 查看进度文件
if [[ -f /tmp/openclaw/extraction_progress.json ]]; then
  echo "📊 当前进度:"
  python3 -c "
import json
d = json.load(open('/tmp/openclaw/extraction_progress.json'))
print(f'  状态: {d[\"status\"]}')
print(f'  总数: {d[\"total\"]}')
print(f'  已处理: {d[\"processed\"]}')
print(f'  成功: {d[\"success\"]}')
print(f'  失败: {d[\"failed\"]}')
print(f'  队列剩余: {d[\"queued\"]}')
print(f'  活跃Worker: {d[\"active_workers\"]}')
if d.get('workers'):
  print('')
  print('  Worker详情:')
  for w in d['workers']:
    print(f'    Worker {w[\"worker_id\"]}: {w[\"model\"]}')
    print(f'      当前: {w.get(\"current_pdf\", \"N/A\")}')
"
fi

echo ""
echo "=================================================="
echo "  🎯 任务监控提示"
echo "=================================================="
echo "  查看实时进度: cat /tmp/openclaw/extraction_progress.json | python3 -m json.tool"
echo "  查看Worker日志: tail -f /tmp/openclaw/litextract_runs/chinese_*/logs/worker_*.log"
echo "  查看通知日志: tail -f /tmp/openclaw/notify_progress.log"
echo "  停止任务: bash scripts/stop_extraction.sh"
echo ""
echo "=================================================="
echo "  🎉 中文文献提参任务启动完成!"
echo "=================================================="
