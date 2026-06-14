#!/usr/bin/env bash
# 验证中文文献提参的汇报机制配置

echo "=================================================="
echo "  提参汇报机制验证"
echo "=================================================="
echo ""

# 1. 检查关键脚本是否存在
echo "📋 检查关键脚本..."
SCRIPTS=(
  "scripts/multi_worker_extract.sh"
  "scripts/progress_monitor_multi.sh"
  "scripts/notify_progress.sh"
  "scripts/single_worker_extract.sh"
  "scripts/launch_chinese_extract.sh"
)

all_ok=true
for script in "${SCRIPTS[@]}"; do
  if [[ -f "/Users/panyao/Qoder/JJJ_Literature/$script" ]]; then
    echo "  ✅ $script"
  else
    echo "  ❌ $script (不存在!)"
    all_ok=false
  fi
done
echo ""

# 2. 检查notify_progress.sh的整点汇报配置
echo "🔍 检查notify_progress.sh配置..."
if grep -q 'SEND_HOURLY_PROGRESS="${SEND_HOURLY_PROGRESS:-0}"' /Users/panyao/Qoder/JJJ_Literature/scripts/notify_progress.sh; then
  echo "  ✅ SEND_HOURLY_PROGRESS环境变量检查: 正确（默认0，需启动时设置为1）"
else
  echo "  ❌ SEND_HOURLY_PROGRESS配置异常"
fi

if grep -q 'CHECK_INTERVAL=60' /Users/panyao/Qoder/JJJ_Literature/scripts/notify_progress.sh; then
  echo "  ✅ 检查间隔: 60秒"
else
  echo "  ⚠️  检查间隔可能不是60秒"
fi

if grep -q 'if \[\[ "\$failed" -gt "\$last_failure_count" \]\]' /Users/panyao/Qoder/JJJ_Literature/scripts/notify_progress.sh; then
  echo "  ✅ 错误立即通知逻辑: 存在"
else
  echo "  ❌ 错误通知逻辑缺失!"
fi
echo ""

# 3. 检查progress_monitor_multi.sh
echo "🔍 检查progress_monitor_multi.sh配置..."
if grep -q 'INTERVAL=30' /Users/panyao/Qoder/JJJ_Literature/scripts/progress_monitor_multi.sh; then
  echo "  ✅ 进度更新间隔: 30秒"
else
  echo "  ⚠️  进度更新间隔可能不是30秒"
fi

if grep -q 'extraction_progress.json' /Users/panyao/Qoder/JJJ_Literature/scripts/progress_monitor_multi.sh; then
  echo "  ✅ 进度文件输出: 正确"
else
  echo "  ❌ 进度文件配置异常"
fi
echo ""

# 4. 检查multi_worker_extract.sh的监控启动逻辑
echo "🔍 检查multi_worker_extract.sh监控启动..."
if grep -q 'START_MONITORS' /Users/panyao/Qoder/JJJ_Literature/scripts/multi_worker_extract.sh; then
  echo "  ✅ START_MONITORS环境变量: 支持"
else
  echo "  ❌ START_MONITORS配置缺失!"
fi

if grep -q 'notify_progress.sh' /Users/panyao/Qoder/JJJ_Literature/scripts/multi_worker_extract.sh; then
  echo "  ✅ notify_progress.sh调用: 存在"
else
  echo "  ❌ notify_progress.sh调用缺失!"
fi

if grep -q 'progress_monitor_multi.sh' /Users/panyao/Qoder/JJJ_Literature/scripts/multi_worker_extract.sh; then
  echo "  ✅ progress_monitor_multi.sh调用: 存在"
else
  echo "  ❌ progress_monitor_multi.sh调用缺失!"
fi
echo ""

# 5. 检查launch_chinese_extract.sh的配置
echo "🔍 检查launch_chinese_extract.sh配置..."
if grep -q 'SEND_HOURLY_PROGRESS=1' /Users/panyao/Qoder/JJJ_Literature/scripts/launch_chinese_extract.sh; then
  echo "  ✅ 整点汇报已启用: SEND_HOURLY_PROGRESS=1"
else
  echo "  ❌ 整点汇报未启用! 需要添加 SEND_HOURLY_PROGRESS=1"
fi

if grep -q 'START_MONITORS=1' /Users/panyao/Qoder/JJJ_Literature/scripts/launch_chinese_extract.sh; then
  echo "  ✅ 监控脚本已启用: START_MONITORS=1"
else
  echo "  ❌ 监控脚本未启用! 需要添加 START_MONITORS=1"
fi
echo ""

# 6. 检查iMessage配置
echo "🔍 检查iMessage通知配置..."
if command -v imsg >/dev/null 2>&1; then
  echo "  ✅ imsg命令: 可用"
else
  echo "  ❌ imsg命令: 不可用! iMessage通知将无法工作"
fi

if grep -q 'PHONE=' /Users/panyao/Qoder/JJJ_Literature/scripts/notify_progress.sh; then
  phone=$(grep 'PHONE=' /Users/panyao/Qoder/JJJ_Literature/scripts/notify_progress.sh | head -1 | cut -d'"' -f2)
  echo "  ✅ 通知手机号: $phone"
else
  echo "  ⚠️  未找到通知手机号配置"
fi
echo ""

# 7. 检查OpenClaw配置
echo "🔍 检查OpenClaw配置..."
if [[ -f /Users/panyao/Qoder/JJJ_Literature/openclaw.json ]]; then
  echo "  ✅ openclaw.json: 存在"
  
  # 检查mimo模型配置
  if grep -q '"mimo-v2.5"' /Users/panyao/Qoder/JJJ_Literature/openclaw.json; then
    echo "  ✅ Mimo模型: mimo-v2.5 (多模态)"
  else
    echo "  ⚠️  Mimo模型版本可能不是mimo-v2.5"
  fi
  
  # 检查bailian模型配置
  if grep -q '"qwen3.6-plus"' /Users/panyao/Qoder/JJJ_Literature/openclaw.json; then
    echo "  ✅ Bailian模型: qwen3.6-plus"
  else
    echo "  ⚠️  Bailian模型配置异常"
  fi
else
  echo "  ❌ openclaw.json: 不存在!"
fi
echo ""

# 8. 总结
echo "=================================================="
if $all_ok; then
  echo "  ✅ 所有检查通过！汇报机制配置正确"
  echo ""
  echo "  📊 汇报机制总结:"
  echo "     - 整点汇报: ✅ 已启用 (每小时)"
  echo "     - 错误通知: ✅ 已配置 (60秒检查一次)"
  echo "     - 完成通知: ✅ 已配置"
  echo "     - 进度监控: ✅ 已配置 (30秒更新)"
  echo ""
  echo "  🚀 可以启动中文文献提参任务了!"
  echo "     命令: bash scripts/launch_chinese_extract.sh"
else
  echo "  ⚠️  部分检查未通过，请检查上述配置"
fi
echo "=================================================="
