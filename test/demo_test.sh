#!/bin/bash

# ==============================================================================
# Antigravity 业务层 (Demo) 验证脚本
# 功能：验证开发层 (Dev) 与共享层 (Share) 的业务连通性及 Traefik 转发
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_common.sh"

print_header "Antigravity Multi-Layer Demo Service Test Status"

# 1. 开发层容器存活性
echo -e "\n${YELLOW}[Step 1] 开发层组件就绪测试 (Dev Layer)${NC}"
check_test "容器 dev-demo 正在运行" "docker ps --filter 'name=dev-demo' --filter 'status=running' -q"

# 2. 跨层级连通性测试 (Dev -> Share)
echo -e "\n${YELLOW}[Step 2] 跨层级连通性测试 (Dev -> Share)${NC}"
# 验证在 dev-demo 中是否能 ping 通共享层服务 (如 share-redis, share-llamacpp)
check_test "Dev 层访问 Share 层 Redis" "docker exec dev-demo getent hosts ops-redis"
check_test "Dev 层访问 Share 层 Llama.cpp" "docker exec dev-demo getent hosts share-llamacpp"

# 3. Traefik 域名路由测试
echo -e "\n${YELLOW}[Step 3] 外部接入转发测试 (Ingress/Traefik)${NC}"
# 注意：由于 dev-demo 默认 entrypoint 是 tail -f，我们需要临时启一个 python server 验证
echo ">>> 启动临时验证服务 (Port 8000)..."
docker exec -d dev-demo python3 -m http.server 8000
sleep 2

check_test "Traefik 业务域名路由 (demo.local)" "$PROBER -H 'Host: demo.local' http://ops-traefik"

echo ">>> 清理临时验证服务..."
docker exec dev-demo pkill -f "python3 -m http.server"

# 4. 业务日志上报验证
echo -e "\n${YELLOW}[Step 4] 业务日志上报验证 (Observability)${NC}"
BUSINESS_TAG="demo_biz_event_$(date +%s)"

# 特殊处理：dev-demo 启用了 pid: host，常规 /proc/1/fd/1 会指向宿主机 init
# 我们需要找到执行 tail -f /dev/null 的真实 PID
REAL_PID=$(docker exec dev-demo ps -ef | grep "tail -f /dev/null" | grep -v grep | awk '{print $2}' | head -n 1)

if [ -n "$REAL_PID" ]; then
    docker exec -u 0 dev-demo sh -c "echo 'BIZ_EVENT: $BUSINESS_TAG' > /proc/$REAL_PID/fd/1" > /dev/null 2>&1
else
    # 回退方案
    docker exec -u 0 dev-demo sh -c "echo 'BIZ_EVENT: $BUSINESS_TAG' > /proc/1/fd/1" > /dev/null 2>&1
fi

echo -n "测试项目: 业务日志进入 Loki ($BUSINESS_TAG) ... "
if check_loki_log "{container=\"dev-demo\"}" "$BUSINESS_TAG"; then
    echo -e "${GREEN}[通过]${NC}"
else
    echo -e "${RED}[失败]${NC}"
fi

print_footer
