#!/bin/bash
# Capture DLedger election evidence for ftB1b freeze.
# Freeze T0_STOP=03:55:27 UTC -> server 11:55:27 ; T1_CONT=03:56:31 UTC -> 11:56:31
echo "=== host $(hostname) ==="
D=/datadisk/rocketmq/logs
echo "=== role/term/election lines 11:54-11:58 ==="
grep -hE '2026-06-28 11:(54|55|56|57|58)' $D/broker.log 2>/dev/null \
  | grep -iE 'become|changeRoleTo|\[n[012]\]\[(LEADER|FOLLOWER|CANDIDATE)\]|currTerm|leaderId|vote|elect|MASTER|SLAVE|registerBroker' | head -80
echo "=== first LEADER term=3 (or higher) line after freeze ==="
grep -hE '\[n[012]\]\[LEADER\] term=[3-9]' $D/broker.log 2>/dev/null | head -5
echo "=== role change events around window ==="
grep -hiE 'changeRoleTo|become a (leader|follower|candidate)' $D/broker.log 2>/dev/null \
  | grep -E '2026-06-28 11:(54|55|56|57|58)' | head -40
