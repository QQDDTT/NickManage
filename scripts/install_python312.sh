#!/bin/bash
# 安装 Python 3.12 及相关工具
set -e

CONTAINER=$1
if [ -z "$CONTAINER" ]; then
    echo "使用方法: $0 <容器名称> (例如: $0 alpacalens-dev)"
    exit 1
fi

echo "正在宿主机调度为容器 '$CONTAINER' 安装 Python 3 环境..."
docker exec -i "$CONTAINER" bash << 'EOF'
set -e
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential

# 创建软链接
sudo ln -sf /usr/bin/python3 /usr/local/bin/python
sudo ln -sf /usr/bin/pip3 /usr/local/bin/pip

echo "Python 3 安装完成！"
python --version
EOF
