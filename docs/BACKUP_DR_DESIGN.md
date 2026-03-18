# 备份与防灾设计文档 (BACKUP_DR_DESIGN)

本文档定义了 NickManage 系统的备份策略、容灾机制以及恢复流程，确保数据的持久性和系统的可用性。

## 1. 备份目标与范围

根据系统架构层级，备份分为以下两个核心部分：

### 1.1 共享层数据 (Share Layer Data)
- **目标**: 保证公共基础设施数据的安全。
- **范围**:
    - `${MNG_HOME}/volumes/share/postgres`: 关系型数据库数据。
    - `${MNG_HOME}/volumes/share/chromadb`: 向量数据库索引与元数据。
    - `${MNG_HOME}/volumes/share/mlflow`: AI 实验记录。
- **原因**: 数据库包含系统的核心业务逻辑状态和长期积累的 AI 训练成果。

### 1.2 开发层代码 (Dev Layer Code)
- **目标**: 保护开发者的劳动成果。
- **范围**: `/home/nick/workspaces/` 下的所有项目源码。
- **原因**: 虽然 Gitea 是源码的最终归宿，但物理挂载的本地工作区包含尚未推送的实验性修改、本地配置等。

## 2. 备份策略 (Backup Strategy)

| 维度 | 策略 | 说明 |
|---|---|---|
| **备份频率** | 每日一次 (Daily) | 建议在系统低峰期（如凌晨 3:00）执行。 |
| **备份方式** | 全量压缩 (Full Archive) | 采用 `tar.gz` 格式。**注意**: 部分数据目录可能需要 root 权限。 |
| **保留周期** | 7 天 | 本地保留最近 7 天的滚动备份，旧备份自动清理。 |
| **存储位置** | `${MNG_HOME}/backups/` | 建议定期同步至外部存储或云端。 |

## 3. 容灾设计 (Disaster Recovery)

### 3.1 代码多中心容灾 (Gitea Mirroring)
- **机制**: `ops-gitea` 服务内置 Mirroring 功能。
- **实现**: 每个本地仓库应配置镜像同步至 GitHub 或其他远程 Git 平台，实现源码级的跨云防灾。

### 3.2 镜像与配置防灾 (Infrastructure as Code)
- **机制**: 整个系统由 Compose 和 Dockerfile 定义。
- **实现**: `NickManage` 自身的代码同步至远程 Git。即使物理机损毁，只需 `git clone NickManage` 并执行备份恢复，即可快速重建底座。

## 4. 恢复流程 (Recovery Process)

### 4.1 数据恢复
1.  停止相关服务：`docker compose down`。
2.  清空损坏的数据目录：`rm -rf ${MNG_HOME}/volumes/share/postgres/*`。
3.  解压备份文件：`tar -zxvf backup_file.tar.gz -C /`。
4.  重启服务并检查日志。

### 4.2 环境重建
1.  在物理机检修完成后，部署 Docker 及基础环境。
2.  克隆管理仓：`git clone <Gitea_URL>/nick/NickManage.git`。
3.  按照 4.1 步恢复 `volumes` 数据。
4.  执行 `./scripts/load_env.sh` 初始化环境变量。
5.  启动底座：`docker compose -f docker/compose/ops-compose.yaml up -d`。

## 5. 监控与告警
- 备份脚本执行结果将记录至 `${MNG_HOME}/backups/logs/` 目录下。
- 由 Vector 采集日志，管理员可通过 Loki 监控备份任务的成功与耗时。
