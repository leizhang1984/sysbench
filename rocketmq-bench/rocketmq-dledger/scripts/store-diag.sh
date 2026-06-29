#!/bin/bash
LOG=/datadisk/rocketmq/logs/broker.log
echo "=== last load/recover/messagestore lines ==="
grep -nE 'load |recover|MessageStore|Load |CommitLog|dispatch|abnormal|normal exit|DLedger' "$LOG" 2>/dev/null | tail -30
echo "=== store dir ==="
du -sh /datadisk/rocketmq/store/* 2>/dev/null
echo "=== commitlog dir ==="
ls -la /datadisk/rocketmq/store/commitlog/ 2>/dev/null | head
ls -la /datadisk/rocketmq/store/dledger* 2>/dev/null | head
echo "=== checkpoint/abort ==="
ls -la /datadisk/rocketmq/store/ 2>/dev/null
