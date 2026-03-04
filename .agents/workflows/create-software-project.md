---
description: 交互式创建新的软件开发工程 (type: software)
---

当用户明确提出要创建一个新的软件工程（App、服务等系统项目）时，必须严格按照以下递进步骤执行：

### Step 1: 需求描述与构思
- **动作**: 询问用户该软件项目的基本构思、核心功能、预期目标以及业务场景。
- **目标**: 获得足够的上下文以支持后续的架构决策。

### Step 2: 方案推荐与项目命名
- **动作**: 根据获取的构思，向用户提供 3~5 个合适的项目英文名称建议（需符合目录命名规范，例如 `E-Commerce-Backend`，避免特殊字符）。
- **要求**: 等待用户明确选择或确认最终的项目名称。

### Step 3: 技术栈选型
- **动作**: 推荐适合该业务场景的编程语言（如 Python, Rust, Node.js, C#, Java 等）及可能需要的附加中间件（数据库、缓存），并等待用户选择。

### Step 4: 生成 Docker Compose 编排
- **动作**: 在 `/home/nick/NickManage/docker/compose/` 目录下生成 `<项目名>.yaml` 文件。
- **强制规范**:
  - `type: software` 必须使用基础镜像：`image: mcr.microsoft.com/devcontainers/base:ubuntu-24.04` (禁止使用 build)。
  - 必须包含挂载点：`- /home/nick/WorkSpace/<项目名>:/workspace:cached`
  - 必须加入 Loki 标准日志驱动配置。
  - `command: >` 必须使用包含断联检测（5秒退出）的自动停机心跳脚本监控 IDE 存活。

### Step 5: 宿主机目录初始化与文档输出
- **动作 1**: 在宿主机的规范路径 `/home/nick/WorkSpace/<项目名>` 下自动创建项目的物理根目录。
- **动作 2**: 在此根目录内生成标准的 `.project` 标识文件（标明 `type: software` 及 `name: <项目名>`）。
- **动作 3**: 根据所选的技术栈及构思，直接在根目录或 `docs/` 下生成第一版《架构设计书》。

### Step 6: 容器实例化启动
- **动作**: 执行命令 `docker compose -f /home/nick/NickManage/docker/compose/<项目名>.yaml up -d` 在后台拉起该新项目的纯净开发容器。
- **结束语**: 告知用户容器已就绪，他们可以通过 `open_workspace.sh` 或者自己利用 `scripts/install_xxx.sh` 对这个裸容器注入相应语言的运行时。
