#!/bin/bash

# 定义颜色代码
RED='\033[0;31m'      # 红色（错误）
GREEN='\033[0;32m'    # 绿色（成功）
YELLOW='\033[0;33m'   # 黄色（警告）
BLUE='\033[0;34m'     # 蓝色（信息）
NC='\033[0m'          # 重置颜色

# 获取所有卷的大小并存入关联数组
declare -A volume_sizes
while read -r name size; do
    volume_sizes["$name"]=$size
done < <(docker system df -v 2>/dev/null | awk '
/^Local Volumes space usage:/{flag=1; next}
flag && /usage:/{flag=0}
flag && !/^VOLUME NAME/ && NF>0 {print $1, $NF}')

# 打印表头
echo -e "${BLUE}所有 Docker 卷:${NC}"
echo -e "${YELLOW}-----------------------------------------------------------------------------------------${NC}"
printf "%-5s %-30s %-15s %-10s\n" "编号" "卷名称" "驱动" "大小"
echo -e "${YELLOW}-----------------------------------------------------------------------------------------${NC}"

# 映射编号与卷名
declare -A VOLUME_MAP
index=1

# 遍历所有卷并显示
mapfile -t volumes < <(docker volume ls --format "{{.Name}} {{.Driver}}")

for volume in "${volumes[@]}"; do
    name=$(awk '{print $1}' <<< "$volume")
    driver=$(awk '{print $2}' <<< "$volume")
    
    # 获取卷大小
    size="${volume_sizes[$name]}"
    if [[ -z "$size" ]]; then
        size="N/A"
    fi

    printf "%-5s %-30s %-15s %-10s\n" "$index" "$name" "$driver" "$size"
    
    VOLUME_MAP[$index]=$name
    ((index++))
done

echo -e "${YELLOW}-----------------------------------------------------------------------------------------${NC}"

# 如果没有卷，直接退出
if [[ ${#VOLUME_MAP[@]} -eq 0 ]]; then
    echo -e "${YELLOW}没有找到任何 Docker 卷。${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 0
fi

# 读取用户输入
read -p "请输入要删除的卷编号 (或输入 0 取消): " input_index

# 取消操作
if [[ "$input_index" == "0" ]]; then
    echo -e "${YELLOW}操作已取消。${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 0
fi

# 输入校验
if [[ ! "$input_index" =~ ^[0-9]+$ ]] || [[ $input_index -lt 1 || $input_index -gt ${#VOLUME_MAP[@]} ]]; then
    echo -e "${RED}错误：无效的编号${NC}"
    read -p "按任意键继续..." -n1 -s
    exit 1
fi

# 获取对应的卷名
volume_to_remove=${VOLUME_MAP[$input_index]}

# 确认删除
echo -e "${RED}警告：删除卷将永久丢失其中的数据！${NC}"
read -p "确认要删除卷 $volume_to_remove 吗？(y/n): " confirm
if [[ $confirm == [Yy] ]]; then
    docker volume rm "$volume_to_remove" && echo -e "${GREEN}卷已删除：$volume_to_remove${NC}" || echo -e "${RED}删除失败。可能该卷正在被容器使用。${NC}"
else
    echo -e "${YELLOW}操作已取消。${NC}"
fi

read -p "按任意键继续..." -n1 -s
