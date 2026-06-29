#!/bin/bash
# RocketMQ client setup: JDK + mqadmin + producer/consumer tools, NAMESRV_ADDR preconfigured.

# Self-detach via systemd-run so the work survives:
#  - run-command client timeouts (SIGTERM to script)
#  - systemd package upgrade (which restarts systemd and kills children of the
#    waagent run-command unit, even those launched via setsid).
if [ "${RMQ_DETACHED:-}" != "1" ]; then
  cp -f "$0" /opt/client-setup-run.sh 2>/dev/null || true
  chmod +x /opt/client-setup-run.sh
  systemctl reset-failed rocketmq-client-setup.service 2>/dev/null || true
  systemd-run --unit=rocketmq-client-setup --description='RocketMQ client setup' \
    --setenv=RMQ_DETACHED=1 \
    /bin/bash /opt/client-setup-run.sh
  echo "client setup launched as systemd unit rocketmq-client-setup; follow /var/log/rocketmq-setup.log"
  exit 0
fi

set -euo pipefail
LOG=/var/log/rocketmq-setup.log
exec >>"$LOG" 2>&1
echo "=== [$(date)] CLIENT setup start ==="

NAMESRV="10.170.0.4:9876;10.170.0.6:9876;10.170.0.5:9876"
RMQ_VER="4.9.7"
RMQ_HOME="/opt/rocketmq-${RMQ_VER}"

# wait for cloud-init / dnf lock to clear
cloud-init status --wait >/dev/null 2>&1 || true
for i in $(seq 1 60); do
  if ! pgrep -x dnf >/dev/null 2>&1; then break; fi
  echo "waiting for dnf lock ($i)..."; sleep 5
done

# recover any interrupted rpm/dnf transaction
rpm --rebuilddb 2>/dev/null || true
dnf -y history redo last 2>/dev/null || true
dnf -y distro-sync 2>/dev/null || true

# upgrade OS to 9.8
dnf -y update

# install JDK 8, wget, unzip
dnf -y install java-1.8.0-openjdk-headless wget unzip

# download and install RocketMQ if not present
if [ ! -d "$RMQ_HOME" ]; then
  cd /opt
  wget -q "https://archive.apache.org/dist/rocketmq/${RMQ_VER}/rocketmq-all-${RMQ_VER}-bin-release.zip" -O rmq.zip
  unzip -q rmq.zip
  mv "rocketmq-all-${RMQ_VER}-bin-release" "$RMQ_HOME"
  rm -f rmq.zip
fi

# system-wide env for all users
cat >/etc/profile.d/rocketmq.sh <<EOF
export ROCKETMQ_HOME=${RMQ_HOME}
export NAMESRV_ADDR="${NAMESRV}"
export JAVA_HOME=\$(dirname \$(dirname \$(readlink -f \$(which java))))
export PATH=\$PATH:\$ROCKETMQ_HOME/bin
EOF
chmod 0644 /etc/profile.d/rocketmq.sh

# convenience symlinks
ln -sf "$RMQ_HOME/bin/mqadmin" /usr/local/bin/mqadmin
ln -sf "$RMQ_HOME/bin/tools.sh" /usr/local/bin/rmq-tools

# shrink tool JVM heap so it runs on this VM (default is 4g)
sed -i 's/-Xms4g -Xmx4g -Xmn2g/-Xms512m -Xmx512m -Xmn256m/' "$RMQ_HOME/bin/tools.sh" || true

# quick sanity check
. /etc/profile.d/rocketmq.sh
echo "--- mqadmin clusterList ---"
mqadmin clusterList -n "$NAMESRV_ADDR" || true

echo "=== [$(date)] CLIENT setup done ==="
