# LitExtract 本地部署与批量提参操作文档 v2

项目：近海油气田多介质污染物特征与控制决策平台开发
负责人场景：子课题五，面向后续智能决策平台的文献知识库和向量知识库建设
默认仓库目录：`Literature-extracting`
更新日期：2026-04-30

---

## 1. 本方案要解决什么

从约 5000 篇 PDF 文献中批量提取结构化知识，支撑后续智能决策平台。

文献来源：Web of Science 和 ScienceDirect 检索，主题为 offshore/marine oil/gas + pollution/treatment/produced water/environmental impact。

输出目标：
- **文献知识库**：参数级结构化条目（污染物、风险、监测、治理、运行、成本、法规、决策模型等）。
- **向量知识库**：面向检索增强和智能体问答的中文语义条目。
- **决策支撑**：保留证据页码、质量判断、适用边界。

技术路线：单 agent 低成本流程（非 6 agent 方案）。
- 模型自主判断提取内容，不按固定模板填空。
- 参数级条目：每条是一个具体的参数/事实，带证据和质量标记。
- 向量条目由模型自动生成。

---

## 2. 两种部署场景

### 2.1 已有 OpenClaw

适用于已经在 Mac mini 或服务器上部署过 OpenClaw，并且已经接入 iMessage、Web UI、TUI 或其他 channel 的机器。

原则：
- 不重装 OpenClaw。
- 不主动重启 Gateway。
- 只安装本项目的 Python 依赖、配置 `.env`、注册 `lit-extract` agent。
- 如果要通过 iMessage 使用，再按现有 OpenClaw 路由策略绑定 channel。

推荐命令：

```bash
git clone https://github.com/YaoPan-NJU/Literature-extracting.git
cd Literature-extracting

# macOS
brew install poppler
pip3 install PyMuPDF pdf2image openai jsonschema

cp .env.example .env
# 填入 BAILIAN_CODING_PLAN_API_KEY 和 MIMO_API_KEY

bash scripts/setup.sh --existing-openclaw
```

如果机器上已经有同名 `lit-extract`，并且需要把它重新指向当前 clone 的目录：

```bash
bash scripts/setup.sh --existing-openclaw --force-register
```

可选 iMessage 绑定：

```bash
openclaw agents bind --agent lit-extract --bind imessage
```

### 2.2 未安装 OpenClaw

适用于新电脑、干净 Linux/WSL 或新 Mac。

Linux / WSL：

```bash
git clone https://github.com/YaoPan-NJU/Literature-extracting.git
cd Literature-extracting
bash scripts/setup.sh
```

macOS：

```bash
brew install node poppler
npm install -g openclaw
pip3 install PyMuPDF pdf2image openai jsonschema

git clone https://github.com/YaoPan-NJU/Literature-extracting.git
cd Literature-extracting
cp .env.example .env
# 编辑 .env 后：
bash scripts/setup.sh --no-start-gateway
scripts/start_gateway_env.sh
```

---

## 3. 手动部署步骤（从零开始）

### 3.1 系统依赖（WSL Ubuntu）

```bash
sudo apt update
sudo apt install -y git curl build-essential python3 python3-pip python3-venv poppler-utils
```

### 3.2 Node.js 22

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

### 3.3 OpenClaw CLI

```bash
sudo npm install -g openclaw
```

macOS 通常使用：

```bash
npm install -g openclaw
```

### 3.4 克隆仓库

```bash
git clone https://github.com/YaoPan-NJU/Literature-extracting.git
cd Literature-extracting
```

### 3.5 Python 虚拟环境

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install PyMuPDF pdf2image openai jsonschema
```

### 3.6 配置 API Key

编辑 `.env`：

```bash
BAILIAN_CODING_PLAN_API_KEY=你的Bailian_Coding_Plan_API_Key
MIMO_API_KEY=你的Mimo_API_Key
```

### 3.7 注册 Agent

```bash
source .env
openclaw agents add lit-extract \
  --workspace ./workspace \
  --agent-dir ./agents/lit-extract/agent \
  --model bailian/qwen3.6-plus \
  --non-interactive
```

验证：

```bash
openclaw agents list
```

应看到 `lit-extract` 在列表中。

### 3.8 启动 Gateway

```bash
source .env
scripts/start_gateway_env.sh &
```

验证：

```bash
curl -s http://127.0.0.1:18789/health
# 应返回 {"ok":true,"status":"live"}
```

---

## 4. 关键配置点（踩坑记录）

### 4.1 OPENCLAW_CONFIG_PATH 必须设置

OpenClaw 有两套配置：
- **全局配置**：`~/.openclaw/openclaw.json`（agent 注册在这里）
- **项目配置**：`<repo>/openclaw.json`（模型 provider、API Key 在这里）

运行 `openclaw agent` 时必须设置 `OPENCLAW_CONFIG_PATH` 指向项目配置，否则模型 API Key 找不到：

```bash
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json"
```

批处理脚本 `batch_extract_pdfs.sh` 已自动处理此问题。

### 4.2 Gateway auth token 问题

如果 agent 报错 `device identity required`，检查 `openclaw.json` 的 `gateway.auth` 配置。确保 `mode: "none"` 且不设多余 token：

```json
"gateway": {
  "auth": {
    "mode": "none"
  }
}
```

### 4.3 首次运行会安装插件

第一次运行 `openclaw agent` 时，OpenClaw 会自动安装 bundled plugins（amazon-bedrock、document-extract 等），耗时约 30-60 秒。后续运行不再需要。

### 4.4 模型输出 JSON 可能有未转义引号

LLM 在长文本字段（如 `embedding_text_zh`）中偶尔使用未转义的双引号，破坏 JSON 结构。批处理脚本的 `extract_first_json` 函数已内置自动修复逻辑。

---

## 5. 单篇测试

```bash
cd Literature-extracting
source .env
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json"

