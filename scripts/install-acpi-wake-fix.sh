#!/usr/bin/env bash
# 此脚本用于解决由于 Surface Pro 9 内置硬件的 ACPI 唤醒信号导致关机后立即自动重启的问题。
# 原理：禁用特定设备（如 USB 控制器 XHCI、Thunderbolt 控制器 TXHC 等）的唤醒功能。
# 包含自动安装为一个 systemd 服务，确保每次开机及睡/关机前该功能被禁用。

if [ "$EUID" -ne 0 ]; then
  echo "请使用 sudo 运行此脚本以安装 systemd 服务。"
  exit 1
fi

SERVICE_FILE="/etc/systemd/system/disable-acpi-wake.service"
SCRIPT_FILE="/usr/local/bin/disable-acpi-wake.sh"

echo "创建禁用唤醒的执行脚本..."
cat << 'EOF' > $SCRIPT_FILE
#!/usr/bin/env bash
# 遍历已知导致重启的设备，如果它们的状态是 enabled，则将其禁用 (echo 会切换它的状态)
for dev in PEG0 XHCI TXHC TDM1 TRP2 TRP3; do
    if grep -q -E "^$dev.*\*[[:space:]]*enabled" /proc/acpi/wakeup; then
        echo $dev > /proc/acpi/wakeup
    fi
done
EOF

chmod +x $SCRIPT_FILE

echo "创建 systemd 服务文件..."
cat << EOF > $SERVICE_FILE
[Unit]
Description=Disable ACPI wake-up for specific devices to prevent auto-reboot
Before=sleep.target shutdown.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_FILE

[Install]
WantedBy=multi-user.target sleep.target
EOF

echo "加载并启动服务..."
systemctl daemon-reload
systemctl enable --now disable-acpi-wake.service

echo "操作完成。现在系统关机后不应再自动重启（进入 ACPI 睡眠配置状态）。"
