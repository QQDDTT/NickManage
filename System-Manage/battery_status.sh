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

upower -i /org/freedesktop/UPower/devices/battery_BAT1

read -p "按 Enter 继续..."

