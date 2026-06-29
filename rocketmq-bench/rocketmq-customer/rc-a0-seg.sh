#!/bin/bash
echo "=== full segment ==="
tail -80 /datadisk/rocketmq/logs/broker.log
echo "=== store.log ==="; tail -30 /datadisk/rocketmq/logs/storeerror.log 2>/dev/null; tail -30 /datadisk/rocketmq/logs/store.log 2>/dev/null
echo "=== runbroker heap ==="; grep -i Xm /opt/rocketmq-4.9.7/bin/runbroker.sh
