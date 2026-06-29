#!/bin/bash
# Schedule a SIGSTOP (freeze) of the local broker at an absolute epoch second
# (NTP-synced across VMs), detached so run-command returns immediately. Arg: TS
TS=$1
PID=$(pgrep -f 'java.*BrokerStartup' | head -1)
IP=$(hostname -I | awk '{print $1}')
if [ -z "$PID" ]; then echo "NO_BROKER_PID ip=$IP"; exit 1; fi
setsid bash -c "
  now=\$(date +%s)
  d=\$(( $TS - now ))
  if [ \$d -gt 0 ]; then sleep \$d; fi
  kill -STOP $PID
  echo \"FROZEN ip=$IP pid=$PID at=\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\" >> /opt/probe/freeze-events.log 2>/dev/null
  echo \"FROZEN ip=$IP pid=$PID at=\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\" > /tmp/freeze-event.log
" </dev/null >/dev/null 2>&1 &
echo "scheduled freeze ip=$IP pid=$PID fire_ts=$TS now=$(date +%s) (in $(( TS - $(date +%s) ))s)"
