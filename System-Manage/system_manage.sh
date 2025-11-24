#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（错误）
GREEN='\033[0;32m'    # 绿色（成功）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

SCRIPT_DIR="/home/nick/NickManage/System-Manage"

# 循环显示菜单
while true; do
    clear  # 清屏，刷新控制台

    echo -e "${BLUE}==============================${NC}"
    echo -e "${GREEN}1.${NC} 挂载 VHD 磁盘"
    echo -e "${GREEN}2.${NC} 卸载 VHD 磁盘"
    echo -e "${BLUE}==============================${NC}"
    echo -e "${GREEN}3.${NC} 执行 Docker Compose"
    echo -e "${RED}0.${NC} 退出"
    echo -e "${BLUE}==============================${NC}"
    
    # 读取用户输入
    read -p "请输入要执行的项目编号: " choice
    
    case "$choice" in
        1)
            bash "${SCRIPT_DIR}/mount_vhd.sh"
            ;;
        2)
            bash "${SCRIPT_DIR}/unmount_vhd.sh"
            ;;
        3)
            bash "${SCRIPT_DIR}/docker_compose.sh"
        0)
    		read -p "按 Enter 退出..."
            exit 0
            ;;
        *)
            echo -e "${RED}无效输入，请重新输入！${NC}"
            ;;
    esac
done

