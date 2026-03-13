#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（错误）
GREEN='\033[0;32m'    # 绿色（正常）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

# 获取所有卷的大小并存入关联数组 (避免使用 sudo du 导致输入密码阻塞)
declare -A volume_sizes
while read -r name size; do
    volume_sizes["$name"]=$size
done < <(docker system df -v 2>/dev/null | awk '
/^Local Volumes space usage:/{flag=1; next}
flag && /usage:/{flag=0}
flag && !/^VOLUME NAME/ && NF>0 {print $1, $NF}')

# 打印表头
echo -e "${BLUE}Docker 卷状态:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------------------------------------------------------${NC}"
printf "%-25s %-10s %-50s %-10s\n" "卷名称" "驱动" "挂载点" "大小"
echo -e "${YELLOW}--------------------------------------------------------------------------------------------------------------${NC}"

# 遍历所有卷
docker volume ls --format "{{.Name}} {{.Driver}}" | while read -r name driver; do
    mountpoint=$(docker volume inspect --format "{{.Mountpoint}}" "$name")

    # 获取卷大小
    size="${volume_sizes[$name]}"
    if [[ -z "$size" ]]; then
        size="N/A"
    fi

    if [[ "$driver" == "local" ]]; then
        color=$GREEN
    else
        color=$YELLOW
    fi

    # 格式化输出
    printf "${color}%-25s %-10s %-50s %-10s${NC}\n" "$name" "$driver" "$mountpoint" "$size"
done

echo -e "${YELLOW}--------------------------------------------------------------------------------------------------------------${NC}"

echo -e "\n${BLUE}Docker 绑定挂载 (Bind Mounts) 状态:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------------------------------------------------------${NC}"
printf "%-20s %-50s %-45s\n" "容器名称" "宿主机路径 (Source)" "容器路径 (Destination)"
echo -e "${YELLOW}--------------------------------------------------------------------------------------------------------------${NC}"

# 遍历所有容器并获取 bind 类型的挂载
docker ps -a --format '{{.Names}}' | while read -r container; do
    docker inspect --format '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}::{{.Destination}}{{println}}{{end}}{{end}}' "$container" 2>/dev/null | while read -r mount; do
        if [[ -n "$mount" ]]; then
            source_path="${mount%%::*}"
            dest_path="${mount##*::}"
            printf "${GREEN}%-20s ${NC}%-50s ${BLUE}%-45s${NC}\n" "$container" "$source_path" "$dest_path"
        fi
    done
done

echo -e "${YELLOW}--------------------------------------------------------------------------------------------------------------${NC}"

read -p "按任意键继续..." -n1 -s