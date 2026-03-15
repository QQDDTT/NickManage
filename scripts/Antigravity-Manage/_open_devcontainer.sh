#!/bin/bash

# 核心逻辑：打开指定的 Dev Container 工作空间 (云端化重构版)
# 参数 1: 项目名称 或 文件夹路径 (可选)

IDENTIFIER="$1"
MNG_DIR="/home/nick/NickManage"
CONFIG_DIR="$MNG_DIR/docker/devcontainer"

# 1. 自动识别项目名称
if [ -z "$IDENTIFIER" ] || [ "$IDENTIFIER" == "." ]; then
    # 如果身处某个文件夹且该文件名为已知项目，则使用当前文件夹名
    PROJECT_NAME=$(basename "$(pwd)")
else
    # 否则直接将参数作为项目名称
    PROJECT_NAME=$(basename "$IDENTIFIER")
fi

# 2. 定位配置文件 (绕过 IDE 路径限制)
# 使用工作区内的软链接 (文件名固定为 devcontainer.json)，以满足 IDE 对配置文件的命名要求
DEVCONTAINER_JSON="/home/nick/workspaces/$PROJECT_NAME/.devcontainer/devcontainer.json"

if [ ! -f "$DEVCONTAINER_JSON" ]; then
    echo "错误：未找到项目 \"$PROJECT_NAME\" 的工作区配置文件: $DEVCONTAINER_JSON"
    echo "提示：请确保已运行创建项目脚本，并检查 $MNG_DIR/docker/devcontainer/${PROJECT_NAME}-devcontainer.json 是否存在。"
    exit 1
fi

# 3. 环境隔离说明 (已取消全局互斥，允许项目并行)
# 之前的互斥逻辑已移除，以支持用户同时打开多个项目的需求。
# echo "正在检查并停止其他冲突容器..."
# RUNNING_DEV_CONTAINERS=$(docker ps --filter "name=dev-" --format "{{.ID}}")
# if [ -n "$RUNNING_DEV_CONTAINERS" ]; then
#     docker stop $RUNNING_DEV_CONTAINERS > /dev/null
# fi

# 4. VS Code 远程引导 (极致解耦)
# workspacePath 必须指向项目的实际工作空间路径，以确保资源解析正确
# 注意：URI authority 使用标准的 dev-container 标识
WORKSPACE_FULL_PATH="/home/nick/workspaces/${PROJECT_NAME}"
echo "正在云端启动项目：$PROJECT_NAME"
JSON=$(printf '{"workspacePath":"%s","devcontainerPath":"%s"}' "$WORKSPACE_FULL_PATH" "$DEVCONTAINER_JSON")
HEX=$(echo -n "$JSON" | xxd -p | tr -d '\n')
# 使用标准的 dev-container 标识符以启用扩展的资源解析器
# 注意：URI 后缀必须指向容器内的映射路径 /workspaces/${PROJECT_NAME}
antigravity --no-sandbox --folder-uri "vscode-remote://dev-container+${HEX}/workspaces/${PROJECT_NAME}"
