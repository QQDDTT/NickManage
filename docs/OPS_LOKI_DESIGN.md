# Loki 日志管理设计文档

## 1. 概述

NickManage 采用 **Vector + Loki** 的架构实现全量日志管理。Vector 作为采集引擎，通过 Docker API 实时捕获容器日志并推送到 Loki 进行存储，以此实现各层服务（ops, share, dev, app）的日志统一化与可搜索化。

## 2. Vector 采集规则

### 2.1 自动发现机制

Vector 监控 Docker 宿主机的容器事件，基于以下标签（Labels）决定采集策略：

- **采集开关**：`nms.collect: "true"`
- **数据流向**：Vector 会拦截所有 stdout/stderr 输出，并自动注入元数据（如容器名、镜像 ID）。

### 2.2 静态标签映射 (Transmutation)

在采集过程中，Vector 会根据 `nms.layer` 标签为日志打上静态标签，方便 Loki 索引：

- `layer`：对应 `ops`, `share`, `dev`, `app`。
- `container_name`：去除 Docker 生成的斜杠前缀。

## 3. Loki 管理规则

### 3.1 索引与分片策略

Loki 通过标签进行分片存储。核心索引维度包括：
- `layer`：最高优先级的查询维度。
- `host`：容器所在的宿主机。
- `container_name`：具体服务的唯一标识。

### 3.2 持久化存储

- **路径**：`${MNG_HOME}/volumes/ops/loki`。
- **配置**：采用单节点模式（Filesystem），适用于工作站环境。
- **保留策略 (Retention)**：`dev` 层日志默认保留 1 天，其他层级详见 `OPS_DESIGN.md`。

## 4. 日志查看方式 (VSCode 插件)

由于系统未部署轻量级 Grafana 以节省资源，推荐开发者在 VSCode 中直接查看日志。

### 4.1 推荐插件
- **插件名称**：`Grafana Loki` (由官方或第三方提供) 或 `Loki Explorer`。

### 4.2 配置步骤
1. **连接地址**：`http://localhost:3100` (或容器内通过 `loki:3100` 访问)。
2. **查询语法 (LogQL)**：
   - 查看所有业务层日志：`{layer="app"}`
   - 过滤特定服务错误：`{container_name="my-app"} |= "error"`
   - 实时流追踪：配合插件的 "Follow" 功能。

## 5. 运维指南

- **状态检查**：访问 `http://localhost:3100/ready` 确认 Loki 服务状态。
- **日志导出**：必要时可使用 `logcli` 命令行工具导出大规模历史日志。
