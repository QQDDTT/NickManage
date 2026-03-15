# 系统架构设计 (ARCHITECTURE)

本项目采用四层容器化架构，旨在实现各层服务在职责、资源分配及隔离性上的严格区分。

## 1. 底座层 (ops)

**职责**：承载整个系统持续运行所依赖的基础核心服务。

*   **核心功能**：包含反向代理与统一负载均衡 (Traefik)、代码托管与本地 CI/CD 集成 (Gitea)、高速缓存与状态存储 (Redis)、日志中心 (Loki) 及全量日志采集 (Vector)。
*   **路由管理**：所有外部 HTTP/HTTPS 流量均由底座层统一路由，其他各层服务禁止直接对外披露端口。
*   **资源策略**：具备最高的 OOM 优先级（最后被终止），全层内存硬限制控制在 1GB 以内，确保基础环境的绝对稳定性。

## 2. 共享层 (share)

**职责**：提供各开发项目公用的基础设施与持久化服务。

*   **核心功能**：主要运行数据库（如 PostgreSQL）、消息队列、AI Agent 等跨项目调用的公共组件。
*   **运行模式**：该层服务应保持长期在线，不随特定开发环境的启停而变化。
*   **资源策略**：通过软限制（Soft Limit）声明预期资源占用，作为系统内存调度时的重要参考依据。

## 3. 开发层 (dev)

**职责**：为各软件项目提供标准化的开发容器环境 (devcontainer)。

*   **核心功能**：封装各语言运行时及工具链，作为代码编写与调试的隔离环境。
*   **运行规则**：原则上同一时刻仅允许运行一个开发层容器，以优化工作站资源分配。
*   **资源策略**：单容器内存硬限制为 4GB，具备最低的 OOM 优先级，在内存极其紧张时优先释放。

## 4. 业务层 (app)

**职责**：承载对外提供服务的业务应用容器。

*   **核心功能**：即实际交付的应用程序。服务容器在生命周期与资源配置上继承并关联其对应的开发层。
*   **部署规范**：端口统一从 10000 起始分配，服务路由规则声明式集成到容器 Label 中，由底座层 Traefik 自动发现。

## 5. 管理规则

为了确保系统的高度可维护性与安全性，所有层级必须遵循以下管理规则：

### 5.1 变量化原则 (Variable-First)
- **数据流向**: `.env` -> 系统环境变量 -> `yaml`/`json` 配置文件。
- **禁令**: 禁止在配置文件中出现任何具体的绝对路径、密钥或敏感信息。所有此类信息必须通过环境变量 `${VAR_NAME}` 引用。

### 5.2 容器构建规范
- **使用预装镜像**: 开发层容器必须使用预装 Antigravity IDE 的官方或社区成熟镜像。
- **禁止本地构建**: 系统禁止在项目仓库内维护自定义 Dockerfile，所有环境差异通过 Compose 配置实现。

### 5.3 开发层 (dev) 挂载规范
- **Compose (服务级) 挂载**:
    - 仅限必要的 runtime 配置文件（只读）。
- **devcontainer.json (IDE 级) 挂载**:
    - 无需手动挂载 VS Code Server 与 Antigravity 环境（已内置于镜像中）。
    - 仅限必要的 runtime 配置文件。
    - Antigravity 项目数据: `antigravity/index`, `antigravity/cache`, `antigravity/config.yaml` (统一存放于 volumes)。

### 5.4 挂载路径分配原则
- **底座层 (ops) 与 共享层 (share)**: 使用 `yaml` 文件构筑，其持久化数据必须使用命名卷或存放在项目根目录的 `volumes/ops/` 和 `volumes/share/` 文件夹内。
- **开发层 (dev)**: 各类开发环境的核心工作区位于 `/home/nick/workspaces/<项目名>/` 目录下。针对源码工作区，采取本地挂载与 Gitea 云端拉取相结合的模式。语言包缓存统一位于 `volumes/dev/` 目录下。

## 6. 网络命名与标签设计

### 6.1 网络命名规范

所有容器网络遵循统一命名格式：

```
<网络名>.<标签名>
```

**示例**：`nms.ops`、`nms.share`、`nms.app`

### 6.2 容器标签定义

每个容器通过 Docker Labels 声明自身属性，供各层基础设施（Vector、Traefik 等）自动发现与配置。

#### `<网络名>.collect`

控制 **Vector** 是否采集该容器的日志。

| 值 | 含义 |
|---|---|
| `true` | Vector 拦截并采集该容器日志 |
| `false` | Vector 忽略该容器，不采集日志 |

```yaml
labels:
  nms.collect: "true"
```

#### `<网络名>.layer`

声明容器所属的架构层级，用于确定**日志等级**与**任务优先级**。

| 值 | 层级 | 日志等级 | OOM 优先级 |
|---|---|---|---|
| `ops` | 底座层 | `warn` | 最高（最后终止） |
| `share` | 共享层 | `info` | 中高 |
| `dev` | 开发层 | `debug` | 最低（优先释放） |
| `app` | 业务层 | `info` | 中低 |

```yaml
labels:
  nms.layer: "ops"
```

#### `<网络名>.proxy`

控制 **Traefik** 是否监控并为该容器配置路由。

| 值 | 含义 |
|---|---|
| `true` | Traefik 自动发现并纳入路由管理 |
| `false` | Traefik 忽略该容器，不生成路由规则 |

```yaml
labels:
  nms.proxy: "true"
```

### 6.3 标签组合示例

```yaml
# 底座层服务（以 Traefik 自身为例）
labels:
  nms.collect: "false"   # Traefik 本身不被 Vector 采集
  nms.layer: "ops"       # 归属底座层
  nms.proxy: "false"     # Traefik 不监控自身

# 共享层业务服务（以 PostgreSQL 为例）
labels:
  nms.collect: "true"    # 日志由 Vector 采集
  nms.layer: "share"     # 归属共享层
  nms.proxy: "false"     # 无需 HTTP 路由

# 业务层 Web 服务（以某 App 为例）
labels:
  nms.collect: "true"    # 日志由 Vector 采集
  nms.layer: "app"       # 归属业务层
  nms.proxy: "true"      # 由 Traefik 统一对外路由

---

## 7. 项目映射规范 (Project Mapping)

为了确保工程管理的透明度与追溯性，系统强制执行“三位一体”的 1:1:1 映射逻辑。

### 7.1 核心映射逻辑

| 层级 | 实体 | 映射关系 | 说明 |
|---|---|---|---|
| **开发层** | Dev Container | **1** | 一个容器对应一个具体的子项目。 |
| **底座层** | Gitea 仓库 | **1** | 每个子项目在内部 Gitea 中有且仅有一个真源仓库。 |
| **外部层** | GitHub 仓库 | **1 (可选)** | 每个 Gitea 仓库对应一个外部镜像（Push Mirror）仓库。 |

### 7.2 命名一致性
- **标识符**：项目名（`<项目名>`）必须在容器命名、Gitea URL 及 GitHub 路径中保持全局一致。
- **示例**：项目 `NickManage` 对应 Gitea 路径 `nick/NickManage` 及 GitHub 路径 `QQDDTT/NickManage`。
```
