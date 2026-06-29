#!/bin/bash
# Show only rows where per-second fail>0, plus the boundary recovery.
RUNID="${1:?need RUNID}"
C=/opt/probe/ft_${RUNID}.csv
echo "=== rows with fail/s>0 (sec,ok,fail,ok_total,fail_total,p99,max,err) ==="
awk -F, 'NR==1{next} ($5+0)>0 {print $3","$4","$5","$6","$7","$9","$10","$11}' "$C"
echo "=== summary ==="
awk -F, 'NR==1{next}{ok=$6;ft=$7} END{print "last ok_total="ok" fail_total="ft}' "$C"
echo "=== first 5 secs ==="
awk -F, 'NR>1 && NR<=6{print $3","$4","$5","$6","$7}' "$C"
