# Redis 任务队列设计文档

## 1. 概述

Redis 在 NickManage 架构中作为底座层（ops）的核心组件，除了担任高速缓存外，还作为**异步任务队列**的中心枢纽。它连接了任务生产者（业务层/管理脚本）与任务消费者（Vector/专用 Worker），确保系统操作的解耦与削峰填谷。

## 2. 任务流转逻辑

### 2.1 任务模型
系统主要采用 Redis 的 `LIST` 数据结构实现简单的生产者-消费者模型：
- **PUSH**：生产者通过 `LPUSH` 或 `RPUSH` 将任务 JSON 对象压入队列。
- **POP**：消费者通过 `BRPOP`（阻塞式弹出）获取任务，确保实时响应。

### 2.2 Vector 任务获取流程
Vector 通过 `redis` 相关 source 插件接入：
1. **连接建立**：Vector 容器通过 `nms` 网络连接 `ops-redis` 服务。
2. **拉取机制**：监听指定的 Key（如 `nms_tasks`）。
3. **数据转换**：将 Redis 中的字符串转换为 Vector 内部事件流，随后分发至后续的 Sink（如执行脚本或存入 Loki）。

## 3. 任务优先级规则

为了确保管理类任务与业务类任务的有序执行，实施了基于多队列的优先级机制：

| 队列名 | 优先级 | 适用场景 |
|---|---|---|
| `q.priority.high` | 高 | 系统管理、OOM 恢复策略、紧急控制脚本 |
| `q.priority.default` | 中 | 常规业务处理、日志聚合任务 |
| `q.priority.low` | 低 | 数据后台同步、统计报表生成 |

**调度逻辑**：消费者（Vector）应按顺序监听 Key。只有高优先级队列为空时，才处理默认及低优先级队列。

## 4. 监控与 redis-exporter 规则

### 4.1 指标采集
`redis-exporter` 负责向 Prometheus 提供监控数据：
- **抓取频率**：默认 15s/次。
- **自定义规则**：通过参数指定监控特定的队列长度（`check-keys`）。

### 4.2 关键监控指标
- `redis_list_length`：监控特定任务队列的堆积情况。
- `redis_memory_used_bytes`：监控 Redis 内存占用，防止超过 `ARCHITECTURE.md` 定义的限制（1GB）。

## 5. 队列信息查看

### 5.1 命令行方式 (redis-cli)
- **查看队列长度**：`LLEN q.priority.default`
- **查看队列头部任务**：`LINDEX q.priority.default 0`
- **检查所有队列 Key**：`KEYS q.priority.*`

### 5.2 UI 工具
- **VSCode 插件**：推荐使用 `Redis` 插件（由 `cweijan` 提供），可直观浏览 List 结构及其数据。
- **内部管理**：若部署了 `RedisInsight`，可通过 `redis-insight.local` 访问。
