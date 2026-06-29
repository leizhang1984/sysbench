#!/bin/bash
# DLedger broker setup. Args: <dLegerGroup> <dLegerSelfId>
# dLegerPeers is derived from the group (IPs are fixed) to avoid passing
# semicolons through run-command (shell treats ';' as a command separator).

# Self-detach: re-exec under setsid so the work survives even if the
# run-command client disconnects/times out (which sends SIGTERM and would
# otherwise interrupt the dnf transaction).
if [ "${RMQ_DETACHED:-}" != "1" ]; then
  cp -f "$0" /opt/broker-setup-run.sh 2>/dev/null || true
  RMQ_DETACHED=1 setsid bash /opt/broker-setup-run.sh "$1" "$2" >/var/log/rocketmq-detach.log 2>&1 < /dev/null &
  echo "broker setup launched detached (group=$1 self=$2); follow /var/log/rocketmq-setup.log"
  exit 0
fi

set -euo pipefail
LOG=/var/log/rocketmq-setup.log
exec >>"$LOG" 2>&1
echo "=== [$(date)] BROKER setup start ==="

DLEGER_GROUP="$1"
DLEGER_SELF="$2"
BROKER_NAME="$DLEGER_GROUP"
NAMESRV="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"

case "$DLEGER_GROUP" in
  broker-a) DLEGER_PEERS="n0-10.170.0.10:40911;n1-10.170.0.11:40911;n2-10.170.0.12:40911" ;;
  broker-b) DLEGER_PEERS="n0-10.170.0.13:40911;n1-10.170.0.14:40911;n2-10.170.0.15:40911" ;;
  *) echo "ERROR: unknown group $DLEGER_GROUP"; exit 1 ;;
esac
echo "group=$DLEGER_GROUP self=$DLEGER_SELF peers=$DLEGER_PEERS"

# wait for cloud-init / dnf lock to clear
cloud-init status --wait >/dev/null 2>&1 || true
for i in $(seq 1 60); do
  if ! pgrep -x dnf >/dev/null 2>&1; then break; fi
  echo "waiting for dnf lock ($i)..."; sleep 5
done

# recover any interrupted rpm/dnf transaction from a previous killed run
rpm --rebuilddb 2>/dev/null || true
dnf -y history redo last 2>/dev/null || true
dnf -y distro-sync 2>/dev/null || true

# upgrade OS to latest 9.x (-> 9.8)
dnf -y update

### 1. Data disk (NVMe-aware) ###
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
  mkfs.xfs -f "$PART"; udevadm settle || true; sleep 2
fi
UUID=$(blkid -s UUID -o value "$PART")
if [ -z "$UUID" ]; then echo "ERROR: empty UUID after mkfs"; exit 1; fi
echo "data disk UUID=$UUID"
mkdir -p /datadisk
sed -i '\| /datadisk |d' /etc/fstab
echo "UUID=$UUID /datadisk xfs defaults,nofail 0 2" >> /etc/fstab
mountpoint -q /datadisk || mount /datadisk
echo "=== data disk mounted ==="; df -h /datadisk

### 2. RocketMQ 4.9.7 broker (DLedger) ###
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
mkdir -p /datadisk/rocketmq/store/commitlog /datadisk/rocketmq/store/consumequeue /datadisk/rocketmq/logs

# DLedger broker config
cat > ${RMQ_HOME}/conf/broker-dledger.conf <<EOF
brokerClusterName=RocketMQCluster
brokerName=${BROKER_NAME}
listenPort=10911
namesrvAddr=${NAMESRV}
flushDiskType=ASYNC_FLUSH
storePathRootDir=/datadisk/rocketmq/store
storePathCommitLog=/datadisk/rocketmq/store/commitlog
enableDLegerCommitLog=true
dLegerGroup=${DLEGER_GROUP}
dLegerPeers=${DLEGER_PEERS}
dLegerSelfId=${DLEGER_SELF}
sendMessageThreadPoolNums=16
autoCreateTopicEnable=true
EOF

# JVM heap for broker (D4s_v6 = 16GB RAM)
RUNBROKER=${RMQ_HOME}/bin/runbroker.sh
sed -i 's|-Xms[0-9]*g -Xmx[0-9]*g -Xmn[0-9]*g|-Xms8g -Xmx8g -Xmn4g|g' "$RUNBROKER" || true

# redirect broker logs to data disk
if [ -f ${RMQ_HOME}/conf/logback_broker.xml ]; then
  sed -i 's|${user.home}/logs/rocketmqlogs|/datadisk/rocketmq/logs|g' ${RMQ_HOME}/conf/logback_broker.xml
fi

cat > ${RMQ_HOME}/bin/start-broker.sh <<EOS
#!/bin/bash
export JAVA_HOME=\$(dirname "\$(dirname "\$(readlink -f "\$(command -v java)")")")
export ROCKETMQ_HOME=${RMQ_HOME}
exec "\$ROCKETMQ_HOME/bin/mqbroker" -c "\$ROCKETMQ_HOME/conf/broker-dledger.conf"
EOS
chmod +x ${RMQ_HOME}/bin/start-broker.sh

cat > /etc/systemd/system/rocketmq-broker.service <<EOS
[Unit]
Description=Apache RocketMQ Broker (DLedger) ${RMQ_VERSION}
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
ss -lnt | grep -E '10911|40911' || echo "broker ports not listening yet"
echo "=== [$(date)] BROKER setup done (group=${DLEGER_GROUP} self=${DLEGER_SELF}) ==="
