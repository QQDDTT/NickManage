#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（错误）
GREEN='\033[0;32m'    # 绿色（桥接网络）
YELLOW='\033[0;33m'   # 黄色（默认网络）
BLUE='\033[0;34m'     # 蓝色（自定义网络）
NC='\033[0m'          # 重置颜色

# 打印表头
echo -e "${BLUE}Docker 网络状态:${NC}"
echo -e "${YELLOW}----------------------------------------------------------------------------${NC}"
printf "%-54s %-12s %-13s %-32s\n" "网络名称" "驱动" "容器数" "子网"
echo -e "${YELLOW}----------------------------------------------------------------------------${NC}"

# 获取所有网络信息
docker network ls --format "{{.Name}} {{.Driver}}" | while read -r name driver; do
    # 获取连接到此网络的容器数量
    container_count=$(docker network inspect --format "{{json .Containers}}" "$name" | jq length)

    # 获取子网信息
    subnet=$(docker network inspect --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' "$name")

    # 颜色高亮
    case "$driver" in
        "bridge") color=$GREEN ;;     # 绿色 - 桥接网络
        "overlay") color=$BLUE ;;     # 蓝色 - 自定义 overlay 网络
        *) color=$YELLOW ;;           # 黄色 - 其他类型
    esac

    # 格式化输出
    printf "${color}%-50s %-10s %-10s %-30s${NC}\n" "$name" "$driver" "$container_count" "$subnet"
done

echo -e "${YELLOW}----------------------------------------------------------------------------${NC}"

read -p "按 Enter 键退出..."