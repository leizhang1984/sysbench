#!/bin/bash
# Phase 4 (Failover C) graceful stop fault: self-timed `systemctl stop` then `start`.
# Run on a-0 and a-1. Args: DELAY DOWN  (default 40s steady, 60s down)
DELAY="${1:-40}"
DOWN="${2:-60}"
mkdir -p /opt/ft
LOG=/opt/ft/graceful.log
setsid bash -c "
  echo \"PLAN delay=$DELAY down=$DOWN start=\$(date '+%H:%M:%S')\"
  sleep $DELAY
  echo \"T0 stop rmq-broker at \$(date '+%H:%M:%S.%N')\"
  systemctl stop rmq-broker
  sleep $DOWN
  echo \"T1 start rmq-broker at \$(date '+%H:%M:%S.%N')\"
  systemctl reset-failed rmq-broker 2>/dev/null || true
  systemctl start rmq-broker
  sleep 12
  echo \"after active=\$(systemctl is-active rmq-broker)\"
  ss -lnt | grep -q 10911 && echo '10911 listening' || echo '10911 NOT listening'
  echo \"DONE \$(date '+%H:%M:%S')\"
" > $LOG 2>&1 < /dev/null &
echo "graceful fault scheduled: delay=${DELAY}s down=${DOWN}s (log /opt/ft/graceful.log)"
