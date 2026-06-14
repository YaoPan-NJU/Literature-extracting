#!/usr/bin/env bash
# 重新提取之前MIMO-v2.5-pro没有多模态能力的文献
# 使用新的mimo-v2.5（多模态）和bailian/qwen3.6-plus

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=================================================="
echo "  Mimo-v2.5-pro 文献重提任务（多模态增强）"
echo "=================================================="
echo ""

# 1. 创建MIMO文献队列
echo "📋 步骤1: 识别MIMO-v2.5-pro提取的文献..."
cd "$REPO_DIR"

python3 << 'PYTHON_SCRIPT'
import json
from pathlib import Path

# 从所有run目录的manifests中找出MIMO提取的文献，并补入先前MIMO重提失败项。
run_dir = Path("/tmp/openclaw/litextract_runs")
mimo_pdfs = {}

# 遍历所有run目录的success.tsv
for success_file in run_dir.glob("*/manifests/success.tsv"):
    try:
        with open(success_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # 跳过header
        for line in lines[1:]:
            parts = line.strip().split('\t')
            if len(parts) >= 5:
                model = parts[3]
                json_path = parts[4]
                
                # 检查是否是MIMO-v2.5-pro
                if 'mimo' in model.lower() and 'v2.5-pro' in model:
                    # 直接使用JSON文件名找PDF
                    json_file = Path(json_path)
                    pdf_name = json_file.stem
                    
                    # PDF可能在两个地方
                    possible_paths = [
                        Path("/Users/panyao/Qoder/JJJ_Literature/workspace/近海油气田污染物相关文献/英文文献") / f"{pdf_name}.pdf",
                        Path("/private/tmp/jjj_retry_20260520234202/英文文献") / f"{pdf_name}.pdf",
                        Path("/private/tmp/jjj_retry_mimo_202605202351/英文文献") / f"{pdf_name}.pdf"
                    ]
                    
                    for pdf_path in possible_paths:
                        if pdf_path.exists():
                            mimo_pdfs[pdf_name] = str(pdf_path)
                            break
    except Exception as e:
        pass

# 上一次重提中已经失败的文献也必须重新入队，避免被遗漏。
base_count = len(mimo_pdfs)
failed_count = 0
for failures_file in run_dir.glob("mimo_rerun_*/manifests/failures.tsv"):
    try:
        with open(failures_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        for line in lines[1:]:
            parts = line.rstrip('\n').split('\t')
            if len(parts) < 2:
                continue
            pdf_path = Path(parts[1])
            if not pdf_path.exists() or pdf_path.suffix.lower() != '.pdf':
                continue
            # 本脚本用于英文MIMO重提，避免混入其他批次/语种。
            if "英文文献" not in pdf_path.parts:
                continue
            if pdf_path.stem not in mimo_pdfs:
                failed_count += 1
            mimo_pdfs[pdf_path.stem] = str(pdf_path)
    except Exception:
        pass

# 写入队列文件
rerun_list = sorted(list(mimo_pdfs.values()))
queue_file = Path("/tmp/openclaw/mimo_rerun_queue.txt")

if rerun_list:
    queue_file.write_text('\n'.join(rerun_list) + '\n', encoding='utf-8')
    print(f"  ✅ 找到 {base_count} 篇MIMO-v2.5-pro提取的文献")
    print(f"  ✅ 已并入 {failed_count} 篇先前MIMO重提失败文献")
    print(f"  ✅ 本次队列合计 {len(rerun_list)} 篇")
    print(f"  📁 队列文件: {queue_file}")
else:
    print("  ⚠️  没有找到需要重提的文献")
    exit(1)
PYTHON_SCRIPT

echo ""

# 2. 检查队列
QUEUE_FILE="/tmp/openclaw/mimo_rerun_queue.txt"
if [[ ! -f "$QUEUE_FILE" ]]; then
  echo "❌ 队列文件不存在"
  exit 1
fi

TOTAL_PDFS=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
echo "📊 重提队列: $TOTAL_PDFS 篇文献"
echo ""

RERUN_WORKERS="${RERUN_WORKERS:-2}"
RERUN_PREPROCESS_WORKERS="${RERUN_PREPROCESS_WORKERS:-1}"
RERUN_PREPROCESS_RETRY_ATTEMPTS="${RERUN_PREPROCESS_RETRY_ATTEMPTS:-6}"
RERUN_PREPROCESS_RETRY_DELAY="${RERUN_PREPROCESS_RETRY_DELAY:-30}"
RERUN_SLEEP_SECONDS="${RERUN_SLEEP_SECONDS:-20}"

case "$RERUN_WORKERS" in
  1|2|3) ;;
  *) echo "❌ RERUN_WORKERS 必须是 1、2 或 3"; exit 2 ;;
esac
for value_name in RERUN_PREPROCESS_WORKERS RERUN_PREPROCESS_RETRY_ATTEMPTS RERUN_PREPROCESS_RETRY_DELAY RERUN_SLEEP_SECONDS; do
  value="${!value_name}"
  case "$value" in
    ''|*[!0-9]*) echo "❌ $value_name 必须是非负整数"; exit 2 ;;
  esac
done
if [[ "$RERUN_PREPROCESS_WORKERS" -lt 1 ]]; then
  echo "❌ RERUN_PREPROCESS_WORKERS 必须至少为 1"
  exit 2
