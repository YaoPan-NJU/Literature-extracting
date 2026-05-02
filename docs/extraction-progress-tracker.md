# 提参进度记录

> 每次开始新批次前先读这份文档。它由 `scripts/update_extraction_progress_doc.py` 从统一 manifest 生成。

## 当前摘要

| 项目 | 值 |
| --- | --- |
| 文档更新时间 | 2026-05-02T10:34:01+08:00 |
| manifest 生成时间 | 2026-05-02T10:31:54 |
| 文献库总量 | 4841 |
| 已提参 | 86 |
| 剩余 | 4756 |
| 总进度 | 1.8% |

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
| 英文文献 | 4368 | 85 | 4283 | 1.9% |
| 中文文献 | 197 | 0 | 197 | 0.0% |
| 专利 | 89 | 0 | 89 | 0.0% |
| 书本/中文 | 14 | 1 | 13 | 7.1% |
| 书本/英文 | 173 | 0 | 173 | 0.0% |

## 输出 JSON 计数

| 输出目录 | JSON 数量 |
| --- | --- |
| outputs/extractions/专利 | 0 |
| outputs/extractions/中文文献 | 0 |
| outputs/extractions/书本 | 1 |
| outputs/extractions/英文文献 | 85 |

## 最近已提文献

| 时间 | 分类 | 模型 | 文献 |
| --- | --- | --- | --- |
| 2026-05-02T10:31:53 | 英文文献 | mimo/mimo-v2.5-pro | A-multi-objective-optimisation-model-to-reduce-greenhouse_2021_Journal-of-Cl.pdf |
| 2026-05-02T10:31:53 | 英文文献 | mimo/mimo-v2.5-pro | A-multi-taxonomic-framework-for-assessing-relative-petro_2021_Science-of-The.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-multivariate-study-of-backpulsing-for-membrane_2021_Journal-of-Environment.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-negotiation-support-system-for-resolving-an-interna_2014_Environmental-Mod.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-new-actuator-disc-model-for-oscillatory-and-steady-flow-that-_2024_Ocean-E.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-new-approach-for-assessing-the-radioecological-risk-associ_2025_Marine-Pol.pdf |
| 2026-05-02T10:31:53 | 英文文献 | mimo/mimo-v2.5-pro | A-new-approach-in-the-optimal-site-selection-of-landfills-for-dr_2021_Chemos.pdf |
| 2026-05-02T10:31:53 | 英文文献 | mimo/mimo-v2.5-pro | A-new-imperative-for-improving-management-of-large-_2002_Ocean---Coastal-Man.pdf |
| 2026-05-02T10:31:53 | 英文文献 | mimo/mimo-v2.5-pro | A-new-spatial-estimation-model-and-source-apportionment-of_2023_Science-of-T.pdf |
| 2026-05-02T10:31:53 | 英文文献 | mimo/mimo-v2.5-pro | A-new-stage-in-China-s-marine-management_1993_Ocean---Coastal-Management.pdf |
| 2026-05-02T10:31:53 | 英文文献 | mimo/mimo-v2.5-pro | A-new-stochastic-oil-spill-risk-assessment-model-for-Pers_2019_Marine-Pollut.pdf |
| 2026-05-02T10:31:53 | 英文文献 | mimo/mimo-v2.5-pro | A-non-contacting-leak-fault-diagnosis-method-for-subsea-Christ_2023_Ocean-En.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-novel-approach-to-rating-SMEs--environmental-performan_2023_Ecological-Ind.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-novel-bioprospecting-strategy-via-13C-based-high-throug_2024_Science-of-Th.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-pH-responsive-phosphoprotein-washing-fluid-for-the-removal-of-p_2023_Chemo.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-parametric-analysis-of-the-influence-of-the-internal-slug-f_2019_Ocean-Eng.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-particle-finite-element-model-to-simulate-pipe-soil-interacti_2025_Ocean-E.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-people-first-approach-to-achieving-global-climate-and-nature_2025_One-Eart.pdf |
| 2026-05-02T10:31:53 | 英文文献 | unknown | A-perspective-on-oil-spills--What-we-should-have-lear_2021_Ocean---Coastal-M.pdf |
| 2026-05-02T10:31:53 | 书本/中文 | unified | haishang_oilfield_env_handbook.pdf |

