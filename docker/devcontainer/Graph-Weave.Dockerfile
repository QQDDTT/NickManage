FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# 安装 Rust 环境
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl build-essential pkg-config libssl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER vscode
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH=/home/vscode/.cargo/bin:$PATH
