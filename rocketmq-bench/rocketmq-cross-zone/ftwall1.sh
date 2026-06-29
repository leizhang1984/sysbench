#!/bin/bash
# Generic fail-window dump for one runId.
R="${1:?need RUNID}"
C=/opt/probe/ft_${R}.csv
[ -f "$C" ] || { echo "NO CSV for $R"; exit 0; }
echo "===== $R ====="
echo "header: $(head -1 $C)"
echo "first-data: $(awk -F, 'NR==2{print $3" | "$2}' $C)"
echo "--- rows with fail/s>0 : sec | wall | ok/s | fail/s | fail_total | err ---"
awk -F, 'NR>1 && ($5+0)>0 {print $3" | "$2" | ok="$4" | fail="$5" | ftot="$7" | "$11}' $C | head -80
echo "--- totals ---"
awk -F, 'NR>1{ok+=$4; f+=$5} END{print "okSum="ok" failSum="f}' $C
echo "last-data: $(awk -F, 'END{print $3" | "$2" | okTot="$6" | failTot="$7}' $C)"
