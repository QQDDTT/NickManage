#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（停止）
GREEN='\033[0;32m'    # 绿色（运行）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

echo -e "${BLUE}运行中的 Docker 容器:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"
printf "%-5s %-30s\n" "编号" "容器名称"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"

# 映射编号与容器ID和PID
declare -A CONTAINER_PID_MAP
declare -A CONTAINER_MAP

index=1
# 遍历容器并处理显示名称
docker ps --format "{{.ID}}\t{{.Names}}\t{{.Labels}}" | while IFS=$'\t' read -r id name labels; do
    # 提取 devcontainer 名称
    name_display="$name"
    if [[ "$labels" == *"devcontainer.local_folder="* ]]; then
        local_folder=$(echo "$labels" | grep -oP 'devcontainer.local_folder=\K[^,]+')
        if [[ -n "$local_folder" ]]; then
            name_display="dev-"$(basename "$local_folder")
        fi
    fi

    pid=$(docker inspect -f '{{.State.Pid}}' "$id")

    printf "%-5s %-30s\n" "$index" "$name_display"

    # 存储映射关系，用于后续命令
    echo "$index $pid $name" >> /tmp/container_map_$$.tmp
    ((index++))
done

# 将临时文件读入映射数组
if [ -f /tmp/container_map_$$.tmp ]; then
    while read -r idx p n; do
        CONTAINER_PID_MAP[$idx]=$p
        CONTAINER_MAP[$idx]=$n
    done < /tmp/container_map_$$.tmp
    rm /tmp/container_map_$$.tmp
fi

echo -e "${YELLOW}--------------------------------------------------------------${NC}"

# 读取用户输入
read -p "请输入要停止的容器编号: " input_index

# 输入校验
if [[ ! "$input_index" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}错误：请输入有效的数字${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 1
elif [[ $input_index -lt 1 || $input_index -gt ${#CONTAINER_PID_MAP[@]} ]]; then
    echo -e "${RED}错误：无效的编号${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 1
fi

# 获取对应 PID 和容器名
pid_to_stop=${CONTAINER_PID_MAP[$input_index]}
name_to_stop=${CONTAINER_MAP[$input_index]}

if [[ -n "$pid_to_stop" ]]; then
    # 获取容器ID
    container_id=$(docker ps -qf "name=$name_to_stop")

    if [[ -n "$container_id" ]]; then
        read -p "确认要停止容器 $name_to_stop 吗？(y/n): " confirm
        if [[ $confirm == [Yy] ]]; then
            docker stop "$container_id" && echo -e "${GREEN}容器已停止：$name_to_stop${NC}" || echo -e "${RED}停止失败。${NC}"
        else
            echo -e "${YELLOW}操作已取消。${NC}"
        fi
    else
        echo -e "${RED}未找到容器：$name_to_stop${NC}"
    fi
else
    echo -e "${RED}无效编号: ${input_index}${NC}"
fi

read -p "按任意键继续..." -n1 -s
