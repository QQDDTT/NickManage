# NickManage 操作手册 (Operating Manual)

本文档定义了 NickManage 开发与管理工程的核心操作规范，旨在为开发者提供一致的服务接入、日志查看及环境管理指导。

> [!IMPORTANT]
> 本手册以只读方式挂载到所有开发层容器 (`devcontainer`) 的 `/docs/OPERATING_MANUAL.md` 路径下。

---

## 1. 核心架构

系统分为四层，严格遵循命名与资源隔离：

| 层级 | 前缀 | 用途 | 内存限制 |
|---|---|---|---|
| **底座层** | `ops-` | Traefik, Gitea, Loki, Vector | 总计 ≤ 1GB |
| **共享层** | `share-` | Postgres, Redis, Embedding | 无硬限制 |
| **开发层** | `dev-` | 各项目 devcontainer | 单容器 ≤ 4GB |
| **业务层** | `app-` | 生产服务 | 继承开发层 |

---

## 2. 常用操作命令

### 2.1 打开工作空间
所有项目必须通过宿主机的管理脚本启动，严禁手动 `up` 开发容器：
```bash
# 在宿主机执行
bash ~/NickManage/Antigravity-Manage/open_workspace.sh
```

### 2.2 查看日志
日志统一汇聚至 Loki，可通过 Grafana (ops-traefik 路由) 或宿主机目录查看：
- **宿主机路径**: `/home/nick/.logs/`
- **开发层路径**: `~/.logs/dev/<project_name>/`

---

## 3. 开发规范

### 3.1 端口分配
开发层容器端口从 `8000` 开始分配，每个项目固定一个。

### 3.2 容器互斥
同一时间仅允许运行一个 `dev-*` 容器。启动新项目时，脚本会自动停止其他开发容器。

### 3.3 挂载规则
所有 `devcontainer` 默认具备以下挂载：
- `/etc/localtime`: 宿主机时间同步 (只读)
- `~/.ssh`: SSH 密钥 (只读)
- `volumes/share/git/gitconfig`: Git 配置 (只读)
- `/logs`: 项目专属日志目录

---

## 4. DevContainer 定位与职责

`devcontainer` 是 NickManage 体系中的**核心开发单元**，其定位与职责如下：

### 4.1 核心定位
- **环境一致性**：为开发者提供开箱即用的、与宿主机解耦的标准开发环境。
- **工具链承载**：所有语言运行时（Python, Node, Java 等）及编译工具链均在容器内，宿主机保持“零安装”。
- **单向隔离**：开发操作在容器内进行，通过 `mounts` 与宿主机源码同步，保护宿主机环境洁净。

### 4.2 交互逻辑 (The "How-to")

#### A. 与 Docker 的交互 (DooD)
- **模式**：采用 **Docker-outside-of-Docker (DooD)** 代理模式。
- **实现**：**禁止**直接挂载 socket。通过 `ops-docker-socket-proxy` 提供的受控 API。
- **职责**：在 `devcontainer` 内可以构建业务镜像 (`docker build`)、启动业务层容器 (`docker compose up`)。

#### B. 与 Traefik 的交互 (路由接入)
- **网络映射**：所有 `devcontainer` 必须加入 `nms-bridge` 网络。
- **实现**：利用 Docker Label 或 `mounts` 导出 Traefik 动态配置。
- **职责**：`devcontainer` 负责声明其访问域名（如 `project.dev.local`），Traefik 负责流量转发。

#### C. 与 Gitea 的交互 (CI/CD 闭环)
- **凭据管理**：通过环境变量 (`remoteEnv`) 注入 Gitea Token 和 URL。
- **实现**：容器内 Git 配置已通过 `mounts` 与宿主机同步。
- **职责**：在容器内完成代码提交 (`git push`)，触发 Gitea Actions 流水线，执行业务镜像的自动化构建。

---

## 5. 故障排查
1. **网络问题**: 检查是否连接到 `nms-bridge`。
2. **权限问题**: 挂载目录权限应为 `755`，数据文件为 `640`。
3. **内存溢出**: 检查 Compose 中的 `deploy.resources.limits.memory`。
