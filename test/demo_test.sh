#!/bin/bash

# ==============================================================================
# Antigravity Demo 服务全生命周期集成测试脚本 (多层级版)
# 功能：验证 dev-demo 和 app-demo 容器在架构中的可靠性、权限及多层级日志校验
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 环境配置
COMPOSE_DIR="/home/nick/NickManage/docker/compose"
PROBER="docker run --rm --network nms curlimages/curl:8.7.1 -s -m 5 -f"
TARGETS=("dev-demo" "app-demo")

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}        Antigravity Multi-Layer Demo Service Test Status         ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 测试函数
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

# 1. 容器生命周期测试
echo -e "\n${YELLOW}[Step 1] 容器生命周期测试 (Lifecycle)${NC}"

for container in "${TARGETS[@]}"; do
    if ! docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
        echo -e "${YELLOW}[提示] 容器 $container 未启动，正在尝试启动...${NC}"
        docker compose -f "$COMPOSE_DIR/$container.yaml" up -d
    fi
    check_test "容器 $container 存活性状态" "docker ps --filter 'name=$container' --filter 'status=running' | grep -q $container"
done

# 特有的资源限制验证 (针对 dev-demo)
check_test "dev-demo 内存限制验证 (4096M)" "docker inspect dev-demo --format '{{.HostConfig.Memory}}' | grep 4294967296"
check_test "dev-demo Ulimit 句柄限制验证 (65536)" "docker inspect dev-demo --format '{{index .HostConfig.Ulimits 0}}' | grep -q '65536'"

# 2. 内核权限与安全验证 (重点针对 dev 层)
echo -e "\n${YELLOW}[Step 2] 内核权限与安全验证 (Kernel/Security)${NC}"
check_test "dev-demo Privileged 模式验证" "docker inspect dev-demo --format '{{.HostConfig.Privileged}}' | grep true"
check_test "dev-demo PID Host 模式验证" "docker inspect dev-demo --format '{{.HostConfig.PidMode}}' | grep host"

# 3. 架构网络连通性测试
echo -e "\n${YELLOW}[Step 3] 架构网络连通性测试 (Connectivity)${NC}"
for container in "${TARGETS[@]}"; do
    check_test "[$container] 访问 ops-gitea" "docker exec $container curl -s -m 2 http://ops-gitea:3000/api/healthz"
    check_test "[$container] 访问 ops-loki" "docker exec $container curl -s -m 2 http://ops-loki:3100/ready"
done

# 4. 可观测性全链路闭环验证
echo -e "\n${YELLOW}[Step 4] 可观测性全链路验证 (Observability)${NC}"
TIMESTAMP=$(date +%s)

for container in "${TARGETS[@]}"; do
    TEST_TAG="${container}_verify_${TIMESTAMP}"
    echo -n "测试项目: [$container] 日志采集链路追踪 ($TEST_TAG) ... "
    
    # 注入日志
    if [ "$container" == "app-demo" ]; then
        # app 容器模拟 JSON 日志输出
        docker exec $container sh -c "echo '{\"level\": \"info\", \"msg\": \"[VERIFY] $TEST_TAG\"}'" > /dev/null 2>&1
    else
        # dev 容器普通文本日志
        docker exec $container sh -c "echo '[VERIFY] $TEST_TAG'" > /dev/null 2>&1
    fi
done

echo -e "${YELLOW}[等待 10s 确保日志流经 Vector 到达 Loki... ]${NC}"
sleep 10

for container in "${TARGETS[@]}"; do
    TEST_TAG="${container}_verify_${TIMESTAMP}"
    echo -n "检查结果: [$container] ... "
    # Loki query_range 需要纳秒时间戳或让其默认
    if $PROBER -G "http://ops-loki:3100/loki/api/v1/query_range" \
        --data-urlencode "query={container=\"$container\"} |= \"$TEST_TAG\"" \
        --data-urlencode "limit=50" | grep -q "$TEST_TAG"; then
        echo -e "${GREEN}[通过]${NC}"
    else
        echo -e "${RED}[失败]${NC}"
    fi
done

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${BLUE}                    测试执行完毕 (Testing Done)                    ${NC}"
echo -e "${BLUE}================================================================${NC}"
