# 共享层设计文档 (SHARE_DESIGN)

共享层 (share) 为整个系统提供公共的基础设施、数据存储以及 AI 推理能力。该层级服务旨在为多个项目提供支持，并保持长期在线运行。

## 1. 服务分类与职责

共享层服务根据其功能主要分为以下三类：

### 1.1 数据存储与管理 (Data & Storage)
| 服务名 | 容器名 | 职责 | 实现技术 |
|---|---|---|---|
| **PostgreSQL** | `share-postgres` | 关系型/时间序列数据存储 | TimescaleDB |
| **PostgreSQL** | `share-postgres` | 关系型/时间序列数据存储 | TimescaleDB |
| **ChromaDB** | `share-chromadb` | 向量数据库 | Chroma |
| **Qdrant** | `share-qdrant` | 向量数据库 | Qdrant |
| **MLFlow** | `share-mlflow` | AI 模型生命周期管理 | MLFlow |

### 1.2 AI 推理能力 (AI Inference)
| 服务名 | 容器名 | 职责 | 实现技术 |
|---|---|---|---|
| **Llama.cpp** | `share-llamacpp` | 大语言模型 (LLM) 推理 | llama.cpp (server) |
| **Embedding** | `share-embedding` | 向量嵌入服务 | llama.cpp (server) |
| **Whisper** | `share-whisper` | 语音转文字 (STT) | Whisper Server |
| **VITS** | `share-vits` | 文字转语音 (TTS) | VITS-Simple-API |

## 2. 挂载规范 (Mounting Rules)

共享层遵循严格的挂载路径分配原则，以区分“持久化数据”与“模型/资源文件”。

### 2.1 持久化数据 (volumes/share/)
根据架构管理规则，所有使用 `yaml` 构筑的数据库及状态化服务，其持久化数据必须使用命名卷或存放在 `volumes/`：
- `${MNG_HOME}/volumes/share/postgres`: 数据库文件。
- `${MNG_HOME}/volumes/share/chromadb`: 向量索引与元数据。
- `${MNG_HOME}/volumes/share/mlflow`: 实验记录与 Artifacts。

### 2.2 模型与共享资源 (mounts/share/)
静态资源、配置文件及大型模型文件存放于 `mounts/`：
- `${MNG_HOME}/mounts/share/models`: 统一存放 GGUF、Bin 等各种格式的模型文件。
- `${MNG_HOME}/mounts/share/vits/config.yaml`: 特定服务的静态配置文件。

## 3. 资源管理与稳定性 (Resource Management)

为了在多任务环境下保证系统稳定性，共享层采用了分级资源策略。

### 3.1 内存预留 (Reservations)
服务通过 `deploy.resources.reservations` 声明其正常运行所需的最小内存：
- **AI 推理**: 预留较高 (1G - 2G)，确保模型加载后不会因内存不足导致的频繁交换。
- **数据库**: 预留中等 (256M)，保证基础索引常驻内存。

### 3.2 OOM 优先级策略
通过 `oom_score_adj` 控制在系统压力过大时的进程终止顺序：
- **核心数据库 (PostgreSQL)**: 设置为 `-800` 到 `-500`，受到高度保护。
- **管理平台 (MLFlow)**: 设置为 `-500`。
- **AI 推理服务 (Whisper, LLM)**: 设置为 `-200`，作为较低权重的服务，在极端情况下会被优先牺牲以保全系统底座及数据库。

## 4. 接入规范
- **网络**: 所有服务均接入 `nms-bridge` 外部网络。
- **变量引用**: 所有路径务必引用 `${MNG_HOME}`，所有密码务必引用 `.env` 中的全局变量。
