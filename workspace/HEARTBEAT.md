# HEARTBEAT.md

## 提参进度检查（每小时自动执行）

每次 heartbeat 触发时，执行以下操作：

1. 读取 `/tmp/openclaw/extraction_progress.json` 获取当前进度
2. 查看最新的 run 目录（`ls -lt /tmp/openclaw/litextract_runs/ | head -2`），读取其中的 `manifests/failures.tsv` 和 `manifests/success.tsv`
3. 检查 worker 是否存活（`ps aux | grep "openclaw agent.*multi-" | grep -v grep | wc -l`）

### 汇报格式

向主人发送 iMessage 进度摘要（`imsg send --to "+8615895848729"`）：

```
📊 提参进度 (X%)
成功: N | 失败: N | 剩余: N
Worker: N/3 存活
Run: <run_id>
```

### 错误处理

- 如果有**新增失败**（failures.tsv 比上次多），立即发送告警：
  ```
  ⚠️ 提参失败
  文件: <pdf_name>
  模型: <model>
  原因: <reason>
  ```
- 如果 worker 全部停止且队列不为空，发送告警：
  ```
  🚨 提参进程已停止，队列中还有 N 篇未处理
  ```
- 如果提参已完成（队列为空，worker 已退出），发送完成通知：
  ```
  ✅ 提参批次完成
  成功: N | 失败: N
  ```

### 状态文件

- 进度文件：`/tmp/openclaw/extraction_progress.json`
- Run 目录：`/tmp/openclaw/litextract_runs/` 下最新的目录
- 队列文件：`/tmp/openclaw/multi_extract_queue_*.txt`（最新的）
