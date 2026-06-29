#!/bin/bash
# failover-evidence.sh <HHMM_prefix>
# Greps DLedger election / role-change / NameServer registration lines around a given UTC+8 minute window.
# broker.log logback tz = UTC+8. Pass e.g. "11:06" "11:07" as args (minute prefixes to match).
LOGDIR=/datadisk/rocketmq/logs
IP=$(hostname -I | awk '{print $1}')
SELF=$(grep -E '^dLegerSelfId=' /opt/rocketmq-4.9.7/conf/broker-dledger.conf | cut -d= -f2)
echo "host=$IP self=$SELF"
echo "=== DLedger role-change / election (all matching minutes: $* ) ==="
PAT=""
for m in "$@"; do PAT="${PAT}${PAT:+|}$m"; done
# DLedger + broker role-change + nameserver registration lines, restricted to the minute prefixes
grep -aE "DLegerRoleChangeHandler|change to (master|slave|candidate)|become|MNROLE|currStoreRole|role=(LEADER|FOLLOWER|CANDIDATE)|term=|[Vv]ote|register broker\[0\]" "$LOGDIR"/*.log 2>/dev/null \
  | grep -aE " (${PAT}):" \
  | tail -40
echo "=== role-change summary (whole log, last 12) ==="
grep -aE "Finish to change to (master|slave)|Finish handling broker role change" "$LOGDIR"/broker.log 2>/dev/null | tail -12
