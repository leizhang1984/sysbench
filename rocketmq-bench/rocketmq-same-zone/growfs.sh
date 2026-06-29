#!/bin/bash
# Grow the /datadisk filesystem after an Azure data-disk resize.
set -e

MP=/datadisk
echo "=== before ==="
df -h "$MP" || true

# Resolve the block device backing /datadisk
SRC=$(findmnt -n -o SOURCE --target "$MP")
echo "source device: $SRC"

# Rescan so the kernel sees the new size
BASEDEV=$(lsblk -no PKNAME "$SRC" 2>/dev/null || true)
if [ -z "$BASEDEV" ]; then
  # whole device (no partition), strip /dev/
  BASEDEV=$(basename "$SRC")
fi
echo "rescanning $BASEDEV"
echo 1 > /sys/block/"$BASEDEV"/device/rescan 2>/dev/null || \
  echo 1 > /sys/class/block/"$BASEDEV"/device/rescan 2>/dev/null || \
  echo "rescan node not found (nvme auto-detects new size)"

# If the source is a partition, grow it first
PKNAME=$(lsblk -no PKNAME "$SRC" 2>/dev/null || true)
if [ -n "$PKNAME" ]; then
  PARTNUM=$(cat /sys/class/block/$(basename "$SRC")/partition 2>/dev/null || true)
  if [ -n "$PARTNUM" ]; then
    echo "growing partition $PARTNUM on /dev/$PKNAME"
    growpart /dev/"$PKNAME" "$PARTNUM" || echo "growpart: nothing to do"
  fi
fi

# Grow the XFS filesystem online
echo "=== growing xfs ==="
xfs_growfs "$MP"

echo "=== after ==="
df -h "$MP"
