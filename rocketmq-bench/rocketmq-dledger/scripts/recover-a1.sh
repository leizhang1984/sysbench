#!/bin/bash
# Recover corrupted DLedger follower a-1 by wiping its message store; it will
# re-sync from the leader. Group broker-a retains quorum (leader .12 + follower .10).
set -e
systemctl stop rocketmq-broker 2>/dev/null || true
sleep 2
S=/datadisk/rocketmq/store
echo "before:"; du -sh $S/dledger-n1 $S/consumequeue $S/index 2>/dev/null
rm -rf $S/dledger-n1 $S/commitlog $S/consumequeue $S/index
rm -f  $S/abort $S/checkpoint $S/checkpoint.bak
echo "wiped message store (kept config/, lock)"
ls -la $S
systemctl reset-failed rocketmq-broker 2>/dev/null || true
systemctl start rocketmq-broker
echo "started; waiting 20s to sync..."
sleep 20
echo "systemd=$(systemctl is-active rocketmq-broker)"
ps -ef | grep BrokerStartup | grep -v grep | awk '{print "pid="$2}'
echo "=== store after sync ==="
du -sh $S/dledger-n1 2>/dev/null
