#!/bin/bash
# 安装 .NET SDK 8.0
set -e

CONTAINER=$1
if [ -z "$CONTAINER" ]; then
    echo "使用方法: $0 <容器名称> (例如: $0 csharp-teaching-dev)"
    exit 1
fi

echo "正在宿主机调度为容器 '$CONTAINER' 安装 .NET SDK 8.0..."
docker exec -i "$CONTAINER" bash << 'EOF'
set -e
sudo apt-get update
sudo apt-get install -y --no-install-recommends curl ca-certificates

curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
chmod +x /tmp/dotnet-install.sh
sudo /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/local/dotnet
rm /tmp/dotnet-install.sh

# 添加配置到 profile.d 以便全局生效
echo 'export DOTNET_ROOT=/usr/local/dotnet' | sudo tee /etc/profile.d/dotnet.sh >/dev/null
echo 'export PATH=$PATH:/usr/local/dotnet' | sudo tee -a /etc/profile.d/dotnet.sh >/dev/null

echo ".NET 8.0 安装完成！重新进入容器 bash 即可生效。"
EOF
