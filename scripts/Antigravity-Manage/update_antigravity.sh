#!/bin/bash

# ==============================================================================
# Antigravity 自动更新脚本
# 功能: 检查、关闭进程、同步源并更新 Antigravity IDE
# ==============================================================================

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# 检查是否为 root/sudo 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 sudo 运行此脚本${RESET}"
    exit 1
fi

echo -e "${BLUE}${BOLD}>>> 开始 Antigravity 更新流程 <<<${RESET}"

# 1. 检查当前版本
CURRENT_VER=$(dpkg-query -W -f='${Version}' antigravity 2>/dev/null)
if [ -z "$CURRENT_VER" ]; then
    echo -e "${RED}错误: 未检测到已安装的 Antigravity 软件包。${RESET}"
    exit 1
fi
echo -e "${GREEN}当前安装版本: ${CURRENT_VER}${RESET}"

# 2. 同步 APT 源
echo -e "${YELLOW}正在同步软件包源...${RESET}"
apt update -o Dir::Etc::sourcelist="sources.list.d/antigravity.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

# 3. 检查是否有可用更新
# 使用 LANG=C 确保输出为英文以便解析
CANDIDATE_VER=$(LANG=C apt-cache policy antigravity | grep "Candidate:" | awk '{print $2}')

echo -e "${BLUE}检测结果: 当前=$CURRENT_VER, 候选=$CANDIDATE_VER${RESET}"

if [ "$CURRENT_VER" == "$CANDIDATE_VER" ]; then
    echo -e "${GREEN}Antigravity 已是最新版本 ($CURRENT_VER)。${RESET}"
    read -p "是否强制重新安装/修复更新? (y/N): " FORCE_REINSTALL
    if [[ ! "$FORCE_REINSTALL" =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    echo -e "${YELLOW}发现新版本: ${CANDIDATE_VER}${RESET}"
fi

# 4. 检查并关闭运行中的进程
ANTIGRAVITY_PIDS=$(pgrep -f "/usr/share/antigravity/bin/antigravity")
if [ -n "$ANTIGRAVITY_PIDS" ]; then
    echo -e "${YELLOW}检测到 Antigravity 正在运行。为了安全更新，需要将其关闭。${RESET}"
    read -p "是否现在关闭所有 Antigravity 进程? (y/N): " KILL_CONFIRM
    if [[ "$KILL_CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}正在终止进程...${RESET}"
        pkill -f "/usr/share/antigravity/bin/antigravity"
        sleep 2
    else
        echo -e "${RED}更新已取消。请手动关闭应用后再试。${RESET}"
        exit 1
    fi
fi

# 5. 执行更新
echo -e "${BLUE}正在执行更新命令...${RESET}"
apt install --only-upgrade antigravity -y

if [ $? -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Antigravity 更新成功!${RESET}"
    NEW_VER=$(dpkg-query -W -f='${Version}' antigravity 2>/dev/null)
    echo -e "${GREEN}当前版本: ${NEW_VER}${RESET}"
else
    echo -e "${RED}更新过程中出现错误。${RESET}"
    exit 1
fi

# 6. 后续提示
echo -e "${BLUE}----------------------------------------${RESET}"
echo -e "${YELLOW}提示: 如果你之前打开了工作空间，现在可以重新运行 open_workspace.sh 启动。${RESET}"
read -p "是否现在启动 Antigravity? (y/N): " START_CONFIRM
if [[ "$START_CONFIRM" =~ ^[Yy]$ ]]; then
    # 以非 root 用户身份启动 (假设常用用户为 nick)
    USER_NAME="nick"
    if id "$USER_NAME" >/dev/null 2>&1; then
        echo -e "${BLUE}正在以用户 $USER_NAME 启动 Antigravity...${RESET}"
        sudo -u "$USER_NAME" antigravity --no-sandbox &
    else
        echo -e "${RED}无法自动启动：未找到用户 $USER_NAME${RESET}"
    fi
fi

echo -e "${GREEN}所有操作已完成。${RESET}"
