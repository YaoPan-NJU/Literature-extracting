# LitExtract — AI 文献数据提参助手

基于 [OpenClaw](https://github.com/nicholasgriffintn/openclaw) 框架的科学文献结构化参数提取智能体。采用 **模型自主判断 + 参数级条目 + 证据定位** 架构，从 PDF 文献中提取可进入知识库和向量库的结构化 JSON。

## 🎯 核心能力

| 能力 | 说明 |
|------|------|
| **模型自主提取** | 模型读完文献后自主判断"这篇对决策平台有什么价值"，不按固定模板填空 |
| **参数级知识条目** | 每条知识是一个具体的参数/事实（数值、单位、条件），带证据页码和质量标记 |
| **自动路由分类** | 自动判断相关性（R1-R4）、文献类型（T1-T4）、领域方向（D1-D10） |
| **向量库条目生成** | 提取时同步生成中文摘要条目，可直接用于 embedding 和 RAG 检索 |
| **证据定位** | 每个提取值标注来源页码和表格/图号，质量分 reliable / needs_review / suspicious |
| **批量处理** | 支持整个文件夹批量提取，断点续跑，失败清单，日志追踪 |

## ⚡ 性能参考

18 篇多类型文献 pilot 测试结果（中英文专利、期刊、学位论文、书本章节）：

| 指标 | 数值 |
|------|------|
| **成功率** | 16/18（89%） |
| **Schema 通过率** | 16/16（100%） |
| **平均处理时间** | ~4 分钟/篇 |
| **总 knowledge_items** | 141 条（16 篇） |
| **总 vector_records** | 45 条 |
| **R4 最小保留** | 平均 2.3 条 / 篇（vs R1/R2 的 14 条） |

## 📦 部署方案

### 前置要求

- **Python** >= 3.9（用于 PyMuPDF、pdf2image 和批处理脚本）
- **阿里百炼 Coding Plan API Key**（用于 Qwen 模型）
- **小米 Mimo API Key**（用于 Mimo provider；当前配置会在启动前检查）
- **poppler-utils**（Linux: `sudo apt install poppler-utils`，macOS: `brew install poppler`）

### 方案 A：已有 OpenClaw（推荐给 Mac mini / iMessage 用户）

如果你的机器已经安装 OpenClaw，并且已经通过 iMessage、Web UI 或其他 channel 接入，不建议运行会重启 Gateway 的部署流程。只需要把本项目注册成一个新的 agent。

```bash
git clone https://github.com/YaoPan-NJU/Literature-extracting.git
cd Literature-extracting

# macOS
brew install poppler
pip3 install PyMuPDF pdf2image openai jsonschema

# Linux / WSL
sudo apt install -y poppler-utils
pip3 install PyMuPDF pdf2image openai jsonschema

cp .env.example .env
# 编辑 .env，填入：
# BAILIAN_CODING_PLAN_API_KEY=...
# MIMO_API_KEY=...

bash scripts/setup.sh --existing-openclaw
```

这个模式会：
- 保留现有 OpenClaw 和 iMessage Gateway，不启动或重启服务
- 配置本项目 `.env`
- 安装 Python 依赖
- 注册 `lit-extract` agent

如果这台机器以前注册过同名 `lit-extract`，并且你想把它重新指向当前 clone 的目录：

```bash
bash scripts/setup.sh --existing-openclaw --force-register
```

如果要让 iMessage 消息默认路由到该 agent：

```bash
openclaw agents bind --agent lit-extract --bind imessage
```

也可以不改默认路由，直接命令行指定 agent：

```bash
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json"
openclaw agent --local --agent lit-extract --message "从 /path/to/paper.pdf 提取文献参数"
```

### 方案 B：未安装 OpenClaw（新电脑从零部署）

Linux / WSL 可以直接运行一键脚本：

```bash
git clone https://github.com/YaoPan-NJU/Literature-extracting.git
cd Literature-extracting

bash scripts/setup.sh
```

脚本会安装或检查：
- Node.js
- OpenClaw CLI
- Python 依赖
- poppler-utils / poppler
- 本地 `.env`
- `lit-extract` agent
- OpenClaw Gateway（端口 18789）

macOS 新电脑建议先安装 Homebrew，然后执行：

```bash
brew install node poppler
npm install -g openclaw
pip3 install PyMuPDF pdf2image openai jsonschema

git clone https://github.com/YaoPan-NJU/Literature-extracting.git
cd Literature-extracting
cp .env.example .env
# 编辑 .env 后执行：
bash scripts/setup.sh --no-start-gateway
scripts/start_gateway_env.sh
```

### 手动配置

如果不使用部署脚本，按下面步骤配置：

```bash
cp .env.example .env
# 编辑 .env，填入 API Key

export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json"
openclaw agents add lit-extract \
  --workspace ./workspace \
  --agent-dir ./agents/lit-extract/agent \
  --model bailian/qwen3.6-plus \
  --non-interactive

# 如需启动本项目 Gateway
scripts/start_gateway_env.sh

# 验证
curl -s http://127.0.0.1:18789/health
```

## 📖 使用教程

### 场景 1：命令行单篇提参

```bash
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json"
openclaw agent --local --agent lit-extract --timeout 300 \
  --message "$(printf '请读取并提取以下 PDF：\n%s\n\n请严格遵循项目提示词，只输出 JSON。\n\n' '/path/to/paper.pdf'; cat prompts/jjj_single_agent_extraction_prompt.md)"
```

模型会自主判断文献内容，提取有价值的参数级知识条目，输出结构化 JSON。

### 场景 2：终端 UI（TUI）

```bash
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json"
openclaw tui
```

进入交互界面后，像聊天一样提出提取需求。

### 场景 3：批量处理 PDF 文件夹

```bash
# 先 dry run 查看待处理文件
scripts/batch_extract_pdfs.sh \
  --pdf-dir "/path/to/pdfs" \
  --out-dir "outputs/pilot_20" \
  --limit 20 \
  --dry-run

# 正式跑
scripts/batch_extract_pdfs.sh \
  --pdf-dir "/path/to/pdfs" \
  --out-dir "outputs/pilot_20" \
  --limit 20 \
  --timeout-seconds 600
```

批量输出目录结构：

```
outputs/pilot_20/
├── json/          ← 每篇 PDF 的结构化 JSON（入库用）
├── raw/           ← OpenClaw 原始输出（调试用）
├── logs/          ← 每篇处理日志
├── prompts/       ← 每篇实际发送的提示词
└── manifests/
    ├── success.tsv    ← 成功清单
    ├── failures.tsv   ← 失败清单和原因
    └── pdf_list.txt   ← PDF 清单
```

同一输出目录重跑时，已有有效 JSON 的 PDF 会自动跳过（断点续跑）。用 `--force` 强制重跑。

## 📊 输出格式（v2）

每个 PDF 输出一个 JSON 文件，核心结构：

```json
{
  "schema_version": "jjj-v2",
  "paper_id": "Yuan_2015_coastal_petroleum_degrading_bacteria",
  "bibliographic_metadata": {
    "title": "海岸带石油降解菌的分离及多样性分析",
    "authors": ["袁梦"],
    "year": 2015,
    "abstract": "..."
  },
  "routing": {
    "relevance_level": "R2_domain_direct",
    "relevance_reason": "研究海岸带石油降解菌，可迁移至近海油气田生物修复",
    "document_type": "T4_thesis_book_chapter",
    "domain_directions": ["D1_pollutant_source", "D5_treatment_technology"],
    "text_quality": "Q1_clean_text"
  },
  "decision_summary": {
    "one_sentence_value": "该论文分离出3株石油降解菌，量化了降解率，为生物修复提供菌种资源",
    "key_findings": ["菌株A降解率30.52%", "组合菌降解率高于单菌"],
    "transferable_value": null,
    "main_limitations": ["仅限实验室规模"]
  },
  "knowledge_items": [
    {
      "record_id": "ki_001",
      "parameter": "菌株A鉴定与降解率 Strain A identification and degradation rate",
      "value": "Gallaecimonas pentaromativorans，降解率30.52%",
      "unit": "%",
      "context": {
        "conditions": "原油为唯一碳源，28°C，150rpm，7天",
        "scale": "实验室摇瓶"
      },
      "domain_direction": "D5_treatment_technology",
      "evidence": [
        {
          "page": 25,
          "locator": "Table 3",
          "evidence_text": "菌株A降解率30.52%",
          "quality": "reliable"
        }
      ],
      "notes": null
    }
  ],
  "vector_index_records": [
    {
      "record_id": "vr_001",
      "chunk_type": "treatment",
      "domain_direction": ["D5_treatment_technology"],
      "title_zh": "海岸带石油降解菌的分离与降解性能",
      "summary_zh": "从黄岛输油管线爆炸事故附近海域分离出3株石油降解菌...",
      "keywords": ["石油降解菌", "生物修复", "海岸带"],
      "embedding_text_zh": "从受污染海域分离出3株石油降解菌：Gallaecimonas pentaromativorans降解率30.52%...",
      "source_evidence": [{"page": 25, "locator": "Table 3", "evidence_text": "...", "quality": "reliable"}]
    }
  ],
  "quality_control": {
    "json_parse_check": "pass",
    "evidence_coverage": "所有知识条目均有证据定位",
    "missing_important_fields": [],
    "suspicious_items": [],
    "manual_review_recommendations": []
  },
  "processing_notes": []
}
```

### 关键设计理念

- **信封格式**：顶层结构固定（元数据、路由、质量控制），中间 `knowledge_items` 由模型自由组织
- **参数级条目**：每条知识是一个具体的参数/事实，不是段落摘要
- **领域方向是标签不是模板**：D1-D10 帮助分类，不是每篇都要填满
- **R4 最小保留**：低相关文献只保留题录和极少量信息，不做大量展开
- **向量条目自动生成**：`vector_index_records` 在提取时同步生成，可直接用于 embedding

## 🏗️ 提取流程

```
PDF 论文
  │
  ├─ 阶段 1：理解文献
  │   └─ 模型通读论文，理解研究内容、方法、结论
  │
  ├─ 阶段 2：路由分类
  │   ├─ 相关性：R1 直接相关 / R2 领域直接 / R3 可迁移 / R4 低相关
  │   ├─ 文献类型：T1 期刊 / T2 专利 / T3 标准 / T4 学位论文/书本
  │   └─ 领域方向：D1-D10 按实际涉及内容标注
  │
  ├─ 阶段 3：自主提取
  │   ├─ 模型判断"这篇对决策平台有什么价值"
  │   ├─ 提取参数级 knowledge_items（带证据和质量标记）
  │   └─ 生成 vector_index_records（中文摘要，适合 embedding）
  │
  └─ 阶段 4：自检输出
      ├─ JSON 格式校验
      ├─ 枚举值校验
      └─ 证据覆盖率检查
```

## ❓ 常见问题

<details>
<summary><b>如何获取阿里百炼 Coding Plan API Key？</b></summary>

1. 访问 [阿里云百炼控制台](https://bailian.console.aliyun.com/?tab=model#/efm/coding_plan)
2. 开通 Coding Plan → 获取 API Key
3. 将 Key 填入项目 `.env` 文件的 `BAILIAN_CODING_PLAN_API_KEY` 字段
4. 或运行 `bash scripts/setup.sh` 交互式输入
</details>

<details>
<summary><b>提取一篇论文需要多长时间？</b></summary>

- 典型 20-40 页论文：~3-5 分钟
- 含详细 SI 的长论文（80+ 页）：~5-7 分钟
- 书本章节、短专利：~2-3 分钟
</details>

<details>
<summary><b>提取结果的质量如何？</b></summary>

每个 knowledge_item 带有证据定位和质量标记：
- `reliable`：原文文本层可查，数值/单位清晰
- `needs_review`：来自图表估读或 OCR，需人工确认
- `suspicious`：在原文中找不到对应内容，可能是幻觉
</details>

<details>
<summary><b>支持哪些语言的论文？</b></summary>

中英文均可。Qwen3.6-plus 对中英文混合文档有良好的理解能力。
</details>

<details>
<summary><b>如果 PDF 是扫描版怎么办？</b></summary>

如果 PyMuPDF 文本层为空，系统自动回退到视觉模式，并在 `text_quality` 中标记 `Q3_ocr_poor` 或 `Q4_metadata_only`。建议优先使用带文本层的原生 PDF。
</details>

<details>
<summary><b>如何校验批量输出？</b></summary>

```bash
# Schema 校验
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
</details>

## 📁 项目结构

```
Literature-extracting/
├── openclaw.json              # OpenClaw 主配置（模型 provider、Gateway、agent）
├── .env.example               # 环境变量模板，.env 不提交
├── scripts/
│   ├── setup.sh               # 一键部署脚本（支持 --existing-openclaw）
│   ├── start_gateway_env.sh   # 加载 .env 后启动 Gateway
│   ├── batch_extract_pdfs.sh  # 批量 PDF 提取（macOS/Linux 兼容）
│   └── preprocess.py          # PDF 文本锚定与视觉预处理
├── prompts/
│   └── jjj_single_agent_extraction_prompt.md   # v2 提示词（模型自主提取）
├── schema/
│   └── jjj_literature_extraction.schema.json   # v2 JSON Schema
├── workspace/
│   ├── IDENTITY.md            # Agent 角色定义
│   ├── SOUL.md                # 行为准则
│   ├── AGENTS.md              # 工作空间配置
│   └── skills/
│       └── literature-data-extraction/
│           └── SKILL.md       # 文献提参技能定义
└── agents/
    └── lit-extract/
        └── agent/
            ├── agent.json     # Agent 模型配置
            └── models.json    # 模型参数
```

## 🔗 相关资源

- [OpenClaw 文档](https://github.com/nicholasgriffintn/openclaw)
- [阿里百炼 Coding Plan](https://bailian.console.aliyun.com/?tab=model#/efm/coding_plan)
- [PyMuPDF 文档](https://pymupdf.readthedocs.io/)

---

**仓库**: [YaoPan-NJU/Literature-extracting](https://github.com/YaoPan-NJU/Literature-extracting)
