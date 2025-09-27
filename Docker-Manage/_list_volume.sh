#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（错误）
GREEN='\033[0;32m'    # 绿色（正常）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

# 打印表头
echo -e "${BLUE}Docker 卷状态:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------------------${NC}"
printf "%-25s %-10s %-50s %-10s\n" "卷名称" "驱动" "挂载点" "大小"
echo -e "${YELLOW}--------------------------------------------------------------------------${NC}"

# 遍历所有卷
docker volume ls --format "{{.Name}} {{.Driver}}" | while read -r name driver; do
    mountpoint=$(docker volume inspect --format "{{.Mountpoint}}" "$name")

    # 计算卷大小（仅适用于 local 卷）
    if [[ "$driver" == "local" ]]; then
        size=$(sudo du -sh "$mountpoint" 2>/dev/null | awk '{print $1}')
        color=$GREEN
    else
        size="N/A"
        color=$YELLOW
    fi

    # 格式化输出
    printf "${color}%-25s %-10s %-50s %-10s${NC}\n" "$name" "$driver" "$mountpoint" "$size"
done

echo -e "${YELLOW}--------------------------------------------------------------------------${NC}"

read -p "按任意键继续..." -n1 -s