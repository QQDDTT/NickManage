---
description: 交互式创建新的软件开发工程 (type: software)
---

# 软件工程项目创建工作流

当用户明确提出要创建新软件工程项目时，按以下步骤执行。

---

## Step 1 — 需求构思

询问用户项目的核心功能、预期目标与业务场景。

## Step 2 — 项目命名

提供 3~5 个英文名称建议（格式如 `E-Commerce-Backend`），等待用户确认。

## Step 3 — 技术栈选型

推荐编程语言及附加中间件（数据库、缓存等），等待用户选择。**记录是否有附加中间件，决定后续是否生成 Docker Compose。**

---

## Step 4 — 生成 Dockerfile

路径：`/home/nick/NickManage/docker/devcontainer/<项目名>.Dockerfile`

```dockerfile
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    git curl vim build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 按所选语言替换此区块，示例为 Python 3.12
RUN apt-get update && apt-get install -y python3.12 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Dev Container 语言识别用
ENV LANG_RUNTIME="python"
ENV LANG_VERSION="3.12"
ENV PATH="/usr/local/bin/python3:$PATH"

WORKDIR /workspace
```

| 语言 | `LANG_RUNTIME` | `LANG_VERSION` |
|---|---|---|
| Python | `python` | `3.12` |
| Node.js | `node` | `20` |
| Java | `java` | `21` |
| Rust | `rust` | `1.78` |
| C# (.NET) | `dotnet` | `8.0` |
| Go | `go` | `1.22` |


---

## Step 5 — 目录初始化与文档

```bash
mkdir -p /home/nick/WorkSpace/<项目名>/{docs,.devcontainer,.agent/rules}
```

**`.project`** — `/home/nick/WorkSpace/<项目名>/.project`
```yaml
type: software
name: <项目名>
lang: <LANG_RUNTIME>
lang_version: <LANG_VERSION>
created_at: <ISO8601>
```

**架构设计书** — `docs/architecture.md`（按技术栈生成，含概述、模块划分、数据流、部署拓扑）

**`soft-rule.md`** — `.agent/rules/soft-rule.md`
```markdown
# 软件开发工程规范

> 仅适用于 `type: software` 工程。

## 1. 工程定位

在 devcontainer 环境中开发应用功能代码，构建产物以容器镜像方式交付。

## 2. 目录结构

```
project/
├── .project
├── .devcontainer/     # devcontainer 配置
├── src/               # 应用源代码
├── docker/            # 构建镜像所需 Dockerfile 及 Compose 文件
└── docs/              # 项目文档（按需创建）
```
\```

**`devcontainer.json`** — `.devcontainer/devcontainer.json`

情况 A（无附加中间件）：
```json
{
  "name": "<项目名>",
  "build": {
    "dockerfile": "/home/nick/NickManage/docker/devcontainer/<项目名>.Dockerfile",
    "context": "/home/nick/NickManage/docker/devcontainer"
  },
  "workspaceFolder": "/workspace",
  "mounts": [
    "source=/home/nick/WorkSpace/<项目名>,target=/workspace,type=bind,consistency=cached",
    "source=/home/nick/.kube,target=/root/.kube,type=bind,readonly",
    "source=/home/nick/.gitconfig,target=/home/vscode/.gitconfig,type=bind,readonly",
    "source=/home/nick/.ssh,target=/vscode/.ssh,type=bind,readonly"
  ],
  "features": {
    "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": { "installHelm": true }
  },
  "remoteEnv": { "LANG_RUNTIME": "<语言名>", "LANG_VERSION": "<版本号>" }
}
```

情况 B（有附加中间件）：
```json
{
  "name": "<项目名>",
  "dockerComposeFile": "/home/nick/NickManage/docker/compose/<项目名>.yaml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "mounts": [
    "source=/home/nick/.kube,target=/vscode/.kube,type=bind,readonly",
    "source=/home/nick/.gitconfig,target=/home/vscode/.gitconfig,type=bind,readonly",
    "source=/home/nick/.ssh,target=/vscode/.ssh,type=bind,readonly"
  ],
  "features": {
    "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": { "installHelm": true }
  },
  "remoteEnv": { "LANG_RUNTIME": "<语言名>", "LANG_VERSION": "<版本号>" }
}
```

---

## Step 6 — 启动

- **情况 A**：用 VS Code 打开项目目录 → 执行「Reopen in Container」。
- **情况 B**：`docker compose -f /home/nick/NickManage/docker/compose/<项目名>.yaml up -d`

容器就绪后，`LANG_RUNTIME` / `LANG_VERSION` 已注入，建议通过 `open_workspace.sh` 开始开发。