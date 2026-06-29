#!/bin/bash
# Grow /datadisk partition + filesystem after Azure disk resize to 500GB
set +e
HOST=$(hostname)
echo "=== HOST: $HOST ==="

DEV=/dev/nvme0n2
PART=/dev/nvme0n2p1
MNT=/datadisk

echo "--- before ---"
df -h "$MNT"
lsblk "$DEV"

# Refresh kernel view of the resized disk
echo 1 > /sys/block/nvme0n2/device/rescan 2>/dev/null || true
partprobe "$DEV" 2>/dev/null || true

# Grow partition 1 to fill the disk
which growpart >/dev/null 2>&1 || (command -v dnf >/dev/null 2>&1 && dnf install -y cloud-utils-growpart >/dev/null 2>&1) || (command -v yum >/dev/null 2>&1 && yum install -y cloud-utils-growpart >/dev/null 2>&1)
growpart "$DEV" 1
partprobe "$DEV" 2>/dev/null || true

# Detect filesystem type and grow it
FSTYPE=$(blkid -o value -s TYPE "$PART")
echo "--- fstype: $FSTYPE ---"
case "$FSTYPE" in
  ext4|ext3|ext2)
    resize2fs "$PART"
    ;;
  xfs)
    xfs_growfs "$MNT"
    ;;
  *)
    echo "Unknown fstype: $FSTYPE, trying resize2fs"
    resize2fs "$PART"
    ;;
esac

echo "--- after ---"
df -h "$MNT"
