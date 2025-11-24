#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

COMPOSE_DIR="/home/nick/NickManage/System-Manage/compose"

# 确保 COMPOSE_DIR 文件夹存在
if [[ ! -d "${COMPOSE_DIR}" ]]; then
    echo -e "${RED}错误：当前目录下未找到 compose 文件夹！${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 1
fi

echo -e "${BLUE}可用的 Compose 文件:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"
printf "%-5s %-30s\n" "编号" "文件名"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"

# 查找 compose 目录下所有 yml/yaml 文件
mapfile -t files < <(find "${COMPOSE_DIR}" -maxdepth 1 -type f \( -iname "*.yml" -o -iname "*.yaml" \) | sort)

# 建立编号和路径映射
declare -A FILE_MAP
index=1
for filepath in "${files[@]}"; do
    filename=$(basename "$filepath")
    printf "%-5s %-30s\n" "$index" "$filename"
    FILE_MAP[$index]="$filepath"
    ((index++))
done

# 无可用文件时退出
if [[ ${#FILE_MAP[@]} -eq 0 ]]; then
    echo -e "${RED}未找到任何 compose 文件。${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 1
fi

echo -e "${YELLOW}--------------------------------------------------------------${NC}"
read -p "请输入要运行的 compose 文件编号: " input_index

# 输入校验
if [[ ! "$input_index" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}错误：请输入有效的数字${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 1
elif [[ $input_index -lt 1 || $input_index -gt ${#FILE_MAP[@]} ]]; then
    echo -e "${RED}错误：无效的编号${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 1
fi

selected_file="${FILE_MAP[$input_index]}"
if [[ -n "$selected_file" ]]; then
    echo -e "${GREEN}正在启动：$selected_file${NC}"
    docker compose -f "${selected_file}" up -d
else
    echo -e "${RED}无效编号。${NC}"
fi

read -p "按任意键继续..." -n1 -s
