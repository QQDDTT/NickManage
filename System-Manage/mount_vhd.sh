#!/bin/bash

# VHD 挂载脚本
# 递归遍历 /media/nick 下的所有 VHD 文件并选择性挂载

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
SOURCE_DIR="/media/nick"
MOUNT_BASE="/mnt/vhd"
MOUNT_LOG="/tmp/vhd_mounts.log"
UMOUNT_SCRIPT="/tmp/umount-vhd.sh"

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 检查必要的工具
if ! command -v qemu-nbd &> /dev/null; then
    echo -e "${RED}错误: qemu-nbd 未安装${NC}"
    echo "请运行: sudo apt install qemu-utils"
    exit 1
fi

# 加载 nbd 模块
echo -e "${BLUE}加载 nbd 内核模块...${NC}"
if ! lsmod | grep -q nbd; then
    modprobe nbd max_part=16
    echo -e "${GREEN}✓ nbd 模块已加载${NC}"
else
    echo -e "${GREEN}✓ nbd 模块已存在${NC}"
fi

# 创建挂载基础目录
mkdir -p "$MOUNT_BASE"

# 初始化日志文件
> "$MOUNT_LOG"

# 查找所有 VHD 文件
echo -e "\n${BLUE}正在搜索 VHD 文件...${NC}"
mapfile -t vhd_files < <(find "$SOURCE_DIR" -type f -iname "*.vhd" 2>/dev/null | sort)

