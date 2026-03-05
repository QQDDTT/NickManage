---
trigger: always_on
---

# 管理工程规范

> 适用范围：`.project` 文件中 `type: management` 的工程。  
> 全局通用规则同样适用，本规范为专项补充。

---

## 1. 工程定位

管理工程是整个开发体系的**基础设施层**，负责：

- 维护所有项目共用的 devcontainer 开发环境
- 编排各软件/研究项目依赖的 Docker 服务（k3s 正式环境 / Compose 本地开发）
- 管理 CI/CD 流水线配置

管理工程**不包含任何应用业务代码**。

---

## 2. `.project` 文件

```yaml
type: management
name: 工程名称
orchestration: k3s   # 正式环境编排方式：k3s 或 compose
```

---

## 3. 目录结构

```
management-project/
├── .project
├── .devcontainer/            # devcontainer 配置
│   └── devcontainer.json     # 必需
├── docker/                   # Docker Compose（本地开发）
│   ├── compose/              # 各项目的 Compose 文件（每项目一个）
│   └── env/                  # 环境变量模板（*.env.example）
├── k3s/                      # Kubernetes 资源清单（正式环境）
│   ├── namespaces/           # 所有 Namespace 集中定义
│   ├── common/               # 跨项目共用资源（RBAC、存储类等）
│   ├── manifests/            # 原生 YAML 清单（自研服务，每项目一个子目录）
│   └── helm/                 # Helm Chart 管理（第三方服务，每项目一个子目录）
├── ci/                       # CI/CD 流水线配置
└── 
```

---

## 4. 核心禁令

| # | 禁止行为 |
|---|---|
| 1 | 在管理工程中创建业务代码文件（如 `src/`） |
| 2 | 在任何文件中硬编码密钥、密码、Token |
| 3 | 提交含真实值的 `.env`、`secret.yaml`、`values-secret.yaml` 到 Git |
| 4 | 使用 `latest` 镜像标签（Compose 和 k3s 均适用） |
| 5 | 在 devcontainer 中启动 Docker daemon（禁止 DinD） |
| 6 | 将 devcontainer 配置放在 `.devcontainer/` 以外的位置 |
| 7 | 将 Compose 文件放在 `docker/compose/` 以外的位置 |
| 8 | 将 Kubernetes 清单放在 `k3s/` 以外的位置 |

---

## 5. k3s 规范

### 5.1 Compose 与 k3s 的分工

| 用途 | 使用方式 |
|---|---|
| 本地开发启动 | `docker/compose/` |
| 正式环境部署 | `k3s/` |

同一服务**不得同时维护两套配置**，须在 `.project` 的 `orchestration` 字段中声明正式环境采用哪种方式。

### 5.2 k3s 目录结构

```
k3s/
├── namespaces/
│   └── namespaces.yaml               # 所有 Namespace 集中定义
├── common/                           # 跨项目共用资源（RBAC、存储类等）
├── manifests/                        # 原生 YAML 清单（kubectl apply，用于自研服务）
│   └── <项目名>/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── configmap.yaml
│       └── secret.yaml.example       # Secret 模板，禁止提交真实值
└── helm/                             # Helm Chart 管理（用于第三方服务）
    ├── repos.yaml                    # 记录所有 helm repo 来源及版本
    └── <项目名>/
        ├── values.yaml               # 默认值（可提交）
        └── values-secret.yaml.example  # 敏感值模板，禁止提交真实值
```

**选型原则**：自研服务使用原生 YAML（`manifests/`），第三方服务（数据库、中间件等）优先使用 Helm（`helm/`）。

### 5.3 Secret 管理

两种方式统一遵循以下流程：

1. 提交 `secret.yaml.example` / `values-secret.yaml.example` 模板到 Git（值留空）
2. 本地复制为实际文件并填写真实值，加入 `.gitignore`
3. 手动执行注入，**不经过 CI/CD 流水线**：
   - 原生 YAML：`kubectl apply -f secret.yaml`
   - Helm：`helm upgrade --install <release> ./helm/<项目名> -f values-secret.yaml`

