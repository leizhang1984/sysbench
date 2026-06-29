#!/bin/bash
# Capture DLedger election evidence on a broker-a node. Logs in /datadisk/rocketmq/logs.
echo "=== host $(hostname) ==="
D=/datadisk/rocketmq/logs
ls -1 $D | grep -iE 'dledger|broker' 
echo "=== role/vote/leader/term across broker*.log (last 40 matches) ==="
grep -hiE 'become|leader|candidate|vote|MASTER|SLAVE|roleChange|changeRoleTo|currentRole' $D/broker*.log 2>/dev/null | tail -40
echo "=== any dledger-named log ==="
for f in $D/dledger*.log $D/*ledger*.log; do
  [ -f "$f" ] && echo "--- $f ---" && tail -30 "$f"
done
echo "=== broker.log tail 15 (context) ==="
tail -15 $D/broker.log 2>/dev/null
