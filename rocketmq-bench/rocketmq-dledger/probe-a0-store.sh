#!/bin/bash
echo "=== store tree ==="
ls -la /datadisk/rocketmq/store 2>&1
echo "--- commitlog ---"
ls -la /datadisk/rocketmq/store/commitlog 2>&1 | head
echo "--- dledger commitlog ---"
ls -la /datadisk/rocketmq/store/dledger-commitlog 2>&1 | head
echo "--- consumequeue ---"
ls -la /datadisk/rocketmq/store/consumequeue 2>&1 | head
echo "--- abort/checkpoint ---"
ls -la /datadisk/rocketmq/store/abort /datadisk/rocketmq/store/checkpoint 2>&1
echo "=== broker.log load lines ==="
LOG=$(ls -t /opt/rocketmq-4.9.7/logs/rocketmqlogs/broker.log 2>/dev/null | head -1)
grep -nE 'load .* (OK|Failed)|load failed|recover|Lock failed|exception|Exception|DLedger|deleteExpired|System.exit' "$LOG" 2>/dev/null | tail -n 40
echo "=== conf store paths ==="
grep -E 'storePathRootDir|storePathCommitLog|enableDLegerCommitLog|dLeger' /opt/rocketmq-4.9.7/conf/broker-dledger.conf
