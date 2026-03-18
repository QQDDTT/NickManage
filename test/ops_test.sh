#!/bin/bash

# ==============================================================================
# Antigravity Ops 层全机能集成测试脚本
# 功能：验证 Ops 层服务的健康状态、资源配额及业务连通性
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_common.sh"

print_header "Antigravity Ops Layer Integration Test Status"

# 1. 基础服务存活性测试
echo -e "\n${YELLOW}[Step 1] 服务存活性测试 (Liveness)${NC}"
SERVICES=("ops-traefik" "ops-redis" "ops-loki" "ops-vector" "ops-docker-socket-proxy" "ops-gitea")
for svc in "${SERVICES[@]}"; do
    check_test "容器 $svc 正在运行" "docker ps --filter 'name=$svc' --filter 'status=running' --format '{{.Names}}' | grep -E '^(.+_)?${svc}$' -q"
done

# 2. 资源配额测试
echo -e "\n${YELLOW}[Step 2] 资源配额合规性测试 (Quotas)${NC}"
check_test "Gitea CPU 限制已生效 (2.0)" "docker inspect ops-gitea --format '{{.HostConfig.NanoCpus}}' | grep 2000000000"
check_test "Gitea 内存限制已生效 (512M)" "docker inspect ops-gitea --format '{{.HostConfig.Memory}}' | grep 536870912"

# 3. 业务连通性测试
echo -e "\n${YELLOW}[Step 3] 业务连通性测试 (Connectivity)${NC}"

# Gitea
check_test "Gitea 健康检查 API 响应 (200)" "$PROBER http://ops-gitea:3000/api/healthz"

# Redis
check_test "Redis 连接正常 (PING)" "docker exec ops-redis redis-cli -a ${REDIS_PASSWORD} ping | grep PONG"
check_test "Redis Exporter 指标采集就绪" "$PROBER http://ops-redis-exporter:9121/metrics | grep redis_up"

# 4. 日志链路测试
echo -e "\n${YELLOW}[Step 4] 日志拦截全链路测试 (Logging)${NC}"
TEST_TAG="ops_error_test_$(date +%s)"
# 触发一个错误日志
docker exec -u 0 ops-gitea sh -c "echo 'ERROR: $TEST_TAG' > /proc/1/fd/1" > /dev/null 2>&1
echo -n "测试项目: 日志拦截追踪 ($TEST_TAG) ... "
if check_loki_log "{container=\"ops-gitea\"}" "$TEST_TAG"; then
    echo -e "${GREEN}[通过]${NC}"
else
    echo -e "${RED}[失败]${NC}"
fi

# 5. 安全拦截测试
echo -e "\n${YELLOW}[Step 5] 安全与任务拦截测试 (Security)${NC}"
# 验证 Docker Socket Proxy 拦截非授权写操作
check_test "Docker Proxy 权限拦截 (阻止非法 DELETE 任务)" "docker exec ops-gitea curl -s -X DELETE http://ops-docker-socket-proxy:2375/v1.41/containers/ops-gitea | grep -qvE 'Conflict|204 No Content'"

print_footer
