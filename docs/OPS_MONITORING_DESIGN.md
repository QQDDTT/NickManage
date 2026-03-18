# 运维监控设计文档 (OPS_MONITORING_DESIGN)

本规范定义了 NickManage 系统的全栈监控体系，涵盖从物理指标到业务链路的完整观测能力。

## 1. 监控架构 (Monitoring Architecture)

本系统采用 **Prometheus 生态** 作为核心监控方案，通过底座层 (ops) 基础设施实现自动化发现与采集。

### 1.1 数据流向
`Exporters` (指标暴露) -> `Prometheus` (拉取/存储) -> `Grafana` (可视化) -> `Alertmanager` (告警分发)。

### 1.2 核心组件
| 服务名 | 职责 | 采集方式 |
|---|---|---|
| **ops-traefik** | 入口流量、响应延迟、错误率 | 内置 Prometheus Endpoint (`:8080/metrics`) |
| **ops-redis-exporter** | Redis 队列长度、缓存命中率 | 外部 Exporter |
| **ops-vector** | 日志采集吞吐、自身性能 | 内置 Prometheus Endpoint |
| **ops-monitor** | 容器 OOM 风险、服务存活心跳 | 脚本主动采集 Docker API |
| **Node Exporter** | 宿主机 CPU、内存、磁盘 IO | 宿主机运行或 Docker 运行 |

## 2. 指标采集规范 (Metrics Collection)

监控系统通过 Docker Label 自动发现采集目标：

- 标签名: `nms.monitor.scrape: "true"`
- 标签名: `nms.monitor.port: "9090"` (可选，默认 8080)

## 3. 看板展示 (Dashboards)

系统内置三个层级的 Grafana 看板：

### 3.1 全局概览 (System Overview)
- 宿主机核心资源使用率 (CPU/RAM/DISK)。
- 各层级 (ops/share/dev/app) 容器分布及健康度。
- 关键底座服务 (Traefik, Redis) 实时状态。

### 3.2 流量审计 (Traffic Audit)
- Traefik 吞吐量 (QPS) 与 响应码分布 (2xx/4xx/5xx)。
- 游客并发限制触发频率。
- 各业务应用 (App 层) 的访问热度排行。

### 3.3 AI 服务深度观测 (AI Inference)
- LLM 推理延迟 (TTFT - Time To First Token)。
- 模型加载内存占用趋势。
- 语音/视频转码处理耗时。

## 4. 紧急告警流程 (Alerting)

告警按严重程度分为三级：

| 等级 | 判定标准 | 预定处置动作 |
|---|---|---|
| **CRITICAL** | 底座层 (ops) 关键服务宕机、宿主机内存 > 95% | 立即发送 Push 消息，`ops-monitor` 执行强制自愈。 |
| **WARNING** | 开发层 (dev) resource 滥用 (如流量超标)、容器重启次数频繁 | 发送通知提醒管理员，30 分钟后若未改善尝试限制资源。 |
| **INFO** | 备份任务成功、共享层资源水位变动 | 记录至管理日志，不触发推送。 |

### 4.1 告警通知渠道
- **管理员控制台**: Grafana Alerting 实时显示。
- **外部推送**: 支持集成钉钉/企业微信 Webhook。
- **自愈脚本**: 触发 `ops-monitor` 执行特定运维命令。

## 5. 资源审计与回收
监控系统每 24 小时生成一份“资源浪费报告”，列出在过去 72 小时内 CPU 极低且无流量的开发容器，建议管理员执行清理。
