#!/bin/bash
# 备份开发层代码的脚本 (Dev Layer)

set -e

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MNG_HOME="${SCRIPT_DIR}/.."
source "${MNG_HOME}/.env"

# 配置
BACKUP_ROOT="${MNG_HOME}/backups/dev"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_ROOT}/dev_backup_${TIMESTAMP}.tar.gz"
LOG_FILE="${MNG_HOME}/backups/logs/backup_dev.log"

# 创建目录
mkdir -p "${BACKUP_ROOT}"
mkdir -p "$(dirname "${LOG_FILE}")"

echo "[$(date)] 开始备份开发层代码..." | tee -a "${LOG_FILE}"

# 执行压缩备份 (部分目录可能需要 sudo)
cd /home/nick
tar -zcvf "${BACKUP_FILE}" \
    --exclude="node_modules" \
    --exclude=".venv" \
    --exclude="target" \
    --exclude=".cache" \
    "workspaces" >> "${LOG_FILE}" 2>&1 || echo "[警告] 部分文件备份失败，请检查权限。" | tee -a "${LOG_FILE}"

# 清理旧备份 (保留 7 天)
find "${BACKUP_ROOT}" -name "dev_backup_*.tar.gz" -mtime +7 -delete

echo "[$(date)] 备份完成: ${BACKUP_FILE}" | tee -a "${LOG_FILE}"