fi
if [[ "$RERUN_PREPROCESS_RETRY_ATTEMPTS" -lt 1 ]]; then
  echo "❌ RERUN_PREPROCESS_RETRY_ATTEMPTS 必须至少为 1"
  exit 2
fi

# 3. 检查是否有任务在运行
echo "📋 步骤2: 检查当前任务状态..."
if [[ -f /tmp/openclaw/extraction_progress.json ]]; then
  status=$(python3 -c "import json; print(json.load(open('/tmp/openclaw/extraction_progress.json'))['status'])")
  if [[ "$status" == "running" ]]; then
    echo "⚠️  当前有任务正在运行!"
    python3 -c "
import json
d = json.load(open('/tmp/openclaw/extraction_progress.json'))
print(f'  状态: {d[\"status\"]}')
print(f'  已处理: {d[\"processed\"]}/{d[\"total\"]}')
"
    echo ""
    echo "请等待当前任务完成后再启动重提任务。"
    exit 1
  fi
fi

# 4. 启动限定队列重提
echo "🚀 步骤3: 启动限定队列重提任务..."
echo "   Worker数量: $RERUN_WORKERS"
echo "   预处理并发: $RERUN_PREPROCESS_WORKERS"
echo "   预处理重试: $RERUN_PREPROCESS_RETRY_ATTEMPTS 次，基础等待 ${RERUN_PREPROCESS_RETRY_DELAY}s"
echo "   单篇间隔: ${RERUN_SLEEP_SECONDS}s"
if [[ "$RERUN_WORKERS" -eq 1 ]]; then
  echo "   Worker 1: mimo/mimo-v2.5 (多模态)"
elif [[ "$RERUN_WORKERS" -eq 2 ]]; then
  echo "   Worker 1: bailian/qwen3.6-plus (多模态)"
  echo "   Worker 2: mimo/mimo-v2.5 (多模态)"
else
  echo "   Worker 1: dashscope/qwen3.6-plus (多模态)"
  echo "   Worker 2: bailian/qwen3.6-plus (多模态)"
  echo "   Worker 3: mimo/mimo-v2.5 (多模态)"
fi
echo ""

cd "$REPO_DIR"

# 启动命令：必须使用 --pdf-list，避免把整个英文目录全量强制重跑。
START_CMD="START_MONITORS=1 \
SEND_HOURLY_PROGRESS=1 \
PREPROCESS_RETRY_ATTEMPTS=$RERUN_PREPROCESS_RETRY_ATTEMPTS \
PREPROCESS_RETRY_DELAY=$RERUN_PREPROCESS_RETRY_DELAY \
MULTI_EXTRACT_RUN_ID=mimo_rerun_$(date +%Y%m%d_%H%M%S) \
bash scripts/multi_worker_extract.sh \
  --pdf-list \"$QUEUE_FILE\" \
  --out-dir \"$REPO_DIR/outputs/extractions\" \
  --workers \"$RERUN_WORKERS\" \
  --timeout-seconds 1800 \
  --sleep-seconds \"$RERUN_SLEEP_SECONDS\" \
  --preprocess-workers \"$RERUN_PREPROCESS_WORKERS\" \
  --force"

echo "📝 启动命令:"
echo "   $START_CMD"
echo ""

# 创建日志目录
LOG_DIR="/tmp/openclaw"
mkdir -p "$LOG_DIR"

# 在后台启动
nohup bash -c "$START_CMD" > "$LOG_DIR/mimo_rerun_2w.log" 2>&1 &
MAIN_PID=$!

echo "✅ 重提任务已启动!"
echo "   PID: $MAIN_PID"
echo "   日志: $LOG_DIR/mimo_rerun_2w.log"
echo ""

# 5. 等待任务初始化
echo "⏳ 等待任务初始化..."
sleep 5

# 6. 验证任务是否成功启动
if ps -p $MAIN_PID > /dev/null 2>&1; then
  echo "✅ 主进程运行正常 (PID: $MAIN_PID)"
else
  echo "❌ 主进程启动失败，请检查日志: $LOG_DIR/mimo_rerun_2w.log"
  exit 1
fi

# 7. 检查Worker是否启动
sleep 3
WORKER_PIDS=$(ps aux | grep "single_worker_extract" | grep -v grep | wc -l | tr -d ' ')
echo "👷 已启动Worker进程数: $WORKER_PIDS"
echo ""

# 8. 显示汇报机制配置
echo "=================================================="
echo "  📡 汇报机制配置（与中文文献一致）"
echo "=================================================="
echo "  ✅ 整点汇报: 每小时整点自动发送进度报告"
echo "  ✅ 错误通知: 发现失败立即发送通知"
echo "  ✅ 完成通知: 任务完成时发送总结报告"
echo "  ✅ 限定队列: 只处理 $QUEUE_FILE 中的 $TOTAL_PDFS 篇文献"
echo "  ✅ 强制重提: 队列内旧JSON会被覆盖，队列外文献不会触碰"
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
echo "  查看Worker日志: tail -f /tmp/openclaw/litextract_runs/mimo_rerun_*/logs/worker_*.log"
echo "  查看通知日志: tail -f /tmp/openclaw/notify_progress.log"
echo "  停止任务: bash scripts/stop_extraction.sh"
echo ""
echo "=================================================="
echo "  🎉 Mimo文献重提任务启动完成!"
echo "=================================================="
echo ""
echo "💡 提示: 多模态模型将能够读取PDF中的图表信息，"
echo "         提取质量会比之前的MIMO-v2.5-pro更好！"
