#!/bin/bash
D=/datadisk/rocketmq/logs
echo "=== host $(hostname) ==="
echo "=== QuorumAckChecker LEADER/role lines 11:55:2x-11:56:4x ==="
grep -hE '2026-06-28 11:5[56]:' $D/broker.log 2>/dev/null \
  | grep -iE '\[n[012]\]\[(LEADER|CANDIDATE|FOLLOWER)\]|changeRoleTo|Begin handling broker role change|become a (leader|follower)|registerBroker|leaderId|currTerm' \
  | head -60
echo "=== term transitions (any term=3/4 LEADER) ==="
grep -hoE '\[n[012]\]\[LEADER\] term=[0-9]+' $D/broker.log 2>/dev/null | sort -u
