#!/bin/bash
# election-log.sh : show recent DLedger role/election log lines with timestamps
LOG=/datadisk/rocketmq/logs/broker.log
IP=$(hostname -I | awk '{print $1}')
echo "host=$IP"
echo "--- last role/election lines ---"
grep -aE "become|Leader|leader|election|ChangeRole|MNROLE|VoteResponse|candidate|term=" /datadisk/rocketmq/logs/*.log 2>/dev/null | tail -25
echo "--- last broker.log mtime / tail ts ---"
ls -la --time-style=+%H:%M:%S /datadisk/rocketmq/logs/broker.log 2>/dev/null
tail -3 /datadisk/rocketmq/logs/broker.log 2>/dev/null
