#!/bin/bash
echo '--- pgrep BrokerStartup ---'
pgrep -af BrokerStartup
echo '--- listening 10911 PID ---'
ss -lntp | grep 10911
echo '--- state of matching pids ---'
for p in $(pgrep -f BrokerStartup); do
  st=$(awk '{print $3}' /proc/$p/stat 2>/dev/null)
  cmd=$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | cut -c1-60)
  echo "pid=$p state=$st cmd=$cmd"
done
