# Docker Labels 规则说明文档

本文档整理了 `/home/nick/NickManage/docker/compose/dev-demo.yaml` 中使用的 Docker 标签（Labels）及其规则，用于规范化容器管理、流量分发与监控。

## 1. NMS Bridge 核心标签 (nms-bridge.*)

这些标签用于 NMS (Nick Manage System) 内部桥接与管理逻辑。

| 标签名 | 示例值 | 说明 |
| :--- | :--- | :--- |
| `nms-bridge.collect` | `true` | **采集开关**：控制是否对该容器进行日志、指标或状态采集。 |
| `nms-bridge.layer` | `dev` | **环境分层**：定义容器所属的生命周期阶段（如 `dev`, `test`, `prod`）。 |
| `nms-bridge.proxy` | `true` | **代理启用**：标识该服务是否接入 NMS 内部的反向代理链路。 |

## 2. Traefik 路由基础标签 (traefik.*)

这些标签用于 Traefik 定义动态配置。

| 标签名 | 示例内容 | 说明 |
| :--- | :--- | :--- |
| `traefik.enable` | `true` | **服务发现**：显式告知 Traefik 处理此容器。 |
| `traefik.http.routers.[name].rule` | `Host(\`demo.local\`)` | **路由规则**：定义访问域名或路径匹配逻辑。 |
| `traefik.http.routers.[name].entrypoints` | `web` | **入口点**：指定监听的端口/协议入口（如 80 端口对应的 `web`）。 |
| `traefik.http.services.[name].loadbalancer.server.port` | `8000` | **后端端口**：容器内服务实际监听的端口。 |

## 3. Traefik 中间件标签 (traefik.http.middlewares.*)

用于定义流量治理策略，如限流。

| 标签名 | 示例值 | 说明 |
| :--- | :--- | :--- |
| `traefik.http.middlewares.[mid].ratelimit.average` | `10` | **平均限流**：每秒允许的平均请求数（Guest Limit）。 |
| `traefik.http.middlewares.[mid].ratelimit.burst` | `20` | **突发限流**：允许超过平均值的峰值请求缓冲。 |
| `traefik.http.middlewares.[mid].ratelimit.period` | `1s` | **统计周期**：限流计算的时间窗口长度。 |
| `traefik.http.routers.[name].middlewares` | `guest-limit` | **中间件绑定**：将上述定义的限流规则应用到具体的 Router 上。 |

---
*注：[name] 对应 docker-compose 中的服务名，[mid] 为自定义的中间件标识符。*
