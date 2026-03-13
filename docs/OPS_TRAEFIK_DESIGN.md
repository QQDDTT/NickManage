# Traefik 反向代理设计文档

## 1. 概述

Traefik 作为 NickManage 的底座层（ops）核心服务，承担统一入口职责。它通过 Docker API 实现服务的动态发现，并根据容器标签自动配置路由、负载均衡及 SSL 终止。

## 2. 监控任务规则 (Service Discovery)

Traefik 监控 Docker 守护进程以发现新容器。其过滤与路由逻辑基于以下规则：

### 2.1 发现机制 (Label-Based)

只有声明了特定标签的容器才会被 Traefik 纳入监控与路由范围：

- **主开关**：`nms.proxy: "true"`
- **逻辑**：Traefik 静态配置中设置了 `exposedByDefault: false`，因此必须显式声明标签。

### 2.2 监控规则数据清单

| 标签 | 必选 | 描述 | 示例 |
|---|---|---|---|
| `nms.proxy` | 是 | 是否由 Traefik 代理 | `"true"` |
| `traefik.http.routers.<app>.rule` | 是 | 路由匹配规则 | `Host(\`app.local\`)` |
| `traefik.http.services.<app>.loadbalancer.server.port` | 是 | 服务内部端口 | `"8080"` |
| `traefik.http.routers.<app>.entrypoints` | 否 | 入口点（默认 web/websecure） | `"web"` |

### 2.3 过滤与例外

- **Traefik 自身**：标记为 `nms.proxy: "false"`，防止循环引用或不必要的监控开销。
- **共享层服务**（如数据库）：通常标记为 `nms.proxy: "false"`，它们通过内部网络直接通信，不接暴露于代理。

## 3. 路由配置规范

### 3.1 域名分配
- **底座/开发管理**：使用 `*.local` 域名（如 `gitea.local`, `traefik.local`）。
- **业务应用**：根据环境（prod/test）分配对应的二级域名。

### 3.2 优先级 (Priority)
- 通配符域名的优先级应低于具体域名的优先级。
- 必要时通过 `traefik.http.routers.<name>.priority` 显式声明。

## 4. 安全规范

### 4.1 认证中间件
- **BasicAuth**：用于保护各种 Dashboard（Gitea 管理页、Traefik Dashboard）。
- 凭证存储在 `.env` 中并通过 Traefik 动态配置引用。

### 4.2 TLS/SSL
- 底座层启用全局 HTTP 向 HTTPS 的重定向。
- 使用通配符证书或 Let's Encrypt 自动续期（视部署环境而定）。

## 5. 运维指南

- **Dashboard 访问**：默认通过 `traefik.local:8080` (受 Auth 保护)。
- **日志监控**：Traefik 的访问日志通过 stdout 输出，由 Vector 采集（若 `nms.collect: "true"`）。

## 6. 闲时自动化逻辑 (Idle Automation)

为了优化存储利用率并保障代码安全，系统利用 Traefik 的流量感知能力触发闲时维护任务。

### 6.1 闲时定义与获取
- **指标来源**：Traefik 通过 `prometheus` 指标暴露实时连接数（`traefik_entrypoint_open_connections`）和请求速率。
- **判断逻辑**：系统监控组件周期性检查过去 15 分钟内所有入口点的请求频率。若低于设定阈值，则视为“闲时”。

### 6.2 闲时自动提交 GitHub 任务
当触发闲时状态时，系统会向 **Redis 任务队列** (`q.priority.low`) 发送以下任务：

| 任务名 | 描述 | 动作 |
|---|---|---|
| `idle_github_sync` | 闲时代码安全同步 | 扫描项目工作区，对未提交的变更执行备份并触发 Gitea Push Mirror 到 GitHub。 |

**执行细节：**
1. **流量监测**：由 Traefik 插件或外部监控 Service 通过 API 监控流量。
2. **任务注入**：通过 Redis 接口向 `ops-redis` 注入同步指令。
3. **消费者处理**：由 Vector 或 Sidecar 接棒执行 Git 同步。
