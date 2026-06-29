#!/usr/bin/env bash
# =============================================================================
# TiDB 节点初始化脚本 (数据盘挂载 + OS 调优)
# 适用: 12 台集群节点 (dv5tidb/tikv 01-03, dv6tidb/tikv 01-03)
# 兼容: CentOS 7.9 与 Rocky 9.6
# 执行: 在每台集群节点上以 root 运行  ->  sudo bash 01-init-node.sh
# =============================================================================
set -euo pipefail

MOUNT_POINT="/tidb"

echo "==================== [1/6] 识别数据盘 ===================="
# 选取未挂载、且非系统盘的数据盘 (Premium SSD v2, 200GB)。
# Azure Linux 上数据盘通常是 /dev/sdc (LUN 0)；为稳妥用排除法识别。
ROOT_DISK=$(lsblk -ndo PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | head -1 || true)
DATA_DEV=""
for dev in $(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}'); do
  # 跳过系统盘
  if [[ "$dev" == "${ROOT_DISK:-__none__}" ]]; then continue; fi
  # 跳过 Azure 临时盘 (通常挂在 /mnt, 文件系统 LABEL=temp 或包含 swap)
  if lsblk -no MOUNTPOINT "/dev/$dev" | grep -q "/mnt"; then continue; fi
  # 跳过已有任何挂载点的盘
  if lsblk -no MOUNTPOINT "/dev/$dev" | grep -q "/"; then continue; fi
  # 选第一块约 200GB 的裸盘
  SIZE_GB=$(( $(lsblk -bdno SIZE "/dev/$dev") / 1024 / 1024 / 1024 ))
  if (( SIZE_GB >= 180 && SIZE_GB <= 220 )); then
    DATA_DEV="/dev/$dev"
    break
  fi
done

if [[ -z "$DATA_DEV" ]]; then
  echo "ERROR: 未找到符合条件的 200GB 数据盘, 请用 lsblk 手动确认后修改脚本" >&2
  lsblk
  exit 1
fi
echo "选定数据盘: $DATA_DEV"

echo "==================== [2/6] 格式化为 xfs ===================="
if blkid "$DATA_DEV" >/dev/null 2>&1; then
  echo "WARN: $DATA_DEV 已有文件系统, 跳过格式化 (避免覆盖数据)。如需重建请手动处理。"
else
  mkfs.xfs -f "$DATA_DEV"
fi

echo "==================== [3/6] 挂载到 $MOUNT_POINT (UUID + nofail) ===================="
mkdir -p "$MOUNT_POINT"
DISK_UUID=$(blkid -s UUID -o value "$DATA_DEV")
echo "数据盘 UUID: $DISK_UUID"

# 幂等写入 fstab: 先移除旧的同挂载点记录, 再追加
sed -i "\#[[:space:]]$MOUNT_POINT[[:space:]]#d" /etc/fstab
echo "UUID=$DISK_UUID  $MOUNT_POINT  xfs  defaults,nofail,noatime  0 0" >> /etc/fstab

mount -a
echo "挂载结果:"
df -h "$MOUNT_POINT"

# TiDB 部署/数据/日志目录 (全部落在 Premium SSD v2 上)
mkdir -p "$MOUNT_POINT/deploy" "$MOUNT_POINT/data" "$MOUNT_POINT/log"

echo "==================== [4/6] 系统限制 (ulimit) ===================="
cat > /etc/security/limits.d/99-tidb.conf <<'EOF'
*    soft    nofile    1000000
*    hard    nofile    1000000
*    soft    stack     32768
*    hard    stack     32768
*    soft    nproc     unlimited
*    hard    nproc     unlimited
EOF

echo "==================== [5/6] 内核参数调优 (sysctl) ===================="
cat > /etc/sysctl.d/99-tidb.conf <<'EOF'
# --- TiDB 官方推荐 ---
fs.file-max = 1000000
net.core.somaxconn = 32768
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 0
net.core.netdev_max_backlog = 26214400
net.ipv4.tcp_max_syn_backlog = 16384
vm.swappiness = 0
vm.overcommit_memory = 1
vm.min_free_kbytes = 1048576
EOF
sysctl --system >/dev/null

# 关闭 swap (TiKV 要求)
swapoff -a || true
sed -i '/[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab || true

echo "==================== [6/6] 关闭透明大页 (THP) ===================="
# 运行时立即关闭
echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
echo never > /sys/kernel/mm/transparent_hugepage/defrag   2>/dev/null || true

# 持久化: 用 systemd 服务保证重启后仍关闭 (兼容 CentOS7 与 Rocky9)
cat > /etc/systemd/system/disable-thp.service <<'EOF'
[Unit]
Description=Disable Transparent Huge Pages (THP) for TiDB
After=sysinit.target local-fs.target
Before=tidb.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled; echo never > /sys/kernel/mm/transparent_hugepage/defrag'

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable disable-thp.service >/dev/null 2>&1 || true

# CPU governor 设为 performance (尽力而为, 部分虚拟化环境无此接口)
if command -v cpupower >/dev/null 2>&1; then
  cpupower frequency-set -g performance >/dev/null 2>&1 || true
fi

echo ""
echo "==================== 完成 ===================="
echo "数据盘:    $DATA_DEV  ->  $MOUNT_POINT  (xfs, UUID=$DISK_UUID, nofail,noatime)"
echo "目录:      $MOUNT_POINT/deploy  (TiUP deploy_dir)"
echo "           $MOUNT_POINT/data    (TiUP data_dir)"
echo "           $MOUNT_POINT/log     (TiDB/PD/TiKV 日志)"
echo "THP:       $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
echo "请重启或确认 limits 生效 (重新登录 shell)。"
