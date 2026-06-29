#!/usr/bin/env python3
"""SSH into broker-c-1 and run the RocketMQ slave recovery script as root.
Password is read from env var C1_PW (never hard-coded)."""
import os
import sys
import paramiko

HOST = "20.52.156.139"
USER = "azureadmin"
PW = os.environ.get("C1_PW")
if not PW:
    print("ERROR: set C1_PW env var", file=sys.stderr)
    sys.exit(2)

REMOTE_SCRIPT = r"""
set -uo pipefail
LOG=/var/log/rocketmq-setup-direct.log
exec > >(tee -a "$LOG") 2>&1
echo "=== [$(date)] BROKER-C-1 recover start on $(hostname) ==="

BROKER_NAME="broker-c"; BROKER_ID="1"; BROKER_ROLE="SLAVE"
NAMESRV="10.162.0.4:9876;10.162.0.5:9876;10.162.0.6:9876"; BROKER_IP1="10.162.0.12"

pkill -x dnf 2>/dev/null || true; sleep 1
rm -f /var/cache/dnf/*.pid 2>/dev/null || true
rpm --rebuilddb 2>/dev/null || true
rm -rf /var/lib/dnf/history.* 2>/dev/null || true
grep -q '^ip_resolve=4' /etc/dnf/dnf.conf 2>/dev/null || echo 'ip_resolve=4' >> /etc/dnf/dnf.conf

ROOT_SRC=$(findmnt -no SOURCE /); ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SRC" | head -1)
DISK=""
for dev in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
  [ "$dev" = "$ROOT_DISK" ] && continue
  case "$dev" in sr*) continue;; esac
  MNTS=$(lsblk -n -o MOUNTPOINT "/dev/$dev" | tr -d ' \n')
  [ -z "$MNTS" ] && { DISK="/dev/$dev"; break; }
done
if mountpoint -q /datadisk; then
  echo "datadisk already mounted"
else
  [ -z "$DISK" ] && { echo "ERROR: data disk not found"; lsblk; exit 1; }
  echo "data disk: $DISK"
  if [ -z "$(lsblk -n -o NAME "$DISK" | tail -n +2)" ]; then
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart primary xfs 0% 100%
    partprobe "$DISK" || true; sleep 3
  fi
  PART=$(lsblk -ln -o NAME,TYPE "$DISK" | awk '$2=="part"{print $1; exit}'); PART="/dev/${PART}"
  for i in $(seq 1 20); do [ -b "$PART" ] && break; sleep 2; done
  CURFS=$(blkid -s TYPE -o value "$PART" 2>/dev/null || true)
  [ "$CURFS" != "xfs" ] && { mkfs.xfs -f "$PART"; udevadm settle || true; sleep 2; }
  UUID=$(blkid -s UUID -o value "$PART")
  [ -n "$UUID" ] || { echo "ERROR: empty UUID"; exit 1; }
  mkdir -p /datadisk
  sed -i '\| /datadisk |d' /etc/fstab
  echo "UUID=$UUID /datadisk xfs defaults,nofail 0 2" >> /etc/fstab
  mount /datadisk
fi
df -h /datadisk

RMQ_VERSION=4.9.7; RMQ_HOME=/opt/rocketmq-${RMQ_VERSION}
dnf -y install java-11-openjdk-headless unzip wget
java -version
cd /opt
if [ ! -d "$RMQ_HOME" ]; then
  wget -4 -q https://archive.apache.org/dist/rocketmq/${RMQ_VERSION}/rocketmq-all-${RMQ_VERSION}-bin-release.zip -O rocketmq.zip
  unzip -q rocketmq.zip
  mv rocketmq-all-${RMQ_VERSION}-bin-release "$RMQ_HOME"
  rm -f rocketmq.zip
fi
mkdir -p /datadisk/rocketmq/store/commitlog /datadisk/rocketmq/store/consumequeue /datadisk/rocketmq/logs

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
[ -f ${RMQ_HOME}/conf/logback_broker.xml ] && sed -i 's|${user.home}/logs/rocketmqlogs|/datadisk/rocketmq/logs|g' ${RMQ_HOME}/conf/logback_broker.xml

cat > ${RMQ_HOME}/bin/start-broker.sh <<'EOS'
#!/bin/bash
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
exec "$ROCKETMQ_HOME/bin/mqbroker" -c "$ROCKETMQ_HOME/conf/broker.conf"
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
echo "=== broker status ==="; systemctl is-active rocketmq-broker.service
echo "=== fstab datadisk ==="; grep datadisk /etc/fstab
echo "=== mount ==="; findmnt -no SOURCE,TARGET,FSTYPE /datadisk
ss -lnt | grep -E '10911|10909|10912' || echo "broker ports not listening yet"
echo "=== [$(date)] recover done (broker-c id=1 SLAVE) ==="
"""


def main():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"connecting {USER}@{HOST} ...", flush=True)
    client.connect(HOST, username=USER, password=PW, timeout=30, look_for_keys=False, allow_agent=False)
    print("connected. running recovery as root (sudo -S) ...", flush=True)

    # Pipe the script to a root shell via sudo. -S reads sudo password from stdin.
    cmd = "sudo -S -p '' bash -s"
    stdin, stdout, stderr = client.exec_command(cmd, get_pty=True, timeout=1800)
    stdin.write(PW + "\n")          # sudo password
    stdin.flush()
    stdin.write(REMOTE_SCRIPT)
    stdin.channel.shutdown_write()

    for line in iter(stdout.readline, ""):
        sys.stdout.write(line)
        sys.stdout.flush()
    rc = stdout.channel.recv_exit_status()
    err = stderr.read().decode(errors="replace")
    if err.strip():
        print("---- stderr ----")
        print(err)
    print(f"---- exit code: {rc} ----")
    client.close()
    sys.exit(rc)


if __name__ == "__main__":
    main()