if [ ${#vhd_files[@]} -eq 0 ]; then
    echo -e "${RED}未找到任何 VHD 文件${NC}"
    exit 1
fi

echo -e "${GREEN}找到 ${#vhd_files[@]} 个 VHD 文件:${NC}\n"

# 显示 VHD 文件列表
for i in "${!vhd_files[@]}"; do
    file="${vhd_files[$i]}"
    size=$(du -h "$file" | cut -f1)
    echo -e "  ${YELLOW}[$i]${NC} $file ${BLUE}($size)${NC}"
done

# 选择要挂载的文件
echo -e "\n${BLUE}请选择要挂载的 VHD 文件:${NC}"
echo "  输入数字 (如: 0 1 2)"
echo "  输入 'all' 挂载所有文件"
echo "  输入 'q' 退出"
read -p "选择: " selection

if [ "$selection" == "q" ]; then
    echo "已取消"
    exit 0
fi

# 获取可用的 nbd 设备
get_free_nbd() {
    for i in {0..15}; do
        if [ ! -b "/sys/block/nbd$i/pid" ] || [ ! -f "/sys/block/nbd$i/pid" ] || [ -z "$(cat /sys/block/nbd$i/pid 2>/dev/null)" ]; then
            echo "/dev/nbd$i"
            return 0
        fi
    done
    return 1
}

# 挂载单个 VHD 文件
mount_vhd() {
    local vhd_path="$1"
    local vhd_basename=$(basename "$vhd_path" .vhd)
    local vhd_basename=$(basename "$vhd_basename" .VHD)
    local mount_point="$MOUNT_BASE/$vhd_basename"
    
    echo -e "\n${BLUE}正在处理: $vhd_path${NC}"
    
    # 获取空闲的 nbd 设备
    local nbd_dev=$(get_free_nbd)
    if [ -z "$nbd_dev" ]; then
        echo -e "${RED}✗ 错误: 没有可用的 nbd 设备${NC}"
        return 1
    fi
    
    echo -e "  使用设备: ${YELLOW}$nbd_dev${NC}"
    
    # 连接 VHD 到 nbd 设备
    if ! qemu-nbd --connect="$nbd_dev" "$vhd_path" 2>/dev/null; then
        echo -e "${RED}✗ 连接 VHD 失败${NC}"
        return 1
    fi
    
    # 等待设备就绪
    sleep 1
    
    # 检测分区
    if ! fdisk -l "$nbd_dev" &>/dev/null; then
        echo -e "${RED}✗ 无法读取分区表${NC}"
        qemu-nbd --disconnect "$nbd_dev" &>/dev/null
        return 1
    fi
    
    # 获取第一个分区
    local partition="${nbd_dev}p1"
    if [ ! -b "$partition" ]; then
        # 尝试不带 p 的分区名
        partition="${nbd_dev}1"
    fi
    
    if [ ! -b "$partition" ]; then
        echo -e "${RED}✗ 未找到分区${NC}"
        qemu-nbd --disconnect "$nbd_dev" &>/dev/null
        return 1
    fi
    
    echo -e "  分区: ${YELLOW}$partition${NC}"
    
    # 创建挂载点
    mkdir -p "$mount_point"
    
    # 挂载分区
    if mount "$partition" "$mount_point" 2>/dev/null; then
        echo -e "${GREEN}✓ 成功挂载到: $mount_point${NC}"
        
        # 记录挂载信息
        echo "$nbd_dev|$partition|$mount_point|$vhd_path" >> "$MOUNT_LOG"
        
        # 显示挂载点内容
        echo -e "  内容预览:"
        ls -lh "$mount_point" | head -5 | sed 's/^/    /'
        
        return 0
    else
        echo -e "${RED}✗ 挂载失败${NC}"
        rmdir "$mount_point" 2>/dev/null
        qemu-nbd --disconnect "$nbd_dev" &>/dev/null
        return 1
    fi
}

# 处理选择
if [ "$selection" == "all" ]; then
    # 挂载所有文件
    for vhd_file in "${vhd_files[@]}"; do
        mount_vhd "$vhd_file"
    done
else
    # 挂载选定的文件
    for idx in $selection; do
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#vhd_files[@]}" ]; then
            mount_vhd "${vhd_files[$idx]}"
        else
            echo -e "${RED}无效的索引: $idx${NC}"
        fi
    done
fi

# 生成卸载脚本
echo -e "\n${BLUE}正在生成卸载脚本...${NC}"
cat > "$UMOUNT_SCRIPT" << 'UMOUNT_EOF'
#!/bin/bash

# VHD 卸载脚本
# 自动生成于挂载时

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MOUNT_LOG="/tmp/vhd_mounts.log"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 请使用 sudo 运行此脚本${NC}"
    exit 1
fi

if [ ! -f "$MOUNT_LOG" ]; then
    echo -e "${RED}错误: 未找到挂载记录${NC}"
    exit 1
fi

echo -e "${BLUE}正在卸载 VHD 文件...${NC}\n"

while IFS='|' read -r nbd_dev partition mount_point vhd_path; do
    echo -e "${BLUE}处理: $(basename "$vhd_path")${NC}"
    
    # 卸载分区
    if mountpoint -q "$mount_point" 2>/dev/null; then
        if umount "$mount_point" 2>/dev/null; then
            echo -e "  ${GREEN}✓ 已卸载: $mount_point${NC}"
            rmdir "$mount_point" 2>/dev/null
        else
            echo -e "  ${RED}✗ 卸载失败: $mount_point${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ 未挂载: $mount_point${NC}"
    fi
    
    # 断开 nbd 设备
    if [ -b "$nbd_dev" ]; then
        if qemu-nbd --disconnect "$nbd_dev" &>/dev/null; then
            echo -e "  ${GREEN}✓ 已断开: $nbd_dev${NC}"
        else
            echo -e "  ${YELLOW}⚠ 断开设备可能失败: $nbd_dev${NC}"
        fi
    fi
    
    echo
done < "$MOUNT_LOG"

# 清理日志文件
rm -f "$MOUNT_LOG"
echo -e "${GREEN}✓ 所有 VHD 已卸载${NC}"

# 卸载 nbd 模块(可选)
read -p "是否卸载 nbd 内核模块? (y/N): " unload
if [[ "$unload" =~ ^[Yy]$ ]]; then
    if rmmod nbd 2>/dev/null; then
        echo -e "${GREEN}✓ nbd 模块已卸载${NC}"
    else
        echo -e "${YELLOW}⚠ 无法卸载 nbd 模块(可能还有其他进程在使用)${NC}"
    fi
fi
UMOUNT_EOF

chmod +x "$UMOUNT_SCRIPT"
echo -e "${GREEN}✓ 卸载脚本已生成: $UMOUNT_SCRIPT${NC}"

# 显示摘要
echo -e "\n${GREEN}=== 挂载摘要 ===${NC}"
if [ -f "$MOUNT_LOG" ] && [ -s "$MOUNT_LOG" ]; then
    echo -e "${BLUE}已挂载的 VHD:${NC}"
    while IFS='|' read -r nbd_dev partition mount_point vhd_path; do
        echo -e "  ${GREEN}✓${NC} $(basename "$vhd_path") → $mount_point"
    done < "$MOUNT_LOG"
    
    echo -e "\n${YELLOW}要卸载所有 VHD,请运行:${NC}"
    echo -e "  ${BLUE}sudo $UMOUNT_SCRIPT${NC}"
else
    echo -e "${YELLOW}没有成功挂载任何 VHD 文件${NC}"
fi

echo -e "\n${GREEN}完成!${NC}"