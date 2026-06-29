#!/bin/bash
# Phase 3 (Failover B) fault on broker a-0: self-timed SIGSTOP/SIGCONT of broker JVM.
# Args: DELAY FREEZE  (default 40s steady, then 60s freeze)
DELAY="${1:-40}"
FREEZE="${2:-60}"
mkdir -p /opt/ft
LOG=/opt/ft/sigstop.log
setsid bash -c "
  echo \"PLAN delay=$DELAY freeze=$FREEZE start=\$(date '+%H:%M:%S')\"
  sleep $DELAY
  PID=\$(ss -lntp 2>/dev/null | grep ':10911 ' | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)
  [ -z \"\$PID\" ] && PID=\$(pgrep -f 'java.*BrokerStartup' | head -1)
  echo \"T0 SIGSTOP pid=\$PID at \$(date '+%H:%M:%S.%N')\"
  kill -STOP \$PID
  sleep $FREEZE
  echo \"T1 SIGCONT pid=\$PID at \$(date '+%H:%M:%S.%N')\"
  kill -CONT \$PID
  echo \"DONE \$(date '+%H:%M:%S')\"
" > $LOG 2>&1 < /dev/null &
echo "sigstop fault scheduled on a-0: delay=${DELAY}s freeze=${FREEZE}s (log /opt/ft/sigstop.log)"
