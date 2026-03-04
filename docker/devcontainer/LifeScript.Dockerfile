FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# 安装 Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Dev Container 语言识别用
ENV LANG_RUNTIME="node"
ENV LANG_VERSION="20"

WORKDIR /workspace
