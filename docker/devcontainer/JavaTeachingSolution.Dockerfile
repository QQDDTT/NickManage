FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# 安装 Java 17 和 Maven
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk \
    maven \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# Dev Container 语言识别用
ENV LANG_RUNTIME="java"
ENV LANG_VERSION="17"

WORKDIR /workspace
