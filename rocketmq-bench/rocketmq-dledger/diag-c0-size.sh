#!/bin/bash
set +e
LOG=/root/logs/rocketmqlogs/broker.log
echo "=== search 'not matched / please check / length' ==="
grep -nE 'not matched|please check it manually|length not|load over, over|loadConsumeQueue|recover' "$LOG" 2>/dev/null | tail -n 30
echo
echo "=== consumequeue mapped files with non-standard size (expect 6000000) ==="
find /datadisk/rocketmq/store/consumequeue -type f 2>/dev/null | while read f; do sz=$(stat -c%s "$f"); if [ "$sz" != "6000000" ]; then echo "ABNORMAL $sz  $f"; fi; done | head -30
echo "=== dledger data files (expect 1073741824) ==="
ls -la /datadisk/rocketmq/store/dledger-n0/data/ 2>/dev/null
echo "=== dledger index files ==="
ls -la /datadisk/rocketmq/store/dledger-n0/index/ 2>/dev/null | tail -5
