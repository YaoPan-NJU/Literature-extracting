# 仿生设计文献提取 -- 对话上下文归档

> 本文档记录了从 Biomimetic-design-library 项目到 Literature-extracting 改造的完整上下文。
> 目的：跨设备接力时，新会话可快速恢复项目认知。
> 最后更新：2026-06-04

---

## 一、项目关系

```
Biomimetic-design-library (仿生设计库)
├── feature/biomimetic-story-v2 -- 4阶段Python流水线 + 30个prototype.md
├── project/tracking -- 项目管理文档 + 完整对话上下文
└── 需求: 需要从341篇文献中提取深层仿生设计知识

Literature-extracting (文献提取工具)
├── main -- 原始版本，面向近海油气田PFAS提取
└── biomimetic-extraction -- 新分支，改造为仿生设计知识提取
    └── 产出直接写入 Biomimetic-design-library
```

## 二、核心背景

### 2.1 仿生设计库当前状态
- 30个 prototype.md 已生成，但仿生叙事章节100%空白
- feature-mapping.json 156条权重已更新，但缺乏实证支撑
- 当前 Python 流水线（Phase 1-4）验证了技术可行性，但产出质量不够
- 综合完成度约 25-30%

### 2.2 为什么需要 Literature-extracting
- OpenClaw 的多代理并行能力更强
- JSON Schema 严格校验确保输出一致性
- 已有的批处理基础设施更成熟（687行并发脚本）
- 多模态能力可提取图表/SEM数据

### 2.3 改造的核心挑战
- 提取 Schema 从"PFAS吸附"完全重写为"仿生设计全维度"
- 提示词从"识别污染物"改为"提取仿生设计逻辑链"
- 需要新增原型映射、词汇映射、库文件生成能力
- 输出必须直接服务于 prototype.md 和 feature-mapping.json

## 三、关键用户偏好

- **对话语言**: 中文
- **效率优先**: API额度充足
- **设计优先**: 一切以仿生库的质量为上
- **跨设备工作**: 所有上下文、计划、进度同步到GitHub
- **提取重点**: 仿生设计逻辑链 > 性能数据 > 结构特征 > 工程约束

## 四、已完成的工作

1. Biomimetic-design-library 的4阶段流水线全部跑通（Phase 1-4）
2. Literature-extracting 项目已完成探索和分析
3. 改造设计文档已撰写（本文档同目录的 design.md）
4. biomimetic-extraction 分支已创建
5. 项目管理看板已创建

## 五、下一步工作

按设计文档的实施计划（13个任务），从 T2（Schema设计）开始。

### 关键参考文件位置
- 设计文档: `docs/2026-06-04-biomimetic-extraction-design.md`
- 项目管理: `docs/project-board.md`
- 仿生库 Schema 参考: `../Biomimetic-design-library/feature-mapping.json`
- 仿生库模板参考: `../Biomimetic-design-library/templates/prototype-template.md`
- 仿生库分类体系: `../Biomimetic-design-library/taxonomy/*.md`
- 原始提取 Schema: `schema/jjj_literature_extraction.schema.json`
- 原始提示词: `prompts/jjj_single_agent_extraction_prompt.md`
- OpenClaw 配置: `openclaw.json`

## 六、环境信息

- **Python**: 3.9.6 (macOS)
- **pip**: 需 `pip3` 或 `python3 -m pip`
- **OpenClaw**: 配置文件为 `openclaw.json`
- **API Providers**: GPT-4o, Claude, qwen 系列（多模态可选）
- **仿生库 API**: coding_plan(qwen3.6-plus), dashscope(qwen3.7-max), mimo(Mimo-v2.5)
