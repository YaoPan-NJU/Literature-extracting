# 提参进度记录

> 每次开始新批次前先读这份文档。它由 `scripts/update_extraction_progress_doc.py` 从统一 manifest 生成。

## 当前摘要

| 项目 | 值 |
| --- | --- |
| 文档更新时间 | 2026-06-06T17:26:45+08:00 |
| manifest 生成时间 | 2026-06-06T17:26:31.917090 |
| 文献库总量 | 215 |
| 已提参 | 215 |
| 剩余 | 0 |
| 总进度 | 100.0% |

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
| 论文 | 215 | 215 | 0 | 100.0% |
| 英文文献 | 0 | 0 | 0 | n/a |
| 中文文献 | 0 | 0 | 0 | n/a |
| 专利 | 0 | 0 | 0 | n/a |
| 书本 | 0 | 0 | 0 | n/a |

## 输出 JSON 计数

| 输出目录 | JSON 数量 |
| --- | --- |
| outputs/extractions/专利 | 0 |
| outputs/extractions/中文文献 | 0 |
| outputs/extractions/书本 | 0 |
| outputs/extractions/英文文献 | 0 |
| outputs/extractions/论文 | 215 |

## 最近已提文献

| 时间 | 分类 | 模型 | 文献 |
| --- | --- | --- | --- |
| 2026-06-06T17:26:31.916877 | 论文 | mimo-v2.5 | 2023-胡-壳聚糖-纤维素-吸附-重金属 |
| 2026-06-06T17:26:31.916882 | 论文 | mimo-v2.5 | 2024-Bao-wastewater-removal-review |
| 2026-06-06T17:26:31.916887 | 论文 | mimo-v2.5 | 2024-Hsu-chitosan-adsorption-heavy-metal-review |
| 2026-06-06T17:26:31.916892 | 论文 | mimo-v2.5 | 2024-Jaffar-membrane-hydroxyapatite-adsorption-adsorbent-review |
| 2026-06-06T17:26:31.916898 | 论文 | mimo-v2.5 | 2024-Jiang-cellulose-magnetic-mof-metal-organic-review |
| 2026-06-06T17:26:31.916903 | 论文 | mimo-v2.5 | 2024-Kang-superhydrophobic-hydrophobic-self-cleaning-separation |
| 2026-06-06T17:26:31.916908 | 论文 | mimo-v2.5 | 2024-Liu-porous-hierarchical-adsorption-wastewater |
| 2026-06-06T17:26:31.916914 | 论文 | mimo-v2.5 | 2024-Novair-wastewater-water-treatment-removal |
| 2026-06-06T17:26:31.916919 | 论文 | mimo-v2.5 | 2024-Omar-superhydrophobic-hydrophobic-separation-membrane-review |
| 2026-06-06T17:26:31.916924 | 论文 | mimo-v2.5 | 2024-Research-cellulose-nanocellulose-mof-biochar-review |
| 2026-06-06T17:26:31.916929 | 论文 | mimo-v2.5 | 2024-Rev-hierarchical-bone-nanofiber-review |
| 2026-06-06T17:26:31.916945 | 论文 | mimo-v2.5 | 2024-Sciences-separation-adsorbent-review |
| 2026-06-06T17:26:31.916960 | 论文 | mimo-v2.5 | 2024-Technol-superhydrophobic-hydrophobic-biochar-wastewater-review |
| 2026-06-06T17:26:31.916969 | 论文 | mimo-v2.5 | 2024-Xiong-superhydrophobic-hydrophobic-separation-wastewater-review |
| 2026-06-06T17:26:31.916976 | 论文 | mimo-v2.5 | 2025-Azad-polydopamine-dopamine-superhydrophobic-hydrophobic-review |
| 2026-06-06T17:26:31.916983 | 论文 | mimo-v2.5 | 2025-Dong-alginate-adsorption-heavy-metal-dye-review |
| 2026-06-06T17:26:31.916989 | 论文 | mimo-v2.5 | 2025-Foorginezhad-membrane-heavy-metal-water-treatment-removal-review |
| 2026-06-06T17:26:31.916995 | 论文 | mimo-v2.5 | 2025-Gao-separation-membrane-review |
| 2026-06-06T17:26:31.917001 | 论文 | mimo-v2.5 | 2025-Liu-hydrophobic-antifouling-separation-review |
| 2026-06-06T17:26:31.917007 | 论文 | mimo-v2.5 | 2025-Wang-superhydrophobic-hydrophobic-self-cleaning-separation-review |

## 下一批候选

下面是 `remaining_queue.tsv` 当前队首的 50 篇。每批只跑几十篇时，优先从这里取，避免跳号和重复。

| 序号 | 分类 | 待提文献 |
| --- | --- | --- |

## 开工流程

1. 先合并最新批次结果：`python3 scripts/merge_results.py`
2. 再刷新本文档：`python3 scripts/update_extraction_progress_doc.py`
3. 阅读本文档的“当前摘要”“最近已提文献”“下一批候选”。
4. 启动新批次时用 `--limit N` 控制几十篇规模。
5. 批次结束后重复第 1 步和第 2 步，让下一次开工看到最新状态。

## 注意事项

- `success.tsv` 和 `remaining_queue.tsv` 是避免遗漏、重复的主依据。
- 启动新任务前用 `--workers 1|2|3` 选择并发路数。
- `--workers 1` 只用 mimo；`--workers 2` 用 bailian + mimo；`--workers 3` 用 dashscope + bailian + mimo。
- 需要每路固定篇数时，用 `--per-worker-limit N`，例如三路各 99 篇：`bash scripts/launch_multi_extract.sh --workers 3 --per-worker-limit 99`。
- 英文批量提参默认读取 `workspace/en_pdfs/` hardlink 目录；不要直接用 symlink 目录喂给 OpenClaw。
- `scripts/multi_worker_extract.sh` 会跳过 `outputs/extractions/` 中已存在的有效 JSON。
- `outputs/extractions/` 是长期保留目录；批次运行目录可在合并后清理。
- 多 worker 并发必须使用独立 `--session-id`，当前脚本已按 worker 和批次号隔离。
