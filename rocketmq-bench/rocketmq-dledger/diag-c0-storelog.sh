#!/bin/bash
set +e
SL=/root/logs/rocketmqlogs/store.log
echo "=== store.log last 60 lines ==="
tail -n 60 "$SL" 2>/dev/null
echo
echo "=== store.log: not matched / load fail / recover / WARN / ERROR ==="
grep -nE 'not matched|please check|load.*fail|fail.*load|WARN|ERROR|recover|Recover|abnormal|truncat|crc|CRC|dispatch|maxPhysical|leastBoundary|delete' "$SL" 2>/dev/null | tail -40
