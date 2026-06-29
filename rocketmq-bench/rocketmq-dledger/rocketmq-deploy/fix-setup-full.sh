#!/bin/bash
set -euo pipefail
LOG=/var/log/rocketmq-setup.log
exec >>"$LOG" 2>&1
echo "=== [$(date)] FULL setup start ==="

# wait for any in-progress cloud-init to finish (avoids dnf lock contention)
cloud-init status --wait >/dev/null 2>&1 || true
# wait for dnf/yum lock to clear
for i in $(seq 1 60); do
  if ! fuser /var/lib/rpm/.rpm.lock /var/cache/dnf/*.lock >/dev/null 2>&1 \
     && ! pgrep -x dnf >/dev/null 2>&1; then break; fi
  echo "waiting for dnf lock ($i)..."; sleep 5
done

# upgrade OS to latest 9.x (-> 9.8)
dnf -y update

### 1. Data disk ###
ROOT_SRC=$(findmnt -no SOURCE /)
ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SRC" | head -1)
DISK=""
for dev in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
  [ "$dev" = "$ROOT_DISK" ] && continue
  case "$dev" in sr*) continue;; esac
  MNTS=$(lsblk -n -o MOUNTPOINT "/dev/$dev" | tr -d ' \n')
  if [ -z "$MNTS" ]; then DISK="/dev/$dev"; break; fi
done
if [ -z "$DISK" ]; then echo "ERROR: data disk not found"; lsblk; exit 1; fi
echo "data disk: $DISK"
if [ -z "$(lsblk -n -o NAME "$DISK" | tail -n +2)" ]; then
  parted -s "$DISK" mklabel gpt
  parted -s "$DISK" mkpart primary xfs 0% 100%
  partprobe "$DISK" || true
  sleep 3
fi
PART=$(lsblk -ln -o NAME,TYPE "$DISK" | awk '$2=="part"{print $1; exit}')
PART="/dev/${PART}"
for i in $(seq 1 20); do [ -b "$PART" ] && break; sleep 2; done
echo "data partition: $PART"
CURFS=$(blkid -s TYPE -o value "$PART" 2>/dev/null || true)
if [ "$CURFS" != "xfs" ]; then
  echo "formatting $PART as xfs (current fs='$CURFS')"
  mkfs.xfs -f "$PART"
  udevadm settle || true
  sleep 2
fi
UUID=$(blkid -s UUID -o value "$PART")
if [ -z "$UUID" ]; then echo "ERROR: empty UUID after mkfs"; exit 1; fi
echo "data disk UUID=$UUID"
mkdir -p /datadisk
sed -i '\| /datadisk |d' /etc/fstab
echo "UUID=$UUID /datadisk xfs defaults,nofail 0 2" >> /etc/fstab
mountpoint -q /datadisk || mount /datadisk
echo "=== data disk mounted ==="
df -h /datadisk

### 2. RocketMQ 4.9.7 NameServer ###
RMQ_VERSION=4.9.7
RMQ_HOME=/opt/rocketmq-${RMQ_VERSION}
command -v java >/dev/null 2>&1 || dnf -y install java-11-openjdk-headless
command -v unzip >/dev/null 2>&1 || dnf -y install unzip
command -v wget >/dev/null 2>&1 || dnf -y install wget
cd /opt
if [ ! -d "$RMQ_HOME" ]; then
  wget -q https://archive.apache.org/dist/rocketmq/${RMQ_VERSION}/rocketmq-all-${RMQ_VERSION}-bin-release.zip -O rocketmq.zip
  unzip -q rocketmq.zip
  mv rocketmq-all-${RMQ_VERSION}-bin-release "$RMQ_HOME"
  rm -f rocketmq.zip
fi
mkdir -p /datadisk/rocketmq/namesrv/logs /datadisk/rocketmq/namesrv/kvstore
cat > ${RMQ_HOME}/bin/start-nameserver.sh <<'EOS'
#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=__RMQ_HOME__
exec "$ROCKETMQ_HOME/bin/mqnamesrv" -c "$ROCKETMQ_HOME/conf/namesrv.properties"
EOS
sed -i "s|__RMQ_HOME__|${RMQ_HOME}|g" ${RMQ_HOME}/bin/start-nameserver.sh
chmod +x ${RMQ_HOME}/bin/start-nameserver.sh
cat > ${RMQ_HOME}/conf/namesrv.properties <<EOS
listenPort=9876
kvConfigPath=/datadisk/rocketmq/namesrv/kvstore/kvConfig.json
EOS
if [ -f ${RMQ_HOME}/conf/logback_namesrv.xml ]; then
  sed -i 's|${user.home}/logs/rocketmqlogs|/datadisk/rocketmq/namesrv/logs|g' ${RMQ_HOME}/conf/logback_namesrv.xml
fi
cat > /etc/systemd/system/rocketmq-nameserver.service <<EOS
[Unit]
Description=Apache RocketMQ NameServer ${RMQ_VERSION}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${RMQ_HOME}/bin/start-nameserver.sh
Restart=on-failure
RestartSec=10
User=root
LimitNOFILE=655350

[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload
systemctl enable rocketmq-nameserver.service
systemctl restart rocketmq-nameserver.service
sleep 6
echo "=== nameserver status ==="
systemctl is-active rocketmq-nameserver.service
ss -lnt | grep 9876 || echo "9876 not listening"
echo "=== [$(date)] FULL setup done ==="
