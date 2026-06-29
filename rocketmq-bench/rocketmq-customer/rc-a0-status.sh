#!/bin/bash
echo "=== now/boot ==="
date '+%F %T %z'
uptime -s
who -b || true
echo "=== broker ==="
systemctl is-active rmq-broker
ss -lnt | grep -E '10911|10912' || true
echo "=== recent broker log ==="
tail -20 /datadisk/rocketmq/logs/broker.log
