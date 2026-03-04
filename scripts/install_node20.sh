#!/bin/bash
# 安装 Node.js 20
set -e

CONTAINER=$1
if [ -z "$CONTAINER" ]; then
    echo "使用方法: $0 <容器名称> (例如: $0 japanese-learning-app-dev)"
    exit 1
fi

echo "正在宿主机调度为容器 '$CONTAINER' 安装 Node.js 20..."
docker exec -i "$CONTAINER" bash << 'EOF'
set -e
sudo apt-get update
sudo apt-get install -y --no-install-recommends curl

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs

echo "Node.js 安装完成！"
node -v
npm -v
EOF
