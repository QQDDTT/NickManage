# IDE 使用规范 (IDE_USAGE_SPECIFICATION)

本文档定义了 NickNet 架构中管理项目与开发容器（devcontainer）的 IDE 使用标准，旨在确保开发环境的高度一致性、安全性和 AI 辅助的高效性。

## 1. 核心原则：Antigravity 唯一性

**本架构中的管理项目（NickManage）和所有 devcontainer 仅能使用 Antigravity 作为唯一的开发工具。**

*   **唯一性要求**：禁止使用传统的本地 IDE（如原生 VS Code, IntelliJ, PyCharm 等）直接打开项目，除非其作为 Antigravity 的底层载体且完全遵循本规范。
*   **AI 深度集成**：系统依赖 Antigravity 提供的 AI Agent 能力进行自动化运维、代码审计及规则校验。

## 2. 身份与授权共享规范

为了确保“无论任何远程电脑访问 dev 容器，都使用宿主机的配置和用户”，所有 devcontainer 必须遵循以下挂载规范：

### 2.1 用户透传
*   **远程用户**：容器内默认用户应设定为 `vscode` 或同等非 root 用户。
*   **权限一致性**：通过 Docker 挂载确保容器内操作与宿主机用户 `nick` 的权限对等。

### 2.2 核心配置挂载 (Uniform Identity)
所有 devcontainer 必须在 `devcontainer.json` 的 `mounts` 属性中挂载以下路径：
*   **Git 配置**：
    *   `source=${MNG_HOME}/volumes/share/git/gitconfig,target=/home/vscode/.gitconfig,type=bind,readonly=true`
    *   `source=${MNG_HOME}/volumes/share/git/.git-credentials,target=/home/vscode/.git-credentials,type=bind,readonly=true`
*   **AI 引擎环境准备**：
    - 无需镜像预装：环境依赖（如 `libsecret`, `libgtk`）和权限纠正已通过 `devcontainer.json` 自动化配置，确保 IDE 运行时可动态部署并平滑运行。
*   **环境基础设施**：
    *   `/etc/localtime` (时间同步)
    *   容器专属 `bash_history` (持久化命令行历史)

## 3. 环境独立性与自治

每个 devcontainer 必须保持技术栈的纯粹性与配置的独立性。

### 3.1 编程语言与运行时 (Runtime Isolation)
*   **禁止宿主机污染**：宿主机不安装任何语言运行时。
*   **按需声明**：每个项目通过 `devcontainer.json` 中的 `features` 或 `dockerfile` 定义各自独立的编程语言版本（如 Python 3.12, Node.js 20 等）。

### 3.2 插件管理 (Customized Plugins)
*   **专属插件集**：在 `devcontainer.json` 的 `customizations.vscode.extensions` 中声明该项目所需的插件。
*   **环境就绪**：IDE 环境随镜像启动即用，无需额外数据平面挂载，极大地简化了环境迁移成本。

### 3.3 动态部署与兼容性 (Dynamic Deployment)
*   **按需加载**：IDE 服务端组件由 Antigravity 客户端在连接时自动部署至容器，无需在镜像中硬编码 IDE 版本。
*   **依赖解耦**：镜像仅负责提供稳定的系统底座（如 Ubuntu 24.04）和必要的共享库。通过 `devcontainer.json` 的 `postCreateCommand` 自动化完成环境微调（如权限补丁）。
*   **快速迭代**：IDE 的升级不再触发镜像重构，显著提升了开发环境的灵活性。

### 3.4 项目规则文件 (.agents)
*   **角色定义**：每个项目根目录下必须包含 `.agents` 文件夹。
*   **功能**：存放该项目专属的 AI Agent 规则、工作流（Workflows）及个性化指令。
*   **优先级**：`.agents` 中的规则优先于全局规则，确保 AI Agent 在不同项目中表现出符合该项目技术规范的行为（例如：仅允许使用特定编程语言）。

---

## 4. 维护与更新

本规范作为 NickNet 的核心准则，由 AI Agent 在创建新项目（通过 `create_project.sh`）时强制执行。任何偏离本规范的配置更改应先更新本文档并经过架构审计。
