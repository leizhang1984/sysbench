#!/bin/bash
set +e
LOG=/root/logs/rocketmqlogs/broker.log
echo "=== last 15 lines BEFORE the final shutdown (context of load fail) ==="
# find last occurrence of AllocateMappedFileService started:false, print 20 lines before it
grep -n 'AllocateMappedFileService started:false' "$LOG" | tail -1
LN=$(grep -n 'AllocateMappedFileService started:false' "$LOG" | tail -1 | cut -d: -f1)
echo "--- context lines $((LN-25)) to $LN ---"
sed -n "$((LN-25)),${LN}p" "$LOG"
echo
echo "=== WARN/not matched/checkCRC fail anywhere ==="
grep -nE 'not matched|please check|recover|Recover|checkpoint|abnormal|truncat|rollback|leastBoundary' "$LOG" | tail -15
echo "=== storeerror.log ==="
ls -la /root/logs/rocketmqlogs/ | grep -iE 'error|store'
tail -n 30 /root/logs/rocketmqlogs/storeerror.log 2>/dev/null
