#!/bin/bash

# 创建新项目脚本
# 用法: ./create_project.sh <项目名>

if [ -z "$1" ]; then
    echo "错误: 请提供项目名。"
    echo "用法: $0 <项目名>"
    exit 1
fi

PROJECT_NAME="$1"
MNG_HOME="/home/nick/NickManage"
DEV_VOL_DIR="${MNG_HOME}/volumes/dev"
WORKSPACE_DIR="/home/nick/workspaces/${PROJECT_NAME}"
COMPOSE_DIR="${MNG_HOME}/docker/compose"
DEVCONTAINER_FILE="${MNG_HOME}/docker/devcontainer/${PROJECT_NAME}-devcontainer.json"
LOG_DIR="/home/nick/.logs/dev/${PROJECT_NAME}"

echo ">>> 开始创建开发层项目: ${PROJECT_NAME} <<<"

# 1. 建立基础目录结构
echo "-> 1. 创建工作空间和日志的目录结构..."
mkdir -p "${WORKSPACE_DIR}/.devcontainer"
mkdir -p "${WORKSPACE_DIR}/.agent"
mkdir -p "${WORKSPACE_DIR}/docs"
mkdir -p "${LOG_DIR}"

# 2. 生成 docker/devcontainer/<项目名>-devcontainer.json
echo "-> 2. 生成 devcontainer.json ..."
cat > "${DEVCONTAINER_FILE}" <<EOF
{
  "name": "${PROJECT_NAME}",
  "dockerComposeFile": [
    "${COMPOSE_DIR}/dev-${PROJECT_NAME}.yaml"
  ],
  "service": "dev-${PROJECT_NAME}",
  "workspaceFolder": "/workspaces/${PROJECT_NAME}",
  "remoteUser": "vscode",
  "features": {},
  "remoteEnv": {
    "LANG_RUNTIME": "none",
    "LANG_VERSION": "latest",
    "PROJECT_NAME": "${PROJECT_NAME}",
    "LOG_DIR": "/logs",
    "GITEA_URL": "\${localEnv:GITEA_URL}",
    "GITEA_USER": "\${localEnv:GITEA_USER}",
    "GITEA_TOKEN": "\${localEnv:GITEA_TOKEN}",
    "REDIS_HOST": "share-redis",
    "POSTGRES_HOST": "share-postgres",
    "EMBEDDING_HOST": "share-embedding",
    "LLM_HOST": "share-llamacpp",
    "GIT_USER_NAME": "\${localEnv:GITEA_USER_NAME}",
    "GIT_USER_EMAIL": "\${localEnv:GITEA_USER_EMAIL}"
  },
  "runArgs": [
    "--network=nms",
    "--name=dev-${PROJECT_NAME}"
  ],
  "postCreateCommand": "echo '正在准备工作空间...' && mkdir -p \${containerWorkspaceFolder} && git config --global --add safe.directory \${containerWorkspaceFolder} && cd \${containerWorkspaceFolder} && [ -d .git ] || (git init . && git remote add origin http://ops-gitea:3000/nick/${PROJECT_NAME}.git && git fetch origin && git checkout -f master || true)",
  "mounts": [
    "source=${MNG_HOME}/volumes/share/git/gitconfig,target=/home/vscode/.gitconfig,type=bind,readonly=true",
    "source=${MNG_HOME}/volumes/share/git/.git-credentials,target=/home/vscode/.git-credentials,type=bind,readonly=true",
    "source=/home/nick/.gemini/GEMINI.md,target=/home/vscode/.gemini/GEMINI.md,type=bind,readonly=true"
  ]
}
EOF

# 3. 生成 dev-<项目名>.yaml (无特定编程语言挂载)
echo "-> 3. 生成 dev-${PROJECT_NAME}.yaml ..."
cat > "${COMPOSE_DIR}/dev-${PROJECT_NAME}.yaml" <<EOF
services:
  dev-${PROJECT_NAME}:
    image: dev-image:latest
    container_name: dev-${PROJECT_NAME}
    labels:
      - "nms.collect=true"
      - "nms.layer=dev"
      - "nms.proxy=false"
    env_file: .env
    
    # --- 1. 权限与内核安全解锁 ---
    privileged: true
    security_opt:
      - seccomp:unconfined
    pid: "host" 

    # --- 2. 资源保障 ---
    deploy:
      resources:
        limits:
          memory: 4096M
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

    ports:
      # TODO: 分配可用的主机端口 (从 8000 起始)
      - "8000:8000"

    # --- 3. 环境变量优化 ---
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/vscode/.local/bin
      - ANTIGRAVITY_LOG_LEVEL=debug
      - GOMAXPROCS=2
      - NODE_OPTIONS=--max-old-space-size=4096
      - CUDA_VISIBLE_DEVICES=-1
      - NO_GPU=1

    # --- 4. 目录挂载 ---
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${WORKSPACE_DIR}:/workspaces/${PROJECT_NAME}
    
    # --- 5. 自动化启动脚本 ---
    entrypoint: >
      /bin/sh -c "
      chown -R vscode:vscode /workspaces/${PROJECT_NAME} 2>/dev/null;
      exec tail -f /dev/null
      "

    networks:
      - nms

networks:
  nms:
    external: true
EOF

# 4. 创建 devcontainer.json 的软链接
echo "-> 4. 生成只读软链接 .devcontainer/devcontainer.json ..."
LINK_DST="${WORKSPACE_DIR}/.devcontainer/devcontainer.json"
LINK_SRC="${DEVCONTAINER_FILE}"

[ -L "${LINK_DST}" ] && rm "${LINK_DST}"
ln -s "${LINK_SRC}" "${LINK_DST}"

# 5. 配置 Gitea 到 GitHub 的镜像同步
echo "-> 5. 配置 Gitea 远端同步链路..."
bash "${MNG_HOME}/scripts/gitea_sync.sh" "${PROJECT_NAME}"

echo "========================================="
echo "项目 ${PROJECT_NAME} 创建成功！"
echo "- 工作目录: ${WORKSPACE_DIR}"
echo "- 日志目录: ${LOG_DIR}"
echo "- Compose : ${COMPOSE_DIR}/dev-${PROJECT_NAME}.yaml"
echo "- DEV JSON: ${LINK_SRC} (已链接到工作目录的 .devcontainer 下)"
echo "-----------------------------------------"
echo "提示: 请记得在 dev-${PROJECT_NAME}.yaml 中调整映射端口 (预留默认 8080)，以及按需后续添加对应的开发语言扩展与挂载。"
