#!/bin/bash
# Find namesrv.log and extract broker-a (10.162.0.7/.8) and broker-c (10.162.0.11/.12)
# lifecycle events. Run on a NameServer node.
LOG=/datadisk/rocketmq/logs/rocketmqlogs/namesrv.log
[ -f "$LOG" ] || LOG=$(ls -t /root/logs/rocketmqlogs/namesrv.log /home/*/logs/rocketmqlogs/namesrv.log /opt/rocketmq*/logs/rocketmqlogs/namesrv.log 2>/dev/null | head -1)
[ -z "$LOG" ] && LOG=$(find / -name namesrv.log 2>/dev/null | head -1)
echo "LOG=$LOG"
echo "=== broker-a (.7/.8) + broker-c (.11/.12) register/unregister/destroy events (last 120) ==="
grep -nE '10\.162\.0\.(7|8|11|12)[: ]' "$LOG" 2>/dev/null | grep -iE 'register|unregister|housekeep|destroy|channel|close|offline|new broker|remove' | tail -120
echo "=== ALL Housekeeping / channel-destroy lines (last 60) ==="
grep -iE 'housekeep|channel.*destroy|onChannelClose|onChannelException|onChannelIdle' "$LOG" 2>/dev/null | tail -60
