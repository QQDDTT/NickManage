# 底座层设计文档 (OPS_DESIGN)

底座层 (ops) 是整个系统的核心基础，承载了流量分发、身份校验、日志采集与 CI/CD 能力。

## 1. 服务列表与职责

| 服务名 | 容器名 | 职责 | 核心功能 |
|---|---|---|---|
| **Docker Socket Proxy** | `ops-docker-socket-proxy` | Docker API 安全代理 | 唯一持有 `docker.sock` 的容器，向下游提供受控的 Docker API。支持开发层所需的写操作（如容器创建、网络管理）。 |
| **Traefik** | `ops-traefik` | 边缘路由与负载均衡 | HTTPS 证书管理 (Let's Encrypt)、动态路由发现、API 暴露管控。通过 `docker-socket-proxy` 访问 Docker API。 |
| **Gitea** | `ops-gitea` | 代码管理与部署中心 | 实现 Git 工作流自动化：通过 Gitea Actions 驱动 App 层部署；内置 Mirroring 机制实时同步代码至 GitHub。 |
| **Redis** | `ops-redis` | 高速缓存与状态存储 | Redis (Alpine)，提供日志队列与 App 层高速缓存。 |
| **Redis Exporter** | `ops-redis-exporter` | Redis 指标暴露 | 将 Redis 内部队列状态转换为 Prometheus Metrics，供 Traefik 及监控系统采集。 |
| **Loki** | `ops-loki` | 日志存储与分析 | 作为一个高效的日志聚合系统，负责接收并持久化存日志数据。 |
| **Vector** | `ops-vector` | 日志采集与路由 | 采集全量日志，按层级过滤并按优先级转发至 Redis/Loki。通过 `docker-socket-proxy` 访问容器元数据。 |

## 2. 挂载与持久化 (Volumes)

本层级严格遵循 `${MNG_HOME}/volumes/ops/` 目录规范。所有持久化数据均通过 Bind Mount 挂载到宿主机。

### 2.1 Docker Socket Proxy 挂载
- `/var/run/docker.sock`: **系统中唯一允许直接挂载 docker.sock 的容器**，向下游提供受控（支持受限写操作）的 Docker API 代理。

### 2.2 Traefik 挂载
- `${MNG_HOME}/volumes/ops/traefik.yaml`: 静态配置文件（只读）。
- `${MNG_HOME}/volumes/ops/traefik-dynamic/`: 存放动态路由配置文件的目录（支持热加载）。
- `${MNG_HOME}/volumes/ops/acme.json`: 用于存储自动申请的 SSL 证书（权限须为 600）。
- Docker API 访问：通过环境变量 `DOCKER_HOST=tcp://ops-docker-socket-proxy:2375`，经代理获取容器标签。

### 2.3 Gitea 与 Redis 挂载
- `${MNG_HOME}/volumes/ops/gitea`: 包含仓库源码、LFS 数据、索引及配置。
- `${MNG_HOME}/volumes/ops/redis`: AOF/RDB 持久化文件。

### 2.4 日志系统相关挂载
- `${MNG_HOME}/volumes/ops/loki.yaml`: Loki 配置文件（只读）。
- `${MNG_HOME}/volumes/ops/vector.yaml`: Vector 配置文件（支持热加载）。
- `${LOG_HOME}/loki`: Loki 索引与数据块的存储路径。
- `${LOG_HOME}/vector`: Vector 自身的运行状态与数据缓冲区。
- Docker API 访问：通过环境变量 `DOCKER_HOST=tcp://ops-docker-socket-proxy:2375`，经代理获取容器元数据。

## 3. 日志系统架构 (Logging System)

本系统采用 **Vector -> Loki -> (Grafana)** 的标准日志链路。

### 3.1 采集与路由逻辑
- **采集端 (Vector)**: 监听所有运行容器，通过 `nms.layer` 标签识别所属层级 (ops/share/dev/app)。
- **多级过滤**:
    - **Ops**: 仅捕捉 `ERROR` 及以上级别，确保核心基座异常即刻感知。
    - **Share**: 捕捉 `WARN` 级别。
    - **App**: 捕捉 `INFO` 级别。
    - **Dev**: 捕捉 `DEBUG` 级别。
- **优先级分发**:
    - **高优先级 (Ops)**: 采用内存缓冲，无延迟推送到 Redis。
    - **延迟处理 (Dev/Share/App)**: 采用磁盘缓冲，在系统负载高时推迟处理。

### 3.2 存储与保留策略
- **Loki**: 采用基于 Label 的索引架构。
- **差异化保留 (Retention)**: 通过 Compactor 组件根据 `nms.layer` 标签自动执行清理：
    - **Ops**: 1年
    - **Share**: 3个月
    - **App**: 1个月
    - **Dev**: 1天

## 4. 资源与稳定性策略
- **内存限制**: 底座层全容器总内存不得超过 1GB。具体建议配额为：
  - `ops-traefik`: 100 MB
  - `ops-gitea`: 512 MB
  - `ops-loki`: 200 MB
  - `ops-vector`: 100 MB
  - `ops-redis`: 64 MB
  - `ops-redis-exporter`: 32 MB
  - `ops-docker-socket-proxy`: 32 MB
- **OOM 优先级**: `oom_score_adj` 统一设为 `-999`，确保在宿主机内存极度短缺时最后被系统终止。

## 5. 资源监控与自动化维护 (Monitoring & Automation)

为了优化系统资源分配并保障全局稳定性，系统引入了 **ops-monitor** 服务（基于极简 Alpine Shell 脚本）：

### 5.1 指标采集与通讯
- **流量指标**: 通过 `ops-traefik:8080/metrics` 获取 Prometheus 格式性能指标。
- **元数据与控制**: 通过环境变量 `DOCKER_HOST=tcp://ops-docker-socket-proxy:2375` 安全访问 Docker API，执行容器信息获取、停止及重启操作。

### 5.2 核心运维逻辑
`ops-monitor` 循环执行以下四项核心任务：

1.  **OOM 风险自动处置 (全层级)**:
    - 实时采集所有标注 `nms.collect=true` 的容器内存状态。
    - 若容器内存占用超过其配额的 **90%**，立即强制关停该容器以防止触发宿主机级 OOM，保护基座层稳定。
2.  **核心服务健康自愈 (Stability)**:
    - 定时探测关键共享服务（如 `share-llamacpp`）的健康接口。
    - 若服务无响应，自动执行 `restart` 操作，实现无人值守。
3.  **流量熔断控制 (Dev)**:
    - 针对 `dev` 层容器，监控 `traefik_service_responses_bytes_total`。
    - 若单次启动后的下行流量累计超过 **500MB**，视为资源误用风险，立即关停容器。
4.  **闲置资源回收 (Dev)**:
    - 监控 `dev` 层容器的请求活跃度。
    - 若连续 **30 分钟** 无 HTTP 请求，自动停止容器以释放宿主机资源。

### 5.3 实现机制
- 使用高性能指标拉取与 Docker SDK (via Proxy) 联动，保障管控的准时性与低开销。
- 运维事件通过结构化 JSON 日志输出，由 Vector 采集并由管理员在 Loki 查阅维护报告。
