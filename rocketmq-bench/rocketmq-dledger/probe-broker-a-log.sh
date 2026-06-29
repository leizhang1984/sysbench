#!/bin/bash
echo "=== journal (last 30) ==="
journalctl -u rocketmq-broker.service --no-pager -n 30 2>/dev/null
echo "=== broker.log tail ==="
for p in /datadisk/rocketmq/logs/broker.log /root/logs/rocketmqlogs/broker.log /opt/rocketmq-4.9.7/logs/broker.log; do
  [ -f "$p" ] && echo "----- $p -----" && tail -n 25 "$p"
done
echo "=== broker_default.log / namesrv? ==="
ls -la /root/logs/rocketmqlogs/ 2>/dev/null | head
echo "=== datadisk mount ==="
findmnt /datadisk || echo "/datadisk NOT mounted"
df -h /datadisk 2>/dev/null
echo "=== conf ==="
cat /opt/rocketmq-4.9.7/conf/broker-dledger.conf
