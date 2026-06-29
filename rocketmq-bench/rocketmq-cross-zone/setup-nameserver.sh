#!/bin/bash
# =====================================================================
# setup-nameserver.sh  —  RocketMQ 4.9.7 Name Server (classic, no DLedger)
# Invoked via: az vm run-command invoke ... --scripts @setup-nameserver.sh
# No arguments required.
# =====================================================================

# Self-detach under setsid so the work survives a run-command disconnect /
# SIGTERM (which would otherwise interrupt the dnf transaction).
if [ "${RMQ_DETACHED:-}" != "1" ]; then
  cp -f "$0" /opt/ns-setup-run.sh 2>/dev/null || true
  RMQ_DETACHED=1 setsid bash /opt/ns-setup-run.sh >/var/log/rocketmq-detach.log 2>&1 < /dev/null &
  echo "nameserver setup launched detached; follow /var/log/rocketmq-setup.log"
  exit 0
fi

set -euo pipefail
LOG=/var/log/rocketmq-setup.log
exec >>"$LOG" 2>&1
echo "=== [$(date)] NAMESERVER setup start ==="

# wait for cloud-init / dnf lock to clear
cloud-init status --wait >/dev/null 2>&1 || true
for i in $(seq 1 60); do
  if ! pgrep -x dnf >/dev/null 2>&1; then break; fi
  echo "waiting for dnf lock ($i)..."; sleep 5
done

# recover any interrupted rpm/dnf transaction
rpm --rebuilddb 2>/dev/null || true
# Force IPv4: mirrors resolve to IPv6 first but these VMs have IPv4-only egress.
grep -q '^ip_resolve=4' /etc/dnf/dnf.conf 2>/dev/null || echo 'ip_resolve=4' >> /etc/dnf/dnf.conf
# NOTE: do NOT run 'dnf distro-sync' here — it upgrades the whole OS (kernel,
# systemd, glibc, ~500 pkgs), is slow and can get SIGTERM'd mid-transaction,
# leaving java uninstalled. We only need a few packages (installed below).

### 1. Data disk: detect, partition, format xfs, mount by UUID ###########
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
CURFS=$(blkid -s TYPE -o value "$PART" 2>/dev/null || true)
if [ "$CURFS" != "xfs" ]; then mkfs.xfs -f "$PART"; udevadm settle || true; sleep 2; fi
UUID=$(blkid -s UUID -o value "$PART")
[ -n "$UUID" ] || { echo "ERROR: empty UUID after mkfs"; exit 1; }
echo "data disk UUID=$UUID"
mkdir -p /datadisk
sed -i '\| /datadisk |d' /etc/fstab
echo "UUID=$UUID /datadisk xfs defaults,nofail 0 2" >> /etc/fstab
mountpoint -q /datadisk || mount /datadisk
df -h /datadisk

### 2. Java 11 + RocketMQ 4.9.7 #########################################
RMQ_VERSION=4.9.7
RMQ_HOME=/opt/rocketmq-${RMQ_VERSION}
command -v java  >/dev/null 2>&1 || dnf -y install java-11-openjdk-headless
command -v unzip >/dev/null 2>&1 || dnf -y install unzip
command -v wget  >/dev/null 2>&1 || dnf -y install wget
cd /opt
if [ ! -d "$RMQ_HOME" ]; then
  wget -4 -q https://archive.apache.org/dist/rocketmq/${RMQ_VERSION}/rocketmq-all-${RMQ_VERSION}-bin-release.zip -O rocketmq.zip
  unzip -q rocketmq.zip
  mv rocketmq-all-${RMQ_VERSION}-bin-release "$RMQ_HOME"
  rm -f rocketmq.zip
fi
mkdir -p /datadisk/rocketmq/namesrv /datadisk/rocketmq/logs

# Name server heap (D4s_v6 = 16GB RAM) -> 2g
RUNSERVER=${RMQ_HOME}/bin/runserver.sh
sed -i 's|-Xms[0-9]*g -Xmx[0-9]*g -Xmn[0-9]*g|-Xms2g -Xmx2g -Xmn1g|g' "$RUNSERVER" || true

# redirect namesrv logs to the data disk
if [ -f ${RMQ_HOME}/conf/logback_namesrv.xml ]; then
  sed -i 's|${user.home}/logs/rocketmqlogs|/datadisk/rocketmq/logs|g' ${RMQ_HOME}/conf/logback_namesrv.xml
fi

cat > ${RMQ_HOME}/bin/start-namesrv.sh <<EOS
#!/bin/bash
export JAVA_HOME=\$(dirname "\$(dirname "\$(readlink -f "\$(command -v java)")")")
export ROCKETMQ_HOME=${RMQ_HOME}
export ROCKETMQ_HOME_NAMESRV=/datadisk/rocketmq/namesrv
exec "\$ROCKETMQ_HOME/bin/mqnamesrv"
EOS
chmod +x ${RMQ_HOME}/bin/start-namesrv.sh

cat > /etc/systemd/system/rocketmq-namesrv.service <<EOS
[Unit]
Description=Apache RocketMQ Name Server ${RMQ_VERSION}
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
systemctl enable rocketmq-namesrv.service
systemctl restart rocketmq-namesrv.service
sleep 6
echo "=== namesrv status ==="
systemctl is-active rocketmq-namesrv.service
ss -lnt | grep 9876 || echo "namesrv port 9876 not listening yet"
echo "=== [$(date)] NAMESERVER setup done ==="
