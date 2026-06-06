# 仿生提参 — Pilot 目标与执行计划

> 创建时间: 2026-06-06 00:25
> 执行者: Claude Code (autonomous)
> 汇报方式: iMessage → +8615895848729

---

## 阶段 1: 小批量验证 (Pilot 5 篇)

**目标**: 验证 LitExtract 仿生提参端到端流水线可用

**测试 PDF** (5 篇，覆盖 5 个不同仿生维度):

| # | 文件 | 组别 | 仿生维度 | 选择理由 |
|---|------|------|----------|----------|
| 1 | `2019-张-壳聚糖-吸附.pdf` | 第1组-配位螯合 | 壳聚糖吸附重金属 | 中文论文，有明确 qmax 数据 |
| 2 | `2020-杨-超疏水-油水分离.pdf` | 第2组-超疏水 | 超疏水油水分离 | 中文论文，荷叶仿生 |
| 3 | `2020-Xu-mof-metal-organic-adsorption-heavy-metal-review.pdf` | 第3组-多孔结构 | MOF 吸附重金属 | 英文综述，数据密集 |
| 4 | `2017-李-牡蛎壳-生物炭-吸附-废水.pdf` | 第4组-生物矿化 | 牡蛎壳生物炭 | 中文论文，生物矿化代表 |
| 5 | `2020-Xu-chitosan-cellulose-nanocellulose-adsorption.pdf` | 第5组-纤维结构 | 壳聚糖纤维素 | 英文论文，纤维结构代表 |

**验收标准**:
- [ ] 5/5 成功提取 JSON
- [ ] 每篇 JSON 能通过 schema 校验
- [ ] 每篇至少有 3 条 knowledge_items
- [ ] qmax 等数值保留原文精度（不被取整）
- [ ] evidence 字段有页码定位
- [ ] iMessage 心跳汇报正常工作

**失败判定**: 3/5 以上失败 → 停下修正，iMessage 通知

---

## 阶段 2: 全量提参 (341 篇)

**前提**: 阶段 1 全部验收通过

**目标**: 对全部 341 篇 PDF 完成结构化提参

**执行方式**:
- `multi_worker_extract.sh --workers 2 --mode multimodal`
- 双路: bailian/qwen3.6-plus + mimo/mimo-v2.5
- 心跳: 每小时整点 iMessage 汇报
- 错误: 即时 iMessage 通知

**验收标准**:
- [ ] 成功率 ≥ 85%
- [ ] 每篇平均 ≥ 5 条 knowledge_items
- [ ] 所有数值数据保留原文精度
- [ ] iMessage 心跳汇报正常

---

## 执行日志

(自动追加)
