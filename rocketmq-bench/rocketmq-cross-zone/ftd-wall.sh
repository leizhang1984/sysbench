#!/bin/bash
# ftD fail-window dump: show first/last fail rows + error category transitions.
C=/opt/probe/ft_ftD.csv
[ -f "$C" ] || { echo "NO CSV"; exit 0; }
echo "header: $(head -1 $C)"
echo "--- ALL rows with fail/s>0 : sec | wall | ok/s | fail/s | fail_total | err ---"
awk -F, 'NR>1 && ($5+0)>0 {print $3" | "$2" | ok="$4" | fail="$5" | ftot="$7" | "$11}' $C
echo "--- totals ---"
awk -F, 'NR>1{ok+=$4; f+=$5} END{print "okSum="ok" failSum="f}' $C
echo "last: $(awk -F, 'END{print $3" | "$2" | okTot="$6" | failTot="$7}' $C)"
