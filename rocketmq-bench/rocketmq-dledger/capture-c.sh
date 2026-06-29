#!/bin/bash
# Fault C: T0_STOP=04:05:02 UTC -> server 12:05:02 UTC+8
D=/datadisk/rocketmq/logs
echo "=== host $(hostname) ==="
echo "=== role/election lines 12:04-12:07 ==="
grep -hE '2026-06-28 12:0[4567]:' $D/broker.log 2>/dev/null \
  | grep -iE 'Begin handling broker role change|changeRoleTo|\[n[012]\]\[(LEADER|CANDIDATE|FOLLOWER)\]|become a|registerBroker|leaderId|currTerm' \
  | head -50
echo "=== LEADER term transitions seen ==="
grep -hoE '\[n[012]\]\[LEADER\] term=[0-9]+' $D/broker.log 2>/dev/null | sort -u | tail -5
