#!/bin/bash
LOG=/datadisk/rocketmq/logs/broker.log
echo "=== broker.log tail 70 ==="
tail -n 70 "$LOG"
echo "=== Exception/Caused/exit/fail in broker.log (last 40) ==="
grep -nE 'Exception|Caused by|System.exit|initialize|load.*fail|Lock failed|ERROR|DLedger|raft|recover|shutdown' "$LOG" | tail -n 40
