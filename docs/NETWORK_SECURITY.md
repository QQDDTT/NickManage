# 网络与安全设计 (NETWORK_SECURITY)

本文档描述 NickManage 系统中的网络拓扑、命名规范、容器标签语义，以及基于单网络的伪隔离安全策略。

---

## 1. 网络拓扑

系统当前使用单一 Docker bridge 网络 `nms`，所有容器均接入该网络。

```
宿主机
└── nms (bridge: 172.x.0.0/16)
    ├── ops-docker-socket-proxy   ← Docker API 安全代理
    ├── ops-traefik               ← 边缘路由（唯一对外暴露端口）
    ├── ops-gitea
    ├── ops-redis
    ├── ops-redis-exporter
    ├── ops-loki
    ├── ops-vector
    ├── share-*                   ← 共享层服务
    └── app-* / dev-*             ← 业务层 / 开发层服务
```

> [!NOTE]
> 当前采用**单网络伪隔离**设计：所有容器在同一 bridge 网络内互通，
> 通过容器命名规范、标签声明与 Traefik 路由规则实现逻辑隔离，
> 而非物理网络隔离。这是在单机工作站资源受限下的有意权衡。

---

## 2. 网络命名规范

网络名遵循如下格式：

```
<网络名>.<层级标识>
```

| 标识 | 示例 | 说明 |
|---|---|---|
| 网络名 | `nms` | 全局唯一的 Docker network 名称 |
| 层级标识 | `ops` / `share` / `dev` / `app` | 服务所属架构层 |

**示例**：在标签中引用 `nms.layer`、`nms.collect`、`nms.proxy`

---

## 3. 容器标签语义

每个容器通过 Docker Labels 声明其属性，供 Vector、Traefik 等基础设施组件自动读取。

### 3.1 `nms.collect` — 日志采集开关

| 值 | 语义 |
|---|---|
| `true` | Vector 拦截并采集该容器的 stdout/stderr |
| `false` | Vector 跳过该容器，不采集任何日志 |

适用场景：`nms.collect=false` 用于基础设施自身（如 Vector、Traefik），避免采集自身产生的大量运维噪音。

### 3.2 `nms.layer` — 架构层级声明

| 值 | 层级 | 日志最低等级 | OOM 优先级 |
|---|---|---|---|
| `ops` | 底座层 | `error` | 最高（`oom_score_adj=-999`） |
| `share` | 共享层 | `warn` | 中高 |
| `app` | 业务层 | `info` | 中低 |
| `dev` | 开发层 | `debug` | 最低（优先释放） |

Vector 依据此标签路由日志到不同优先级队列（Redis `logs:priority:high` 或 `logs:priority:normal`）。

### 3.3 `nms.proxy` — Traefik 路由发现开关

| 值 | 语义 |
|---|---|
| `true` | Traefik 自动发现此容器并生成 HTTP 路由，需配合 `traefik.*` 标签使用 |
| `false` | Traefik 完全忽略此容器，不生成任何路由规则 |

---

## 4. 伪隔离安全规则

在单网络架构下，通过以下规则建立访问边界：

### 4.1 Docker Socket 访问管控

> [!IMPORTANT]
> **禁止**任何业务容器直接挂载 `/var/run/docker.sock`。
> 所有需要访问 Docker API 的服务必须通过 `ops-docker-socket-proxy` 代理。

| 容器 | 访问方式 | 允许的权限 |
|---|---|---|
| `ops-docker-socket-proxy` | 直接挂载 | 代理层，控制下游权限 |
| `ops-traefik` / `ops-vector` | `tcp://ops-docker-socket-proxy:2375` | `CONTAINERS`, `EVENTS`, `PING` |
| `ops-monitor` | `tcp://ops-docker-socket-proxy:2375` | `CONTAINERS`, `INFO`, `EVENTS` |
| `dev-*` (开发层项目) | `tcp://ops-docker-socket-proxy:2375` | `CONTAINERS`, `IMAGES`, `NETWORKS`, `POST` (受控写) |
| 其他业务容器 (`app-*`) | **禁止访问** | — |

`docker-socket-proxy` 环境变量权限说明：

```yaml
environment:
  - CONTAINERS=1   # 允许查询容器列表与详情
  - INFO=1         # 允许查询系统信息
  - EVENTS=1       # 允许监听 Docker 事件流
  - PING=1         # 允许健康检查
  - POST=1         # 允许受控写操作（支持开发层部署业务服务）
  - IMAGES=1       # 允许镜像管理（支持开发层拉取镜像）
  - NETWORKS=1     # 允许网络管理（支持开发层容器互联）
  - SERVICES=0     # 禁止 Swarm 服务操作
  - TASKS=0        # 禁止 Swarm 任务操作
  - VOLUMES=0      # 禁止卷管理操作
```

### 4.2 端口暴露管控

> [!IMPORTANT]
> 仅 `ops-traefik` 允许对外暴露端口（80/443/3000）。
> 其他所有容器禁止在 Compose 中直接声明 `ports` 映射，外部访问必须通过 Traefik 路由。

| 容器 | 对外端口 | 说明 |
|---|---|---|
| `ops-traefik` | `80`, `443`, `3000` | 唯一合法的宿主机端口映射 |
| `ops-redis` | `5000:6379` | 仅限本机调试，生产环境应移除 |
| 其他服务 | 无 | 通过 Traefik labels 路由，不直接映射端口 |

### 4.3 服务间通信规则

由于所有容器处于同一网络，通信规则通过约定而非防火墙强制执行：

| 发起方 | 目标方 | 规则 |
|---|---|---|
| `app-*` / `dev-*` | `share-*` | ✅ 允许（共享服务的设计目的） |
| `app-*` / `dev-*` | `ops-*` | ⚠️ 仅允许访问 `ops-redis`（消息队列）和 `ops-gitea`（代码托管） |
| `app-*` | `ops-docker-socket-proxy` | ❌ 禁止（业务服务无需访问） |
| `dev-*` | `ops-docker-socket-proxy` | ✅ 允许（通过 DOCKER_HOST 进行受控部署操作） |
| 任意容器 | `ops-loki` / `ops-vector` | ❌ 禁止直接写入（由 Vector 自动采集） |

### 4.4 敏感信息管控

- 所有密钥、密码、Token 必须通过 `.env` 文件注入，禁止硬编码在 Compose 文件中
- `.env` 文件已加入 `.gitignore`，禁止提交到代码仓库
- 参考 `.env.example` 维护变量清单（不含真实值）

---

## 5. 未来升级路径

当业务规模增长需要真正的网络隔离时，可按以下方向演进：

```
当前：单一 nms 网络（伪隔离）
  ↓
阶段一：按层拆分网络
  nms-ops    ← 仅底座层服务
  nms-share  ← 共享层服务 + 需访问共享服务的 app/dev
  nms-app    ← 业务层服务（含对外暴露）
  ↓
阶段二：引入 Traefik IngressRoute + NetworkPolicy（Swarm/k8s）
```
