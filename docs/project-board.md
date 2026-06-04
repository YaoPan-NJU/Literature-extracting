# 仿生设计文献提取 -- 项目管理看板

> 分支: biomimetic-extraction
> 基础: Literature-extracting (OpenClaw)
> 最后更新: 2026-06-04

---

## 任务状态

| # | 任务 | 状态 | 依赖 | 说明 |
|---|------|------|------|------|
| T1 | 创建分支 | ✅ 完成 | - | biomimetic-extraction 分支已创建 |
| T2 | Schema 设计 | ⏳ 待办 | - | biomimetic_extraction.schema.json |
| T3 | 提示词设计 | ⏳ 待办 | T2 | biomimetic_extraction_prompt.md |
| T4 | 词汇映射表 | ⏳ 待办 | - | vocabulary_mapping.json |
| T5 | 原型路由配置 | ⏳ 待办 | - | prototype_routing.json |
| T6 | 原型映射脚本 | ⏳ 待办 | T4,T5 | map_to_prototypes.py |
| T7 | prototype.md生成器 | ⏳ 待办 | T2 | generate_prototype_md.py |
| T8 | feature-mapping更新器 | ⏳ 待办 | T2 | update_feature_mapping.py |
| T9 | 端到端流水线脚本 | ⏳ 待办 | T6-T8 | biomimetic_pipeline.sh |
| T10 | OpenClaw配置更新 | ⏳ 待办 | T3 | openclaw.json 多模态+仿生 |
| T11 | 样本端到端测试 | ⏳ 待办 | T9,T10 | 5篇论文完整测试 |
| T12 | 问题修复 | ⏳ 待办 | T11 | 修复测试发现的问题 |
| T13 | 推送+文档 | ⏳ 待办 | T12 | 推送到GitHub |

---

## 下一步行动

在新设备上接力时，从 T2（Schema设计）开始。

### 快速恢复

```bash
git clone https://github.com/YaoPan-NJU/Literature-extracting.git
cd Literature-extracting
git checkout biomimetic-extraction

# 阅读设计文档
cat docs/2026-06-04-biomimetic-extraction-design.md

# 阅读上下文
cat docs/conversation-context.md

# 开始实施（从T2开始）
# Schema 参考: docs/2026-06-04-biomimetic-extraction-design.md 第二节
# 原型模板参考: 从 Biomimetic-design-library 项目的 templates/prototype-template.md
```

---

## 外部依赖

需要从 Biomimetic-design-library 项目获取的参考文件：
- `feature-mapping.json` -- 标准特征标签定义（27个标签）
- `taxonomy/organisms.md` -- 生物分类
- `taxonomy/pollutants.md` -- 污染物分类
- `taxonomy/mechanisms.md` -- 机制分类
- `templates/prototype-template.md` -- prototype.md 格式模板

这些文件位于: https://github.com/YaoPan-NJU/Biomimetic-design-library

---

## 关联项目

- **Biomimetic-design-library**: 仿生设计库主项目
  - 分支 `feature/biomimetic-story-v2`: 包含 Python 流水线 + 30个prototype.md
  - 分支 `project/tracking`: 项目管理文档 + 对话上下文
  - 本项目的提取结果将直接写入该库
