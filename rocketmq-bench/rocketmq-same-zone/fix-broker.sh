#!/bin/bash
set -x
systemctl stop rmq-broker 2>/dev/null || true
sleep 2
echo "--- java procs ---"
pgrep -af java || echo none
pkill -9 -f mqbroker 2>/dev/null || true
pkill -9 -f BrokerStartup 2>/dev/null || true
sleep 3
echo "--- lock files ---"
ls -la /datadisk/rocketmq/store/lock 2>/dev/null || echo "no lock file"
echo "--- disk usage ---"
df -h /datadisk
echo "--- reset and start ---"
systemctl reset-failed rmq-broker
systemctl start rmq-broker
sleep 15
systemctl is-active rmq-broker
ss -lnt | grep -q 10911 && echo "10911 listening" || echo "NOT listening"
echo "--- journal ---"
journalctl -u rmq-broker --no-pager -n 8 | tail -8
