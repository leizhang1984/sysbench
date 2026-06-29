#!/bin/bash
# ns-health.sh  —  Run ON a name server VM: check setup log + service + port.
set -uo pipefail
echo "host: $(hostname)"
echo "=== setup log tail ==="; tail -n 20 /var/log/rocketmq-setup.log 2>/dev/null || echo "(no setup log)"
echo "=== java ==="; java -version 2>&1 | head -1 || echo "no java"
echo "=== datadisk ==="; findmnt -no SOURCE,FSTYPE /datadisk 2>/dev/null || echo "NOT MOUNTED"
echo "=== service ==="; systemctl is-active rocketmq-namesrv 2>/dev/null || echo "inactive"
echo "=== port 9876 ==="; ss -lnt | grep 9876 || echo "9876 NOT listening"
echo "=== dnf running? ==="; pgrep -x dnf >/dev/null && echo "dnf RUNNING" || echo "dnf idle"
