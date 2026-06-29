#!/bin/bash
# Show recent DLedger role transitions and current role from the broker log.
LOG=/datadisk/rocketmq/logs/broker.log
IP=$(hostname -I | awk '{print $1}')
echo "host=$IP"
grep -aE 'become (LEADER|FOLLOWER|CANDIDATE)|BecomeLeader|leaderId|change leader' "$LOG" 2>/dev/null | tail -8
echo "--- last 3 role lines ---"
grep -aoE 'role=(LEADER|FOLLOWER|CANDIDATE)' "$LOG" 2>/dev/null | tail -3
