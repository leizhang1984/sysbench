#!/bin/bash
LOG=/datadisk/rocketmq/logs/broker.log
# Find the LAST occurrence of consumerFilter.json OK and print the 30 lines AFTER it
LINE=$(grep -nE 'consumerFilter.json OK' "$LOG" | tail -1 | cut -d: -f1)
echo "consumerFilter OK at line $LINE"
END=$((LINE+30))
sed -n "${LINE},${END}p" "$LOG"
