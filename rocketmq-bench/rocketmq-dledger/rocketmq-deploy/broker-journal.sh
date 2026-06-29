#!/bin/bash
echo "=== journal (last 40) ==="
journalctl -u rocketmq-broker --no-pager -n 40 2>/dev/null
echo "=== free mem ==="
free -m
echo "=== ExecStart unit ==="
grep -E 'ExecStart|Environment' /etc/systemd/system/rocketmq-broker.service
