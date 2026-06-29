#!/bin/bash
# Deploy Apache RocketMQ 4.9.7 in DLedger mode on a broker-c node.
# Mirrors baseline v6rocketmqbroker-a-0 layout.
# Usage (via run-command): pass dLegerSelfId as $1 (n0|n1|n2)
set -euo pipefail

SELF_ID="${1:?need dLegerSelfId n0|n1|n2}"

RMQ_VER="4.9.7"
RMQ_HOME="/opt/rocketmq-${RMQ_VER}"
DATA_MNT="/datadisk"
STORE_ROOT="${DATA_MNT}/rocketmq/store"
NAMESRV="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
DLEDGER_PEERS="n0-10.170.0.16:40911;n1-10.170.0.17:40911;n2-10.170.0.18:40911"
DL_URL="https://archive.apache.org/dist/rocketmq/${RMQ_VER}/rocketmq-all-${RMQ_VER}-bin-release.zip"

echo "===== [1/8] Install packages (java-11-openjdk, unzip, curl) ====="
dnf install -y java-11-openjdk unzip curl >/dev/null 2>&1 || dnf install -y java-11-openjdk unzip curl

echo "===== [2/8] Prepare & mount data disk at ${DATA_MNT} (UUID mount only) ====="
if ! mountpoint -q "${DATA_MNT}"; then
  # pick the 100G data disk (non-OS). Use raw output to avoid tree-drawing chars.
  DEV=$(lsblk -drno NAME,SIZE,TYPE | awk '$3=="disk" && $2=="100G"{print $1; exit}')
  if [ -z "${DEV}" ]; then echo "ERROR: data disk not found"; lsblk; exit 1; fi
  DEVPATH="/dev/${DEV}"
  echo "Data disk: ${DEVPATH}"
  # Determine partition name: nvme disks use 'p1' suffix, others use '1'.
  case "${DEV}" in
    nvme*) PARTPATH="${DEVPATH}p1" ;;
    *)     PARTPATH="${DEVPATH}1" ;;
  esac
  if [ ! -b "${PARTPATH}" ]; then
    parted -s "${DEVPATH}" mklabel gpt
    parted -s "${DEVPATH}" mkpart primary xfs 0% 100%
    udevadm settle || true
    partprobe "${DEVPATH}" || true
    sleep 3
  fi
  echo "Partition: ${PARTPATH}"
  # Force a clean xfs filesystem unless a VALID xfs already exists (avoids stale signatures).
  FSTYPE=$(blkid -s TYPE -o value "${PARTPATH}" 2>/dev/null || true)
  if [ "${FSTYPE}" != "xfs" ]; then
    wipefs -a "${PARTPATH}" || true
    mkfs.xfs -f "${PARTPATH}"
  fi
  udevadm settle || true
  sleep 2
  mkdir -p "${DATA_MNT}"
  # UUID-based mount ONLY (never device path).
  UUID=$(blkid -s UUID -o value "${PARTPATH}")
  if [ -z "${UUID}" ]; then echo "ERROR: could not read UUID for ${PARTPATH}"; exit 1; fi
  echo "Data disk UUID: ${UUID}"
  # Persist in fstab using UUID.
  sed -i "\#[[:space:]]${DATA_MNT}[[:space:]]#d" /etc/fstab
  echo "UUID=${UUID} ${DATA_MNT} xfs defaults,nofail 0 0" >>/etc/fstab
  # Mount strictly via UUID.
  mount -U "${UUID}" "${DATA_MNT}"
fi
findmnt "${DATA_MNT}"
mkdir -p "${STORE_ROOT}/commitlog" "${DATA_MNT}/rocketmq/logs"
df -h "${DATA_MNT}"

