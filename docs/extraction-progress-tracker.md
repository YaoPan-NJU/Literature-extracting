# 提参进度记录

> 每次开始新批次前先读这份文档。它由 `scripts/update_extraction_progress_doc.py` 从统一 manifest 生成。

## 当前摘要

| 项目 | 值 |
| --- | --- |
| 文档更新时间 | 2026-05-02T17:01:55+08:00 |
| manifest 生成时间 | 2026-05-02T17:01:55 |
| 文献库总量 | 4841 |
| 已提参 | 240 |
| 剩余 | 4602 |
| 总进度 | 5.0% |

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
| 英文文献 | 4368 | 239 | 4129 | 5.5% |
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
| outputs/extractions/英文文献 | 239 |

## 最近已提文献

| 时间 | 分类 | 模型 | 文献 |
| --- | --- | --- | --- |
| 2026-05-02T17:01:55 | 英文文献 | unified | Aerosol-characteristics-and-types-in-the-marine-environments-_2023_Atmospher.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Aerosol-composition-and-sources-during-high-and-low-pollu_2016_Atmospheric-R.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Africa-s-protected-areas-are-brightening-at-night--A-long-_2021_Global-Envir.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | After-decades-of-stressor-research-in-urban-estuarine-ecos_2019_Science-of-T.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Aged-diesel-and-heavy-metal-pollution-in-the-Arctic_2021_Science-of-The-Tota.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Agricultural-HDPE-pyrolysis-for-environmental-management_2026_Journal-of-Env.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Agro-environmental-sustainability-and-financial-cost-of-_2020_Agricultural-W.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Aguirre-Martinez 等 - 2015 - Applicative implications of Carcinus maenas and Ruditapes philippinarum in biomonitoring studies aft.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Agwa 等 - 2013 - Fate of drilling waste discharges and ecological risk assessment in the Egyptian Red Sea an aquival.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Ahmad 等 - 2021 - Fate of radium on the discharge of oil and gas produced water to the marine environment.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Air-pollution-from-the-Los-Angeles-and-Long-Beach-Ports_2025_Atmospheric-Env.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Air-pollution-from-unconventional-oil-and-gas-developme_2024_Atmospheric-Env.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Air-pollution-inputs-to-the-Mojave-Desert-by-fusing-surface-mob_2020_Atmosph.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Air-pollution-scenario-over-Pakistan--Characterization-and-_2021_Remote-Sens.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Air-pollution-trends-over-Indian-megacities-and-their-l_2016_Atmospheric-Env.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Air-quality-impacts-in-the-vicinity-of-a-chemical-herde_2023_Science-of-The-.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Air-quality-trends-for-the-ports-of-Los-Angeles-and-Long-Be_2023_Atmospheric.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Airborne-mercury-pollution-from-a-large-oil-spill-ac_2009_Journal-of-Hazardo.pdf |
| 2026-05-02T17:01:55 | 英文文献 | unified | Aisien 等 - 2006 - Comparative absorption of crude oil from fresh and marine water using recycled rubber.pdf |
| 2026-05-02T17:01:55 | 书本/中文 | unified | haishang_oilfield_env_handbook.pdf |

## 下一批候选

下面是 `remaining_queue.tsv` 当前队首的 50 篇。每批只跑几十篇时，优先从这里取，避免跳号和重复。

