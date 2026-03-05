#!/bin/bash
# 用途: 将所有软件开发项目的 devcontainer.json 同步为最新工作流标准模板
# 使用方式: bash /home/nick/NickManage/scripts/sync_devcontainer.sh

set -euo pipefail

WORKSPACE="/home/nick/WorkSpace"
NICKMANAGE="/home/nick/NickManage"

# ──────────────────────────────────────────────
# 项目语言及版本配置（项目名 → 语言 版本 有无Compose）
# ──────────────────────────────────────────────
declare -A LANG_RUNTIME=(
  ["NeoCompanion"]="python"
  ["japanese-learning-app"]="python"
  ["AlpacaLens"]="python"
  ["Evo-Holon"]="python"
  ["Graph-Weave"]="rust"
  ["CSharpTeachingSolution"]="dotnet"
  ["JavaTeachingSolution"]="java"
  ["LifeScript"]="node"
  ["Microcontroller_Flasher_Project"]="python"
)

declare -A LANG_VERSION=(
  ["NeoCompanion"]="3.12"
  ["japanese-learning-app"]="3.12"
  ["AlpacaLens"]="3.12"
  ["Evo-Holon"]="3.12"
  ["Graph-Weave"]="1.78"
  ["CSharpTeachingSolution"]="8.0"
  ["JavaTeachingSolution"]="17"
  ["LifeScript"]="20"
  ["Microcontroller_Flasher_Project"]="3.12"
)

# 项目目录名与 Dockerfile 名称不同时的映射表（目录名 → Dockerfile 前缀）
declare -A DOCKERFILE_NAME=(
  ["Microcontroller_Flasher_Project"]="microcontroller-flasher"
)

# 有 Docker Compose 配置的项目（情况B模板）
# 目前所有项目均使用情况A（直接 build Dockerfile），无附加中间件
declare -A HAS_COMPOSE=()

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

for project in "${!LANG_RUNTIME[@]}"; do
  project_dir="$WORKSPACE/$project"
  devcontainer_dir="$project_dir/.devcontainer"
  devcontainer_file="$devcontainer_dir/devcontainer.json"
  project_info_file="$project_dir/.project"
  
  # 检查项目目录是否存在
  if [ ! -d "$project_dir" ]; then
    echo -e "${YELLOW}[跳过] 项目目录不存在: $project_dir${RESET}"
    continue
  fi
  
  # 提取项目显示名称（从 .project 中读取，若不存在则使用文件夹名）
  display_name="$project"
  if [ -f "$project_info_file" ]; then
    display_name=$(grep "^name:" "$project_info_file" | cut -d: -f2 | xargs)
  fi

  mkdir -p "$devcontainer_dir"
  
  runtime="${LANG_RUNTIME[$project]}"
  version="${LANG_VERSION[$project]}"
  has_compose="${HAS_COMPOSE[$project]:-false}"
  github_user="QQDDTT"
  
  if [ "$has_compose" = "true" ]; then
    # 情况B: 有附加中间件，使用 dockerComposeFile
    compose_file="$NICKMANAGE/docker/compose/${project}.yaml"
    cat > "$devcontainer_file" <<EOF
{
  "name": "${display_name}",
  "dockerComposeFile": "${compose_file}",
  "service": "app",
  "workspaceFolder": "/workspace",
  "mounts": [
    "source=\${localEnv:HOME}/.kube,target=/home/vscode/.kube,type=bind,readonly",
    "source=\${localEnv:HOME}/.gitconfig,target=/home/vscode/.gitconfig,type=bind,readonly",
    "source=\${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
  ],
  "remoteUser": "vscode",
  "features": {
    "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {
      "installHelm": true,
      "installMinikube": false
    }
  },
  "remoteEnv": {
    "LANG_RUNTIME": "${runtime}",
    "LANG_VERSION": "${version}",
    "GITHUB_USER": "${github_user}",
    "PROJECT_NAME": "${display_name}"
  }
}
EOF
  else
    # 情况A: 无附加中间件，直接 build Dockerfile
    dockerfile_key="${DOCKERFILE_NAME[$project]:-$project}"
    dockerfile_path="$NICKMANAGE/docker/devcontainer/base-dev.Dockerfile"
    cat > "$devcontainer_file" <<EOF
{
  "name": "${display_name}",
  "build": {
    "dockerfile": "${dockerfile_path}",
    "context": "${NICKMANAGE}/docker/devcontainer"
  },
  "workspaceFolder": "/workspace",
  "mounts": [
    "source=${WORKSPACE}/${project},target=/workspace,type=bind,consistency=cached",
    "source=\${localEnv:HOME}/.kube,target=/home/vscode/.kube,type=bind,readonly",
    "source=\${localEnv:HOME}/.gitconfig,target=/home/vscode/.gitconfig,type=bind,readonly",
    "source=\${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
  ],
  "remoteUser": "vscode",
  "features": {
    "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {
      "installHelm": true,
      "installMinikube": false
    }
  },
  "remoteEnv": {
    "LANG_RUNTIME": "${runtime}",
    "LANG_VERSION": "${version}",
    "GITHUB_USER": "${github_user}",
    "PROJECT_NAME": "${display_name}"
  }
}
EOF
  fi
  
  echo -e "${GREEN}[✓] ${project} → devcontainer.json 已更新 (GitHub: ${github_user}, Project: ${display_name})${RESET}"
done

echo ""
echo -e "${GREEN}全部同步完成。${RESET}"
