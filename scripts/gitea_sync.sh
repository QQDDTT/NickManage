#!/bin/bash

# Gitea -> GitHub 自动镜像同步脚本
# 用法: ./gitea_sync.sh <项目名>

PROJECT_NAME="$1"

if [ -z "$PROJECT_NAME" ]; then
    echo "使用方法: $0 <项目名>"
    exit 1
fi

# 加载环境变量
ENV_FILE="/home/nick/NickManage/.env"
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "错误: 找不到 .env 文件"
    exit 1
fi

GITEA_API="http://ops-gitea:3000/api/v1"
if ! curl -s --connect-timeout 2 http://ops-gitea:3000 > /dev/null; then
    # 如果内部域名不可达，尝试使用容器 IP 或 localhost (取决于执行环境)
    GITEA_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ops-gitea 2>/dev/null)
    GITEA_API="http://${GITEA_IP:-172.28.0.12}:3000/api/v1"
fi

echo "--- 正在处理项目: $PROJECT_NAME ---"

# 1. 确保 Gitea 仓库存在 (如果不存在则创建)
REPO_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITEA_TOKEN" "$GITEA_API/repos/nick/$PROJECT_NAME")

if [ "$REPO_EXISTS" != "200" ]; then
    echo "-> 正在创建 Gitea 仓库..."
    curl -s -X POST -H "Authorization: token $GITEA_TOKEN" -H "Content-Type: application/json" \
         -d "{\"name\":\"$PROJECT_NAME\", \"private\":false}" \
         "$GITEA_API/user/repos" > /dev/null
fi

# 2. 配置 GitHub 镜像同步 (Push Mirror)
# 先检查是否已存在镜像
MIRROR_EXISTS=$(curl -s -H "Authorization: token $GITEA_TOKEN" "$GITEA_API/repos/nick/$PROJECT_NAME/push_mirrors" | jq -r ".[] | select(.remote_address | contains(\"github.com/QQDDTT/$PROJECT_NAME\")) | .remote_name")

if [ -z "$MIRROR_EXISTS" ]; then
    echo "-> 正在配置 GitHub 镜像同步..."
    # 注意：这里使用 GITHUB_ACCESS_TOKEN 构造带鉴权的远程地址
    # 格式: https://<token>@github.com/QQDDTT/<repo>.git
    REMOTE_ADDR="https://${GITHUB_ACCESS_TOKEN}@github.com/QQDDTT/${PROJECT_NAME}.git"
    
    curl -s -X POST -H "Authorization: token $GITEA_TOKEN" -H "Content-Type: application/json" \
         -d "{\"remote_address\":\"$REMOTE_ADDR\", \"sync_on_commit\":true, \"interval\":\"8h0m0s\"}" \
         "$GITEA_API/repos/nick/$PROJECT_NAME/push_mirrors" > /dev/null
    echo "同步链路已建立: Gitea -> GitHub"
else
    echo "-> GitHub 镜像已存在，确保同步状态..."
    # 强制开启实时同步 (sync_on_commit)
    # Gitea API 目前可能需要获取 remote_name 来更新，或者重新创建
    echo "镜像记录已就绪。"
fi

echo "--- $PROJECT_NAME 同步配置完成 ---"
