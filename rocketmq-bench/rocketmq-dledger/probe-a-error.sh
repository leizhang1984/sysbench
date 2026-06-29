#!/bin/bash
echo "=== ERROR/Exception/Caused in broker logs ==="
grep -nE 'ERROR|Exception|Caused by|BindException|Address already|DLedger|raft|cannot|Failed|shutdown' /datadisk/rocketmq/store/../logs/broker.log 2>/dev/null | tail -n 40
for p in /root/logs/rocketmqlogs/broker.log /datadisk/rocketmq/logs/broker.log; do
  [ -f "$p" ] && echo "##### $p" && grep -nE 'ERROR|Exception|Caused by|BindException|Address already|DLedger|cannot|Failed|Shutdown hook|JVM' "$p" 2>/dev/null | tail -n 40
done
echo "=== systemd journal full reason ==="
journalctl -u rocketmq-broker.service --no-pager -n 25 2>/dev/null | grep -vE 'load exist|subscriptionGroup'
echo "=== 40911 already used? ==="
ss -lntp 2>/dev/null | grep -E '40911|10911'
echo "=== free mem (8g heap needs RAM) ==="
free -g
