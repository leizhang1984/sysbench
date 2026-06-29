#!/bin/bash
echo "=== install layout on healthy broker-b node ==="
echo "--- rocketmq dir ---"
ls -ld /opt/rocketmq-4.9.7 2>/dev/null
echo "--- broker.conf path & content ---"
find /opt/rocketmq-4.9.7/conf -name "broker*.conf" 2>/dev/null
CONF=$(find /opt/rocketmq-4.9.7/conf -name "broker*.conf" 2>/dev/null | head -1)
echo "CONF=$CONF"
echo "----- broker.conf -----"
cat "$CONF" 2>/dev/null
echo "----- systemd unit -----"
systemctl cat rocketmq-broker.service 2>/dev/null | head -40
echo "----- store path mount -----"
df -h /datadisk 2>/dev/null
echo "----- store dir on datadisk? -----"
ls -ld /datadisk/store 2>/dev/null
echo "----- java -----"
java -version 2>&1 | head -1
which java
