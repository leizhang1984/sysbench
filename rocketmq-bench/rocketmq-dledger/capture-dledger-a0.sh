#!/bin/bash
# Capture DLedger election / role-change evidence on a broker-a node around the freeze windows.
# Logback timestamps are UTC+8. Freezes (client-local): B1 ~03:38:48-03:39:44, B2 ~03:42:59-03:43:55.
echo "=== host $(hostname) ==="
for d in /root/logs/rocketmqlogs /home/*/logs/rocketmqlogs /datadisk/rocketmq/logs /opt/rocketmq-4.9.7/logs; do
  [ -d "$d" ] && echo "LOGDIR=$d" && ls -1 "$d" 2>/dev/null | head
done
LOG=$(ls /root/logs/rocketmqlogs/broker.log 2>/dev/null || ls /root/logs/rocketmqlogs/*.log 2>/dev/null | head -1)
echo "=== grep DLedger role/vote/leader in broker.log + store.log (recent) ==="
for f in /root/logs/rocketmqlogs/broker.log /root/logs/rocketmqlogs/store.log; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  grep -iE 'become|leader|candidate|vote|term|MASTER|SLAVE|roleChange|DLedger' "$f" 2>/dev/null | tail -25
done
