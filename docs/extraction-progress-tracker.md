# 提参进度记录

> 每次开始新批次前先读这份文档。它由 `scripts/update_extraction_progress_doc.py` 从统一 manifest 生成。

## 当前摘要

| 项目 | 值 |
| --- | --- |
| 文档更新时间 | 2026-06-10T14:22:08+08:00 |
| manifest 生成时间 | 2026-06-10T14:22:08 |
| 文献库总量 | 33 |
| 已提参 | 33 |
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
| 英文文献 | 0 | 0 | 0 | n/a |
| 中文文献 | 0 | 0 | 0 | n/a |
| 专利 | 33 | 33 | -33 | 100.0% |
| 书本/中文 | 0 | 0 | 0 | n/a |
| 书本/英文 | 0 | 0 | 0 | n/a |

## 输出 JSON 计数

| 输出目录 | JSON 数量 |
| --- | --- |
| outputs/extractions/专利 | 73 |
| outputs/extractions/中文文献 | 2 |
| outputs/extractions/书本 | 0 |
| outputs/extractions/标准 | 3 |
| outputs/extractions/第三波 | 63 |
| outputs/extractions/第二波 | 108 |
| outputs/extractions/英文文献 | 0 |
| outputs/extractions/论文 | 308 |

## 最近已提文献

| 时间 | 分类 | 模型 | 文献 |
| --- | --- | --- | --- |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN113975979B-超疏水-油水分离-膜-泡沫.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114682215A-仿生-重金属-吸附-废水.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114772567A-羟基磷灰石-吸附-除氟.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114832781A-超疏水-油水分离-吸附-海绵.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114849640A-羟基磷灰石-吸附-染料.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114849661A-聚多巴胺-吸附-膜.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114873705A-壳聚糖-磁性-重金属-废水.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114874407A-超疏水-海绵.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114887602A-聚多巴胺-纤维素-吸附-除磷.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114920307A-海藻酸钠-纤维素-吸附-水处理.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN114988519A-油水分离-废水-膜-泡沫.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN115040496A-聚多巴胺-壳聚糖-吸附.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN115044085A-超疏水-膜.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2022-CN115055171A-聚多巴胺-磁性-重金属-吸附.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2024-CN117654453A-壳聚糖-海藻酸钠-磁性-生物基.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2025-CN119488883A-壳聚糖-海藻酸钠-纤维素-生物基.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2025-CN119524803A-生物基-吸附.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2025-CN120325258A-生物基-吸附-染料.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2025-CN121130847A-壳聚糖-纤维素-生物基-MOF.pdf |
| 2026-06-10T14:22:08 | 专利 | unified | 2026-CN121715049A-仿生-膜.pdf |

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
