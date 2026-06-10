#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# 增量提取：只跑缺失论文（双路多模态并行）
#   Worker 1: bailian/qwen3.6-plus (多模态)
#   Worker 2: mimo/mimo-v2.5       (多模态)
# 用法: bash scripts/extract_missing_26.sh [--dry-run]
# ─────────────────────────────────────────────────────────
set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(cd "$REPO_DIR/../.." && pwd)"

LINK_DIR="$REPO_DIR/missing_26_pdf_dir"
OUT_DIR="$REPO_DIR/outputs/extractions"
PROMPT_V2="$REPO_DIR/prompts/biomimetic_extraction_prompt_v2.md"
PROMPT_FALLBACK="$REPO_DIR/prompts/biomimetic_extraction_prompt.md"

DRY_RUN="${1:-}"

# ── Step 1: 重建符号链接目录 ──
echo "=== Step 1: 生成缺失论文符号链接 ==="

python3 - "$PROJECT_DIR" "$LINK_DIR" <<'PY'
import os, glob, re, sys

project = sys.argv[1]
link_dir = sys.argv[2]

os.makedirs(link_dir, exist_ok=True)

# 清除旧链接
for f in os.listdir(link_dir):
    p = os.path.join(link_dir, f)
    if os.path.islink(p):
        os.unlink(p)

# 收集所有 PDF（去掉 " 2"/" 3" 后缀归一化）
pdf_map = {}
for pdf in glob.glob(os.path.join(project, '仿生文献库/论文/**/*.pdf'), recursive=True):
    base = os.path.splitext(os.path.basename(pdf))[0]
    clean = re.sub(r'\s+\d+$', '', base)
    pdf_map.setdefault(clean, []).append(pdf)

# 收集已有 JSON
json_dir = os.path.join(project, 'tools/litextract/outputs/extractions/论文/json')
jsons = set()
if os.path.isdir(json_dir):
    for j in glob.glob(os.path.join(json_dir, '*.json')):
        jsons.add(os.path.splitext(os.path.basename(j))[0])

# 找缺失的
missing = sorted(set(pdf_map.keys()) - jsons)

if not missing:
    print("✅ 没有缺失的论文，全部已提取！")
    sys.exit(0)

# 创建符号链接
for name in missing:
    src = os.path.abspath(pdf_map[name][0])
    dst = os.path.join(link_dir, name + '.pdf')
    os.symlink(src, dst)

print(f"📋 缺失论文: {len(missing)} 篇")
print(f"📁 链接目录: {link_dir}")
for i, name in enumerate(missing, 1):
    print(f"   {i:2d}. {name}")
PY

# ── Step 2: 检查提示词 ──
echo ""
echo "=== Step 2: 选择提示词 ==="

if [[ -f "$PROMPT_V2" ]]; then
    PROMPT_FILE="$PROMPT_V2"
    echo "✅ 使用 v2 提示词: $PROMPT_V2"
elif [[ -f "$PROMPT_FALLBACK" ]]; then
    PROMPT_FILE="$PROMPT_FALLBACK"
    echo "⚠️ v2 提示词不存在，回退到 v1: $PROMPT_FALLBACK"
else
    echo "❌ 找不到任何提示词文件"
    exit 1
fi

# ── Step 3: 双路多模态并行提取 ──
echo ""
echo "=== Step 3: 双路多模态并行提取 ==="
echo "  Worker 1: bailian/qwen3.6-plus (多模态)"
echo "  Worker 2: mimo/mimo-v2.5       (多模态)"

PDF_COUNT=$(ls "$LINK_DIR"/*.pdf 2>/dev/null | wc -l | tr -d ' ')

if [[ "$PDF_COUNT" -eq 0 ]]; then
    echo "✅ 没有需要提取的论文"
    exit 0
fi

echo "待提取: ${PDF_COUNT} 篇"
echo "输出目录: $OUT_DIR"
echo ""

EXTRA_ARGS=""
if [[ "$DRY_RUN" == "--dry-run" ]]; then
    EXTRA_ARGS="--dry-run"
    echo "🔍 DRY RUN 模式 — 只列出不执行"
fi

bash "$REPO_DIR/scripts/multi_worker_extract.sh" \
    --pdf-dir "$LINK_DIR" \
    --out-dir "$OUT_DIR" \
    --workers 2 \
    --mode multimodal \
    $EXTRA_ARGS

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo ""
    echo "💡 确认无误后，去掉 --dry-run 参数重新运行即可"
    exit 0
fi

echo ""
echo "=== 提取完成 ==="
echo ""
echo "后续步骤："
echo "  1. 映射到原型:  python3 scripts/map_to_prototypes.py"
echo "  2. 重建正典:    python3 $PROJECT_DIR/tools/build_prototypes_db.py"
echo "  3. 校验:        python3 $PROJECT_DIR/tools/validate_consistency.py"
