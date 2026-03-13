#!/bin/bash

# 建立开发层基础镜像脚本
# 镜像名: dev-image:latest

MNG_HOME="/home/nick/NickManage"
DOCKERFILE_DIR="${MNG_HOME}/docker/dev"
IMAGE_NAME="dev-image:latest"

echo ">>> 开始构建开发层基础镜像: ${IMAGE_NAME} <<<"

# 检查 Dockerfile 是否存在
if [ ! -f "${DOCKERFILE_DIR}/Dockerfile" ]; then
    echo "错误: 未找到 Dockerfile 在 ${DOCKERFILE_DIR}"
    exit 1
fi

# 构建镜像
docker build -t "${IMAGE_NAME}" "${DOCKERFILE_DIR}"

if [ $? -eq 0 ]; then
    echo "========================================="
    echo "镜像 ${IMAGE_NAME} 构建成功！"
    echo "可用指令: docker images | grep dev-image"
    echo "========================================="
else
    echo "错误: 镜像构建失败。"
    exit 1
fi
