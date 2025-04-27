#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# 输出带颜色的消息
message() {
    local color="$1"
    local text="$2"

    # 根据参数选择颜色
    case "$color" in
        "red")    color_code=$RED ;;
        "green")  color_code=$GREEN ;;
        "yellow") color_code=$YELLOW ;;
        "blue")   color_code=$BLUE ;;
        *)        color_code=$RESET ;;
    esac

    # 输出带颜色的文本到控制台
    echo -e "${color_code}${text}${RESET}"

    # 获取当前时间
    DATE=$(date "+%Y-%m-%d %H:%M:%S")
}

# 初始化日志
message "blue" "开始系统清理..."
# 1.1 停止 syslog.socket 服务
message "yellow" "停止 syslog.socket..."
if ! sudo systemctl stop syslog.socket; then
    message "red" "停止 syslog.socket 服务失败！"
    exit 1
fi

# 1.2 禁用 syslog.socket 以防止它重新启动 rsyslog
message "yellow" "禁用 syslog.socket..."
if ! sudo systemctl disable syslog.socket; then
    message "red" "禁用 syslog.socket 服务失败！"
    exit 1
fi

# 确认 syslog.socket 是否已停止
message "yellow" "检查 syslog.socket 状态..."
if sudo systemctl status syslog.socket | grep -q "inactive"; then
    message "green" "syslog.socket 已成功停止！"
else
    message "red" "syslog.socket 停止失败！"
    exit 1
fi

# 1. 停止 rsyslog 日志服务
message "yellow" "停止日志服务 rsyslog..."
if ! sudo systemctl stop rsyslog; then
    message "red" "停止 rsyslog 服务失败！"
    exit 1
fi

# 确认 rsyslog 是否已停止
message "yellow" "检查 rsyslog 服务状态..."
if sudo systemctl status rsyslog | grep -q "inactive"; then
    message "green" "rsyslog 已成功停止！"
else
    message "red" "rsyslog 停止失败！"
    exit 1
fi

# 2. 清理 APT 缓存
message "yellow" "清理 APT 缓存..."
if ! sudo apt-get clean; then
    message "red" "清理 APT 缓存失败！"
    exit 1
fi
if ! sudo apt-get autoclean; then
    message "red" "清理 APT 自动缓存失败！"
    exit 1
fi

# 3. 清理 Snap 缓存
message "yellow" "清理 Snap 缓存..."
if ! sudo rm -rf /var/lib/snapd/cache/*; then
    message "red" "清理 Snap 缓存失败！"
    exit 1
fi

# 4. 清理系统日志（仅保留最近 3 天的日志）
message "yellow" "清理系统日志（保留 3 天）..."
if ! sudo journalctl --vacuum-time=3d; then
    message "red" "清理系统日志失败！"
    exit 1
fi

# 5. 限制日志文件大小（100MB）
message "yellow" "限制日志文件大小至 100MB..."
if ! sudo journalctl --vacuum-size=100M; then
    message "red" "限制日志文件大小失败！"
    exit 1
fi

# 6. 清理 /var/log 目录中过大的日志文件（超过 1000MB 的清空）
LOG_DIR="/var/log"
THRESHOLD_MB=1000
find $LOG_DIR -type f -name "*" -size +"${THRESHOLD_MB}M" | while read FILE; do
    message "yellow" "清理日志: $FILE"
    if ! sudo truncate -s 0 "$FILE"; then
        message "red" "清理日志 $FILE 失败！"
    fi
done

# 7. 重新启动 rsyslog 日志服务
message "yellow" "重新启动日志服务 rsyslog..."
if ! sudo systemctl start rsyslog; then
    message "red" "启动 rsyslog 服务失败！"
    exit 1
fi

# 8. 显示磁盘使用情况
message "yellow" "磁盘使用情况:"
if ! df -h; then
    message "red" "显示磁盘使用情况失败！"
    exit 1
fi

message "green" "系统清理完成！"

# 暂停，等待用户输入后继续
read -p "按任意键结束脚本..."

