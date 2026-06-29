#!/bin/bash
# Fetch Probe results for a runId: failure-window rows + totals. Arg1=runId
RUNID=$1
CSV=/opt/probe/$RUNID.csv
echo "===== console tail $RUNID ====="
grep -E 'PRODUCE_DONE|PRODUCER started' /opt/probe/$RUNID.console.log 2>/dev/null
echo "===== failure window (fail/s > 0) sec|wall|ok|fail|fail_total|p99|max ====="
awk -F',' 'NR==1{next} $5>0 {print $3"|"$2"|"$4"|"$5"|"$7"|"$9"|"$10}' $CSV 2>/dev/null
echo "===== first/last 3 rows ====="
awk -F',' 'NR==1{next}{print $3"|"$2"|ok="$4"|fail="$5"|okTot="$6"|failTot="$7}' $CSV 2>/dev/null | head -3
echo "..."
awk -F',' 'NR==1{next}{print $3"|"$2"|ok="$4"|fail="$5"|okTot="$6"|failTot="$7}' $CSV 2>/dev/null | tail -3
echo "===== totals ====="
awk -F',' 'END{print "lastRow_okTotal_failTotal_at_sec="$3" okTotal="$6" failTotal="$7}' $CSV 2>/dev/null
