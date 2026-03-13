# 项目目录结构 (DIRECTORY_STRUCTURE)

本文档定义了管理工程的物理与逻辑目录结构，旨在实现配置、数据与脚本的严格解耦。

```text
/home/nick/NickManage/
├── scripts/                 # 管理脚本目录
│   ├── load_env.sh          # 全局环境变量加载脚本
│   ├── Antigravity-Manage/  # Antigravity 专有启动及管理脚本
│   └── Docker-Manage/       # 通用 Docker 容器管理工具及脚本
├── docker/                  # 容器定义核心目录
│   ├── compose/             # 各层级服务的 Compose 配置文件 (.yaml)
│   └── devcontainer/        # 开发层各项目的 devcontainer 定义文件
├── docs/                    # 系统设计、架构、IDE 规范及运行维护文档
│   ├── IDE_USAGE_SPECIFICATION.md # IDE 使用规范 (Antigravity 唯一性与配置规范)

├── .env                     # 全局环境变量 (敏感数据，GIT 忽略)
├── .env.example             # 全局环境变量模板
├── link/                    # 宿主机配置文件的符号链接 (Symlinks)
│   ├── applications/      # 系统应用程序快捷方式 (.desktop) 链接
│   ├── env/                 # 宿主机 shell 环境变量与全局规则链接
│   └── github/              # Git 配置与 SSH 密钥公钥链接
├── mounts/                  # 基于 Bind Mount 的容器挂载点
│   ├── ops/                 # 底座层服务的持久化数据
│   └── share/               # 共享层服务的持久化数据
├── volumes/                 # 基于 Named Volume 的容器卷声明
│   ├── ops/                 # 底座层服务的持久化数据 (如 Gitea)
│   └── share/               # 共享层服务的持久化数据
├── .project                 # 项目标识文件
└── .env                     # 工程级全局环境变量
```

## 目录职能说明

1.  **管理脚本 (Manage)**: 分为 `Antigravity-Manage` 和 `Docker-Manage`，分别负责 AI Agent 专用逻辑与通用容器运维。
2.  **容器配置 (docker)**: 本项目的灵魂，所有服务的拓扑结构 (Compose) 与 环境上下文 (env) 均在此定义。
3.  **配置链接 (link)**: 集中管理宿主机分散的配置文件，通过软链接实现配置的版本化控制而不侵入宿主机。
4.  **数据挂载 (mounts/volumes)**:
    *   `mounts/`: 用于需要宿主机直接访问或权限较为透明的数据。
    *   `volumes/`: 用于完全由 Docker 管理的具名卷数据。
5.  **文档中心 (docs)**: 存放包括架构设计、目录规范在内的所有非技术性说明文件。
