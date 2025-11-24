#!/bin/bash

# VHD 卸载脚本
# 用于卸载通过 mount-vhd.sh 挂载的 VHD 文件

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MOUNT_LOG="/tmp/vhd_mounts.log"
MOUNT_BASE="/mnt/vhd"

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 检查是否有挂载记录
if [ ! -f "$MOUNT_LOG" ] || [ ! -s "$MOUNT_LOG" ]; then
    echo -e "${YELLOW}未找到挂载记录,尝试清理残留挂载点...${NC}\n"
    
    # 清理 /mnt/vhd 下的挂载点
    if [ -d "$MOUNT_BASE" ]; then
        for mount_point in "$MOUNT_BASE"/*; do
            if [ -d "$mount_point" ]; then
                if mountpoint -q "$mount_point" 2>/dev/null; then
                    echo -e "${BLUE}发现挂载点: $mount_point${NC}"
                    if umount "$mount_point" 2>/dev/null; then
                        echo -e "  ${GREEN}✓ 已卸载${NC}"
                        rmdir "$mount_point" 2>/dev/null
                    else
                        echo -e "  ${RED}✗ 卸载失败${NC}"
                    fi
                fi
            fi
        done
    fi
    
    # 清理 nbd 设备
    echo -e "\n${BLUE}清理 nbd 设备...${NC}"
    for i in {0..15}; do
        nbd_dev="/dev/nbd$i"
        if [ -b "$nbd_dev" ] && [ -f "/sys/block/nbd$i/pid" ]; then
            pid=$(cat "/sys/block/nbd$i/pid" 2>/dev/null || echo "")
            if [ -n "$pid" ] && [ "$pid" != "0" ]; then
                echo -e "${YELLOW}断开 $nbd_dev...${NC}"
                qemu-nbd --disconnect "$nbd_dev" &>/dev/null || true
            fi
        fi
    done
    
    echo -e "\n${GREEN}清理完成${NC}"
    exit 0
fi

echo -e "${BLUE}正在卸载 VHD 文件...${NC}\n"

# 统计
total=0
success=0
failed=0

# 读取挂载记录并卸载
while IFS='|' read -r nbd_dev partition mount_point vhd_path; do
    ((total++))
    
    echo -e "${BLUE}[$total] 处理: $(basename "$vhd_path")${NC}"
    echo -e "    设备: $nbd_dev"
    echo -e "    挂载点: $mount_point"
    
    has_error=0
    
    # 卸载分区
    if mountpoint -q "$mount_point" 2>/dev/null; then
        if umount "$mount_point" 2>/dev/null; then
            echo -e "    ${GREEN}✓ 已卸载文件系统${NC}"
            rmdir "$mount_point" 2>/dev/null || true
        else
            echo -e "    ${RED}✗ 卸载文件系统失败${NC}"
            has_error=1
        fi
    else
        echo -e "    ${YELLOW}⚠ 文件系统未挂载${NC}"
    fi
    
    # 断开 nbd 设备
    if [ -b "$nbd_dev" ]; then
        if qemu-nbd --disconnect "$nbd_dev" &>/dev/null; then
            echo -e "    ${GREEN}✓ 已断开 nbd 设备${NC}"
        else
            echo -e "    ${YELLOW}⚠ 断开 nbd 设备可能失败${NC}"
            has_error=1
        fi
    else
        echo -e "    ${YELLOW}⚠ nbd 设备不存在${NC}"
    fi
    
    if [ $has_error -eq 0 ]; then
        ((success++))
    else
        ((failed++))
    fi
    
    echo
done < "$MOUNT_LOG"

# 清理日志文件
rm -f "$MOUNT_LOG"

# 显示统计
echo -e "${BLUE}=== 卸载统计 ===${NC}"
echo -e "  总计: $total"
echo -e "  ${GREEN}成功: $success${NC}"
if [ $failed -gt 0 ]; then
    echo -e "  ${RED}失败: $failed${NC}"
fi

# 询问是否卸载 nbd 模块
echo
read -p "是否卸载 nbd 内核模块? (y/N): " unload
if [[ "$unload" =~ ^[Yy]$ ]]; then
    if rmmod nbd 2>/dev/null; then
        echo -e "${GREEN}✓ nbd 模块已卸载${NC}"
    else
        echo -e "${YELLOW}⚠ 无法卸载 nbd 模块${NC}"
        echo -e "   (可能还有其他进程在使用)"
    fi
fi

echo -e "\n${GREEN}完成!${NC}"