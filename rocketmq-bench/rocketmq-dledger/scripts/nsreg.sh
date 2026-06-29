#!/bin/bash
# nsreg.sh <min1> <min2> ... : show "register broker[0] ... OK" (master registration to NameServer)
LOG=/datadisk/rocketmq/logs/broker.log
IP=$(hostname -I | awk '{print $1}')
echo "host=$IP"
PAT=""
for m in "$@"; do PAT="${PAT}${PAT:+|}$m"; done
echo "=== register broker[0] (master) -> NameServer, minutes: $* ==="
grep -aE "register broker\[0\]to name server" "$LOG" 2>/dev/null | grep -aE " (${PAT}):" | head -12
