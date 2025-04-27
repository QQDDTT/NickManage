#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 确保使用 sudo 运行
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 sudo 运行此脚本！${NC}"
    exit 1
fi

echo -e "${BLUE}停止的 Docker 容器:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"
printf "%-5s %-20s %-25s\n" "编号" "容器名称" "端口映射"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"

# 使用 mapfile 读取 docker ps -a 输出
mapfile -t containers < <(docker ps -a --filter "status=exited" --format "{{.ID}} {{.Names}} {{.Ports}}")

# 映射编号与容器ID
declare -A CONTAINER_MAP

index=1
for container in "${containers[@]}"; do
    id=$(echo "$container" | awk '{print $1}')
    name=$(echo "$container" | awk '{print $2}')
    ports=$(echo "$container" | awk '{print $3}')

    # 打印容器信息
    printf "%-5s %-20s %-25s\n" "$index" "$name" "$ports"
    CONTAINER_MAP[$index]=$name
    ((index++))
done

echo -e "${YELLOW}--------------------------------------------------------------${NC}"

# 输入编号
read -p "请输入要启动的容器编号: " input_index

# 输入校验
if [[ ! "$input_index" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}错误：请输入有效的数字${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 1
elif [[ $input_index -lt 1 || $input_index -gt ${#CONTAINER_MAP[@]} ]]; then
    echo -e "${RED}错误：无效的编号${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 1
fi

# 确认输入的编号是否有效
if [[ -z "${CONTAINER_MAP[$input_index]}" ]]; then
    echo -e "${RED}无效编号。请重新输入有效编号。${NC}"
else
    container=${CONTAINER_MAP[$input_index]}
    read -p "确认要启动容器 $container 吗？(y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        # 尝试启动容器并捕获错误
        if docker start "$container"; then
            echo -e "${GREEN}容器已启动：$container${NC}"
        else
            echo -e "${RED}启动容器失败。请检查容器状态或日志。${NC}"
        fi
    else
        echo -e "${YELLOW}操作已取消。${NC}"
    fi
fi

read -p "按任意键继续..." -n1 -s
