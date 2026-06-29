#!/bin/bash
# setup-nameserver-direct.sh — RocketMQ 4.9.7 Name Server, DIRECT (no detach,
# no distro-sync, no dnf-redo). Runs synchronously under run-command.
set -uo pipefail
LOG=/var/log/rocketmq-setup-direct.log
exec > >(tee -a "$LOG") 2>&1
echo "=== [$(date)] NS direct setup start on $(hostname) ==="

# Abort any leftover interrupted dnf transaction WITHOUT redoing it.
pkill -x dnf 2>/dev/null || true
sleep 1
rm -f /var/cache/dnf/*.pid 2>/dev/null || true
rpm --rebuilddb 2>/dev/null || true
# Drop any pending transaction journal so dnf won't try to resume distro-sync.
rm -rf /var/lib/dnf/history.* 2>/dev/null || true
grep -q '^ip_resolve=4' /etc/dnf/dnf.conf 2>/dev/null || echo 'ip_resolve=4' >> /etc/dnf/dnf.conf

### data disk should already be mounted; ensure it ###
if ! mountpoint -q /datadisk; then
  echo "WARN: /datadisk not mounted, attempting mount"; mount /datadisk 2>/dev/null || true
fi
mkdir -p /datadisk/rocketmq/store /datadisk/rocketmq/logs

### java + unzip + wget (only what we need) ###
echo "--- installing java/unzip/wget ---"
dnf -y install java-11-openjdk-headless unzip wget
java -version

### RocketMQ 4.9.7 ###
RMQ_VERSION=4.9.7
RMQ_HOME=/opt/rocketmq-${RMQ_VERSION}
cd /opt
if [ ! -d "$RMQ_HOME" ]; then
  echo "--- downloading RocketMQ ${RMQ_VERSION} ---"
  wget -4 -q https://archive.apache.org/dist/rocketmq/${RMQ_VERSION}/rocketmq-all-${RMQ_VERSION}-bin-release.zip -O rocketmq.zip
  unzip -q rocketmq.zip
  mv rocketmq-all-${RMQ_VERSION}-bin-release "$RMQ_HOME"
  rm -f rocketmq.zip
fi

# nameserver heap (16GB RAM) -> 2g
RUNSRV=${RMQ_HOME}/bin/runserver.sh
sed -i 's|-Xms[0-9]*g -Xmx[0-9]*g -Xmn[0-9]*g|-Xms2g -Xmx2g -Xmn1g|g' "$RUNSRV" || true
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

cat > /etc/systemd/system/rocketmq-namesrv.service <<EOS
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
systemctl enable rocketmq-namesrv.service
systemctl restart rocketmq-namesrv.service
sleep 6
echo "=== service status ==="
systemctl is-active rocketmq-namesrv.service
ss -lnt | grep ':9876' && echo "PORT 9876 LISTENING" || echo "port 9876 NOT listening yet"
echo "=== [$(date)] NS direct setup done on $(hostname) ==="
