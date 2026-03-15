#!/bin/bash

# ==============================================================================
# Antigravity Ops 层全机能集成测试脚本
# 功能：一键验证 Ops 层服务的健康状态、资源配额及业务连通性
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 加载环境变量
COMPOSE_DIR="/home/nick/NickManage/docker/compose"
if [ -f "$COMPOSE_DIR/.env" ]; then
    export $(grep -v '^#' "$COMPOSE_DIR/.env" | xargs)
else
    echo -e "${RED}[错误] 未找到 .env 配置文件${NC}"
fi

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}          Antigravity Ops Layer Integration Test Status          ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 测试函数：运行并打印结果
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

# 1. 基础服务存活性测试
echo -e "\n${YELLOW}[Step 1] 服务存活性测试 (Liveness)${NC}"
SERVICES=("ops-traefik" "ops-redis" "ops-loki" "ops-vector" "ops-docker-socket-proxy" "ops-gitea")
for svc in "${SERVICES[@]}"; do
    check_test "容器 $svc 正在运行" "docker ps --filter 'name=$svc' --filter 'status=running' | grep $svc"
done

# 2. 资源配额测试
echo -e "\n${YELLOW}[Step 2] 资源配额合规性测试 (Quotas)${NC}"
check_test "Gitea CPU 限制已生效 (2.0)" "docker inspect ops-gitea --format '{{.HostConfig.NanoCpus}}' | grep 2000000000"
check_test "Gitea 内存限制已生效 (512M)" "docker inspect ops-gitea --format '{{.HostConfig.Memory}}' | grep 536870912"
check_test "Llama.cpp CPU 限制已生效 (4.0)" "docker inspect share-llamacpp --format '{{.HostConfig.NanoCpus}}' | grep 4000000000"

# 定义网络探测工具 (使用独立容器以提高鲁棒性，使用 curlimages/curl 镜像以秒开)
PROBER="docker run --rm --network nms curlimages/curl:8.7.1 -s -m 5 -f"

# 3. 业务连通性测试
echo -e "\n${YELLOW}[Step 3] 业务连通性测试 (Connectivity)${NC}"

# Gitea
check_test "Gitea 健康检查 API 响应 (200)" "$PROBER http://ops-gitea:3000/api/healthz"
check_test "Gitea 内部网络访问正常" "$PROBER http://ops-gitea:3000/api/healthz"

# Redis
check_test "Redis 连接正常 (PING)" "docker exec ops-redis redis-cli -a ${REDIS_PASSWORD} ping | grep PONG"
check_test "Redis Exporter 指标采集就绪" "$PROBER http://ops-redis-exporter:9121/metrics | grep redis_up"

# 4. 可观测性链路测试 (Observability)
echo -e "\n${YELLOW}[Step 4] 可观测性链路测试 (Observability)${NC}"
check_test "Loki 就绪状态探测" "$PROBER http://ops-loki:3100/ready"

# 日志拦截测试 (Log Interception)
TEST_TAG="antigravity_error_test_$(date +%s)"
# 如果 ops-gitea 还在重启中，尝试产生的日志可能会失败，故加个防护
docker exec ops-gitea sh -c "echo '$TEST_TAG'" > /dev/null 2>&1
echo -n "测试项目: 日志拦截全链路追踪 ($TEST_TAG) ... "
sleep 7
if $PROBER "http://ops-loki:3100/loki/api/v1/query?query={container=\"ops-gitea\"}" | grep -q "$TEST_TAG"; then
    echo -e "${GREEN}[通过]${NC}"
else
    echo -e "${RED}[失败]${NC}"
fi

# 日志管理测试 (Log Management)
check_test "Loki 标签管理 API 响应正常" "$PROBER http://ops-loki:3100/loki/api/v1/labels | grep -q 'container'"

# 5. 安全与任务拦截测试 (Security & Interception)
echo -e "\n${YELLOW}[Step 5] 安全与任务拦截测试 (Security & Interception)${NC}"
# 验证 Docker Socket Proxy 拦截非授权写操作 (DELETE)
check_test "Docker Proxy 权限拦截 (阻止非法 DELETE 任务)" "docker exec ops-gitea curl -s -X DELETE http://ops-docker-socket-proxy:2375/v1.41/containers/ops-gitea | grep -q 'Forbidden'"

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${BLUE}                    测试执行完毕 (Testing Done)                    ${NC}"
echo -e "${BLUE}================================================================${NC}"