## 下一批候选

下面是 `remaining_queue.tsv` 当前队首的 50 篇。每批只跑几十篇时，优先从这里取，避免跳号和重复。

| 序号 | 分类 | 待提文献 |
| --- | --- | --- |
| 1 | 中文文献 | 3 in 1智能测温系统在海上某平台的首次应用研究.pdf |
| 2 | 英文文献 | A-hybrid-system-based-on-the-combination-of-adsorption--elec_2024_Journal-of.pdf |
| 3 | 英文文献 | A-methodology-for-Response-Gap-Analysis-in-offshore-oi_2022_Marine-Pollution.pdf |
| 4 | 英文文献 | A-novel-dynamic-parameter-method--DPM--based-on-ANN-for-safe_2023_Ocean-Engi.pdf |
| 5 | 英文文献 | A-novel-environment-adaptive-dual-light-image-enhancemen_2024_Marine-Polluti.pdf |
| 6 | 英文文献 | A-novel-failure-mode-and-effects-analysis-model-enhanced-with-sy_2026_Ocean-.pdf |
| 7 | 英文文献 | A-novel-sub-seabed-CO2-release-experiment-informin_2015_International-Journa.pdf |
| 8 | 英文文献 | A-novel-wave-energy-converter-with-an-extended-operational-r_2026_Ocean-Engi.pdf |
| 9 | 英文文献 | A-numerical-fire-simulation-approach-for-effectiveness-analysis_2018_Ocean-E.pdf |
| 10 | 英文文献 | A-numerical-model-for-geometrically-nonlinear-analysis-of-a_2022_Ocean-Engin.pdf |
| 11 | 英文文献 | A-numerical-study-on-water-wetting-associated-with-the-inte_2016_Ocean-Engin.pdf |
| 12 | 英文文献 | A-pipeline-leakage-sensing-method-for-offshore-platform-thr_2025_Ocean-Engin.pdf |
| 13 | 英文文献 | A-power-series-method-for-static-and-dynamic-analysis-of-o_2022_Ocean-Engine.pdf |
| 14 | 英文文献 | A-practical-assesment-of-CCUS-opportunities-in-the-Southe_2025_Journal-of-Cl.pdf |
| 15 | 英文文献 | A-preliminary-assessment-on-CO2-storage-capacity-_2011_International-Journal.pdf |
| 16 | 英文文献 | A-primer-on-the--blue-economy---Promise--pitfalls--and-pathway_2022_One-Eart.pdf |
| 17 | 英文文献 | A-probabilistic-ecological-risk-model-for-_2017_Journal-of-Environmental-Che.pdf |
| 18 | 英文文献 | A-probabilistic-framework-for-risk-management-and-_2022_Process-Safety-and-E.pdf |
| 19 | 英文文献 | A-proposed-interdisciplinary-framework-for-the-environmenta_2018_Ocean---Coa.pdf |
| 20 | 英文文献 | A-qualitative-analysis-of-key-stakeholders--perception_2025_International-Jo.pdf |
| 21 | 英文文献 | A-quantitative-safety-assessment-for-offshore-equipment-evaluat_2024_Ocean-E.pdf |
| 22 | 英文文献 | A-rapid-assessment-of-litter-magnitudes-and-impacts-along-_2021_Marine-Pollu.pdf |
| 23 | 英文文献 | A-rapid-change-in-microbial-communities-of-the-shale-gas_2021_Science-of-The.pdf |
| 24 | 英文文献 | A-regional-collaborative-approach-in-transboundary-polluti_2010_Ocean---Coas.pdf |
| 25 | 英文文献 | A-regional-parameterisation-method-for-oil-spill-susceptibi_2020_Ocean-Engin.pdf |
| 26 | 英文文献 | A-resilient-approach-of-safety-assessment-for-confined-spac_2022_Ocean-Engin.pdf |
| 27 | 英文文献 | A-retrospective-analysis-of-trace-metals--C--N-and-diatom-_2004_Marine-Pollu.pdf |
| 28 | 英文文献 | A-review-of-CO2-injection-projects-in-the-Brazili_2024_International-Journal.pdf |
| 29 | 英文文献 | A-review-of-NOx-and-SOx-emission-reduction-technologies-fo_2021_Science-of-T.pdf |
| 30 | 英文文献 | A-review-of-atmospheric-carbon-dioxide-sequestration-_2024_Carbon-Capture-Sc.pdf |
| 31 | 英文文献 | A-review-of-biophysical-and-socio-economic-effects-of-u_2016_Journal-of-Envi.pdf |
| 32 | 英文文献 | A-review-of-current-practices-for-the-completion--stimulation-_1981_Ocean-Ma.pdf |
| 33 | 英文文献 | A-review-of-ecological-impacts-of-oil-and-gas-development_2004_Ocean---Coast.pdf |
| 34 | 英文文献 | A-review-of-end-life-management-options-for-marine-struct_2022_Cleaner-Engin.pdf |
| 35 | 英文文献 | A-review-of-energy-extraction-from-wind-and-ocean--Technolog_2023_Ocean-Engi.pdf |
| 36 | 英文文献 | A-review-of-floating-renewable-energy-technologies-for-sus_2026_Ocean-Engine.pdf |
| 37 | 英文文献 | A-review-of-geospatial-technologies-for-improving-Marine_2023_Ocean---Coasta.pdf |
| 38 | 英文文献 | A-review-of-global-gas-flaring-and-venting-and-_2016_International-Journal-o.pdf |
| 39 | 英文文献 | A-review-of-graphene-based-semiconductors-for-photocatalytic-deg_2022_Chemos.pdf |
| 40 | 英文文献 | A-review-of-marine-photovoltaic-power-plants--Status--prospec_2026_Ocean-Eng.pdf |
| 41 | 英文文献 | A-review-of-microalgae-based-biorefineries-approach-f_2022_Journal-of-Enviro.pdf |
| 42 | 英文文献 | A-review-of-nanotechnological-applications-to-dete_2021_Environmental-Techno.pdf |
| 43 | 英文文献 | A-review-of-offshore-decommissioning-regulations-in-five-cou_2018_Ocean-Engi.pdf |
| 44 | 英文文献 | A-review-of-oil-spill-research-in-Canadian-Arctic-ma_2024_Marine-Pollution-B.pdf |
| 45 | 英文文献 | A-review-of-oily-wastewater-treatment-using-ultrafiltra_2020_Journal-of-Wate.pdf |
| 46 | 英文文献 | A-review-of-organophosphonates--their-natural-and-anthropog_2024_Journal-of-.pdf |
| 47 | 英文文献 | A-review-of-polymer-nanofibres-by-electrospinning-and-their_2016_Marine-Poll.pdf |
| 48 | 英文文献 | A-review-of-progress-and-challenges-in-research-on-the-e_2024_Journal-of-Cle.pdf |
| 49 | 英文文献 | A-review-of-radioactivity-in-the-Gulf-region_2020_Marine-Pollution-Bulletin.pdf |
| 50 | 英文文献 | A-review-of-renewable-energy-resources-in-_2024_Case-Studies-in-Chemical-and.pdf |

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
- `scripts/multi_worker_extract.sh` 会跳过 `outputs/extractions/` 中已存在的有效 JSON。
- `outputs/extractions/` 是长期保留目录；批次运行目录可在合并后清理。
- 多 worker 并发必须使用独立 `--session-id`，当前脚本已按 worker 和批次号隔离。
