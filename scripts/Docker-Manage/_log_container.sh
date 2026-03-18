#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（大镜像）
GREEN='\033[0;32m'    # 绿色（小镜像）
YELLOW='\033[0;33m'   # 黄色（中等大小）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

# 获取所有运行中的容器ID
# 建立索引到容器ID和名称的映射
index=1
docker ps --format "{{.ID}}\t{{.Names}}\t{{.Labels}}" | while IFS=$'\t' read -r id name labels; do
    # 提取 devcontainer 名称
    name_display="$name"
    if [[ "$labels" == *"devcontainer.local_folder="* ]]; then
        local_folder=$(echo "$labels" | grep -oP 'devcontainer.local_folder=\K[^,]+')
        if [[ -n "$local_folder" ]]; then
            name_display="dev-"$(basename "$local_folder")
        fi
    fi

    echo -e "  [${YELLOW}$index${NC}] 容器名称: ${BLUE}$name_display${NC}"
    
    # 存储关系到临时文件
    echo "$index $id $name_display" >> /tmp/log_map_$$.tmp
    ((index++))
done

# 读取临时文件内容到数组
if [ -f /tmp/log_map_$$.tmp ]; then
    while read -r idx id disp; do
        container_ids_map[$idx]="$id"
        container_names[$idx]="$disp"
        # 记录总数用于后续校验
        total_containers=$idx
    done < /tmp/log_map_$$.tmp
    rm /tmp/log_map_$$.tmp
fi

echo -e "${YELLOW}--------------------------------------------------------------${NC}"

# 重复读取直到输入有效或输入 0
while true; do
    read -p "请输入要查看日志的容器编号（输入 0 退出）: " input_index

    # 输入的是 0：退出
    if [[ "$input_index" == "0" ]]; then
        echo -e "${YELLOW}已退出。${NC}"
        exit 0
    fi

    # 是否为合法编号
    if [[ "$input_index" =~ ^[0-9]+$ ]] && [ "$input_index" -gt 0 ] && [ "$input_index" -le "$total_containers" ]; then
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
gnome-terminal -- bash -c "docker logs -f $selected_cid; exec bash"

read -p "按 Enter 键退出..."
exit 0