# 开发层设计文档 (DEV_DESIGN)

开发层 (dev) 为开发者提供一致、隔离且功能完整的云开发环境。通过 Docker Compose 与 VS Code Dev Containers 的深度整合，实现“随时随地、即开即用”的云端开发体验。

## 1. 核心组件协作

开发环境的构筑由分散式转向中心化管理：

### 1.1 服务基础层 (Compose)
由 `docker/compose/dev-*.yaml` 定义。其职责是定义容器运行时环境。
- **配置职责**:
    - **位置变更**: 所有开发环境 Compose 文件均存放在 `docker/compose/` 目录下。
    - **本地挂载 (物理存储)**: 项目工程源码统一存放在 `/home/nick/workspaces/<项目名>`。所有源码、配置与插件数据均持久化在此目录下，确保环境重建后的连续性。
    - **环境隔离**: **必须** 使用 `env_file` 指向根目录 `.env`。严禁硬编码路径。
    - **权限保障**: 保持 `privileged: true` 以兼容特定内核环境。
    - **资源保障**: 固定 **4096M (4GB)** 内存限制，优化 `ulimits`。
    - **共享资源**:
        - `${DEV_CACHE_HOME}`: 集中挂载多种开发语言（Java, Python, Go 等）的运行时环境与依赖缓存（位于 `volumes/dev/`）。
    - **全局配置**: 无需手动挂载 `${USER_HOME}/.gemini` 等配置，系统已内置集成。
    - **无宿主机身份依赖**: 移除所有与宿主机相关的 `.gitconfig` 或 `.ssh` 挂载，统一由 Gitea 代理身份认证。

### 1.2 IDE 增强层 (devcontainer.json)
由 `docker/devcontainer/devcontainer-*.json` 集中定义。其职责是配置编辑器行为。
- **集中管理**: 各项目的 Dev Container 配置统一存放于 `docker/devcontainer/`，并且通过软链接至项目的工作区目录内（`/home/nick/workspaces/<项目名>/.devcontainer`），以适配 VS Code 扫描要求。
- **特定挂载**: 须在 `devcontainer.json` 中配置项目工作区的 `workspaceMount`。由于镜像内置 Antigravity，无需手动挂载 IDE 服务端数据。
- **外部代理**: 引用 `../compose/dev-*.yaml` 作为基础设施定义。

## 2. 云开发代理机制 (Gitea)

为了实现彻底的云端化，开发环境不再依赖宿主机的身份凭证和文件系统。

### 2.1 源码与身份全权代理
- **Gitea 核心角色**: 容器内的 `git` 操作由 Gitea 全权代理。
- **认证自动化**: 容器启动时通过环境变量（`GITEA_TOKEN` 等）自动配置内部 Git 令牌，无需挂载宿主机的 `.gitconfig` 或 `.ssh`。
- [x] **数据流转**: 虽然保留物理挂载以加速开发，但 Gitea 仍作为源码的最终归宿。
- [x] **安全性**: 强制推行“及时推送”原则，所有未推送至 Gitea 的本地代码变更应视为处于易失状态。

### 2.3 初始化引导 (Bootstrapping)
当容器检测到工作空间目录为空时，将触发自动引导逻辑：
1. **获取配置**: 从环境变量提取 `GITEA_REPO_URL`。
2. **身份就位**: 使用注入的 `GITEA_TOKEN` 配置本地 Git 凭证。
3. **自动克隆**: 执行 `git clone` 将最新的源码同步至容器内部路径。
4. **状态锁定**: 标记引导完成，后续启动将直接进入开发状态。

### 2.2 容器能力隔离
- **取消直接 Socket 挂载**: 严禁在开发容器中直接挂载宿主机的 `/var/run/docker.sock`，以消除容器逃逸和非法提权风险。
- **DooD (Docker-outside-of-Docker) 代理方案**: 开发容器通过 `nms` 网络访问 `ops-docker-socket-proxy`。所有针对 Docker Daemon 的操作必须经过此代理。

### 2.4 App 层服务自动化部署
开发容器通过代理服务实现对业务应用（App 层）的透明管理与部署：

1.  **通信协议**: 开发容器内部配置环境变量 `DOCKER_HOST=tcp://ops-docker-socket-proxy:2375`。
2.  **写操作授权**: `ops-docker-socket-proxy` 配置为允许 `POST` 请求，从而支持开发环境执行 `docker compose up`、`docker build` 等写操作。
3.  **必备组件**: 开发层镜像或 `devcontainer.json` 必须预装 `docker-cli` (或 `docker.io`) 及 `docker-compose-v2` 插件，否则无法发起 API 调用。
4.  **部署流程**:
    - 开发者在 VS Code 终端执行部署指令。
    - 指令经由 `DOCKER_HOST` 转发至底座层的代理服务。
    - 代理服务在安全过滤后将请求传递给宿主机 Docker 守护进程。
    - 业务容器直接运行在宿主机网络空间，并受底座层监控与路由系统的管理。

## 3. 开发层管理规则
1. **集中化配置**: 严禁在项目源码目录内存储任何环境配置文件（如 `.devcontainer` 文件夹）。
2. **预装 IDE 镜像**: 废弃在启动时安装工具的逻辑，开发层必须使用预装 Antigravity IDE 的基础镜像（如 `antigravityide/antigravity`），确保环境一致性。
3. **变量驱动**: 所有路径引用必须通过全域环境变量，确保存储后端可平滑切换至 S3 或云盘。
