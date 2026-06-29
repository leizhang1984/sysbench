#!/bin/bash
echo "=== disk space ==="
df -h /datadisk
echo "=== dledger-n0 recursive ==="
ls -laR /datadisk/rocketmq/store/dledger-n0 2>&1 | head -50
echo "=== broker_default.log tail 50 ==="
tail -n 50 /datadisk/rocketmq/logs/broker_default.log 2>&1
echo "=== grep dledger/leader/term/recover EXCLUDING transaction.log ==="
grep -rinE 'dledger|leader|term|recover|quorum|EXIT|stop|corrupt|no space' /datadisk/rocketmq/logs --include='broker*.log' 2>/dev/null | tail -n 40