openclaw agent --local --agent lit-extract --timeout 300 \
  --message "$(printf '请读取并提取以下 PDF：\n%s\n\n请严格遵循下面的项目提示词。最终只输出一个 JSON 对象。\n\n' '/path/to/paper.pdf'; cat prompts/jjj_single_agent_extraction_prompt.md)"
```

判断是否通过：
- 输出是 JSON 对象
- `schema_version` 为 `jjj-v2`
- `routing.relevance_level` 为 R1-R4 之一
- `knowledge_items` 有合理数量的条目（R4 应为空或极少）
- 每条 `knowledge_item` 有 `evidence` 且含页码

---

## 6. 批量处理

### 6.1 先 dry run

```bash
scripts/batch_extract_pdfs.sh \
  --pdf-dir "/path/to/pdfs" \
  --out-dir "outputs/pilot_20" \
  --limit 20 \
  --dry-run
```

### 6.2 正式跑 20 篇

```bash
scripts/batch_extract_pdfs.sh \
  --pdf-dir "/path/to/pdfs" \
  --out-dir "outputs/pilot_20" \
  --limit 20 \
  --timeout-seconds 600
```

### 6.3 输出目录结构

```
outputs/pilot_20/
├── json/          # 每篇 PDF 的结构化 JSON
├── raw/           # OpenClaw 原始输出
├── logs/          # 处理日志
├── prompts/       # 每篇发送的提示词
└── manifests/
    ├── pdf_list.txt
    ├── success.tsv
    └── failures.tsv
```

### 6.4 断点续跑

同一输出目录重跑时，已有有效 JSON 的 PDF 会自动跳过。用 `--force` 强制重跑。

---

## 7. 结果校验

### 7.1 JSON 解析检查

```bash
find outputs/pilot_20/json -name "*.json" -print0 \
  | xargs -0 -I {} python3 -m json.tool "{}" >/dev/null
```

### 7.2 Schema 校验

```bash
source .venv/bin/activate
python3 -c "
import json, glob
from jsonschema import validate, ValidationError

schema = json.load(open('schema/jjj_literature_extraction.schema.json'))
for f in glob.glob('outputs/pilot_20/json/*.json'):
    data = json.load(open(f))
    try:
        validate(instance=data, schema=schema)
    except ValidationError as e:
        print(f'FAIL {f}: {e.message}')
"
```

### 7.3 人工抽样

建议 pilot 阶段每批至少看 10 篇：
- 路由分级是否合理
- knowledge_items 是否真的有价值
- R4 是否只保留了题录
- 证据页码能否回到原 PDF
- vector_index_records 的中文摘要是否适合入向量库

---

## 8. 推荐推进节奏

1. 单篇测试通过 ✅
2. 5 篇混合测试（R1-R4 各有）
3. 20 篇 pilot
4. 50 篇 pilot
5. 修订提示词
6. 200 篇试运行
7. 全量 5000 篇

pilot 门槛：
- JSON 解析成功率 ≥ 90%
- 路由分类准确率 ≥ 85%
- 关键参数证据覆盖率 ≥ 80%

---

## 9. 关键文件清单

| 文件 | 路径 | 说明 |
|------|------|------|
| 提示词 | `prompts/jjj_single_agent_extraction_prompt.md` | v2 柔性提取，模型自主判断 |
| JSON Schema | `schema/jjj_literature_extraction.schema.json` | v2 信封格式 + knowledge_items |
| 批处理脚本 | `scripts/batch_extract_pdfs.sh` | 含 JSON 修复、断点续跑 |
| 部署文档 | 本文件 | |
| 项目配置 | `openclaw.json` | 模型 provider、Gateway 端口 |
| 环境变量 | `.env` | API Keys |
| Agent 配置 | `agents/lit-extract/agent/agent.json` | 默认模型 |
| 技能定义 | `workspace/skills/literature-data-extraction/SKILL.md` | PDF 提参流程 |

---

## 10. 常见问题

### Gateway 启动后 agent 报超时

检查 `OPENCLAW_CONFIG_PATH` 是否设置。未设置时 agent 找不到模型 API Key。

### 输出不是 JSON

查看 `raw/` 目录中的原始输出。常见原因：
- PDF 读取失败
- 提示词过长导致上下文溢出
- 模型输出了 Markdown 代码块（提示词已约束，但偶尔发生）

### JSON 解析失败但有输出

批处理脚本会自动尝试修复未转义引号。如果仍失败，查看 `raw/` 文件人工修复。

### 某篇 PDF 一直失败

- 检查 PDF 是否加密或损坏
- 尝试增大 `--timeout-seconds`
- 如果是扫描版，接受 Q3/Q4 质量标记
- 列入人工处理清单
