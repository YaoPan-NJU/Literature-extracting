#!/usr/bin/env bash
# ============================================================
# LitExtract — 一键部署脚本
# ============================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║   📑  LitExtract — 文献智能提参助手       ║"
echo "║     一键部署脚本 v1.0                    ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ---- Check Node.js ----
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}[1/6] Node.js 未安装，正在安装...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
else
    echo -e "${GREEN}[1/6] Node.js 已安装: $(node --version)${NC}"
fi

# ---- Install OpenClaw ----
if ! command -v openclaw &> /dev/null; then
    echo -e "${YELLOW}[2/6] 安装 OpenClaw CLI...${NC}"
    npm install -g openclaw
else
    echo -e "${GREEN}[2/6] OpenClaw 已安装: $(openclaw --version 2>&1 | head -1)${NC}"
fi

# ---- Configure API Keys in local .env ----
echo -e "${YELLOW}[3/6] 配置 API Key 到本地 .env...${NC}"
if [ ! -f "openclaw.json" ]; then
    echo -e "${RED}  未找到 openclaw.json，请检查工作目录${NC}"
    exit 1
fi

touch .env

upsert_env_var() {
    local var_name="$1"
    local var_value="$2"
    VAR_NAME="$var_name" VAR_VALUE="$var_value" python3 - <<'PY'
import os
from pathlib import Path

path = Path(".env")
name = os.environ["VAR_NAME"]
value = os.environ["VAR_VALUE"]
lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
updated = False
out = []
for line in lines:
    if line.startswith(f"{name}="):
        out.append(f"{name}={value}")
        updated = True
    else:
        out.append(line)
if not updated:
    out.append(f"{name}={value}")
path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY
}

ensure_env_key() {
    local var_name="$1"
    local label="$2"
    local current
    current="$(grep -E "^${var_name}=" .env 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    if [ -n "$current" ] && [[ "$current" != your_*_api_key_here ]]; then
        echo -e "${GREEN}  ${label} 已在 .env 中配置 ✅${NC}"
        return
    fi
    echo -ne "  请输入你的 ${label}: "
    read -rs api_key
    echo ""
    if [ -n "$api_key" ]; then
        upsert_env_var "$var_name" "$api_key"
        echo -e "${GREEN}  ${label} 已写入 .env ✅${NC}"
    else
        echo -e "${RED}  ${label} 为空；请稍后手动写入 .env 的 ${var_name}${NC}"
    fi
}

ensure_env_key "BAILIAN_CODING_PLAN_API_KEY" "阿里百炼 Coding Plan API Key"
ensure_env_key "MIMO_API_KEY" "小米 Mimo API Key"

# ---- Install Python dependencies (for PyMuPDF / pdf2image) ----
echo -e "${YELLOW}[4/6] 安装 Python 依赖...${NC}"
if command -v python3 &> /dev/null; then
    pip3 install PyMuPDF pdf2image openai jsonschema 2>/dev/null || pip3 install PyMuPDF pdf2image openai jsonschema --user 2>/dev/null || echo "  ⚠️ pip 安装失败，请手动安装: pip install PyMuPDF pdf2image openai jsonschema"
    # Check poppler
    if ! ldconfig -p 2>/dev/null | grep -q libpoppler || ! command -v pdftoppm &> /dev/null; then
        echo "  ⚠️ pdf2image 需要 poppler-utils，尝试安装..."
        sudo apt install -y poppler-utils 2>/dev/null || echo "  请手动安装: sudo apt install poppler-utils"
    fi
else
    echo -e "${YELLOW}  ⚠️ Python3 未安装，视觉精读功能需要 Python${NC}"
fi

# ---- Register Agent ----
echo -e "${YELLOW}[5/6] 注册 lit-extract Agent...${NC}"
if openclaw agents list 2>/dev/null | grep -q "lit-extract"; then
    echo -e "${GREEN}  lit-extract 已注册 ✅${NC}"
else
    openclaw agents add lit-extract \
        --workspace "$PWD/workspace" \
        --agent-dir "$PWD/agents/lit-extract/agent" \
        --model bailian/qwen3.6-plus \
        --non-interactive
    echo -e "${GREEN}  lit-extract 注册完成 ✅${NC}"
fi

# ---- Start Gateway ----
echo -e "${YELLOW}[6/6] 启动 OpenClaw Gateway...${NC}"
scripts/start_gateway_env.sh &
sleep 3

if curl -s http://127.0.0.1:18789/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Gateway 已启动: http://127.0.0.1:18789${NC}"
else
    echo -e "${RED}⚠️ Gateway 启动失败，请检查日志: cat /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  部署完成！📑 LitExtract 已就绪${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "  快速开始:"
echo "    openclaw tui                # 终端对话"
echo "    openclaw agent --message \"帮我从 PDF 提取文献参数\""
echo "    openclaw status             # 查看状态"
echo ""
echo "  Web UI: http://127.0.0.1:18789"
echo ""
