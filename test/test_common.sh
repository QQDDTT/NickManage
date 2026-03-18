#!/bin/bash

# ==============================================================================
# Antigravity 测试框架公共库 (test_common.sh)
# 功能：颜色定义、环境加载、通用测试函数
# ==============================================================================

# 1. 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 2. 加载环境变量
COMPOSE_DIR="/home/nick/NickManage/docker/compose"
if [ -f "$COMPOSE_DIR/.env" ]; then
    export $(grep -v '^#' "$COMPOSE_DIR/.env" | xargs)
else
    # 尝试当前目录或上级目录
    if [ -f "../.env" ]; then
        export $(grep -v '^#' "../.env" | xargs)
    elif [ -f "./.env" ]; then
        export $(grep -v '^#' "./.env" | xargs)
    fi
fi

# 3. 网络探测工具定义 (使用独立容器以提高鲁棒性)
PROBER="docker run --rm --network nms-bridge curlimages/curl:8.7.1 -s -m 5 -f"

# 4. 通用测试函数：运行并打印结果
check_test() {
    local test_name=$1
    local cmd=$2
    echo -n "测试项目: $test_name ... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}[通过]${NC}"
        return 0
    else
        echo -e "${RED}[失败]${NC}"
        return 1
    fi
}

# 5. Loki 检索重试函数
check_loki_log() {
    local query=$1
    local pattern=$2
    local retries=${3:-10}
    local delay=${4:-3}
    
    # 获取 10 分钟前的纳秒时间戳作为开始时间
    local start=$(date -d "10 minutes ago" +%s%N 2>/dev/null || date -v -10M +%s%N 2>/dev/null || echo "$(( $(date +%s) - 600 ))000000000")

    while [ $retries -gt 0 ]; do
        # 使用 query_range 接口以支持正确的 start 时间窗口
        # 增加 limit 至 1000 以应对高频健康检查日志的“噪音淹没”
        if $PROBER -G "http://ops-loki:3100/loki/api/v1/query_range" \
            --data-urlencode "query=$query |= \"$pattern\"" \
            --data-urlencode "start=$start" \
            --data-urlencode "limit=1000" | grep -q "$pattern"; then
            return 0
        fi
        sleep $delay
        retries=$((retries - 1))
    done
    return 1
}

# 6. 打印页眉
print_header() {
    local title=$1
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}          $title          ${NC}"
    echo -e "${BLUE}================================================================${NC}"
}

# 7. 打印页脚
print_footer() {
    echo -e "\n${BLUE}================================================================${NC}"
    echo -e "${BLUE}                    测试执行完毕 (Testing Done)                    ${NC}"
    echo -e "${BLUE}================================================================${NC}"
}