echo "===== [3/8] Download & install RocketMQ ${RMQ_VER} ====="
if [ ! -x "${RMQ_HOME}/bin/mqbroker" ]; then
  cd /tmp
  curl -fsSL -o rmq.zip "${DL_URL}"
  rm -rf /tmp/rmq-extract
  mkdir -p /tmp/rmq-extract
  unzip -q -o rmq.zip -d /tmp/rmq-extract
  # The release zip extracts to rocketmq-all-<ver>-bin-release (or similar); detect it.
  SRC=$(find /tmp/rmq-extract -maxdepth 1 -mindepth 1 -type d | head -n1)
  if [ -z "${SRC}" ]; then echo "ERROR: extracted dir not found"; ls -la /tmp/rmq-extract; exit 1; fi
  echo "Extracted: ${SRC}"
  rm -rf "${RMQ_HOME}"
  mv "${SRC}" "${RMQ_HOME}"
  chmod +x "${RMQ_HOME}"/bin/*.sh "${RMQ_HOME}"/bin/mqbroker "${RMQ_HOME}"/bin/mqnamesrv 2>/dev/null || true
  rm -rf /tmp/rmq.zip /tmp/rmq-extract
fi
"${RMQ_HOME}/bin/mqbroker" -h >/dev/null 2>&1 || true

echo "===== [4/8] Write broker-dledger.conf (selfId=${SELF_ID}) ====="
cat > "${RMQ_HOME}/conf/broker-dledger.conf" <<EOF
brokerClusterName=RocketMQCluster
brokerName=broker-c
listenPort=10911
namesrvAddr=${NAMESRV}
flushDiskType=ASYNC_FLUSH
storePathRootDir=${STORE_ROOT}
storePathCommitLog=${STORE_ROOT}/commitlog
enableDLegerCommitLog=true
dLegerGroup=broker-c
dLegerPeers=${DLEDGER_PEERS}
dLegerSelfId=${SELF_ID}
sendMessageThreadPoolNums=16
autoCreateTopicEnable=true
preferredLeaderId=n1
EOF
cat "${RMQ_HOME}/conf/broker-dledger.conf"

echo "===== [5/8] Write start-broker.sh ====="
cat > "${RMQ_HOME}/bin/start-broker.sh" <<EOF
#!/bin/bash
export JAVA_HOME=\$(dirname "\$(dirname "\$(readlink -f "\$(command -v java)")")")
export ROCKETMQ_HOME=${RMQ_HOME}
exec "\$ROCKETMQ_HOME/bin/mqbroker" -c "\$ROCKETMQ_HOME/conf/broker-dledger.conf"
EOF
chmod +x "${RMQ_HOME}/bin/start-broker.sh"
# Restore SELinux context so systemd can exec files under /opt (avoids 203/EXEC).
restorecon -Rv "${RMQ_HOME}/bin" >/dev/null 2>&1 || true
cat "${RMQ_HOME}/bin/start-broker.sh"

echo "===== [6/8] Write systemd unit ====="
cat > /etc/systemd/system/rocketmq-broker.service <<EOF
[Unit]
Description=Apache RocketMQ Broker (DLedger) ${RMQ_VER}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash ${RMQ_HOME}/bin/start-broker.sh
Restart=on-failure
RestartSec=10
User=root
LimitNOFILE=655350

[Install]
WantedBy=multi-user.target
EOF

echo "===== [7/8] Enable & start service ====="
systemctl daemon-reload
systemctl enable rocketmq-broker.service
systemctl restart rocketmq-broker.service
sleep 20

echo "===== [8/8] Status ====="
systemctl --no-pager -l status rocketmq-broker.service | head -n 14
echo "--- java proc ---"
ps -ef | grep -E 'BrokerStartup|mqbroker' | grep -v grep | head
echo "--- listen ports ---"
ss -lntp 2>/dev/null | grep -E '10911|40911|10909|10912' || echo "(ports not up yet)"
echo "--- broker log tail ---"
tail -n 15 /datadisk/rocketmq/logs/broker.log 2>/dev/null
tail -n 15 ${RMQ_HOME}/logs/broker.log 2>/dev/null
tail -n 15 /root/logs/rocketmqlogs/broker.log 2>/dev/null
echo "DONE selfId=${SELF_ID}"
