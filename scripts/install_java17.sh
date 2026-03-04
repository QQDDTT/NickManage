#!/bin/bash
# 安装 Java 17 (Temurin) 和 Maven
set -e

CONTAINER=$1
if [ -z "$CONTAINER" ]; then
    echo "使用方法: $0 <容器名称> (例如: $0 java-teaching-dev)"
    exit 1
fi

echo "正在宿主机调度为容器 '$CONTAINER' 安装 Java 17 和 Maven..."
docker exec -i "$CONTAINER" bash << 'EOF'
set -e
sudo apt-get update
sudo apt-get install -y --no-install-recommends wget apt-transport-https gnupg

wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo $VERSION_CODENAME) main" | sudo tee /etc/apt/sources.list.d/adoptium.list

sudo apt-get update
sudo apt-get install -y --no-install-recommends temurin-17-jdk maven

echo 'export JAVA_HOME=/usr/lib/jvm/temurin-17-amd64' | sudo tee /etc/profile.d/java.sh >/dev/null
echo 'export PATH=$PATH:$JAVA_HOME/bin' | sudo tee -a /etc/profile.d/java.sh >/dev/null

echo "Java 17 安装完成！重新进入容器 bash 即可生效。"
EOF
