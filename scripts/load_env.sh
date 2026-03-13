#!/bin/bash

# load_env.sh: 将项目根目录的 .env 文件加载到当前 Shell 环境变量中
# 使用方法: source ./scripts/load_env.sh

# 获取脚本所在目录的绝对路径，并推导出项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

if [ -f "$ENV_FILE" ]; then
    echo "正在加载环境变量: $ENV_FILE"
    
    # 导出环境变量，忽略注释和空行
    # 使用 allexport 模式自动导出后续定义的变量
    set -a
    source "$ENV_FILE"
    set +a
    
    echo "环境变量加载完成。"
    echo "MNG_HOME: $MNG_HOME"
else
    echo "错误: 未找到 .env 文件 ($ENV_FILE)"
    return 1 2>/dev/null || exit 1
fi
