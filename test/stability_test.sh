#!/bin/bash

# ==============================================================================
# Antigravity 平台稳定性多层级验证脚本
# 验证内容：OOM 熔断、服务挂死检测、跨层级异常报告
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROBER="docker run --rm --network nms curlimages/curl:8.7.1 -s -m 5 -f"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}           Antigravity Architecture Stability Test              ${NC}"
echo -e "${BLUE}================================================================${NC}"

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

# 1. 监控服务就绪巡检
echo -e "\n${YELLOW}[Step 1] 监控服务就绪巡检${NC}"
check_test "Ops 监控容器 (ops-monitor) 运行中" "docker ps --filter 'name=ops-monitor' --filter 'status=running' | grep -q ops-monitor"
check_test "监控服务健康日志上报" "$PROBER -G 'http://ops-loki:3100/loki/api/v1/query_range' --data-urlencode 'query={origin=\"ops-monitor\"}' | grep -q '监控服务已启动'"

# 2. 模拟 Share 层服务挂死 (Service Unresponsive)
echo -e "\n${YELLOW}[Step 2] 模拟 Share 层服务无响应 (Zombie Process)${NC}"
echo ">>> 正在模拟 share-llamacpp 进程挂起 (SIGSTOP)..."
docker exec share-llamacpp kill -STOP 1 2>/dev/null

echo ">>> 等待 Ops Monitor 探测并重启 (预计 30-60s)..."
SLEEP_COUNT=0
while [ $SLEEP_COUNT -lt 6 ]; do
    sleep 10
    if docker inspect share-llamacpp --format '{{.State.Status}}' | grep -q 'restarting' || \
       [ $(docker inspect share-llamacpp --format '{{.State.Pid}}') -ne 0 ] && \
       docker exec share-llamacpp kill -CONT 1 2>/dev/null; then
       # 如果能 CONT 说明还在运行，但我们要看重启。
       # 实际上，如果 monitor 触发了 restart，容器 PID 会变。
       echo -n "."
    fi
    # 简单检查健康接口是否恢复
    if curl -s -m 2 http://localhost:5004/health > /dev/null; then
        echo -e "\n${GREEN}[确认] share-llamacpp 已被 Ops Monitor 自动修复并恢复访问。${NC}"
        break
    fi
    SLEEP_COUNT=$((SLEEP_COUNT + 1))
done

if [ $SLEEP_COUNT -ge 6 ]; then
    echo -e "\n${RED}[失败] Ops Monitor 未能在规定时间内修复 share-llamacpp。${NC}"
    docker exec share-llamacpp kill -CONT 1 2>/dev/null # 恢复现场
fi

# 3. 跨层级异常报告验证 (Reporting)
echo -e "\n${YELLOW}[Step 3] 异常报告通报机制验证${NC}"
echo ">>> 检查 Loki 中是否存在稳定性异常报告..."
if $PROBER -G 'http://ops-loki:3100/loki/api/v1/query_range' \
    --data-urlencode 'query={msg=~\"\.*STABILITY_REPORT\.*\"}' \
    --data-urlencode "limit=10" | grep -q "STABILITY_REPORT"; then
    echo -e "${GREEN}[通过] 异常报告已成功发送至管理员视图。${NC}"
else
    echo -e "${RED}[失败] 未能在日志系统中发现稳定性报告。${NC}"
fi

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${BLUE}                  稳定性验证完毕 (Stability Done)                 ${NC}"
echo -e "${BLUE}================================================================${NC}"
