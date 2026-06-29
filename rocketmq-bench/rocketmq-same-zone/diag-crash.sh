#!/bin/bash
echo "=== broker.log ERROR/Exception (last 30) ==="
grep -iE 'error|exception|caused by|fail' /datadisk/rocketmq/logs/broker.log 2>/dev/null | tail -n 30
echo "=== latest start attempt around exit ==="
ls -t /datadisk/rocketmq/logs/ 2>/dev/null | head
echo "=== journal full last 25 ==="
journalctl -u rmq-broker -n 25 --no-pager 2>/dev/null | tail -25
