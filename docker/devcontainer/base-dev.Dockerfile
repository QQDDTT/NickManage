FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# 设置环境变量：确保命令路径全局可用，并防止 Python 产生 .pyc 文件
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DOTNET_ROOT=/usr/local/dotnet \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# 安装通用构建工具和所有开发语言
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    pkg-config \
    libssl-dev \
    udev \
    # Python 3.12
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    # Java 17 & Maven
    openjdk-17-jdk \
    maven \
    && ln -sf /usr/bin/python3 /usr/local/bin/python \
    && ln -sf /usr/bin/pip3 /usr/local/bin/pip \
    # Node.js 20
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    # .NET 8 SDK
    && curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/local/dotnet \
    && rm /tmp/dotnet-install.sh \
    # 清理缓存
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 为 vscode 用户安装 Rust 和 PlatformIO
USER vscode
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable \
    && pip install --no-cache-dir --break-system-packages platformio

# 设置最终的环境变量
ENV PATH=/home/vscode/.cargo/bin:/home/vscode/.local/bin:/usr/local/dotnet:$JAVA_HOME/bin:$PATH

WORKDIR /workspace
