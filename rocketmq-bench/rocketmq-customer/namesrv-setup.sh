#!/bin/bash
# Runs ON a NameServer node (pushed via az vm run-command).
# - mounts the Premium SSD v2 data disk by UUID (nofail) at /datadisk
# - installs OpenJDK 11.0.25 (Red Hat build)
# - installs RocketMQ 4.9.7 and starts mqnamesrv via systemd
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

### 1. Logs on OS disk (NameServer has no data disk) ###
mkdir -p /opt/rocketmq/logs

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

# NameServer JVM heap (modest; D4s_v6 16GB but NS needs little)
sed -i 's|-Xms[0-9]*g -Xmx[0-9]*g -Xmn[0-9]*g|-Xms2g -Xmx2g -Xmn1g|g' ${RMQ_HOME}/bin/runserver.sh || true
if [ -f ${RMQ_HOME}/conf/logback_namesrv.xml ]; then
  sed -i 's|${user.home}/logs/rocketmqlogs|/opt/rocketmq/logs|g' ${RMQ_HOME}/conf/logback_namesrv.xml
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
