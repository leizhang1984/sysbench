#!/bin/bash
set +e
LOG=/root/logs/rocketmqlogs/broker.log
echo "=== lines 498877..498962 (final boot store load) ==="
sed -n '498877,498962p' "$LOG" 2>/dev/null
echo
echo "=== dledger-n0 mapped files (sizes) ==="
ls -la /datadisk/rocketmq/store/dledger-n0/ 2>/dev/null | head -40
echo "=== count + last file ==="
ls -la /datadisk/rocketmq/store/dledger-n0/ 2>/dev/null | tail -5
