# 仿生设计库 — 补充文献检索指令

> 日期：2026-06-06
> 使用人：文献检索助手（学生）
> 预计工作量：半天下载，后续由 AI 自动提参

---

## 一、任务背景

### 我们在做什么

我们在建设一个**"水处理仿生吸附材料开发智能体系统"**。

核心思路是**仿生**：自然界中很多生物天生就具备吸附/分离/抗污的能力，例如：
- 贻贝能在水下强力粘附岩石（邻苯二酚配位机制）
- 荷叶表面能自动排斥水和油污（微纳二级结构）
- 硫酸盐还原菌能把重金属变成极难溶的硫化物（生物沉淀机制）

我们需要把这些生物的"本领"结构化整理成一个知识库，让 AI 能检索和调用。

### 当前文献库现状

已有 **341 篇**文献，覆盖 8 个分组：

| 分组 | 数量 | 覆盖内容 |
|------|------|----------|
| 第1组-配位螯合 | 35 篇 | 贻贝仿生、壳聚糖、聚多巴胺 |
| 第2组-超疏水 | 34 篇 | 荷叶仿生、超疏水膜 |
| 第3组-多孔结构 | 36 篇 | MOF、沸石、多孔碳 |
| 第4组-生物矿化 | 37 篇 | 碳酸钙、羟基磷灰石 |
| 第5组-纤维结构 | 34 篇 | 蚕丝、蜘蛛丝、纤维素 |
| 第6组-功能仿生 | 35 篇 | 功能性仿生材料 |
| 第7组-系统仿生 | 33 篇 | 系统级仿生设计 |
| 第8组-仿生材料 | 38 篇 | 通用仿生材料 |
| 全局综述 | 20 篇 | 跨领域综述 |

### 文献库短板

现有文献偏**"材料→应用"**视角，缺少：
- **仿生设计方法论**：如何从生物现象中提取设计原则？
- **设计原则与标准**：构效关系、条件-机制关系、设计权衡
- **跨原型比较研究**：系统比较多种仿生原型的优劣
- **仿生设计案例研究**：完整展示"自然观察→机制理解→材料设计→性能验证"全链条

### 你的任务

补充上述 4 个方向的文献，每个方向下载 **20-30 篇**，总计 **80-120 篇**。

---

## 二、检索来源

| 来源 | 用途 | 说明 |
|------|------|------|
| Web of Science (WoS) | 英文论文主检索 | 校园网访问 |
| CNKI | 中文论文检索 | 校园网访问 |
| Google Scholar | 补充检索 | 可选 |

**所有操作在校园网环境下完成。**

---

## 三、四个补充方向的检索式

### 方向一：仿生设计方法论（目标 25-35 篇）

**为什么需要**：理解如何从生物现象中提取设计原则，如何把自然策略转化为工程参数。

**WoS 检索式（按优先级执行）**：

| # | 检索式 | 优先级 |
|---|--------|--------|
| 1 | `TS=("biomimetic design" AND ("methodology" OR "framework" OR "approach"))` | 高 |
| 2 | `TS=("bio-inspired design" AND ("water treatment" OR "adsorption" OR "adsorbent"))` | 高 |
| 3 | `TS=("biomimicry" AND ("design process" OR "design principles" OR "engineering design"))` | 高 |
| 4 | `TS=("bio-inspiration" AND ("functional translation" OR "functional abstraction" OR "design transfer"))` | 中 |
| 5 | `TS=("biologically inspired" AND ("scale-up" OR "scale translation" OR "multi-scale design"))` | 中 |
| 6 | `TS=("functional equivalence" AND ("biomimetic" OR "bio-inspired"))` | 中 |
| 7 | `TS=("biomimetic" AND ("multi-mechanism" OR "synergistic design" OR "integrated function"))` | 低 |
| 8 | `TS=("nature-inspired" AND ("design strategy" OR "design paradigm") AND ("environmental" OR "water" OR "pollutant"))` | 中 |

