#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（停止）
GREEN='\033[0;32m'    # 绿色（运行）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

echo -e "${BLUE}运行中的 Docker 容器:${NC}"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"
printf "%-5s %-20s %-25s %-10s\n" "编号" "容器名称" "端口映射" "主进程PID"
echo -e "${YELLOW}--------------------------------------------------------------${NC}"

# 映射编号与容器ID和PID
declare -A CONTAINER_PID_MAP
declare -A CONTAINER_MAP

index=1

# 使用 mapfile 读取 docker ps 输出
mapfile -t containers < <(docker ps --format "{{.ID}} {{.Names}} {{.Ports}}")

for container in "${containers[@]}"; do
    id=$(awk '{print $1}' <<< "$container")
    name=$(awk '{print $2}' <<< "$container")
    ports=$(cut -d' ' -f3- <<< "$container")
    pid=$(docker inspect -f '{{.State.Pid}}' "$id")

    printf "%-5s %-20s %-25s %-10s\n" "$index" "$name" "$ports" "$pid"

    CONTAINER_PID_MAP[$index]=$pid
    CONTAINER_MAP[$index]=$name

    ((index++))
done

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
