#!/bin/bash
echo "host=$(hostname -I | awk '{print $1}')"
echo "--- all procs matching BrokerStartup ---"
ps -eo pid,ppid,stat,comm,args | grep -i BrokerStartup | grep -v grep
echo "--- pgrep -f BrokerStartup ---"
pgrep -af BrokerStartup
echo "--- pgrep java ---"
pgrep -af 'java' | grep -i broker
