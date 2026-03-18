#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# 设置工作目录路径
WORKSPACE_DIR="/home/nick/workspaces"

# 加载 LOG_HOME
LOG_HOME="${LOG_HOME:-/home/nick/.logs}"
mkdir -p "$LOG_HOME"

# SSH 远程服务器别名 (在 ~/.ssh/config 中定义)
SERVER_ALIAS="nick-surface"

# 检查工作目录是否存在
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo -e "${RED}工作目录不存在: $WORKSPACE_DIR${RESET}"
    exit 1
fi

# 处理命令行参数
if [[ "$1" == "-u" ]]; then
    echo -e "${YELLOW}正在通过命令行触发更新...${RESET}"
    sudo bash "$(dirname "$0")/update_antigravity.sh"
    exit $?
fi

while true; do
    clear
    echo -e "${BLUE}以下是 /home/nick/workspaces 下的所有项目文件夹：${RESET}"
    folders=("$WORKSPACE_DIR"/*/)
    counter=1
    for folder in "${folders[@]}"; do
        echo -e "${GREEN}${counter}. $(basename "$folder")${RESET}"
        ((counter++))
    done

    echo -e "${BLUE}以下是其他项目：${RESET}"
    echo -e "${YELLOW}t. 文档${RESET}"
    echo -e "${YELLOW}s. 自定义系统工具${RESET}"
    echo -e "${YELLOW}e. GNOME 扩展 (gnome-devpulse)${RESET}"
    echo -e "${YELLOW}l. 日志${RESET}"
    echo -e "${YELLOW}u. 更新 Antigravity${RESET}"
    echo -e "${YELLOW}q. 退出${RESET}"

    echo -n -e "${YELLOW}请输入你想要打开的项目编号: ${RESET}"
    read folder_number

    if [[ "$folder_number" =~ ^[0-9]+$ ]] && [ "$folder_number" -ge 1 ] && [ "$folder_number" -lt "$counter" ]; then
        selected_folder="${folders[folder_number-1]}"
        folder_path=$(echo "$selected_folder" | sed 's:/*$::')

        bash "$(dirname "$0")/_open_devcontainer.sh" "$folder_path"
        exit 0

    elif [[ "$folder_number" =~ ^[Tt]$ ]]; then
        echo -e "${GREEN}正在打开：文档${RESET}"
        antigravity --no-sandbox "/home/nick/文档/document"
        exit 0
    elif [[ "$folder_number" =~ ^[Ss]$ ]]; then
        echo -e "${GREEN}正在打开：自定义系统工具${RESET}"
        antigravity --no-sandbox "/home/nick/NickManage"
        exit 0
    elif [[ "$folder_number" =~ ^[Ee]$ ]]; then
        echo -e "${GREEN}正在打开：GNOME 扩展 (gnome-devpulse)${RESET}"
        # 特殊项目：路径与常规不同
        WORKSPACE_PATH="/home/nick/.local/share/gnome-shell/extensions/devpulse@nickmanage.local"
        DEVCONTAINER_JSON="${WORKSPACE_PATH}/.devcontainer/devcontainer.json"
        CONTAINER_PROJECT_PATH="/workspace/gnome-shell/extensions/devpulse@nickmanage.local"

        JSON=$(printf '{"workspacePath":"%s","devcontainerPath":"%s"}' "$WORKSPACE_PATH" "$DEVCONTAINER_JSON")
        HEX=$(echo -n "$JSON" | xxd -p | tr -d '\n')
        antigravity --no-sandbox --folder-uri "vscode-remote://dev-container+${HEX}${CONTAINER_PROJECT_PATH}"
        exit 0
    elif [[ "$folder_number" =~ ^[Ll]$ ]]; then
        echo -e "${GREEN}正在打开：日志${RESET}"
        antigravity --no-sandbox "$LOG_HOME"
        exit 0
    elif [[ "$folder_number" =~ ^[Uu]$ ]]; then
        echo -e "${YELLOW}正在启动更新程序...${RESET}"
        sudo bash "$(dirname "$0")/update_antigravity.sh"
        # 更新后可能需要重启脚本以应用环境变化（虽然此处主要是更新 IDE 二进制文件）
        echo -e "${GREEN}更新任务已处理。${RESET}"
        read -p "按任意键返回菜单..."
    elif [[ "$folder_number" =~ ^[Qq]$ ]]; then
        read -p "按 Enter 退出..."
        exit 0
    else
        echo -e "${RED}无效的编号${RESET}"
        read -p "按任意键继续..."
    fi  # ← if folder_number 的 fi

done