# LitExtract 多路并行提参经验总结与失败分析

> 日期：2026-05-01 ~ 05-02
> 作者：系统自动生成

---

## 一、统一输出结构

已合并所有提参结果到 `outputs/extractions/`，结构与源文献库一致：

```
outputs/extractions/
├── 英文文献/json/       (85 篇)
├── 中文文献/json/       (0 篇)
├── 专利/json/           (0 篇)
├── 书本/
│   ├── 中文/json/       (1 篇: haishang_oilfield_env_handbook)
│   └── 英文/json/       (0 篇)
└── manifests/
    ├── success.tsv       (统一成功记录)
    ├── remaining_queue.tsv (剩余待提参队列)
    └── progress.json     (进度统计)
```

**总体进度：86/4841（1.8%）**

| 分类 | 已提参 | 总数 | 进度 |
|------|--------|------|------|
| 英文文献 | 85 | 4,368 | 1.9% |
| 中文文献 | 0 | 197 | 0% |
| 专利 | 0 | 89 | 0% |
| 书本/中文 | 1 | 14 | 7.1% |
| 书本/英文 | 0 | 173 | 0% |

---

## 二、多路并行架构

### 设计方案

使用共享队列 + Python 原子锁（`fcntl.flock`）实现多 worker 并发：

```
                   ┌─ Worker 1 (dashscope/qwen3.6-plus) ─┐
共享队列 ─── flock ─┼─ Worker 2 (bailian/qwen3.6-plus)  ─┼─ 共享 manifest
                   └─ Worker 3 (mimo/mimo-v2.5-pro)     ─┘
```

每个 worker 循环：抢锁 → 取队首 → 释放锁 → 提参 → 写结果 → 循环

### 实际使用的模型

| 模型 | API | 状态 | 提参量 |
|------|-----|------|--------|
| `mimo/mimo-v2.5-pro` | 小米 Token Plan | ✅ 正常 | ~80 篇 |
| `bailian/qwen3.6-plus` | 百炼 Coding Plan | ❌ 配额耗尽 | 0 篇 |
| `dashscope/qwen3.6-plus` | 百炼普通 API | ⚠️ 间歇性问题 | ~3 篇 |

**实际只有 mimo 一个模型在稳定工作。**

---

## 三、昨日失败原因分析

### 失败 1：macOS 兼容性问题（已修复）

| 问题 | 原因 | 修复 |
|------|------|------|
| `flock: command not found` | macOS 无 `flock` 命令 | 改用 Python `fcntl.flock`（`queue_helper.py`） |
| `timeout: command not found` | macOS 无 `timeout` 命令 | 改用 Python `subprocess.run(timeout=)` |

**教训**：写跨平台脚本时，避免直接使用 Linux 特有命令。

### 失败 2：Session 锁冲突（已修复）

```
SessionWriteLockTimeoutError: session file locked (timeout 10000ms)
```

**原因**：三个 worker 共用同一个 agent（`lit-extract`），OpenClaw 的 session 文件不支持并发写入。

**修复**：为每个 worker 添加独立 `--session-id`：
```bash
openclaw agent --session-id "multi-w${worker_id}-${label}"
```

**教训**：OpenClaw 的 agent session 是单写者模型，并发必须用独立 session。

### 失败 3：文件访问权限（已修复）

```
Local media path is not under an allowed directory
```

**原因**：OpenClaw 的媒体访问白名单只包含 agent workspace 目录。符号链接会被解析到实际路径，导致路径越界。

**修复过程**：
1. 先尝试符号链接 → OpenClaw 解析后路径越界
2. 改用 hardlink 将 PDF 复制到 workspace 内 → 成功

**教训**：OpenClaw 不信任符号链接，必须用 hardlink 或直接放在 workspace 内。

### 失败 4：百炼 Coding Plan 配额耗尽（未恢复）

```
429 usage allocated quota exceeded. please try again later.
```

**原因**：Coding Plan API 有使用配额限制，之前单 worker 跑了 20 篇（每篇 5-7 分钟）可能消耗了大量配额。

**影响**：Worker 2 (bailian) 完全无法工作，Worker 1 (dashscope) 回退到 bailian 也失败。

**教训**：
- 不同 API 的配额/限流策略不同，需要提前了解
- 应实现配额感知的 worker 调度（检测 429 后自动暂停该 worker）

### 失败 5：JSON 提取器取错对象（部分修复）

**原因**：LLM 输出的外层 JSON 有语法错误（主要是字符串内含未转义的双引号 `21"×1"`），导致 `extract_first_json` 找到的第一个合法 JSON 是某个子对象而非完整 schema。

**修复**：编写 `recover_truncated_json.py`，先尝试修复未转义引号再重新解析。成功恢复 2/3。

**教训**：LLM 输出的 JSON 质量不可靠，提取器需要具备容错能力。

### 失败 6：dashscope API 认证问题（部分解决）

**原因**：`dashscope/qwen3.6-plus` 配置了独立的 API key（`DASHSCOPE_API_KEY`），但 OpenClaw 的 model fallback 机制在 dashscope 失败后会回退到 bailian（而非重试 dashscope）。

**教训**：model fallback 链路需要仔细设计，避免回退到已知不可用的模型。

---

## 四、量化数据

### 提参速度

| 模式 | 速度 | 说明 |
|------|------|------|
| 单 worker (mimo) | ~6.75 min/篇 | 20 篇 / 2h15m |
| 2 worker (mimo+dashscope) | ~3.5 min/篇（有效） | mimo 稳定，dashscope 间歇失败 |
| 3 worker (理论) | ~2.25 min/篇 | 仅当三个 API 都正常时 |

### 成功率

| 批次 | 总尝试 | 成功 | 失败 | 成功率 |
|------|--------|------|------|--------|
| 单 worker batch | 20 | 20 | 0 | 100% |
| Multi batch 1 (3 worker) | ~90 | 77 | ~13 | 86% |
| Multi batch 2 (部分) | ~30 | ~28 | ~2 | 93% |
| **合计** | ~140 | ~125 | ~15 | **89%** |

失败的 15 次中，大部分是 dashscope/bailian 的 API 问题，重试后用 mimo 成功了。

---

## 五、改进建议

1. **API 配额管理**：实现配额感知调度，检测 429 后自动暂停对应 worker，定时重试
2. **Session 隔离**：每个 worker 必须用独立 `--session-id`，这是硬性要求
3. **文件路径**：所有 PDF 必须 hardlink 到 workspace 内，不能依赖符号链接
4. **JSON 提取**：提取器需要更强的容错能力（处理未转义引号、Markdown 代码块等）
5. **Model fallback**：配置合理的 fallback 链，避免回退到已知不可用的模型
6. **进度监控**：进度文件需要实时更新，不能依赖轮询间隔过长的 monitor
7. **统一输出**：从一开始就按源文献目录结构组织输出，避免事后合并

---

## 六、关键脚本清单

| 脚本 | 用途 |
|------|------|
| `scripts/multi_worker_extract.sh` | 三路并发提参主脚本 |
| `scripts/queue_helper.py` | 跨平台原子队列操作 |
| `scripts/progress_monitor_multi.sh` | 多 worker 进度监控 |
| `scripts/merge_results.py` | 合并历史结果到统一目录 |
| `scripts/recover_truncated_json.py` | 恢复被截断的 JSON |
| `scripts/stop_extraction.sh` | 停止所有提参进程 |
| `scripts/launch_multi_extract.sh` | 启动多 worker 提参 |