| 序号 | 分类 | 待提文献 |
| --- | --- | --- |
| 1 | 中文文献 | 3 in 1智能测温系统在海上某平台的首次应用研究.pdf |
| 2 | 专利 | APPARATUS FOR PREVENTING OFFSHORE OIL WELL POLLUTION.pdf |
| 3 | 专利 | APPARATUS FOR PREVENTING POLLUTION FROM OFFSHORE OIL WELLS.pdf |
| 4 | 英文文献 | Akar 等 - 2011 - Detection and object-based classification of offshore oil slicks using ENVISAT-ASAR images.pdf |
| 5 | 英文文献 | Akovetsky 等 - 2020 - Automation of Aerospace Observations of Manifestation of Oil and Gas in Marine Areas.pdf |
| 6 | 英文文献 | Alaska-Sakhalin-2002-Symposium-Discussion-of-Undergrou_2005_Developments-in-.pdf |
| 7 | 英文文献 | Alaskan-North-Slope-Coastal-Tun_2022_Imperiled--The-Encyclopedia-of-Conserva.pdf |
| 8 | 英文文献 | Alaskan-Underground-Injection-Control-of-Solid-W_2005_Developments-in-Water-.pdf |
| 9 | 英文文献 | Alaskan-oil-and-gas-lease-sale-cancelled_1986_Marine-Pollution-Bulletin.pdf |
| 10 | 英文文献 | Albano 等 - 2016 - Contamination patterns and molluscan and polychaete assemblages in two Persian (Arabian) Gulf oilfie.pdf |
| 11 | 英文文献 | Algal-based-biochar-and-hydrochar--A-holistic-and-sust_2024_Chemical-Enginee.pdf |
| 12 | 英文文献 | Algal-biofuels--impact-significance-and-implications_2014_Journal-of-Cleaner.pdf |
| 13 | 英文文献 | Alharbi和El-Sorogy - 2019 - Assessment of seawater pollution of the Al-Khafji coastal area, Arabian Gulf, Saudi Arabia.pdf |
| 14 | 英文文献 | Alien-hotspot--Benthic-marine-species-introduced-in-th_2022_Marine-Pollution.pdf |
| 15 | 英文文献 | Aliphatic-and-aromatic-hydrocarbons-in-coastal-caspi_2004_Marine-Pollution-B.pdf |
| 16 | 英文文献 | Aliphatic-and-polycyclic-aromatic-hydrocarbons-risk-assess_2016_Marine-Pollu.pdf |
| 17 | 英文文献 | Aliphatic-hydrocarbons-and-triterpane-biomarkers-in-mangrov_2017_Marine-Poll.pdf |
| 18 | 英文文献 | Alterations-in-cardiometabolic-markers-associated-with-Cana_2026_Environment.pdf |
| 19 | 英文文献 | Alternative-fuels-and-design-modifications-for-environmenta_2025_Ocean-Engin.pdf |
| 20 | 英文文献 | Alternative-marine-fuel-adoption--Probabilisti_2026_Transportation-Research-.pdf |
| 21 | 英文文献 | Alternative-uses-of-offshore-installations_1986_Marine-Pollution-Bulletin.pdf |
| 22 | 英文文献 | Alvarez 等 - 2014 - A revealed preference approach to valuing non-market recreational fishing losses from the Deepwater.pdf |
| 23 | 英文文献 | Amir-Heidari和Raie - 2019 - A new stochastic oil spill risk assessment model for Persian Gulf Development, application and eval.pdf |
| 24 | 英文文献 | Ammonia-as-a-fuel-for-ships--A-review-of-hazards-and_2026_Journal-of-Hazardo.pdf |
| 25 | 英文文献 | An--Olympic--framework-for-a-green-decommissioning-of_2009_Ocean---Coastal-M.pdf |
| 26 | 英文文献 | An-Active-Learning-Polynomial-Chaos-Kriging-metamodel-for-re_2021_Ocean-Engi.pdf |
| 27 | 英文文献 | An-Arctic-natural-oil-seep-investigated-from-spa_2024_Science-of-The-Total-E.pdf |
| 28 | 英文文献 | An-Italian-proposal-on-the-monitoring-of-underwater-noise--Re_2015_Ocean---C.pdf |
| 29 | 英文文献 | An-Overview-of-the-Nature-of-Hydrocarbon-Jet-Fire-Haza_2007_Process-Safety-a.pdf |
| 30 | 英文文献 | An-Overview-of-the-USEPA-National-Oil-and-Hazardous-Subs_2003_Spill-Science-.pdf |
| 31 | 英文文献 | An-accident-causation-network-for-quantitative-_2021_Process-Safety-and-Envi.pdf |
| 32 | 英文文献 | An-active-learning-framework-assisted-development-o_2024_Process-Safety-and-.pdf |
| 33 | 英文文献 | An-advanced-technique-to-predict-time-dependent-_2020_International-Journal-.pdf |
| 34 | 英文文献 | An-air-quality-emission-inventory-of-offshore-operations-for_2003_Atmospheri.pdf |
| 35 | 英文文献 | An-algebraic-targeting-approach-for-optimal-planning_2018_Process-Safety-and.pdf |
| 36 | 英文文献 | An-anodic-stripping-voltammetric-approach-for-total-mercury_2024_Marine-Poll.pdf |
| 37 | 英文文献 | An-approach-to-assess-potential-environmental-mercury-release_2023_Journal-o.pdf |
| 38 | 英文文献 | An-assessment-of-PCB-and-PBDE-contamination-in-two-tropica_2015_Marine-Pollu.pdf |
| 39 | 英文文献 | An-assessment-of-change-to-fish-and-benthic-communiti_2020_Regional-Studies-.pdf |
| 40 | 英文文献 | An-assessment-of-human-influences-on-sources-of-polycyclic-_2015_Marine-Poll.pdf |
| 41 | 英文文献 | An-assessment-of-pollution-impacts-due-to-the-oil-and-gas-in_2006_Ecological.pdf |
| 42 | 英文文献 | An-assessment-of-the-footprint-and-carrying-capacity-of-o_2018_Science-of-Th.pdf |
| 43 | 英文文献 | An-assessment-of-the-potential-health-hazards-associated-with-_2024_Marine-P.pdf |
| 44 | 英文文献 | An-early-stage-approach-to-optimise-a-marine-energy-system-for_2019_Ocean-En.pdf |
| 45 | 英文文献 | An-eco-friendly-approach-to-separate-emulsified-oil-from-water_2024_Cleaner-.pdf |
| 46 | 英文文献 | An-ecological-risk-assessment-model-for-Arctic-oil-spi_2018_Marine-Pollution.pdf |
| 47 | 英文文献 | An-ecotoxicological-risk-model-for-the-microplastics-_2022_Environmental-Pol.pdf |
| 48 | 英文文献 | An-efficient-and-simple-strategy-for-fabricating-a-polypyrrole_2023_Environm.pdf |
| 49 | 英文文献 | An-environmental-benign-method-to-enhance-hydrate-produc_2024_Journal-of-Cle.pdf |
| 50 | 英文文献 | An-environmental-impact-assessment-of-Saudi-Arabia-s-vi_2024_Environmental-a.pdf |

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
