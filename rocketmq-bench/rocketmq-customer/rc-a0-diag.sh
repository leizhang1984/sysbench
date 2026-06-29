#!/bin/bash
echo "=== broker.log fatal ==="
grep -iE 'error|exception|fail|cannot|insufficient|java.lang' /datadisk/rocketmq/logs/broker.log | tail -20
echo "=== broker.log tail ==="
tail -30 /datadisk/rocketmq/logs/broker.log
echo "=== store dir ==="
df -h /datadisk; ls -la /datadisk/rocketmq/store
echo "=== free ==="; free -m
