#!/bin/bash
# 安装 Rust 稳定版
set -e

CONTAINER=$1
if [ -z "$CONTAINER" ]; then
    echo "使用方法: $0 <容器名称> (例如: $0 graph-weave-dev)"
    exit 1
fi

echo "正在宿主机调度为容器 '$CONTAINER' 安装 Rust 工具链..."
docker exec -i "$CONTAINER" bash << 'EOF'
set -e
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    pkg-config \
    libssl-dev

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

# 全局环境变量
echo 'export PATH=/home/vscode/.cargo/bin:$PATH' | sudo tee /etc/profile.d/rust.sh >/dev/null

echo "Rust 安装完成！重新进入容器 bash 即可生效。"
EOF
