#!/bin/bash
# Force an NVMe controller rescan, then grow the /datadisk XFS filesystem.
set -e
MP=/datadisk
SRC=$(findmnt -n -o SOURCE --target "$MP")   # e.g. /dev/nvme0n2
echo "source: $SRC"

# Derive controller (nvme0) from namespace device (nvme0n2)
NS=$(basename "$SRC")
CTRL=$(echo "$NS" | sed -E 's/n[0-9]+$//')   # nvme0n2 -> nvme0
echo "controller: $CTRL"

echo "=== before ==="
lsblk "$SRC"

# Rescan via nvme-cli if present, else via sysfs
if command -v nvme >/dev/null 2>&1; then
  nvme ns-rescan /dev/"$CTRL" && echo "nvme ns-rescan done" || echo "nvme ns-rescan failed"
fi
echo 1 > /sys/class/nvme/"$CTRL"/rescan_controller 2>/dev/null && echo "sysfs rescan done" || echo "sysfs rescan n/a"

sleep 2
echo "=== after rescan ==="
lsblk "$SRC"

echo "=== growing xfs ==="
xfs_growfs "$MP"

echo "=== df ==="
df -h "$MP"
