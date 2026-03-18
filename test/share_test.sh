#!/bin/bash

# ==============================================================================
# Antigravity 共享层 (Share Layer) 集成测试脚本
# 功能：一键验证共享层数据库、AI 模型服务及管理工具的健康状态与连通性
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_common.sh"

print_header "Antigravity Share Layer Integration Test Status"

# 1. 基础服务存活性测试
echo -e "\n${YELLOW}[Step 1] 服务存活性测试 (Liveness)${NC}"
SERVICES=(
    "share-postgres" 
    "share-chromadb" 
    "share-qdrant" 
    "share-llamacpp" 
    "share-whisper" 
    "share-vits" 
    "share-mlflow" 
    "share-embedding"
)
for svc in "${SERVICES[@]}"; do
    check_test "容器 $svc 正在运行" "docker ps --filter 'name=$svc' --filter 'status=running' --format '{{.Names}}' | grep -E '^(.+_)?${svc}$' -q"
done

# 2. 数据库连通性测试
echo -e "\n${YELLOW}[Step 2] 数据库连通性测试 (Databases)${NC}"

# Postgres
check_test "Postgres 响应正常 (Select 1)" "docker exec share-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c 'SELECT 1' | grep -q '(1 row)'"

# ChromaDB
check_test "ChromaDB 心跳 API 响应 (200)" "$PROBER http://share-chromadb:8000/api/v2/heartbeat"

# Qdrant
check_test "Qdrant 健康检查 API 响应 (200)" "$PROBER http://share-qdrant:6333/healthz"

# 3. AI 模型服务连通性测试
echo -e "\n${YELLOW}[Step 3] AI 模型服务连通性测试 (AI Models)${NC}"

# Llama.cpp (LLM)
check_test "Llama.cpp 健康状态响应" "$PROBER http://share-llamacpp:8080/health | grep -q 'ok'"

# Embedding (BGE-M3)
check_test "Embedding 服务健康状态响应" "$PROBER http://share-embedding:8080/health | grep -q 'ok'"

# Whisper (STT)
check_test "Whisper 服务健康状态响应" "$PROBER http://share-whisper:8080/health | grep -q 'ok'"

# VITS (TTS)
check_test "VITS 服务响应 (/) " "$PROBER http://share-vits:23456/ | grep -q 'VITS'"

# 4. 管理工具连通性测试
echo -e "\n${YELLOW}[Step 4] 管理工具连通性测试 (Tools)${NC}"

# MLFlow
check_test "MLFlow 健康检查 API 响应 (200)" "$PROBER http://share-mlflow:5000/health"

print_footer
