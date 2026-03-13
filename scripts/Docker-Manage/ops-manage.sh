#!/bin/bash

# ops-manage.sh: 底座层 (Ops) 容器一键管理脚本
# 支持操作: start, stop, restart, status

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

COMPOSE_FILE="$MNG_HOME/docker/compose/ops-compose.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}错误: 找不到 ops-compose.yaml ($COMPOSE_FILE)${NC}"
    exit 1
fi

function show_usage() {
    echo -e "${BLUE}用法: $0 {start|stop|restart|status}${NC}"
}

ACTION=$1

case "$ACTION" in
    start)
        echo -e "${YELLOW}正在启动底座层容器...${NC}"
        docker compose -f "$COMPOSE_FILE" up -d
        echo -e "${GREEN}启动指令已发送。${NC}"
        ;;
    stop)
        echo -e "${YELLOW}正在停止底座层容器...${NC}"
        docker compose -f "$COMPOSE_FILE" stop
        echo -e "${GREEN}停止指令已发送。${NC}"
        ;;
    restart)
        echo -e "${YELLOW}正在重启底座层容器...${NC}"
        docker compose -f "$COMPOSE_FILE" restart
        echo -e "${GREEN}重启指令已发送。${NC}"
        ;;
    status)
        echo -e "${BLUE}底座层容器状态:${NC}"
        docker compose -f "$COMPOSE_FILE" ps
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
