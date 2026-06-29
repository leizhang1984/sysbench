#!/bin/bash
echo "=== disk space datadisk ==="
df -h /datadisk
echo "=== dledger-n0 listing ==="
ls -la /datadisk/rocketmq/store/dledger-n0 2>&1
echo "--- dledger-n0 subdirs ---"
ls -la /datadisk/rocketmq/store/dledger-n0/* 2>&1 | head -30
echo "=== broker_default.log tail 45 ==="
tail -n 45 /datadisk/rocketmq/logs/broker_default.log 2>&1
