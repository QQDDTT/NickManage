# 基础镜像使用 Ubuntu 24.04
FROM ubuntu:24.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 安装基础软件和 Antigravity 运行所需依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    sudo \
    libatomic1 \
    libgbm1 \
    libasound2t64 \
    libnss3 \
    libx11-xcb1 \
    libxcb-dri3-0 \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# 创建 vscode 用户并赋予 sudo 权限 (对应宿主机身份)
RUN useradd -m -s /bin/bash vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

# 安装 Antigravity IDE (假设通过官方安装指令下载)
# 注意：实际生产中应根据 Antigravity 提供的最新安装命令进行调整
RUN curl -fsSL https://antigravity.google/install.sh | bash || true
# 如果安装脚本需要参数或者有特定路径，请在此处扩展。
# 目前根据 Antigravity-Manage 脚本推断，安装目录应在 /usr/local/bin 或用户目录下

USER vscode
WORKDIR /home/vscode

# 默认启动命令
CMD ["tail", "-f", "/dev/null"]
