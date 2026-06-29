#!/bin/bash
echo "=== dledger-n0 dir ==="
ls -laR /datadisk/rocketmq/store/dledger-n0 2>&1 | head -40
echo "=== all logs in /datadisk/rocketmq/logs ==="
ls -la /datadisk/rocketmq/logs 2>&1
echo "=== search ALL logs for dledger/WARN/ERROR/Recover/quorum/leader ==="
grep -rinE 'dledger|WARN|ERROR|recover|quorum|leader|term|disk full|no space|corrupt' /datadisk/rocketmq/logs 2>/dev/null | grep -ivE 'load exist subscription' | tail -n 40
