#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# 设置工作目录路径
WORKSPACE_DIR="/home/nick/WorkSpace"

# 加载 LOG_HOME
LOG_HOME="${LOG_HOME:-/home/nick/logs}"
mkdir -p "$LOG_HOME"

# SSH 远程服务器别名 (在 ~/.ssh/config 中定义)
SERVER_ALIAS="nick-surface"

# 检查工作目录是否存在
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo -e "${RED}工作目录不存在: $WORKSPACE_DIR${RESET}"
    exit 1
fi

while true; do
    clear
    # 获取所有文件夹名称并为其编号
    echo -e "${BLUE}以下是 /home/nick/WorkSpace 下的所有项目文件夹：${RESET}"
    folders=("$WORKSPACE_DIR"/*/)
    counter=1
    for folder in "${folders[@]}"; do
        echo -e "${GREEN}${counter}. $(basename "$folder")${RESET}"
        ((counter++))
    done

    echo -e "${BLUE}以下是其他项目：${RESET}"
    # 添加其他项目
    echo -e "${YELLOW}t. 文档${RESET}"
    echo -e "${YELLOW}s. 自定义系统工具${RESET}"
    echo -e "${YELLOW}l. 日志${RESET}"
    echo -e "${YELLOW}k. k3s客户端${RESET}"
    echo -e "${YELLOW}q. 退出${RESET}"

    # 提示用户输入编号选择项目
    echo -n -e "${YELLOW}请输入你想要打开的项目编号: ${RESET}"
    read folder_number

    # 根据输入处理
    if [[ "$folder_number" =~ ^[0-9]+$ ]] && [ "$folder_number" -ge 1 ] && [ "$folder_number" -lt "$counter" ]; then
        selected_folder="${folders[folder_number-1]}"
        # 移除末尾斜杠以精确匹配
        folder_path=$(echo "$selected_folder" | sed 's:/*$::')
        
        # 读取项目类型
        project_type="unknown"
        if [ -f "$folder_path/.project" ]; then
            project_type=$(grep "^type:" "$folder_path/.project" | cut -d':' -f2 | tr -d '[:space:]')
        fi
        
        if [ "$project_type" == "software" ]; then
            project_name=$(grep "^name:" "$folder_path/.project" | cut -d':' -f2 | tr -d '[:space:]')
            echo -e "${GREEN}检测到软件开发项目 [${project_name}]，正在准备环境...${RESET}"
            # 自动查找到映射了该目录的 compose 文件
            compose_file=$(grep -l "${folder_path}:/workspace" /home/nick/NickManage/docker/compose/*.yaml 2>/dev/null | head -n 1)
            if [ -n "$compose_file" ]; then
                echo -e "${YELLOW}找到容器配置: $(basename "$compose_file")，正在启动服务...${RESET}"
                # 使用项目名作为 compose 项目名，避免孤儿容器警告
                docker compose -p "${project_name,,}" -f "$compose_file" up -d
            fi

            echo -e "${GREEN}正在通过 Antigravity 打开项目（请在 IDE 中确认进入 Dev Container）：$folder_path${RESET}"
            # 直接打开目录，IDE 会识别 .devcontainer 并提示 Reopen in Container
            antigravity --no-sandbox "$folder_path"
        else
            echo -e "${YELLOW}未知项目类型，以普通模式打开：$folder_path${RESET}"
            antigravity --no-sandbox "$folder_path"
        fi
        exit 0
    elif [[ "$folder_number" =~ ^[Tt]$ ]]; then
        echo -e "${GREEN}正在打开：文档${RESET}"
        antigravity --no-sandbox "/home/nick/文档/document"
        exit 0
    elif [[ "$folder_number" =~ ^[Ss]$ ]]; then
        echo -e "${GREEN}正在打开：自定义系统工具${RESET}"
        antigravity --no-sandbox "/home/nick/NickManage"
        exit 0
    elif [[ "$folder_number" =~ ^[Ll]$ ]]; then
        echo -e "${GREEN}正在打开：日志${RESET}"
        xdg-open http://localhost:3000
        exit 0
    elif [[ "$folder_number" =~ ^[Kk]$ ]]; then
        echo -e "${GREEN}正在打开：k3s客户端${RESET}"
        antigravity --no-sandbox "/home/nick/k3s-client"
        exit 0
    elif [[ "$folder_number" =~ ^[Qq]$ ]]; then
    	read -p "按 Enter 退出..."
        exit 0
    else
        echo -e "${RED}无效的编号${RESET}"
        read -p "按任意键继续..."
    fi
done