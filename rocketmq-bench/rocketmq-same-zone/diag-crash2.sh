#!/bin/bash
echo "=== broker.log tail 40 (most recent startup attempt) ==="
tail -n 40 /datadisk/rocketmq/logs/broker.log 2>/dev/null
echo "=== store.log tail 20 ==="
tail -n 20 /datadisk/rocketmq/logs/store.log 2>/dev/null
echo "=== mem ==="
free -g
echo "=== store du ==="
du -sh /datadisk/rocketmq/store/* 2>/dev/null
