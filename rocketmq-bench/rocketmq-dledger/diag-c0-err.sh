#!/bin/bash
set +e
LOG=/root/logs/rocketmqlogs/broker.log
echo "=== ERROR/WARN lines (last 40) ==="
grep -nE ' ERROR | WARN ' "$LOG" 2>/dev/null | tail -n 40
echo
echo "=== java exception stack markers ==="
grep -nE 'java\.|at org\.apache|Exception|Throwable|Caused by' "$LOG" 2>/dev/null | tail -n 30
echo
echo "=== dledger recover lines ==="
grep -nE 'DLedger|dledger|recover|Recover|load commit|commitlog|mappedFile|MappedFile load' "$LOG" 2>/dev/null | tail -n 30
echo
echo "=== store error log ==="
tail -n 40 /root/logs/rocketmqlogs/storeerror.log 2>/dev/null
