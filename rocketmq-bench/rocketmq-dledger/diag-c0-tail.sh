#!/bin/bash
set +e
LOG=/root/logs/rocketmqlogs/broker.log
echo "=== literal last 50 lines of broker.log ==="
tail -n 50 "$LOG" 2>/dev/null
echo
echo "=== search fatal markers ==="
grep -nE 'Lock|shutdown|Shutdown|Halt|halt|DLedger|dledger|recover abnormal|recover normal|crc|CRC|corrupt|truncate|IllegalState|NullPointer|FileNotFound|load\(\)|initialize|disk space|maxUsedSpace' "$LOG" 2>/dev/null | tail -n 30
