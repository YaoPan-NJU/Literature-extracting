# 仿生设计文献提取工具改造设计文档

> 分支: biomimetic-extraction
> 基础项目: Literature-extracting (OpenClaw-based)
> 目标: 将"近海油气田特征污染物提取"改造为"仿生水处理吸附材料设计知识提取"
> 创建日期: 2026-06-04

---

## 一、改造背景

### 1.1 源项目能力

Literature-extracting 基于 OpenClaw 架构，具备：
- OpenClaw Gateway + 多模型 Provider 调度（GPT-4o, Claude, qwen 等）
- JSON Schema 严格校验（298行 schema，确保输出结构化）
- 专业提取提示词（332行，面向 PFAS 吸附文献）
- 多 Worker 并发提取（`multi_worker_extract.sh`，687行）
- 并行预处理器（`preprocess.py`，Stage 0 文本提取 + Stage 1 初步分类）
- 批量 PDF 处理脚本（`batch_extract_pdfs.sh`，543行）
- 多模态模型支持（图表/SEM/等温线图提取）

### 1.2 目标项目需求

仿生设计库（Biomimetic-design-library）需要：
- 30+ 个仿生原型的结构化知识档案（prototype.md）
- 四层特征映射权重更新（feature-mapping.json）
- 仿生设计逻辑链提取（自然挑战→进化策略→关键机制→材料映射）
- 多尺度结构-功能关系（宏观/介观/微观/纳米）
- 标准化特征词汇（映射到 feature-mapping.json 中的27个标准标签）
- 吸附机制详解（现象→分子基础→官能团→仿生启示）

### 1.3 改造范围

| 维度 | 当前（PFAS提取） | 目标（仿生设计提取） |
|------|-----------------|-------------------|
| 提取目标 | 近海油气田特征污染物（PFAS等） | 仿生水处理吸附材料设计知识 |
| Schema | PFAS吸附数据（7条记录/篇） | 仿生设计全维度（设计链+性能+结构+机制+约束） |
| 提示词 | 面向污染物识别和吸附性能 | 面向仿生设计知识提取 |
| 输出格式 | 单篇论文JSON | 按原型聚合的结构化数据 + prototype.md + 权重更新 |
| 词汇标准 | 污染物名称标准化 | 特征标签映射到 feature-mapping.json |
| 多模态 | 已配置但未启用 | 启用，提取图表/SEM数据 |

---

## 二、模块一：提取 Schema 设计

### 2.1 新 Schema 文件

**路径**: `schema/biomimetic_extraction.schema.json`

替换原有 `jjj_literature_extraction.schema.json`，新 Schema 包含以下顶层结构：

```
{
  "paper_metadata": { ... },         // 论文基本信息
  "prototype_associations": [ ... ],  // 关联的仿生原型列表
  "biomimetic_design_chain": { ... }, // 仿生设计逻辑链
  "performance_data": [ ... ],       // 吸附性能定量数据（数组，每条件一组）
  "structural_features": { ... },    // 多尺度结构特征
  "mechanism_analysis": [ ... ],     // 吸附机制详解（数组，每个机制一条）
  "engineering_constraints": [ ... ], // 工程约束评估
  "evidence_tracking": { ... }       // 证据溯源汇总
}
```

### 2.2 核心字段定义

**biomimetic_design_chain（仿生设计逻辑链）** -- 库的灵魂字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `nature_challenge` | string | 生物原型在自然界中面临的具体挑战（50-100字） |
| `evolutionary_strategy` | string | 生物通过进化形成的解决策略 |
| `key_mechanisms` | array[string] | 支撑该策略的关键生物机制列表 |
| `key_functional_groups` | array[object] | 关键官能团/结构特征：`{group, function}` |
| `bio_to_material_mapping` | array[object] | 从生物特征到材料设计的映射：`{bio_feature, material_design, confidence}` |
| `must_keep_features` | array[object] | 必须保留的特征：`{feature, reason}` |
| `adjustable_features` | array[object] | 可调整的特征：`{feature, adjustment_range}` |
| `one_line_story` | string | 一句话仿生故事（面向可解释性） |
| `design_traceability` | string | 设计可追溯性描述 |

