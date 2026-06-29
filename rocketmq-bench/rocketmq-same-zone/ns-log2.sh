#!/bin/bash
LOG=$(ls -t /root/logs/rocketmqlogs/namesrv.log /home/*/logs/rocketmqlogs/namesrv.log /opt/rocketmq*/logs/rocketmqlogs/namesrv.log 2>/dev/null | head -1)
[ -z "$LOG" ] && LOG=$(find / -name namesrv.log 2>/dev/null | head -1)
echo "LOG=$LOG"
echo "=== A) broker-a channel-destroyed (server-detected disconnect, time) ==="
grep -nE "the broker's channel destroyed, 10\.161\.0\.1[01]" "$LOG"
echo "=== B) unregisterBroker (graceful active deregister) for broker-a ==="
grep -niE 'unregister' "$LOG" | grep -E '10\.161\.0\.1[01]|broker-a' | tail -30
echo "=== C) broker-a re-register / new broker (recover) ==="
grep -niE 'new broker|register' "$LOG" | grep -E '10\.161\.0\.1[01]' | grep -ivE 'unregister|destroy' | tail -30
echo "=== D) scanNotActiveBroker timeout removals (frozen/dead heartbeat) ==="
grep -niE 'not active|scanNotActive|remove it' "$LOG" | tail -20
