#!/bin/bash
# Recover a corrupted DLedger node by wiping its message store; it will re-sync
# from the current leader. Run ONLY when the group still has quorum (2/3 healthy).
# Auto-detects this node's dLegerSelfId from broker-dledger.conf.
set -e
CONF=/opt/rocketmq-4.9.7/conf/broker-dledger.conf
SELF=$(grep -E '^dLegerSelfId=' "$CONF" | cut -d= -f2 | tr -d '[:space:]')
S=/datadisk/rocketmq/store
echo "self=$SELF store=$S host=$(hostname -I | awk '{print $1}')"
systemctl stop rocketmq-broker 2>/dev/null || true
sleep 2
echo "before:"; du -sh "$S/dledger-$SELF" "$S/consumequeue" "$S/index" 2>/dev/null || true
rm -rf "$S/dledger-$SELF" "$S/commitlog" "$S/consumequeue" "$S/index"
rm -f  "$S/abort" "$S/checkpoint" "$S/checkpoint.bak"
echo "wiped message store (kept config/, lock)"
ls -la "$S"
systemctl reset-failed rocketmq-broker 2>/dev/null || true
systemctl start rocketmq-broker
echo "started; waiting 25s to sync..."
sleep 25
echo "systemd=$(systemctl is-active rocketmq-broker)"
pgrep -f BrokerStartup | head -3 | awk '{print "pid="$1}'
echo "=== store after sync ==="
du -sh "$S/dledger-$SELF" 2>/dev/null || true
