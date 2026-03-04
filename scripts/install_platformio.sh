#!/bin/bash
# 安装 Python 3 和 PlatformIO
set -e

CONTAINER=$1
if [ -z "$CONTAINER" ]; then
    echo "使用方法: $0 <容器名称> (例如: $0 microcontroller-flasher-dev)"
    exit 1
fi

echo "正在宿主机调度为容器 '$CONTAINER' 安装 PlatformIO..."
docker exec -i "$CONTAINER" bash << 'EOF'
set -e
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    udev

sudo ln -sf /usr/bin/python3 /usr/local/bin/python
sudo ln -sf /usr/bin/pip3 /usr/local/bin/pip

sudo pip install --no-cache-dir platformio

# 修复 pio 环境变量
echo 'export PATH=$PATH:/home/vscode/.local/bin' | sudo tee /etc/profile.d/pio.sh >/dev/null

echo "PlatformIO 安装完成！重新进入容器 bash 即可生效。"
EOF
