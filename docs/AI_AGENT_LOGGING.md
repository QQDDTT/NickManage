# AI 代理日志过滤设计 (AI_AGENT_LOGGING)

本文档描述 NickManage 系统中针对 AI 代理（Antigravity 等）行为日志的过滤策略，
旨在解决 AI Agent 产生的高频、重复、结构化调用日志（即"消息爆炸"问题），
防止其淹没真正有意义的业务日志和错误信息。

---

## 1. 问题背景：AI 行为日志的特殊性

AI Agent 在运行时会产生大量与系统故障无关的**正常工作噪音**：

| 噪音类型 | 示例 | 产生频率 |
|---|---|---|
| 健康检查轮询 | `GET /health`, `GET /ping` | 每秒多次 |
| 工具调用轮询 | `POST /v1/tools/list_dir` | 每次 Agent 循环 |
| Token 状态上报 | `POST /v1/session/heartbeat` | 周期性 |
| 嵌入向量查询 | `POST /v1/embeddings` | 每次检索 |
| 模型推理请求 | `POST /v1/chat/completions` | 高频 |
| 静态资源加载 | `GET /assets/*.js`, `GET /favicon.ico` | 页面刷新时 |

若不加过滤，这些日志将占用 Redis 队列和 Loki 存储大量空间，同时使真实告警被淹没。

---

## 2. 过滤策略设计

Vector 在 `filter_by_layer` 之后、写入 Redis/Loki 之前，新增一个 **AI 噪音过滤** Transform。

### 2.1 过滤器架构

```
docker_source
    ↓
parsed_logs          ← 解析 label 和 severity
    ↓
filter_collect       ← nms.collect=true 才继续
    ↓
filter_by_layer      ← 按层级过滤 severity
    ↓
filter_ai_noise  ←── 【新增】AI 噪音过滤（本文档设计重点）
    ↓      ↓
 ops_stream  other_stream
    ↓             ↓
redis_ops    redis_others + loki_sink
```

### 2.2 `noise_pattern` — 消息内容噪音规则

基于日志消息内容的正则匹配黑名单，命中即丢弃：

```toml
# vector.yaml — filter_ai_noise transform
filter_ai_noise:
  type: filter
  inputs:
    - filter_by_layer
  condition: |
    # 不命中任何噪音规则时才保留（取反逻辑）
    noise_patterns = [
      # --- 健康检查类 ---
      r'(GET|HEAD) /health',
      r'(GET|HEAD) /ping',
      r'(GET|HEAD) /ready',
      r'(GET|HEAD) /live',
      r'(GET|HEAD) /metrics',        # Prometheus 抓取日志

      # --- AI 工具调用轮询类 ---
      r'POST /v1/tools/',
      r'POST /v1/session/heartbeat',
      r'"method":"tools/list"',
      r'"method":"sampling/createMessage"',

      # --- 嵌入与推理类（正常成功调用，非错误）---
      r'POST /v1/embeddings.*2[0-9]{2}',     # 2xx 成功的嵌入请求
      r'POST /v1/chat/completions.*2[0-9]{2}',

      # --- 静态资源类 ---
      r'GET /assets/',
      r'GET /favicon\.ico',
      r'GET /robots\.txt',
      r'GET .*\.(js|css|png|woff2?)(\?.*)?$',
    ]
    matched = false
    for_each(noise_patterns) -> |_index, pattern| {
      if match(.msg, pattern) {
        matched = true
      }
    }
    !matched
```

### 2.3 `path_blacklist` — URL 路径黑名单

对于结构化 HTTP 访问日志（如 Traefik Access Log），直接按 URL 路径过滤：

```toml
# 适用于 Traefik access log 的路径黑名单
path_blacklist = [
  "/health",
  "/healthz",
  "/ping",
  "/ready",
  "/live",
  "/metrics",
  "/favicon.ico",
  "/robots.txt",
  "/v1/session/heartbeat",
  "/v1/tools/list_dir",
  "/v1/tools/read_file",
  "/v1/tools/grep_search",
]

# 在 remap transform 中使用
if exists(.RequestPath) {
  for_each(path_blacklist) -> |_index, path| {
    if starts_with(string!(.RequestPath), path) {
      abort          # 丢弃该日志事件
    }
  }
}
```

---

## 3. 防消息爆炸策略

### 3.1 速率限制（Rate Limiting）

对同一容器、同一消息模式的日志进行去重：

```toml
# 使用 Vector 的 throttle transform 限速
throttle_ai_container:
  type: throttle
  inputs:
    - filter_ai_noise
  window_secs: 60          # 60 秒窗口
  threshold: 100           # 每窗口最多 100 条
  key_field: container_name  # 按容器分组限速
  internal_metrics: true
```

### 3.2 去重（Deduplication）

对完全相同的日志消息在短时间内只保留一条：

```toml
dedupe_repeated:
  type: dedupe
  inputs:
    - throttle_ai_container
  fields:
    match:
      - container_name
      - msg
  cache:
    num_events: 5000        # 缓存最近 5000 条作为去重判断依据
```

### 3.3 层级豁免规则

> [!IMPORTANT]
> 以下情况**绕过**所有噪音过滤，确保错误绝不丢失：
> - `severity` 为 `error`、`critical`、`fatal`、`panic` 的任何消息
> - `ops` 层的任何日志（底座层日志优先级最高，不过滤）
> - 包含关键词 `exception`、`traceback`、`stack trace` 的消息

```toml
# 在 filter_ai_noise 前先放行高优先级日志
filter_critical_bypass:
  type: filter
  inputs:
    - filter_by_layer
  condition: |
    .severity == "error" || .severity == "critical" ||
    .severity == "fatal" || .severity == "panic" ||
    .layer == "ops" ||
    contains(string!(.msg), "exception") ||
    contains(string!(.msg), "traceback") ||
    contains(string!(.msg), "stack trace")
```

完整路由逻辑：

```
filter_by_layer
    ├── filter_critical_bypass  → 直接进入 ops_stream / other_stream（不过滤）
    └── filter_ai_noise         → throttle → dedupe → ops_stream / other_stream
```

---

## 4. 监控过滤效果

通过 Vector 内部指标观察过滤是否有效：

```bash
# 查看 Vector 各 transform 的事件吞吐量
curl http://ops-traefik:8080/api/http/services | jq

# 或直接查看 Vector 内部指标（需在 traefik.yaml 开启 prometheus）
curl http://localhost:9598/metrics | grep vector_component_received_events_total
```

关键指标：

| 指标 | 含义 | 健康阈值 |
|---|---|---|
| `filter_ai_noise.events_out` / `filter_ai_noise.events_in` | 过滤保留率 | 应低于 30%（70% 应被过滤） |
| `throttle_ai_container.events_discarded` | 限速丢弃量 | 偶发正常，持续高值需检查 AI 频率 |
| `dedupe_repeated.events_discarded` | 去重丢弃量 | 高值说明 AI 有重复轮询行为 |
| Redis `logs:priority:normal` 队列长度 | 积压情况 | 超过 50000 需告警 |

---

## 5. 配置维护规范

- `noise_pattern` 和 `path_blacklist` 均应维护在 `vector.yaml` 的注释区块中，便于版本控制
- 新增 AI 服务时，需同步评估其日志模式是否需要追加过滤规则
- 每季度审查过滤器的保留率，确保有效日志未被误过滤
- 过滤规则变更后，通过 `--watch-config` 自动热加载，无需重启 Vector
