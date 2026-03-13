#!/bin/sh

# DevContainer 配置审计脚本 (Shell 版)
# 用于检查 .json 文件是否符合 IDE_USAGE_SPECIFICATION.md 规范

BASE_DIR="/home/nick/NickManage/docker/devcontainer"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "--- DevContainer JSON Audit Report (Shell) ---"

for f in "$BASE_DIR"/*.json; do
    filename=$(basename "$f")
    errors=""
    
    # 1. 检查 remoteUser
    if ! grep -q '"remoteUser": "vscode"' "$f"; then
        errors="$errors\n  - Missing/Wrong remoteUser"
    fi
    
    # 2. 检查关键挂载点
    if ! grep -q "gitconfig" "$f"; then
        errors="$errors\n  - Missing gitconfig mount"
    fi
    if ! grep -q ".git-credentials" "$f"; then
        errors="$errors\n  - Missing git-credentials mount"
    fi
    if ! grep -q ".antigravity" "$f"; then
        errors="$errors\n  - Missing .antigravity mount"
    fi
    if ! grep -q ".gemini" "$f"; then
        errors="$errors\n  - Missing .gemini mount"
    fi
    if ! grep -q "vscode-server" "$f"; then
        errors="$errors\n  - Missing vscode-server persistent mount"
    fi

    # 3. 检查扩展插件
    if ! grep -q '"extensions": \[' "$f"; then
        errors="$errors\n  - Missing extensions definition"
    fi

    if [ -z "$errors" ]; then
        printf "${GREEN}✅ %s${NC}\n" "$filename"
    else
        printf "${RED}❌ %s${NC}\n" "$filename"
        echo "$errors"
    fi
done