**performance_data（性能数据）** -- 每条件一组实验数据：

| 字段 | 类型 | 说明 |
|------|------|------|
| `pollutant` | string | 目标污染物（使用 taxonomy/pollutants.md 标准名称） |
| `material_form` | string | 材料形态描述 |
| `qmax_mg_g` | number/null | 最大吸附容量 (mg/g) |
| `removal_rate_pct` | number/null | 去除率 (%) |
| `pH` | number/null | 实验 pH |
| `temperature_C` | number/null | 实验温度 (°C) |
| `kinetics_model` | string/null | 动力学模型 |
| `isotherm_model` | string/null | 等温线模型 |
| `selectivity` | string/null | 选择性描述 |
| `reusability_cycles` | number/null | 可循环次数 |
| `data_source` | enum | "experimental" / "reported" / "estimated" |
| `reference` | string | 数据来源（论文内引用标记） |
| `confidence` | enum | "high" / "medium" / "low" |

**structural_features（多尺度结构）**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `macro_scale` | object | 宏观特征：`{feature, size_range, function}` |
| `meso_scale` | object | 介观特征 |
| `micro_scale` | object | 微观特征 |
| `nano_scale` | object | 纳米特征 |
| `structure_function_relationship` | string | 结构-功能关系的综合描述 |

**mechanism_analysis（机制详解）** -- 每个机制一条：

| 字段 | 类型 | 说明 |
|------|------|------|
| `mechanism_name` | string | 机制名称（使用 taxonomy/mechanisms.md 标准名称） |
| `phenomenon` | string | 现象描述 |
| `molecular_basis` | array[string] | 分子基础（可多条） |
| `key_functional_groups` | array[object] | 关键官能团：`{group, role}` |
| `biomimetic_inspiration` | string | 对仿生材料设计的启示 |
| `supporting_evidence` | string | 论文中的支持证据 |

### 2.3 标准词汇映射表

**新文件**: `config/vocabulary_mapping.json`

从文献原始表述到 feature-mapping.json 标准标签的映射：

```json
{
  "feature_mapping": {
    "catechol group": "邻苯二酚基团",
    "DOPA": "邻苯二酚基团",
    "hydrophobic": "疏水性",
    "superhydrophobic": "超疏水性",
    "electrostatic attraction": "静电吸附",
    "coordination chelation": "配位螯合",
    "metal coordination": "金属配位能力",
    "microporous": "微孔",
    "mesoporous": "介孔",
    "hierarchical pores": "层次孔",
    ...（覆盖 feature-mapping.json 中全部27个标准特征标签）
  },
  "mechanism_mapping": {
    "ion exchange": "离子交换",
    "coordination": "配位螯合",
    "electrostatic": "静电吸附",
    ...（覆盖 taxonomy/mechanisms.md 中全部机制）
  },
  "pollutant_mapping": {
    "cadmium": "Cd2+",
    "lead": "Pb2+",
    "methylene blue": "阳离子染料",
    ...（覆盖 taxonomy/pollutants.md 中全部污染物层级）
  },
  "category_mapping": {
    "bacteria": "微生物",
    "plant": "植物",
    "animal": "动物",
    "synthetic": "仿生材料"
  }
}
```

---

## 三、模块二：提示词设计

### 3.1 新提示词文件

**路径**: `prompts/biomimetic_extraction_prompt.md`

替换原有 `jjj_single_agent_extraction_prompt.md`（332行），新提示词面向仿生设计知识提取。

### 3.2 提示词结构

