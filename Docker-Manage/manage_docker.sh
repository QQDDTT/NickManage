#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（错误）
GREEN='\033[0;32m'    # 绿色（成功）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

SCRIPT_DIR="/home/nick/NickManage/Docker-Manage"

# 循环显示菜单
while true; do
    clear  # 清屏，刷新控制台

    echo -e "${BLUE}====== Docker 监控工具 ======${NC}"
    echo -e "${GREEN}1.${NC} 查看 Docker 容器状态"
    echo -e "${GREEN}2.${NC} 查看 Docker 镜像信息"
    echo -e "${GREEN}3.${NC} 查看 Docker 卷信息"
    echo -e "${GREEN}4.${NC} 查看 Docker 网络状态"
    echo -e "${BLUE}==============================${NC}"
    echo -e "${GREEN}5.${NC} 启动 Docker 容器"
    echo -e "${GREEN}6.${NC} 停止 Docker 容器"
    echo -e "${GREEN}7.${NC} 创建 Docker 容器"
    echo -e "${GREEN}8.${NC} 进入 Docker 容器"
    echo -e "${RED}0.${NC} 退出"
    echo -e "${BLUE}==============================${NC}"
    
    # 读取用户输入
    read -p "请输入要执行的项目编号: " choice
    
    case "$choice" in
        1)
            echo -e "${YELLOW}正在获取容器信息...${NC}"
            bash "${SCRIPT_DIR}/_list_container.sh"
            ;;
        2)
            echo -e "${YELLOW}正在获取镜像信息...${NC}"
            bash "${SCRIPT_DIR}/_list_image.sh"
            ;;
        3)
            echo -e "${YELLOW}正在获取卷信息...${NC}"
            bash "${SCRIPT_DIR}/_list_volume.sh"
            ;;
        4)
            echo -e "${YELLOW}正在获取网络信息...${NC}"
            bash "${SCRIPT_DIR}/_list_network.sh"
            ;;
        5)
            echo -e "${YELLOW}正在启动容器...${NC}"
            bash "${SCRIPT_DIR}/_start_container.sh"
            ;;
        6)
            echo -e "${YELLOW}正在停止容器...${NC}"
            bash "${SCRIPT_DIR}/_stop_container.sh"
            ;;
        7)
            echo -e "${YELLOW}正在创建容器...${NC}"
            bash "${SCRIPT_DIR}/_compose_docker.sh"
            ;;
        8)
            echo -e "${YELLOW}正在进入容器...${NC}"
            bash "${SCRIPT_DIR}/_enter_container.sh"
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