**CNKI 检索式**：

| # | 检索式 | 优先级 |
|---|--------|--------|
| 1 | `SU='仿生设计方法' OR SU='仿生设计框架'` | 高 |
| 2 | `SU='仿生吸附' AND SU='设计原理'` | 高 |
| 3 | `SU='生物启发设计' AND (SU='水处理' OR SU='吸附')` | 高 |
| 4 | `SU='仿生材料' AND SU='设计方法论'` | 中 |
| 5 | `SU='功能仿生' AND SU='尺度效应'` | 中 |

**重点期刊**：*Bioinspiration & Biomimetics*、*Journal of Bionic Engineering*、*Biomimetics (MDPI)*

---

### 方向二：设计原则与标准（目标 20-30 篇）

**为什么需要**：将构效关系、条件-机制关系、设计权衡编码为可检索的设计规则。

**WoS 检索式**：

| # | 检索式 | 优先级 |
|---|--------|--------|
| 1 | `TS=("structure-function relationship" AND ("adsorbent" OR "adsorption material"))` | 高 |
| 2 | `TS=("design principle*" AND "adsorbent" AND ("selectivity" OR "capacity" OR "kinetics"))` | 高 |
| 3 | `TS=("adsorbent design" AND ("trade-off" OR "optimization" OR "cost-performance"))` | 高 |
| 4 | `TS=("adsorption mechanism" AND ("review" OR "critical review") AND ("functional group" OR "surface chemistry"))` | 高 |
| 5 | `TS=("green synthesis" AND "adsorbent" AND ("principle*" OR "sustainable"))` | 中 |
| 6 | `TS=("selective adsorption" AND ("design" OR "tailoring" OR "engineering") AND ("heavy metal" OR "organic pollutant"))` | 中 |
| 7 | `TS=("adsorption" AND ("pH effect" OR "temperature effect" OR "ionic strength") AND ("mechanism" OR "functional group"))` | 中 |

**CNKI 检索式**：

| # | 检索式 | 优先级 |
|---|--------|--------|
| 1 | `SU='吸附剂设计' AND (SU='构效关系' OR SU='结构功能关系')` | 高 |
| 2 | `SU='吸附材料' AND SU='设计原则'` | 高 |
| 3 | `SU='吸附' AND SU='选择性' AND SU='设计'` | 中 |
| 4 | `SU='绿色合成' AND SU='吸附材料'` | 中 |
| 5 | `SU='吸附机理' AND SU='pH' AND SU='综述'` | 中 |

**重点**：找含有"官能团→目标污染物→条件"汇总表的综述，是编码 design rule 的最佳素材。
**重点期刊**：*Chemical Engineering Journal*、*J Hazardous Materials*、*Water Research*

---

### 方向三：跨原型比较研究（目标 15-25 篇）

**为什么需要**：系统比较多种仿生原型或材料类别，为原型选择和规则验证提供依据。

**WoS 检索式**：

| # | 检索式 | 优先级 |
|---|--------|--------|
| 1 | `TS=("bio-inspired" OR "biomimetic") AND ("comparative" OR "comparison") AND "adsorption"` | 高 |
| 2 | `TS=("meta-analysis" OR "systematic review") AND "adsorbent" AND ("performance" OR "capacity")` | 高 |
| 3 | `TS=("biomimetic adsorbent" AND "review") OR TS=("bio-inspired adsorbent" AND "review")` | 高 |
| 4 | `TS=("natural adsorbent" AND "synthetic adsorbent" AND "comparison")` | 中 |
| 5 | `TS=("adsorbent" AND ("benchmark" OR "benchmarking" OR "standardized comparison"))` | 中 |
| 6 | `TS=("review" AND ("chitosan" OR "cellulose" OR "biochar" OR "MOF" OR "hydrogel") AND "adsorption" AND "comparison")` | 低 |
| 7 | `TS=("adsorption performance" AND ("across" OR "among" OR "different classes") AND "material*")` | 中 |