---

## 6. devcontainer 要求

### 6.1 基础镜像

统一使用微软官方 devcontainer 基础镜像，固定到具体版本标签，禁止使用 `latest`：

```
mcr.microsoft.com/devcontainers/base:ubuntu-24.04
```

### 6.2 工具安装

通过 **devcontainer features** 安装工具链，不在 Dockerfile 中手动 `apt-get`：

```jsonc
// .devcontainer/devcontainer.json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
  "features": {
    // Docker CLI（DooD，不含 daemon）
    "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {},
    // kubectl
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {
      "installHelm": true,
      "installMinikube": false
    }
  },
  "workspaceFolder": "/workspaces/xxxx",
  "mounts": [
    // 项目目录（bind mount）
    "source=/home/nick/WorkSpace/xxxx,target=/workspaces/xxxx,type=bind,consistency=cached",
    // 宿主机 k3s kubeconfig（只读）
    "source=${localEnv:HOME}/.kube,target=/home/vscode/.kube,type=bind,readonly"
  ],
  "remoteUser": "vscode"
}
```

> `docker-outside-of-docker` feature 会自动挂载 `/var/run/docker.sock` 并完成用户组配置，无需手动添加 Socket mount。

### 6.3 禁止事项

1. 禁止使用 `latest` 标签指定基础镜像
2. 禁止在容器内启动 Docker daemon（不使用 DinD）
3. 禁止在宿主机直接安装 Java、Python、Node.js 等语言运行时

---



---

## 8. 日志收集规范

### 8.1 技术栈

本地开发环境统一使用 **Loki + Grafana + Promtail** 收集并可视化容器运行日志，通过 Docker Compose 部署。

### 8.2 Compose 文件位置

```
docker/compose/logging.yaml
```

### 8.3 Compose 配置规范

```yaml
# 日志收集服务：Loki + Grafana + Promtail
# 用途：收集本地开发环境所有容器的运行日志

services:
  loki:
    image: grafana/loki:3.0.0          # 禁止使用 latest
    restart: unless-stopped
    ports:
      - "3100:3100"
    volumes:
      - /home/nick/WorkSpace/logs/loki:/loki

  grafana:
    image: grafana/grafana:11.0.0      # 禁止使用 latest
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - /home/nick/WorkSpace/logs/grafana:/var/lib/grafana
    env_file:
      - ../env/logging.env
    depends_on:
      - loki

  promtail:
    image: grafana/promtail:3.0.0      # 禁止使用 latest
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /home/nick/WorkSpace/logs/promtail:/etc/promtail
    command: -config.file=/etc/promtail/config.yaml
    depends_on:
      - loki
```

### 8.4 宿主机目录结构

日志数据统一存放在以下路径，**须在启动前手动创建**，并加入 `.gitignore`：

```
/home/nick/.log/
├── loki/        # Loki 日志数据
│   ├── dev/     # devcontainer 开发环境日志 (路径：/home/nick/.log/loki/dev/<项目名>)
│   └── prod/    # 部署产品/服务日志 (路径：/home/nick/.log/loki/prod/<服务名>)
├── grafana/     # Grafana 配置与仪表盘
└── promtail/    # Promtail 采集配置文件
```

### 8.5 其他服务接入

其他项目的 Compose 文件须添加 Loki logging driver，将日志推送至本服务：

```yaml
services:
  <服务名>:
    logging:
      driver: loki
      options:
        loki-url: "http://localhost:3100/loki/api/v1/push"
        loki-external-labels: "project=<项目名>"
```

### 8.6 禁止事项

1. 禁止使用 `latest` 镜像标签
2. 禁止硬编码 `GF_SECURITY_ADMIN_PASSWORD`，须通过 `docker/env/logging.env` 注入
3. 禁止将 `/home/nick/.log/` 下的数据目录提交到 Git

---

## 9. 环境变量规则（Compose 模式）

- `docker/env/*.env.example`：字段模板，值留空，**必须提交 Git**
- `docker/env/*.env`：含真实值，**加入 `.gitignore`，禁止提交**