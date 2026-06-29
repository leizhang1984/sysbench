#!/bin/bash
# DLedger election evidence on this node. Search all logs for role/term changes.
echo "=== host $(hostname) ==="
D=/datadisk/rocketmq/logs
echo "=== files ==="
ls -1 $D | head -30
echo "=== DLedger elector lines across ALL logs (become/term/Candidate/Leader/Follower/changeRoleTo/MsgPicker) ==="
grep -rhiE 'become (a )?(leader|follower|candidate)|changeRoleTo|MemberState|DLedgerLeaderElector|maintainState|currTerm|leaderId=' $D/*.log 2>/dev/null | tail -50
echo "=== broker_default.log tail 20 ==="
tail -20 $D/broker_default.log 2>/dev/null
echo "=== store.log role hints tail ==="
grep -iE 'role|master|slave|recover' $D/store*.log 2>/dev/null | tail -15
