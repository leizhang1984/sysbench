#!/bin/bash
# setup-broker-direct.sh — RocketMQ 4.9.7 Broker, DIRECT (sync, no detach,
# no distro-sync). Args: $1=brokerName $2=brokerId $3=brokerRole
#   $4=namesrvAddr(comma-sep) $5=brokerIP1
set -uo pipefail
LOG=/var/log/rocketmq-setup-direct.log
exec > >(tee -a "$LOG") 2>&1
echo "=== [$(date)] BROKER direct setup start on $(hostname) ==="

BROKER_NAME="$1"; BROKER_ID="$2"; BROKER_ROLE="$3"
NAMESRV="$(echo "$4" | tr ',' ';')"; BROKER_IP1="$5"
echo "name=$BROKER_NAME id=$BROKER_ID role=$BROKER_ROLE ip=$BROKER_IP1 ns=$NAMESRV"

# Abort leftover interrupted dnf transaction WITHOUT redoing it.
pkill -x dnf 2>/dev/null || true
sleep 1
rm -f /var/cache/dnf/*.pid 2>/dev/null || true
rpm --rebuilddb 2>/dev/null || true
rm -rf /var/lib/dnf/history.* 2>/dev/null || true
grep -q '^ip_resolve=4' /etc/dnf/dnf.conf 2>/dev/null || echo 'ip_resolve=4' >> /etc/dnf/dnf.conf

### data disk: detect, partition, format xfs, mount by UUID ###
ROOT_SRC=$(findmnt -no SOURCE /)
ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SRC" | head -1)
DISK=""
for dev in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
  [ "$dev" = "$ROOT_DISK" ] && continue
  case "$dev" in sr*) continue;; esac
  MNTS=$(lsblk -n -o MOUNTPOINT "/dev/$dev" | tr -d ' \n')
  if [ -z "$MNTS" ]; then DISK="/dev/$dev"; break; fi
done
if mountpoint -q /datadisk; then
  echo "datadisk already mounted"
else
  if [ -z "$DISK" ]; then echo "ERROR: data disk not found"; lsblk; exit 1; fi
  echo "data disk: $DISK"
  if [ -z "$(lsblk -n -o NAME "$DISK" | tail -n +2)" ]; then
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart primary xfs 0% 100%
    partprobe "$DISK" || true; sleep 3
  fi
  PART=$(lsblk -ln -o NAME,TYPE "$DISK" | awk '$2=="part"{print $1; exit}')
  PART="/dev/${PART}"
  for i in $(seq 1 20); do [ -b "$PART" ] && break; sleep 2; done
  CURFS=$(blkid -s TYPE -o value "$PART" 2>/dev/null || true)
  if [ "$CURFS" != "xfs" ]; then mkfs.xfs -f "$PART"; udevadm settle || true; sleep 2; fi
  UUID=$(blkid -s UUID -o value "$PART")
  [ -n "$UUID" ] || { echo "ERROR: empty UUID after mkfs"; exit 1; }
  mkdir -p /datadisk
  sed -i '\| /datadisk |d' /etc/fstab
  echo "UUID=$UUID /datadisk xfs defaults,nofail 0 2" >> /etc/fstab
  mount /datadisk
fi
df -h /datadisk

### java + RocketMQ 4.9.7 ###
RMQ_VERSION=4.9.7
RMQ_HOME=/opt/rocketmq-${RMQ_VERSION}
echo "--- installing java/unzip/wget ---"
dnf -y install java-11-openjdk-headless unzip wget
java -version
cd /opt
if [ ! -d "$RMQ_HOME" ]; then
  echo "--- downloading RocketMQ ${RMQ_VERSION} ---"
  wget -4 -q https://archive.apache.org/dist/rocketmq/${RMQ_VERSION}/rocketmq-all-${RMQ_VERSION}-bin-release.zip -O rocketmq.zip
  unzip -q rocketmq.zip
  mv rocketmq-all-${RMQ_VERSION}-bin-release "$RMQ_HOME"
  rm -f rocketmq.zip
fi
mkdir -p /datadisk/rocketmq/store/commitlog /datadisk/rocketmq/store/consumequeue /datadisk/rocketmq/logs

### broker config (classic master-slave, SYNC) ###
cat > ${RMQ_HOME}/conf/broker.conf <<EOF
brokerClusterName=RocketMQCluster
brokerName=${BROKER_NAME}
brokerId=${BROKER_ID}
brokerRole=${BROKER_ROLE}
flushDiskType=ASYNC_FLUSH
namesrvAddr=${NAMESRV}
brokerIP1=${BROKER_IP1}
listenPort=10911
storePathRootDir=/datadisk/rocketmq/store
storePathCommitLog=/datadisk/rocketmq/store/commitlog
autoCreateTopicEnable=true
sendMessageThreadPoolNums=16
EOF

RUNBROKER=${RMQ_HOME}/bin/runbroker.sh
sed -i 's|-Xms[0-9]*g -Xmx[0-9]*g -Xmn[0-9]*g|-Xms8g -Xmx8g -Xmn4g|g' "$RUNBROKER" || true
if [ -f ${RMQ_HOME}/conf/logback_broker.xml ]; then
  sed -i 's|${user.home}/logs/rocketmqlogs|/datadisk/rocketmq/logs|g' ${RMQ_HOME}/conf/logback_broker.xml
fi

cat > ${RMQ_HOME}/bin/start-broker.sh <<EOS
#!/bin/bash
export JAVA_HOME=\$(dirname "\$(dirname "\$(readlink -f "\$(command -v java)")")")
export ROCKETMQ_HOME=${RMQ_HOME}
exec "\$ROCKETMQ_HOME/bin/mqbroker" -c "\$ROCKETMQ_HOME/conf/broker.conf"
EOS
chmod +x ${RMQ_HOME}/bin/start-broker.sh

cat > /etc/systemd/system/rocketmq-broker.service <<EOS
[Unit]
Description=Apache RocketMQ Broker ${RMQ_VERSION} (${BROKER_NAME} id=${BROKER_ID} ${BROKER_ROLE})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${RMQ_HOME}/bin/start-broker.sh
Restart=on-failure
RestartSec=10
User=root
LimitNOFILE=655350

[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload
systemctl enable rocketmq-broker.service
systemctl restart rocketmq-broker.service
sleep 8
echo "=== broker status ==="
systemctl is-active rocketmq-broker.service
ss -lnt | grep -E '10911|10909|10912' || echo "broker ports not listening yet"
echo "=== [$(date)] BROKER direct setup done (name=${BROKER_NAME} id=${BROKER_ID} role=${BROKER_ROLE}) ==="
