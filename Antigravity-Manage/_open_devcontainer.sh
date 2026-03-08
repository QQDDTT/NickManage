#!/bin/bash

# 核心逻辑：打开指定的 Dev Container 工作空间
# 参数 1: 文件夹绝对路径

FOLDER_PATH="$1"

if [ -z "$FOLDER_PATH" ]; then
    echo "错误：未指定文件夹路径"
    exit 1
fi

if [ ! -d "$FOLDER_PATH" ]; then
    echo "错误：文件夹不存在: $FOLDER_PATH"
    exit 1
fi

DEVCONTAINER_JSON="$FOLDER_PATH/.devcontainer/devcontainer.json"

if [ ! -f "$DEVCONTAINER_JSON" ]; then
    echo "错误：devcontainer.json 不存在: $DEVCONTAINER_JSON"
    exit 1
fi

# 互斥性保证：关闭其他正在运行的开发层容器
echo "正在检查并关闭其他开发层容器..."
RUNNING_DEV_CONTAINERS=$(docker ps --filter "name=dev-" --format "{{.ID}}")
if [ -n "$RUNNING_DEV_CONTAINERS" ]; then
    echo "发现正在运行的开发层容器，正在停止..."
    docker stop $RUNNING_DEV_CONTAINERS > /dev/null
fi

PROJECT_NAME=$(basename "$FOLDER_PATH")
echo "正在打开 Dev Container：$FOLDER_PATH"
JSON=$(printf '{"workspacePath":"%s","devcontainerPath":"%s"}' "$FOLDER_PATH" "$DEVCONTAINER_JSON")
HEX=$(echo -n "$JSON" | xxd -p | tr -d '\n')
antigravity --no-sandbox --folder-uri "vscode-remote://dev-container+${HEX}/workspace/${PROJECT_NAME}"
