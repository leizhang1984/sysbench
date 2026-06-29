#!/bin/bash
# Find namesrv.log and extract broker-a (10.163.0.10 / .11) lifecycle events.
LOG=$(ls -t /root/logs/rocketmqlogs/namesrv.log /home/*/logs/rocketmqlogs/namesrv.log /opt/rocketmq*/logs/rocketmqlogs/namesrv.log 2>/dev/null | head -1)
[ -z "$LOG" ] && LOG=$(find / -name namesrv.log 2>/dev/null | head -1)
echo "LOG=$LOG"
echo "=== broker-a (.10/.11) register / unregister / housekeeping / channel events (last 80) ==="
grep -nE '10\.161\.0\.1[01]' "$LOG" 2>/dev/null | grep -iE 'register|unregister|housekeep|destroy|channel|close|offline|new broker' | tail -80
echo "=== ALL Housekeeping / channel-destroy lines (last 40) ==="
grep -iE 'housekeep|channel.*destroy|onChannelClose|onChannelException|onChannelIdle' "$LOG" 2>/dev/null | tail -40
