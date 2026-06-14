# 提参进度记录

> 每次开始新批次前先读这份文档。它由 `scripts/update_extraction_progress_doc.py` 从统一 manifest 生成。

## 当前摘要

| 项目 | 值 |
| --- | --- |
| 文档更新时间 | 2026-06-14T19:30:26+08:00 |
| manifest 生成时间 | 2026-06-14T19:30:26 |
| 文献库总量 | 4841 |
| 已提参 | 4836 |
| 剩余 | 5 |
| 总进度 | 99.90% |

## 权威文件

| 用途 | 文件 |
| --- | --- |
| 统一成功清单 | `outputs/extractions/manifests/success.tsv` |
| 统一剩余队列 | `outputs/extractions/manifests/remaining_queue.tsv` |
| 统计摘要 | `outputs/extractions/manifests/progress.json` |
| 统一输出根目录 | `outputs/extractions/` |
| 批次运行目录 | `/tmp/openclaw/litextract_runs/<run_id>/`，保存 raw、logs、prompts 和本批 manifest |

## 分类进度

| 分类 | 总数 | 已提参 | 剩余 | 进度 |
| --- | --- | --- | --- | --- |
| 英文文献 | 4368 | 4368 | 0 | 100.00% |
| 中文文献 | 197 | 195 | 2 | 98.98% |
| 专利 | 89 | 88 | 1 | 98.88% |
| 书本/中文 | 14 | 13 | 1 | 92.86% |
| 书本/英文 | 173 | 172 | 1 | 99.42% |

## 输出 JSON 计数

| 输出目录 | JSON 数量 |
| --- | --- |
| outputs/extractions/英文文献/json | 4368 |
| outputs/extractions/中文文献/json | 196 |
| outputs/extractions/专利/json | 88 |
| outputs/extractions/书本/中文/json | 13 |
| outputs/extractions/书本/英文/json | 172 |

## 最近已提文献

| 时间 | 分类 | 模型 | 文献 |
| --- | --- | --- | --- |
| 2026-06-14T19:30:26 | 中文文献 | unified | 盘点全球重大海上石油平台溢油事故.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 相选择性超分子凝油剂的研究现状.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 石油勘探开发区风险评估及对策研究.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 移动船舶微波通信关键技术研究.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 絮凝旋流-UBD菌深度降解组合工艺脱除海上采油污水石油烃研究.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 自航式甲板驳船用于海上油田废弃物处理中心.pdf |
| 2026-06-14T19:30:26 | 书本/中文 | unified | 船舶辅机 4 船用泵分油机与防污染技术 (上海海运学院轮机系辅机教研组编) (z-library.sk, 1lib.sk, z-lib.sk).pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 船舶避碰技术在海上石油平台附近水域的应用与优化.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 论中国海上石油开发环境污染法律救济机制的完善.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 论我国海洋油污生态损害赔偿制度的完善.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 论我国海洋油污生态损害赔偿制度的完善_1.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 论海上石油污染与中国海洋环保法制.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 辽东湾油类污染物分布特征及生态风险评价.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 辽东湾海水中PAHs分布与来源特征及风险评估.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 近海石油开发所致海洋环境污染损害赔偿制度研究.pdf |
| 2026-06-14T19:30:26 | 专利 | unified | 适用于大中型船舶柴油机含硫废气处理的海水脱硫系统.pdf |
| 2026-06-14T19:30:26 | 专利 | unified | 遏制漂浮在海面上的污染油或类似污染物的作业方法.pdf |
| 2026-06-14T19:30:26 | 专利 | unified | 铝材加工油气回收处理的净化设备.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 集团型石油石化企业设备设施分级研究.pdf |
| 2026-06-14T19:30:26 | 中文文献 | unified | 震源船通过海上石油平台的操作方法及注意事项.pdf |

## 下一批候选

下面是 `remaining_queue.tsv` 当前队首的 50 篇。每批只跑几十篇时，优先从这里取，避免跳号和重复。

| 序号 | 分类 | 待提文献 |
| --- | --- | --- |
| 1 | 书本/英文 | Risk Management in the Oil and Gas Industry Offshore and Onshore Concepts and Case Studies (Gerardo Portela Da Ponte Jr) (z-library.sk, 1lib.sk, z-lib.sk).pdf |
| 2 | 专利 | Working platform for oil drilling operations in ice covered sea areas.pdf |
| 3 | 书本/中文 | 海上油气田环境保护基础知识手册.pdf |
| 4 | 中文文献 | 海上溢油风险分析及处置技术研究.pdf |
| 5 | 中文文献 | 海上石油锚机液压制动器建模与仿真分析.pdf |

## 开工流程

1. 先合并最新批次结果：`python3 scripts/merge_results.py`
2. 再刷新本文档：`python3 scripts/update_extraction_progress_doc.py`
3. 阅读本文档的“当前摘要”“最近已提文献”“下一批候选”。
4. 启动新批次时用 `--limit N` 控制几十篇规模。
5. 批次结束后重复第 1 步和第 2 步，让下一次开工看到最新状态。

## 注意事项

- `success.tsv` 和 `remaining_queue.tsv` 是避免遗漏、重复的主依据。
- 启动新任务前用 `--workers 1|2|3` 选择并发路数。
- `--workers 1` 只用 `mimo/mimo-v2.5`；`--workers 2` 用 `bailian/qwen3.6-plus` + `mimo/mimo-v2.5`；`--workers 3` 用 dashscope + bailian + mimo。
- 需要每路固定篇数时，用 `--per-worker-limit N`，例如三路各 99 篇：`bash scripts/launch_multi_extract.sh --workers 3 --per-worker-limit 99`。
- 英文批量提参默认读取 `workspace/en_pdfs/` hardlink 目录；不要直接用 symlink 目录喂给 OpenClaw。
- `scripts/multi_worker_extract.sh` 会跳过 `outputs/extractions/` 中已存在的有效 JSON。
- `outputs/extractions/` 是长期保留目录；批次运行目录可在合并后清理。
- 多 worker 并发必须使用独立 `--session-id`，当前脚本已按 worker 和批次号隔离。
