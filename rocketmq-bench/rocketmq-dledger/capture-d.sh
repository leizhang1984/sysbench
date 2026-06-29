#!/bin/bash
# Fault D: T0_POWEROFF=04:12:18 UTC -> server 12:12:18 UTC+8
D=/datadisk/rocketmq/logs
echo "=== host $(hostname) ==="
echo "=== role/election lines 12:11-12:14 ==="
grep -hE '2026-06-28 12:1[1234]:' $D/broker.log 2>/dev/null \
  | grep -iE 'Begin handling broker role change|changeRoleTo|\[n[012]\]\[(LEADER|CANDIDATE|FOLLOWER)\]|become a|registerBroker|leaderId|currTerm' \
  | head -50
echo "=== LEADER term transitions seen (tail) ==="
grep -hoE '\[n[012]\]\[LEADER\] term=[0-9]+' $D/broker.log 2>/dev/null | sort -u | tail -5
