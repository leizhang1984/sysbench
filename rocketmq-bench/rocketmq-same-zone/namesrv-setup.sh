#!/bin/bash
# Runs ON a NameServer node (pushed via az vm run-command).
# - mounts the Premium SSD v2 data disk by UUID (nofail) at /data
# - installs OpenJDK 11.0.25 (Red Hat build)
# - installs RocketMQ 4.9.7 and starts mqnamesrv via systemd
#
# Self-detach so the work survives a run-command client timeout/SIGTERM.
if [ "${RMQ_DETACHED:-}" != "1" ]; then
  cp -f "$0" /opt/namesrv-setup-run.sh 2>/dev/null || true
  RMQ_DETACHED=1 setsid bash /opt/namesrv-setup-run.sh >/var/log/rocketmq-detach.log 2>&1 < /dev/null &
  echo "namesrv setup launched detached; follow /var/log/rocketmq-setup.log"
  exit 0
fi

set -euo pipefail
LOG=/var/log/rocketmq-setup.log
exec >>"$LOG" 2>&1
echo "=== [$(date)] NAMESERVER setup start ==="

RMQ_VERSION=4.9.7
JDK_VER=11.0.25.0.9
RMQ_HOME=/opt/rocketmq-${RMQ_VERSION}

cloud-init status --wait >/dev/null 2>&1 || true
for i in $(seq 1 60); do pgrep -x dnf >/dev/null 2>&1 || break; echo "waiting dnf lock ($i)"; sleep 5; done

### 1. Data disk -> /datadisk (UUID + nofail) ###
DISK="/dev/disk/azure/scsi1/lun0"
if mountpoint -q /datadisk; then
  echo "/datadisk already mounted; skipping disk setup"
else
  # migrate from legacy /data mount if present (keeps existing fs/data)
  if mountpoint -q /data; then
    echo "migrating data disk mount /data -> /datadisk"
    systemctl stop rmq-namesrv 2>/dev/null || true
    DISK=$(findmnt -no SOURCE /data)
    umount /data || true
    sed -i '\| /data |d' /etc/fstab
  fi
  for i in $(seq 1 30); do [ -e "$DISK" ] && break; sleep 2; done
  if [ ! -e "$DISK" ]; then
    echo "WARN: $DISK not found, scanning for unmounted data disk"
    ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" | head -1)
    DISK=""
    for dev in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
      [ "$dev" = "$ROOT_DISK" ] && continue; case "$dev" in sr*) continue;; esac
      [ -z "$(lsblk -n -o MOUNTPOINT /dev/$dev | tr -d ' \n')" ] && DISK="/dev/$dev" && break
    done
  fi
  [ -n "$DISK" ] && [ -e "$DISK" ] || { echo "ERROR: no data disk found"; exit 1; }
  echo "data disk: $DISK"
  CURFS=$(blkid -s TYPE -o value "$DISK" 2>/dev/null || true)
  [ "$CURFS" = "xfs" ] || { mkfs.xfs -f "$DISK"; udevadm settle || true; sleep 2; }
  UUID=$(blkid -s UUID -o value "$DISK")
  [ -n "$UUID" ] || { echo "ERROR: empty UUID"; exit 1; }
  echo "UUID=$UUID"
  mkdir -p /datadisk
  sed -i '\| /datadisk |d' /etc/fstab
  echo "UUID=$UUID /datadisk xfs defaults,nofail,x-systemd.device-timeout=10 0 2" >> /etc/fstab
  mount /datadisk
fi
mkdir -p /datadisk/rocketmq/logs
df -h /datadisk

### 2. JDK 11.0.25 ###
if ! java -version 2>&1 | grep -q '11\.0\.25'; then
  dnf -y install "java-11-openjdk-headless-1:${JDK_VER}-"*".el9" \
    || dnf -y install "java-11-openjdk-headless-${JDK_VER}-"*".el9" \
    || dnf -y install java-11-openjdk-headless
fi
command -v dnf >/dev/null && { dnf -y install unzip wget 2>/dev/null || true; }
java -version 2>&1 | head -1

### 3. RocketMQ 4.9.7 ###
cd /opt
if [ ! -d "$RMQ_HOME" ]; then
  wget -q https://archive.apache.org/dist/rocketmq/${RMQ_VERSION}/rocketmq-all-${RMQ_VERSION}-bin-release.zip -O rocketmq.zip
  unzip -q rocketmq.zip
  mv rocketmq-all-${RMQ_VERSION}-bin-release "$RMQ_HOME"
  rm -f rocketmq.zip
fi

# NameServer JVM heap (kept modest; node has 16GB but NS needs little)
sed -i 's|-Xms[0-9]*g -Xmx[0-9]*g -Xmn[0-9]*g|-Xms2g -Xmx2g -Xmn1g|g' ${RMQ_HOME}/bin/runserver.sh || true
# redirect namesrv logs to data disk
if [ -f ${RMQ_HOME}/conf/logback_namesrv.xml ]; then
  sed -i 's|${user.home}/logs/rocketmqlogs|/datadisk/rocketmq/logs|g' ${RMQ_HOME}/conf/logback_namesrv.xml
fi

cat > ${RMQ_HOME}/bin/start-namesrv.sh <<EOS
#!/bin/bash
export JAVA_HOME=\$(dirname "\$(dirname "\$(readlink -f "\$(command -v java)")")")
export ROCKETMQ_HOME=${RMQ_HOME}
exec "\$ROCKETMQ_HOME/bin/mqnamesrv"
EOS
chmod +x ${RMQ_HOME}/bin/start-namesrv.sh

cat > /etc/systemd/system/rmq-namesrv.service <<EOS
[Unit]
Description=Apache RocketMQ NameServer ${RMQ_VERSION}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${RMQ_HOME}/bin/start-namesrv.sh
Restart=on-failure
RestartSec=10
User=root
LimitNOFILE=655350

[Install]
WantedBy=multi-user.target
EOS

systemctl daemon-reload
systemctl enable rmq-namesrv.service
systemctl restart rmq-namesrv.service
sleep 6
systemctl is-active rmq-namesrv.service
ss -lnt | grep 9876 || echo "9876 not listening yet"
echo "=== [$(date)] NAMESERVER setup done ==="
