#!/bin/bash
# Provision rebuilt broker-b-2 (n2): mount data disk, install java11 + rocketmq 4.9.7, configure, start
set +e
echo "=== HOST: $(hostname) ==="

echo "--- 1. mount data disk to /datadisk ---"
# data disk has existing XFS with /datadisk/rocketmq/store data; identify the data disk device
mkdir -p /datadisk
# find the non-OS disk (the one with existing xfs and rocketmq data). OS is the smaller/root device.
DATADEV=""
for d in $(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}'); do
  # skip the disk that hosts the root mount
  ROOTDISK=$(findmnt -no SOURCE / | sed -E 's/p?[0-9]+$//')
  if [ "$d" = "$ROOTDISK" ]; then continue; fi
  # candidate data disk; look for a partition or the disk itself with xfs
  PART="${d}p1"
  [ -b "$PART" ] || PART="$d"
  FS=$(blkid -o value -s TYPE "$PART" 2>/dev/null)
  echo "candidate $d part=$PART fs=$FS"
  if [ "$FS" = "xfs" ]; then DATADEV="$PART"; break; fi
done
echo "DATADEV=$DATADEV"
if [ -n "$DATADEV" ]; then
  mount "$DATADEV" /datadisk 2>&1
  UUID=$(blkid -o value -s UUID "$DATADEV")
  grep -q "$UUID" /etc/fstab || echo "UUID=$UUID /datadisk xfs defaults,nofail 0 2" >> /etc/fstab
fi
df -h /datadisk
echo "--- existing store? ---"
ls -ld /datadisk/rocketmq/store 2>/dev/null
du -sh /datadisk/rocketmq/store 2>/dev/null

echo "--- 2. install java 11 ---"
dnf install -y java-11-openjdk java-11-openjdk-devel wget unzip >/dev/null 2>&1
java -version 2>&1 | head -1

echo "--- 3. download rocketmq 4.9.7 ---"
cd /opt
if [ ! -d /opt/rocketmq-4.9.7 ]; then
  wget -q https://archive.apache.org/dist/rocketmq/4.9.7/rocketmq-all-4.9.7-bin-release.zip -O /tmp/rmq.zip 2>&1
  echo "wget exit=$?"
  unzip -q /tmp/rmq.zip -d /opt 2>&1
  mv /opt/rocketmq-all-4.9.7-bin-release /opt/rocketmq-4.9.7 2>/dev/null
fi
ls -ld /opt/rocketmq-4.9.7
