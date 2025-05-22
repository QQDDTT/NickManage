#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（停止）
GREEN='\033[0;32m'    # 绿色（运行）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

# 确保脚本以 sudo 运行
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 sudo 运行此脚本！${NC}"
    exit 1
fi

# 打印表头
echo -e "${BLUE}Docker 容器状态:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------------------------------------------------${NC}"
printf "%-20s %-10s %-15s %-20s %-20s\n" "容器名称" "状态" "CPU 使用率" "内存使用" "端口"
echo -e "${YELLOW}--------------------------------------------------------------------------------------------------------${NC}"

# 遍历所有容器
docker ps -a --format "{{.ID}} {{.Names}}" | while read -r id name; do
    # 获取容器状态
    status=$(docker inspect --format '{{.State.Status}}' "$id")

    # 获取 CPU 和内存使用情况
    stats=$(docker stats "$id" --no-stream --format "{{.CPUPerc}} {{.MemUsage}}" 2>/dev/null)
    cpu=$(echo "$stats" | awk '{print $1}')
    mem=$(echo "$stats" | awk '{print $2, $3, $4, $5}')

    # 获取端口映射
    ports=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{printf "%s->%s " $p (index $conf 0).HostPort}}{{end}}{{end}}' "$id")
    ports=${ports:-"-"}  # 如果没有端口映射则显示 -

    # 颜色处理
    if [[ $status == "running" ]]; then
        color=$GREEN  # 运行中
    elif [[ $status == "exited" ]]; then
        color=$RED  # 已退出
    else
        color=$YELLOW  # 其他状态
    fi

    # 格式化输出
    printf "${color}%-20s %-10s %-15s %-20s %-20s${NC}\n" "$name" "$status" "$cpu" "$mem" "$ports"
done

echo -e "${YELLOW}--------------------------------------------------------------------------------------------------------${NC}"

read -p "按任意键继续..." -n1 -s
