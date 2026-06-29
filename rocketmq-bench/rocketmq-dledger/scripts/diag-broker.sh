#!/bin/bash
echo "=== systemctl status ==="
systemctl status rocketmq-broker --no-pager -l 2>&1 | head -20
echo "=== journal (last 15) ==="
journalctl -u rocketmq-broker --no-pager -n 15 2>&1
echo "=== broker.log tail ==="
ls -t /opt/rocketmq-4.9.7/logs/rocketmqlogs/broker.log /root/logs/rocketmqlogs/broker.log 2>/dev/null
tail -n 25 /root/logs/rocketmqlogs/broker.log 2>/dev/null
echo "=== broker_default / dledger log ==="
tail -n 25 /root/logs/rocketmqlogs/broker_default.log 2>/dev/null
echo "=== disk ==="
df -h /datadisk 2>/dev/null
