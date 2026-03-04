FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# 安装 Python 3 和 PlatformIO
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    udev \
    && ln -sf /usr/bin/python3 /usr/local/bin/python \
    && ln -sf /usr/bin/pip3 /usr/local/bin/pip \
    && pip install --no-cache-dir --break-system-packages platformio \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/home/vscode/.local/bin

# Dev Container 语言识别用
ENV LANG_RUNTIME="python"
ENV LANG_VERSION="3.12"

WORKDIR /workspace
