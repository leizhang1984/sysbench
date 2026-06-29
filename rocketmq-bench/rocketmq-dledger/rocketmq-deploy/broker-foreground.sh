#!/bin/bash
# Stop the auto-restart loop, then run broker in foreground briefly to capture the real error.
systemctl stop rocketmq-broker 2>/dev/null
sleep 2
source /etc/profile.d/rocketmq.sh 2>/dev/null
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
# Find the config the unit uses
echo "=== start-broker.sh head ==="
sed -n '1,40p' /opt/rocketmq-4.9.7/bin/start-broker.sh
echo "=== run foreground 15s ==="
timeout 15 /opt/rocketmq-4.9.7/bin/start-broker.sh 2>&1 | tail -n 40
echo "EXIT=${PIPESTATUS[0]}"
