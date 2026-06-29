#!/bin/bash
# Show probe progress: tail of CSV + running state. Arg: RUNID
RUNID=$1
CSV=/opt/probe/$RUNID.csv
LOG=/opt/probe/$RUNID.console.log
echo "running=$(pgrep -f "Probe produce.*$RUNID" | head -1 | wc -l) at=$(date -u +%H:%M:%S.%3NZ)"
echo "=== CSV tail ==="
tail -15 "$CSV" 2>/dev/null
echo "=== console tail ==="
tail -6 "$LOG" 2>/dev/null
