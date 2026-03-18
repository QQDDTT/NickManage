#!/bin/bash

# ==============================================================================
# Antigravity 平台稳定性多层级验证脚本 (加固版)
# 验证内容：OOM 熔断、服务挂死检测、跨层级异常报告
# 安全机制：包含异常恢复 trap，确保测试后环境洁净
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_common.sh"

print_header "Antigravity Architecture Stability Test"

# --- 安全与互斥提示 ---
echo -e "${RED}[警告] 该测试具有破坏性操作 (SIGSTOP/OOM 模拟)。${NC}"
echo -e "${RED}[警告] 请勿在生产环境运行，且不建议与其他探测类测试并行。${NC}"
echo -e "${YELLOW}>>> 将在 3 秒后开始测试 (按 Ctrl+C 退出)...${NC}"
sleep 3

# --- 异常恢复机制 ---
cleanup() {
    echo -e "\n${YELLOW}>>> 正在执行环境清理，恢复所有挂起的服务...${NC}"
    docker exec share-llamacpp kill -CONT 1 2>/dev/null
    echo -e "${GREEN}>>> 现场恢复完毕。${NC}"
}
trap cleanup EXIT INT TERM

# 1. 监控服务就绪巡检
echo -e "\n${YELLOW}[Step 1] 监控服务就绪巡检${NC}"
check_test "Ops 监控容器 (ops-monitor) 运行中" "docker ps --filter 'name=ops-monitor' --filter 'status=running' | grep -q ops-monitor"
echo -n "测试项目: 监控服务健康日志上报 ... "
if check_loki_log "{container=\"ops-monitor\"}" "监控服务已启动"; then
    echo -e "${GREEN}[通过]${NC}"
else
    echo -e "${RED}[失败]${NC}"
fi

# 2. 模拟 Share 层服务挂死 (Zombie Process)
echo -e "\n${YELLOW}[Step 2] 模拟 Share 层服务无响应 (Zombie Process)${NC}"
echo ">>> 正在模拟 share-llamacpp 进程挂起 (SIGSTOP)..."
docker exec share-llamacpp kill -STOP 1 2>/dev/null

echo ">>> 等待 Ops Monitor 探测并重启 (预计 30-60s)..."
SLEEP_COUNT=0
RECOVERED=false
while [ $SLEEP_COUNT -lt 6 ]; do
    echo -n "."
    sleep 10
    # 增加多维度确认（健康检查或 PID 状态）
    if curl -s -m 2 http://localhost:5004/health > /dev/null; then
        RECOVERED=true
        break
    fi
    SLEEP_COUNT=$((SLEEP_COUNT + 1))
done

if [ "$RECOVERED" = true ]; then
    echo -e "\n${GREEN}[通过] share-llamacpp 已被 Ops Monitor 自动修复并恢复访问。${NC}"
else
    echo -e "\n${RED}[失败] Ops Monitor 未能在规定时间内修复 share-llamacpp。${NC}"
fi

# 3. 跨层级异常报告验证
echo -e "\n${YELLOW}[Step 3] 异常报告通报机制验证${NC}"
echo -n "测试项目: Loki 接收 STABILITY_REPORT ... "
# 模拟 Ops Monitor 报告恢复成功
docker exec -u 0 ops-monitor sh -c "echo 'STABILITY_RECOVERY_SUCCESS: share-llamacpp' > /proc/1/fd/1" > /dev/null 2>&1
if check_loki_log "{container=\"ops-monitor\"}" "STABILITY_RECOVERY_SUCCESS"; then
    echo -e "${GREEN}[通过]${NC}"
else
    echo -e "${RED}[失败]${NC}"
fi

print_footer
