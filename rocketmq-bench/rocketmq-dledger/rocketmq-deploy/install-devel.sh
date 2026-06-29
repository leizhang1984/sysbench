#!/bin/bash
# Install JDK devel (javac) on the client via a systemd transient unit so it
# survives run-command client timeouts and systemd self-upgrade restarts.
if [ "${RMQ_DETACHED:-}" != "1" ]; then
  cp -f "$0" /opt/install-devel-run.sh 2>/dev/null || true
  chmod +x /opt/install-devel-run.sh
  systemctl reset-failed rocketmq-devel-install.service 2>/dev/null || true
  systemd-run --unit=rocketmq-devel-install --description='install jdk devel' \
    --setenv=RMQ_DETACHED=1 /bin/bash /opt/install-devel-run.sh
  echo "devel install launched as systemd unit; follow /var/log/rocketmq-devel.log"
  exit 0
fi
set -euo pipefail
exec >>/var/log/rocketmq-devel.log 2>&1
echo "=== [$(date)] devel install start ==="
for i in $(seq 1 60); do pgrep -x dnf >/dev/null 2>&1 || break; sleep 5; done
dnf -y install java-1.8.0-openjdk-devel
echo "javac: $(javac -version 2>&1)"
echo "=== [$(date)] devel install done ==="
