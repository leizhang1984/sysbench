#!/bin/bash
systemctl stop rocketmq-broker 2>/dev/null
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
cd /opt/rocketmq-4.9.7
echo "=== free -m ==="
free -m
echo "=== runbroker heap setting ==="
grep -nE 'Xms|Xmx|Xmn' bin/runbroker.sh | head
echo "=== run mqbroker foreground 8s ==="
timeout 8 sh bin/mqbroker -c conf/broker-dledger.conf 2>&1 | head -40
echo "=== exit done ==="
