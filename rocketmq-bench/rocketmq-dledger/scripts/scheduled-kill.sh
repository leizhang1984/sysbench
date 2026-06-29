#!/bin/bash
# Schedule a kill -9 of the local broker at an absolute epoch second (NTP-synced
# across VMs), detached so run-command returns immediately. Arg: TS (epoch sec)
TS=$1
PID=$(pgrep -f BrokerStartup | head -1)
IP=$(hostname -I | awk '{print $1}')
if [ -z "$PID" ]; then echo "NO_BROKER_PID ip=$IP"; exit 1; fi
setsid bash -c "
  now=\$(date +%s)
  d=\$(( $TS - now ))
  if [ \$d -gt 0 ]; then sleep \$d; fi
  kill -9 $PID
  echo \"KILLED ip=$IP pid=$PID at=\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\" >> /opt/probe/kill-events.log 2>/dev/null
  echo \"KILLED ip=$IP pid=$PID at=\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\" > /tmp/kill-event.log
" </dev/null >/dev/null 2>&1 &
echo "scheduled kill ip=$IP pid=$PID fire_ts=$TS now=$(date +%s) (in $(( TS - $(date +%s) ))s)"
