#!/usr/bin/env bash
# ============================================================
# LitExtract — 一键部署脚本
# ============================================================
set -e

START_GATEWAY=1
INSTALL_OPENCLAW=1
FORCE_REGISTER=0

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

usage() {
    cat <<'USAGE'
Usage:
  bash scripts/setup.sh [options]

Options:
  --existing-openclaw    Use an existing OpenClaw installation and do not start/restart Gateway.
  --no-start-gateway     Install dependencies and register the agent, but leave Gateway untouched.
  --force-register       Recreate the lit-extract agent if it is already registered.
  -h, --help             Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --existing-openclaw)
            INSTALL_OPENCLAW=0
            START_GATEWAY=0
            shift
            ;;
        --no-start-gateway)
            START_GATEWAY=0
            shift
            ;;
        --force-register)
            FORCE_REGISTER=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 2
            ;;
    esac
done

OS_NAME="$(uname -s)"

# ---- Check Node.js ----
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}[1/6] Node.js 未安装。${NC}"
    if [[ "$OS_NAME" == "Linux" ]] && command -v apt >/dev/null 2>&1; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt install -y nodejs
    elif [[ "$OS_NAME" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        brew install node
    else
        echo -e "${RED}  请先安装 Node.js >= 20，然后重试。${NC}"
        exit 2
    fi
else
    echo -e "${GREEN}[1/6] Node.js 已安装: $(node --version)${NC}"
fi

# ---- Install OpenClaw ----
if [[ "$INSTALL_OPENCLAW" -eq 0 ]]; then
    if command -v openclaw &> /dev/null; then
        echo -e "${GREEN}[2/6] 使用已有 OpenClaw: $(openclaw --version 2>&1 | head -1)${NC}"
    else
        echo -e "${RED}[2/6] 未找到 openclaw。去掉 --existing-openclaw 或先安装 OpenClaw。${NC}"
        exit 2
    fi
elif ! command -v openclaw &> /dev/null; then
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
    if ! command -v pdftoppm &> /dev/null; then
        echo "  ⚠️ pdf2image 需要 poppler-utils，尝试安装..."
        if [[ "$OS_NAME" == "Linux" ]] && command -v apt >/dev/null 2>&1; then
            sudo apt install -y poppler-utils 2>/dev/null || echo "  请手动安装: sudo apt install poppler-utils"
        elif [[ "$OS_NAME" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
            brew install poppler || echo "  请手动安装: brew install poppler"
        else
            echo "  请手动安装 poppler-utils/poppler"
        fi
    fi
else
    echo -e "${YELLOW}  ⚠️ Python3 未安装，视觉精读功能需要 Python${NC}"
fi

# ---- Register Agent ----
echo -e "${YELLOW}[5/6] 注册 lit-extract Agent...${NC}"
if openclaw agents list 2>/dev/null | grep -q "lit-extract"; then
    if [[ "$FORCE_REGISTER" -eq 1 ]]; then
        echo -e "${YELLOW}  lit-extract 已存在，正在重新注册...${NC}"
        openclaw agents delete lit-extract --force >/dev/null 2>&1 || true
        openclaw agents add lit-extract \
            --workspace "$PWD/workspace" \
            --agent-dir "$PWD/agents/lit-extract/agent" \
            --model bailian/qwen3.6-plus \
            --non-interactive
        echo -e "${GREEN}  lit-extract 重新注册完成 ✅${NC}"
    else
        echo -e "${GREEN}  lit-extract 已注册 ✅${NC}"
        echo "  如需把已存在的同名 agent 指向当前目录，请重新运行: bash scripts/setup.sh --force-register"
    fi
else
    openclaw agents add lit-extract \
        --workspace "$PWD/workspace" \
        --agent-dir "$PWD/agents/lit-extract/agent" \
        --model bailian/qwen3.6-plus \
        --non-interactive
    echo -e "${GREEN}  lit-extract 注册完成 ✅${NC}"
fi

# ---- Start Gateway ----
if [[ "$START_GATEWAY" -eq 1 ]]; then
    echo -e "${YELLOW}[6/6] 启动 OpenClaw Gateway...${NC}"
    scripts/start_gateway_env.sh &
    sleep 3

    if curl -s http://127.0.0.1:18789/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Gateway 已启动: http://127.0.0.1:18789${NC}"
    else
        echo -e "${RED}⚠️ Gateway 启动失败，请检查 OpenClaw 日志${NC}"
    fi
else
    echo -e "${GREEN}[6/6] 已跳过 Gateway 启动；现有 OpenClaw/iMessage 服务不会被重启。${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  部署完成！📑 LitExtract 已就绪${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "  快速开始:"
echo "    export OPENCLAW_CONFIG_PATH=\"$PWD/openclaw.json\""
echo "    openclaw tui                # 终端对话"
echo "    openclaw agent --local --agent lit-extract --message \"帮我从 PDF 提取文献参数\""
echo "    openclaw status             # 查看状态"
echo ""
echo "  Web UI: http://127.0.0.1:18789"
echo ""
