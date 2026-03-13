#!/bin/bash

# 改进版：批量给 Compose 文件添加标签的脚本 (Shell 版)
COMPOSE_DIR="/home/nick/NickManage/docker/compose"

update_labels() {
    local pattern=$1
    local tier=$2

    echo "正在处理层级: $tier (匹配模式: $pattern)"

    for file in "$COMPOSE_DIR"/$pattern; do
        [ -e "$file" ] || continue
        
        # 0. 安全检查：如果该文件已经包含 nms.layer 标签且值正确，则跳过
        if grep -q "nms.layer=$tier" "$file"; then
            echo "跳过: $(basename "$file") (nms.layer=$tier 已存在)"
            continue
        fi

        # 1. 注入或更新 nms.layer 标签
        if grep -q "labels:" "$file"; then
            echo "同步中: $(basename "$file") (更新现有 labels 块)"
            # 如果已经存在 nms.layer 但值不对，先删除旧的
            sed -i '/nms.layer=/d' "$file"
            # 插入正确的值
            sed -i "/labels:/a \      - \"nms.layer=$tier\"" "$file"
        else
            echo "同步中: $(basename "$file") (新建 labels 块)"
            sed -i "/container_name:/a \    labels:\n      - \"nms.layer=$tier\"" "$file"
        fi
        
        echo "更新成功: $(basename "$file")"
    done
}

# 1. 同步 share 层 (nms.layer=share)
update_labels "share-*.yaml" "share"

# 2. 同步 dev 层 (nms.layer=dev)
update_labels "dev-*.yaml" "dev"

echo "所有架构标签同步任务已完成。"
