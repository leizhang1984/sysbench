#!/bin/bash
# Pull DLedger lines during the two freeze windows (server logback = UTC+8).
# B1 freeze UTC 03:38:48-03:39:44 -> server 11:38:48-11:39:44
# B2 freeze UTC 03:42:59-03:43:55 -> server 11:42:59-11:43:55
echo "=== host $(hostname) ==="
D=/datadisk/rocketmq/logs
echo "=== broker.log lines 11:38-11:44 (election/role/heartbeat/term) ==="
grep -hE '2026-06-28 11:(38|39|40|41|42|43|44)' $D/broker.log 2>/dev/null \
  | grep -iE 'term|leader|candidate|vote|become|changeRole|heartbeat|MASTER|SLAVE|elect|DLedger|n0|n1|n2' | head -60
echo "=== ALL logs DLedger elector lines 11:38-11:44 ==="
grep -rhE '2026-06-28 11:(38|39|40|41|42|43|44)' $D/*.log 2>/dev/null \
  | grep -iE 'DLedgerLeaderElector|become a|changeRoleTo|\[n[012]\]\[(LEADER|FOLLOWER|CANDIDATE)\]|currTerm|leaderId' | head -40