```markdown
# 角色定义
你是一位仿生材料设计领域的科学文献分析专家。你的任务是从水处理吸附材料相关论文中
提取仿生设计知识，产出可直接写入仿生设计库的结构化数据。

# 输入
- 论文全文（可能包含文本、表格、图表描述）
- 目标仿生原型列表（如果已知）
- 标准词汇表（feature labels）

# 提取指令

## 1. 仿生设计逻辑链 [最核心]
从论文中识别"生物→设计→材料"的完整因果链：
- 自然界中该生物面临什么挑战？
- 进化出了什么策略？
- 哪些机制支撑这个策略？
- 如何映射到材料设计？
- 哪些特征必须保留？哪些可以调整？

## 2. 吸附性能数据
提取论文中明确报告的实验数据（不要推断）：
- qmax、去除率、pH、温度、动力学、等温线
- 每个数据点标注来源和置信度

## 3. 多尺度结构特征
从论文中识别四个尺度的结构特征...

## 4. 吸附机制详解
对论文中讨论的每个吸附机制...

## 5. 工程约束评估
评估以下10项工程约束的适用性...

## 6. 词汇规范化
提取的特征/机制/污染物必须使用以下标准词汇表...
[嵌入标准词汇映射表]

# 输出格式
严格遵循 biomimetic_extraction.schema.json 定义的JSON格式。
```

### 3.3 多模态提取指令

在提示词中增加图表处理指令：

```markdown
# 多模态提取指令
如果论文中包含以下类型的图表，请额外提取：
- **SEM/TEM图像**: 描述形貌特征（颗粒大小、孔隙结构、表面粗糙度），
  提取尺寸数据，标注与吸附性能的关系
- **吸附等温线图**: 提取qmax值和等温线模型（Langmuir/Freundlich等）
- **动力学曲线**: 提取动力学模型（伪一级/伪二级）和速率常数
- **FTIR/XPS谱图**: 识别关键官能团和化学键信息
- **对比表格**: 提取不同材料/条件下的性能对比数据
```

---

## 四、模块三：原型映射与路由

### 4.1 原型路由配置

**新文件**: `config/prototype_routing.json`

定义如何将提取结果关联到仿生原型：

```json
{
  "prototypes": {
    "mussel-foot-adhesion": {
      "keywords_en": ["mussel", "Mytilus", "DOPA", "foot protein", "byssus"],
      "keywords_cn": ["贻贝", "足丝", "足蛋白", "DOPA"],
      "category": "动物",
      "biomimetic_dimension": "分子仿生",
      "organism": "Mytilus edulis"
    },
    "lotus-leaf": {
      "keywords_en": ["lotus", "Nelumbo", "superhydrophobic", "self-cleaning"],
      "keywords_cn": ["荷叶", "莲花", "超疏水", "自清洁"],
      "category": "植物",
      "biomimetic_dimension": "形态仿生",
      "organism": "Nelumbo nucifera"
    },
    ...（覆盖全部33+个原型）
  },
  "routing_rules": {
    "match_threshold": 2,
    "max_prototypes_per_paper": 3,
    "prefer_direct": true
  }
}
```

### 4.2 原型映射脚本

**新文件**: `scripts/map_to_prototypes.py`

- 读取提取结果 JSON
- 基于关键词匹配将结果关联到原型
- 执行标准词汇映射（vocabulary_mapping.json）
- 按原型聚合提取结果
- 输出 `aggregated/<prototype_id>.json`

---

## 五、模块四：库文件生成器

### 5.1 prototype.md 生成器

**新文件**: `scripts/generate_prototype_md.py`

将聚合后的提取结果转换为 prototype.md：

```
aggregated/<prototype_id>.json
    |
    v
[frontmatter 生成] YAML字段（id, name, category, organism, features, pollutants...）
    |
    v
[正文生成]
  第1节：生物原型简介（从 biomimetic_design_chain 生成）
  第2节：吸附机制详解（从 mechanism_analysis 生成）
  第3节：结构特征（从 structural_features 生成）
  第4节：性能数据表（从 performance_data 生成）
  第5节：仿生设计叙事（从 biomimetic_design_chain 生成）
  第6节：适用场景（从 engineering_constraints 推导）
  第7节：相关原型 + 参考文献
    |
    v
prototypes/<id>/prototype.md
```

### 5.2 feature-mapping.json 更新器

**新文件**: `scripts/update_feature_mapping.py`

- 读取聚合提取结果中的权重证据
- 基于"70%推理+20%文献+10%证据链"原则计算权重
- 增量更新 feature-mapping.json（不覆盖高置信度旧值）
- 输出更新日志

### 5.3 集成入口脚本

**新文件**: `scripts/biomimetic_pipeline.sh`

端到端流水线：

