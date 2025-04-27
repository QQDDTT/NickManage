#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（大镜像）
GREEN='\033[0;32m'    # 绿色（小镜像）
YELLOW='\033[0;33m'   # 黄色（中等大小）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

# 确保脚本以 sudo 运行
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 sudo 运行此脚本！${NC}"
    exit 1
fi

# 打印表头
echo -e "${BLUE}Docker 镜像信息:${NC}"
echo -e "${YELLOW}------------------------------------------------${NC}"
echo -e "镜像名称\t标签\t\t镜像 ID\t\t大小\t创建时间"
echo -e "${YELLOW}------------------------------------------------${NC}"

# 获取所有 Docker 镜像信息
docker images --format "{{.Repository}} {{.Tag}} {{.ID}} {{.Size}} {{.CreatedAt}}" | while read -r repo tag id size created; do
    # 判断镜像大小并设置颜色
    size_value=$(echo "$size" | awk '{print $1}')
    unit=$(echo "$size" | awk '{print $2}')

    # 转换为 MB 或 GB 进行判断
    if [[ $unit == "GB" ]]; then
        color=$RED  # 大镜像（>1GB）
    elif [[ $unit == "MB" && $(echo "$size_value > 500" | bc) -eq 1 ]]; then
        color=$YELLOW  # 中等大小（500MB+）
    else
        color=$GREEN  # 小镜像（<500MB）
    fi

    # 格式化输出，确保对齐
    printf "${color}%-20s %-10s %-15s %-10s %-20s${NC}\n" "$repo" "$tag" "$id" "$size" "$created"
done

echo -e "${YELLOW}------------------------------------------------${NC}"

read -p "按 Enter 键退出..."