#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（停止）
GREEN='\033[0;32m'    # 绿色（运行）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

# 打印表头
echo -e "${BLUE}Docker 容器状态:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"
printf "%-30s %-10s\n" "容器名称" "状态"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"

# 遍历所有容器
docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Labels}}" | while IFS=$'\t' read -r id name labels; do
    # 提取 devcontainer 名称
    name_display="$name"
    if [[ "$labels" == *"devcontainer.local_folder="* ]]; then
        local_folder=$(echo "$labels" | grep -oP 'devcontainer.local_folder=\K[^,]+')
        if [[ -n "$local_folder" ]]; then
            name_display="dev-"$(basename "$local_folder")
        fi
    fi

    # 获取容器状态
    status=$(docker inspect --format '{{.State.Status}}' "$id")

    # 获取端口映射 (不再显示，但保留逻辑以备后用)
    # ports=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{printf "%s->%s " $p (index $conf 0).HostPort}}{{end}}{{end}}' "$id")
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
    printf "${color}%-30s %-10s${NC}\n" "$name_display" "$status"
done

echo -e "${YELLOW}--------------------------------------------------------------${NC}"

read -p "按任意键继续..." -n1 -s
