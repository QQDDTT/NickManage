#!/bin/bash
# 备份共享层数据的脚本 (Share Layer)

set -e

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MNG_HOME="${SCRIPT_DIR}/.."
source "${MNG_HOME}/.env"

# 配置
BACKUP_ROOT="${MNG_HOME}/backups/share"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_ROOT}/share_backup_${TIMESTAMP}.tar.gz"
LOG_FILE="${MNG_HOME}/backups/logs/backup_share.log"

# 创建目录
mkdir -p "${BACKUP_ROOT}"
mkdir -p "$(dirname "${LOG_FILE}")"

echo "[$(date)] 开始备份共享层数据..." | tee -a "${LOG_FILE}"

# 执行压缩备份 (部分目录可能需要 sudo)
cd "${MNG_HOME}"
tar -zcvf "${BACKUP_FILE}" "volumes/share" >> "${LOG_FILE}" 2>&1 || echo "[警告] 部分文件备份失败，请检查权限 (建议使用 sudo 运行)。" | tee -a "${LOG_FILE}"

# 清理旧备份 (保留 7 天)
find "${BACKUP_ROOT}" -name "share_backup_*.tar.gz" -mtime +7 -delete

echo "[$(date)] 备份完成: ${BACKUP_FILE}" | tee -a "${LOG_FILE}"
