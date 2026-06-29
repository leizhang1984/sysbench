#!/bin/bash
LOG=/datadisk/rocketmq/logs/broker.log
echo "=== 35 lines BEFORE first AllocateMappedFileService shutdown of last run ==="
# get last run block: from last 'The broker' or 'Set user' boot marker
LINE=$(grep -nE 'Try to shutdown service thread:AllocateMappedFileService' "$LOG" | tail -1 | cut -d: -f1)
START=$((LINE-40))
sed -n "${START},${LINE}p" "$LOG"
echo "=== grep load result lines ==="
grep -nE 'load |Load |recover|DLedger|dLeger|dispatch|message store|messageStore|consumeQueue|store config' "$LOG" | tail -n 40
