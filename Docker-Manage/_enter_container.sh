#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（大镜像）
GREEN='\033[0;32m'    # 绿色（小镜像）
YELLOW='\033[0;33m'   # 黄色（中等大小）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

# 获取所有运行中的容器ID
container_ids=$(docker ps -q)


# 检查是否有容器运行
if [ ${#container_ids[@]} -eq 0 ]; then
    echo -e "${YELLOW}当前没有正在运行的 Docker 容器。${NC}"
    read -p "按 Enter 键退出..."
    exit 0
fi

echo -e "${GREEN}正在运行的容器列表：${NC}"

# 建立索引到容器ID和名称的映射
index=1
for cid in "${container_ids[@]}"; do
    cname=$(docker inspect --format '{{.Name}}' "$cid" | sed 's/^\/\(.*\)/\1/')
    echo -e "  [${YELLOW}$index${NC}] 容器名称: ${BLUE}$cname${NC} (ID: ${cid:0:12})"
    container_names[$index]="$cname"
    container_ids_map[$index]="$cid"
    ((index++))
done

echo -e "${YELLOW}--------------------------------------------------------------${NC}"

# 重复读取直到输入有效或输入 0
while true; do
    read -p "请输入要进入的容器编号（输入 0 退出）: " input_index

    # 输入的是 0：退出
    if [[ "$input_index" == "0" ]]; then
        echo -e "${YELLOW}已退出。${NC}"
        exit 0
    fi

    # 是否为合法编号
    if [[ "$input_index" =~ ^[0-9]+$ ]] && [ "$input_index" -gt 0 ] && [ "$input_index" -le "${#container_ids[@]}" ]; then
        break
    else
        echo -e "${RED}输入无效，请输入有效的编号或 0 退出。${NC}"
    fi
done

# 获取选择的容器ID
selected_cid="${container_ids_map[$input_index]}"
selected_cname="${container_names[$input_index]}"


echo -e "将打开新终端并进入容器: ${GREEN}$selected_cname${NC}"

# 使用新终端打开并进入容器
gnome-terminal -- bash -c "docker exec -it $selected_cid /bin/bash || docker exec -it $selected_cid /bin/sh; exec bash"

read -p "按 Enter 键退出..."
exit 0