FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# 安装 Python 3.12 环境
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    && ln -sf /usr/bin/python3 /usr/local/bin/python \
    && ln -sf /usr/bin/pip3 /usr/local/bin/pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
