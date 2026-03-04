FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# 安装 .NET 8 SDK
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates \
    && curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/local/dotnet \
    && rm /tmp/dotnet-install.sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV DOTNET_ROOT=/usr/local/dotnet
ENV PATH=$PATH:/usr/local/dotnet

# Dev Container 语言识别用
ENV LANG_RUNTIME="dotnet"
ENV LANG_VERSION="8.0"

WORKDIR /workspace