**CNKI 检索式**：

| # | 检索式 | 优先级 |
|---|--------|--------|
| 1 | `SU='仿生吸附剂' AND SU='综述'` | 高 |
| 2 | `SU='吸附材料' AND (SU='对比' OR SU='比较研究') AND SU='性能'` | 高 |
| 3 | `SU='吸附剂' AND SU='Meta分析'` | 中 |
| 4 | `SU='生物吸附剂' AND SU='传统吸附剂' AND SU='比较'` | 中 |

**注意**：必须是同时对比 ≥2 种仿生原型的文献，仅罗列不算。

---

### 方向四：仿生设计案例研究（目标 20-30 篇）

**为什么需要**：完整展示"自然观察→机制理解→材料设计→性能验证"全链条的深度案例。

**WoS 检索式**：

| # | 检索式 | 优先级 |
|---|--------|--------|
| 1 | `TS=("biomimetic" OR "bio-inspired") AND "adsorbent" AND ("design" OR "development") AND ("performance" OR "application")` | 高 |
| 2 | `TS=("nature-inspired" AND ("water treatment" OR "water purification") AND "material*")` | 高 |
| 3 | `TS=("biomimetic" AND "industrial" AND ("adsorption" OR "water treatment" OR "scale-up"))` | 高 |
| 4 | `TS=("mussel-inspired" OR "lotus-inspired" OR "gecko-inspired" OR "nacre-inspired") AND ("adsorption" OR "water treatment" OR "pollutant removal")` | 中 |
| 5 | `TS=("biomimetic" AND ("challenge*" OR "limitation*" OR "lesson*" OR "failure") AND ("material*" OR "design"))` | 中 |
| 6 | `TS=("biomimetic" OR "bio-inspired") AND ("case study" OR "proof of concept" OR "pilot")` | 中 |
| 7 | `TS=("bio-inspired" AND ("from nature to" OR "nature to application" OR "lab to industry"))` | 中 |
| 8 | `TS=("surface engineering" AND "bio-inspired" AND ("heavy metal" OR "dye" OR "pharmaceutical" OR "PFAS"))` | 低 |

**CNKI 检索式**：

| # | 检索式 | 优先级 |
|---|--------|--------|
| 1 | `SU='仿生' AND SU='吸附' AND SU='制备' AND SU='性能'` | 高 |
| 2 | `SU='仿生材料' AND (SU='水处理' OR SU='废水处理') AND SU='应用'` | 高 |
| 3 | `SU='仿生' AND SU='中试' OR SU='工业化'` | 中 |
| 4 | `SU='贻贝仿生' OR SU='荷叶仿生' OR SU='珍珠层仿生'` | 中 |
| 5 | `SU='仿生设计' AND SU='案例分析'` | 低 |

**重点**：贻贝仿生（聚多巴胺）是全链条案例最丰富来源，从 Lee et al. (2007) *Science* 追引用网络。

---

## 四、全局综述检索（补充）

用于发现同时覆盖多个仿生维度的高质量综述：

**WoS 检索式**：
```
TS=("bioinspired" OR "biomimetic" OR "nature-inspired") 
AND 
TS=("adsorbent" OR "adsorption" OR "membrane" OR "sorbent" OR "water purification") 
AND 
TS=("review" OR "overview" OR "recent progress" OR "state-of-the-art")
```

按被引量降序排列，下载前 **20 篇**。

---

## 五、检索操作步骤

### WoS 检索

1. 在校园网环境下登录 Web of Science
2. 选择"高级检索"
3. 复制粘贴上面的检索式到检索框
4. 点击检索
5. **排序方式**：按"被引次数"降序排列
6. 下载前 20-30 篇（优先综述，其次高被引研究论文）

### CNKI 检索

1. 在校园网环境下登录中国知网
2. 选择"高级检索"
3. 复制粘贴中文检索式
4. 下载前 10-15 篇高被引论文

### Google Scholar（可选）

