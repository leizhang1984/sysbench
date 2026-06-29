#!/bin/bash
echo "=== broker.log last 45 lines ==="
tail -45 /datadisk/rocketmq/store/../logs/broker.log 2>/dev/null
echo "=== store.log last 25 ==="
tail -25 /datadisk/rocketmq/logs/store.log 2>/dev/null
echo "=== storeerror.log ==="
tail -25 /datadisk/rocketmq/logs/storeerror.log 2>/dev/null
echo "=== commitlog dir ==="
ls -la /datadisk/rocketmq/store/commitlog/ 2>/dev/null
echo "=== free mem ==="
free -g
