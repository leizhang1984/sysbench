#!/bin/bash
RUNID=$1
cat /opt/probe/$RUNID.csv 2>/dev/null
echo "=== PRODUCE_DONE line ==="
grep -a PRODUCE_DONE /opt/probe/$RUNID.console.log 2>/dev/null | tail -1
echo "running=$(pgrep -f "Probe produce.*$RUNID" | wc -l)"
