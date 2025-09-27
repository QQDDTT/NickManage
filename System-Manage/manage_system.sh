#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（错误）
GREEN='\033[0;32m'    # 绿色（成功）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

# 确保脚本以 sudo 运行
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 sudo 运行此脚本！${NC}"
	read -p "按 Enter 继续..."
    exit 1
fi

SCRIPT_DIR="/home/nick/NickManage/System-Manage"

# 循环显示菜单
while true; do
    clear  # 清屏，刷新控制台

    echo -e "${BLUE}====== Docker 监控工具 ======${NC}"
    echo -e "${GREEN}1.${NC} 清理系统垃圾"
    echo -e "${GREEN}2.${NC} 查看电池状态"
    echo -e "${GREEN}3.${NC} 查看进程信息"
    echo -e "${BLUE}==============================${NC}"
    echo -e "${RED}0.${NC} 退出"
    echo -e "${BLUE}==============================${NC}"
    
    # 读取用户输入
    read -p "请输入要执行的项目编号: " choice
    
    case "$choice" in
        1)
            sudo bash "${SCRIPT_DIR}/clean_system.sh"
            ;;
        2)
            sudo bash "${SCRIPT_DIR}/battery_status.sh"
            ;;
        3)
            sudo bash "${SCRIPT_DIR}/process_info.sh"
            ;;
        0)
    		read -p "按 Enter 退出..."
            exit 0
            ;;
        *)
            echo -e "${RED}无效输入，请重新输入！${NC}"
            ;;
    esac
done