```bash
#!/bin/bash
# Stage 0: PDF 预处理（复用现有 preprocess.py）
# Stage 1: OpenClaw 批量提取（复用现有 multi_worker_extract.sh）
# Stage 2: 原型映射与聚合（新 map_to_prototypes.py）
# Stage 3: 库文件生成（新 generate_prototype_md.py + update_feature_mapping.py）
# Stage 4: 质量报告（新生成 summary report）
```

---

## 六、模块五：项目管理与同步

### 6.1 分支结构

在 Literature-extracting 仓库新建 `biomimetic-extraction` 分支：

```
biomimetic-extraction/
├── docs/
│   ├── biomimetic-extraction-design.md    # 本文档
│   ├── project-board.md                    # 任务看板
│   └── conversation-context.md            # 对话上下文归档
├── schema/
│   └── biomimetic_extraction.schema.json  # 新 Schema
├── prompts/
│   └── biomimetic_extraction_prompt.md    # 新提示词
├── config/
│   ├── vocabulary_mapping.json           # 标准词汇映射
│   └── prototype_routing.json            # 原型路由
├── scripts/
│   ├── map_to_prototypes.py              # 原型映射
│   ├── generate_prototype_md.py          # prototype.md 生成器
│   ├── update_feature_mapping.py         # feature-mapping 更新器
│   └── biomimetic_pipeline.sh           # 端到端入口
└── openclaw.json                          # 更新后的 OpenClaw 配置
```

### 6.2 实施计划（13个任务）

| # | 任务 | 依赖 | 预估 |
|---|------|------|------|
| T1 | 创建 biomimetic-extraction 分支 | - | 5min |
| T2 | 设计并编写 biomimetic_extraction.schema.json | - | 2h |
| T3 | 编写 biomimetic_extraction_prompt.md | T2 | 2h |
| T4 | 创建 vocabulary_mapping.json | - | 1h |
| T5 | 创建 prototype_routing.json | - | 1h |
| T6 | 编写 map_to_prototypes.py | T4, T5 | 2h |
| T7 | 编写 generate_prototype_md.py | T2 | 2h |
| T8 | 编写 update_feature_mapping.py | T2 | 1h |
| T9 | 编写 biomimetic_pipeline.sh | T6-T8 | 1h |
| T10 | 更新 openclaw.json（多模态+仿生配置） | T3 | 30min |
| T11 | 用5篇样本论文做端到端测试 | T9, T10 | 1h |
| T12 | 修复测试发现的问题 | T11 | 1-2h |
| T13 | 推送到GitHub + 项目管理文档 | T12 | 30min |

### 6.3 依赖的外部数据

需要从 Biomimetic-design-library 项目复制/引用：
- `feature-mapping.json` → 用于词汇映射和权重更新
- `taxonomy/*.md` → 用于标准词汇验证
- `templates/prototype-template.md` → 用于 prototype.md 格式参考
- `prototypes/` 目录 → 写入目标

---

## 七、关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| Schema 格式 | 严格 JSON Schema | OpenClaw 内置 Schema 校验，确保输出一致性 |
| 提示词长度 | 400-500行 | 比原版（332行）更详细，因为需要覆盖仿生设计全维度 |
| 词汇映射 | 静态映射表 + LLM fallback | 标准词汇优先匹配，无法匹配时LLM推理映射 |
| 多模态 | 启用 | 341篇论文含大量图表/SEM，多模态可提取额外30%数据 |
| 原型映射 | 关键词匹配 | 简单可靠，后续可升级为语义匹配 |
| 增量更新 | 置信度优先 | 新数据只在置信度≥旧数据时覆盖 |
| 库同步 | 脚本直写 | generate_prototype_md.py 直接写入 prototype 目录 |

---

## 八、待确认问题

1. Literature-extracting 项目的 OpenClaw 配置中，哪些模型可用于多模态？需要确认 API key 和额度。
2. 仿生设计库的 feature-mapping.json 是否需要在 Literature-extracting 中保留一份副本？还是通过路径引用？
3. 提取结果的中间 JSON 文件是否需要长期保留？还是只保留最终的 prototype.md 和更新后的 feature-mapping.json？
4. 是否需要支持"断点续传"（上次提取到第N篇，下次从N+1继续）？
