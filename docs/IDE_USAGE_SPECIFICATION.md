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
    *   `source=${MNG_DIR}/volumes/share/git/gitconfig,target=/home/vscode/.gitconfig,type=bind,readonly=true`
    *   `source=${MNG_DIR}/volumes/share/git/.git-credentials,target=/home/vscode/.git-credentials,type=bind,readonly=true`
*   **AI 引擎配置**：
    *   `source=/home/nick/.antigravity,target=/home/vscode/.antigravity,type=bind`
    *   `source=/home/nick/.gemini,target=/home/vscode/.gemini,type=bind`
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
*   **持久化**：VS Code 服务端数据应挂载到单独的 volume 中（如 `volumes/dev/<project>/vscode-server`），确保插件安装状态不因容器销毁而丢失。

### 3.3 项目规则文件 (.agents)
*   **角色定义**：每个项目根目录下必须包含 `.agents` 文件夹。
*   **功能**：存放该项目专属的 AI Agent 规则、工作流（Workflows）及个性化指令。
*   **优先级**：`.agents` 中的规则优先于全局规则，确保 AI Agent 在不同项目中表现出符合该项目技术规范的行为（例如：仅允许使用特定编程语言）。

---

## 4. 维护与更新

本规范作为 NickNet 的核心准则，由 AI Agent 在创建新项目（通过 `create_project.sh`）时强制执行。任何偏离本规范的配置更改应先更新本文档并经过架构审计。
