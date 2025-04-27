#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（错误）
GREEN='\033[0;32m'    # 绿色（成功）
YELLOW='\033[0;33m'   # 黄色（提示）
BLUE='\033[0;34m'     # 蓝色（标题）
NC='\033[0m'          # 重置颜色

# 确保脚本以 sudo 运行
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：请使用 sudo 运行此脚本！${NC}"
    exit 1
fi

while true; do
    clear
    echo -e "${BLUE}===== 当前正在运行的进程 =====${NC}"
    ps -eo pid,user,comm,%cpu,%mem --sort=-%cpu | head -n 20


    echo
    echo -e "${YELLOW}请输入要终止的进程编号（PID），或输入 Q 退出：${NC} "
    read pid

    # 用户退出
    if [[ ${pid} =~ ^[Qq]$ ]]; then
        echo -e "${BLUE}退出脚本...${NC}"
        exit 0
    fi

    # 输入校验
    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误：请输入有效的数字 PID。${NC}"
        sleep 1.5
        continue
    fi

    # 检查 PID 是否存在
    if ps -p "$pid" > /dev/null; then
        kill -9 "$pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}进程 $pid 已成功终止。${NC}"
        else
            echo -e "${RED}无法终止进程 $pid，可能没有权限或是系统进程。${NC}"
        fi
    else
        echo -e "${RED}错误：进程 $pid 不存在。${NC}"
    fi

    echo
    read -n 1 -s -r -p "按任意键继续..."
done
