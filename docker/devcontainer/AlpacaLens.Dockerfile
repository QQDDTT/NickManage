FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# 设置环境变量：确保命令路径全局可用，并防止 Python 产生 .pyc 文件
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 安装 Python 3.12 环境及常用构建工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    ca-certificates \
    curl \
    git \
    && ln -sf /usr/bin/python3 /usr/local/bin/python \
    && ln -sf /usr/bin/pip3 /usr/local/bin/pip \
    # 清理缓存以缩小镜像体积
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Dev Container 语言识别用
ENV LANG_RUNTIME="python"
ENV LANG_VERSION="3.12"

WORKDIR /workspace