1. 访问 Google Scholar
2. 复制粘贴检索式
3. 优先下载 PDF 全文可获取的文献

---

## 六、文件命名与组织规范

### 文件夹结构

```
仿生文献库/论文/
├── 第9组-仿生方法论/     ← 方向一
├── 第10组-设计原则/      ← 方向二
├── 第11组-跨原型比较/    ← 方向三
└── 第12组-仿生案例/      ← 方向四
```

### 文件命名规则

**格式**：`[年份]-[第一作者姓]-[关键词缩写].pdf`

**示例**：
- `2021-Vincent-biomimetic-design-methodology-framework-review.pdf`
- `2022-王-仿生吸附剂-构效关系-设计原则-综述.pdf`
- `2019-Smith-mussel-inspired-PDA-adsorbent-heavy-metal-removal.pdf`

**跨方向文献**：归入主方向，文件名末尾加 `[多方向]`。

---

## 七、质量筛选标准

### 优先下载

1. **综述论文**（Review）：特别是近 5 年的高被引综述
2. **高被引论文**：被引次数 > 50 的研究论文
3. **近 5 年论文**：2021-2026 年发表
4. **讨论设计逻辑**的文献（非纯材料表征）
5. **建立与生物原型联系**的文献（非"我们用了壳聚糖"，而是"我们基于生物原则X进行设计"）

### 可以跳过

1. 被引次数 < 10 的普通论文（除非是近 2 年新发表的）
2. 会议论文（除非是顶级会议如 ACS、RSC 的）
3. 与水处理无关的纯材料论文

---

## 八、注意事项

1. **同一篇文献可能命中多个方向**：这是正常的，放第一个命中的方向即可
2. **综述优先**：每组至少要有 3-5 篇综述
3. **遇到问题及时沟通**：如果某组检索结果太少（< 10 篇），放宽检索词；如果太多（> 100 篇），增加限定条件
4. **先下载高优先级**：时间充裕再补中低优先级

---

## 九、各方向检索结果预估

| 方向 | 检索式数量 | 预估命中 | 预估纳入 | 下载耗时 |
|------|-----------|---------|---------|---------|
| 方向一：仿生方法论 | 13 条 | 200-400 | 25-35 | ~1h |
| 方向二：设计原则 | 12 条 | 300-500 | 20-30 | ~1h |
| 方向三：跨原型比较 | 11 条 | 100-200 | 15-25 | ~30min |
| 方向四：仿生案例 | 13 条 | 300-600 | 20-30 | ~1h |
| 全局综述 | 1 条 | 50-100 | 20 | ~15min |
| **合计** | **50 条** | **950-1800** | **100-140** | **半天** |

---

## 十、交付物

完成后提交按上述文件夹结构组织好的 PDF 文件即可。

下载完成后告知项目负责人，将：
1. 检查文件命名和存放结构
2. 将新文献纳入 AI 提参队列
3. 用 LitExtract 批量提参
4. 将提参结果映射到知识库

---

## 附录：现有文献回扫（不需要下载新文献）

在已有 PDF 中用 Ctrl+F 搜索以下关键词，找出被误分类的方法论文献：

| 中文关键词 | 英文关键词 |
|-----------|-----------|
| 设计框架/策略 | design framework, design strategy, design methodology |
| 翻译/抽象 | translate, abstraction, extract, inspired by |
| 构效关系 | structure-function, structure-property |
| 设计权衡 | trade-off, balance, compromise, optimization |
| 尺度问题 | scale-up, multi-scale, hierarchical, from nano to macro |
| 比较分析 | comparative, versus, benchmark, systematic comparison |

**重点回扫分组**：
- 第6组-功能仿生（35篇）：高概率含方法论文献
- 第7组-系统仿生（33篇）：高概率含系统级仿生设计框架
- 第4组-生物矿化（36篇）：中概率含"过程仿生"方法论
- 第8组-仿生材料（38篇）：中概率含通用设计综述
- 20篇全局综述：用上述关键词重新审读
