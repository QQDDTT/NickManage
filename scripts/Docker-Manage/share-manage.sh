#!/bin/bash

# share-manage.sh: 共享层 (Share) 容器分类管理脚本
# 支持操作: start, stop, restart, status
# 依赖检查: 必须先启动底座层 (ops-traefik)

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOAD_ENV="$PROJECT_ROOT/scripts/load_env.sh"

if [ -f "$LOAD_ENV" ]; then
    source "$LOAD_ENV"
else
    echo -e "${RED}错误: 找不到 load_env.sh ($LOAD_ENV)${NC}"
    exit 1
fi

COMPOSE_DIR="$MNG_HOME/docker/compose"

function check_ops() {
    # 检查 ops-traefik 是否在运行
    if ! docker ps --format '{{.Names}}' | grep -q "ops-traefik"; then
        echo -e "${RED}警告: 底座层核心容器 (ops-traefik) 未启动。${NC}"
        echo -e "${YELLOW}请先运行: bash scripts/Docker-Manage/ops-manage.sh start${NC}"
        exit 1
    fi
}

function show_usage() {
    echo -e "${BLUE}用法: $0 {service_name|all} {start|stop|restart|status}${NC}"
    echo -e "${YELLOW}可用服务列表 (基于 share-*.yaml):${NC}"
    ls "$COMPOSE_DIR"/share-*.yaml | sed 's/.*share-\(.*\)\.yaml/\1/'
}

SERVICE=$1
ACTION=$2

if [ -z "$SERVICE" ] || [ -z "$ACTION" ]; then
    show_usage
    exit 1
fi

# 检查底座层
check_ops

function manage_service() {
    local srv=$1
    local act=$2
    local file="$COMPOSE_DIR/share-$srv.yaml"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 未找到服务配置文件 $file${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}正在对共享层服务 [$srv] 执行操作: $act...${NC}"
    case "$act" in
        start)
            docker compose -f "$file" up -d
            ;;
        stop)
            docker compose -f "$file" stop
            ;;
        restart)
            docker compose -f "$file" up -d
            ;;
        status)
            docker compose -f "$file" ps
            ;;
    esac
}

if [ "$SERVICE" == "all" ]; then
    for f in "$COMPOSE_DIR"/share-*.yaml; do
        srv_name=$(echo "$f" | sed 's/.*share-\(.*\)\.yaml/\1/')
        manage_service "$srv_name" "$ACTION"
    done
else
    manage_service "$SERVICE" "$ACTION"
fi
