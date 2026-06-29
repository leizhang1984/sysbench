#!/bin/bash
ls -la /opt/probe/ 2>/dev/null
echo "--- ftB summary ---"; tail -3 /opt/probe/produce_ftB.log 2>/dev/null
echo "--- ftB1 summary ---"; tail -3 /opt/probe/produce_ftB1.log 2>/dev/null
for R in ftB ftB1; do C=/opt/probe/ft_$R.csv; [ -f "$C" ] || { echo "$R NO CSV"; continue; }; echo "== $R fail>0 =="; awk -F, 'NR>1 && ($5+0)>0{print $3" "$2" ok="$4" fail="$5" ftot="$7}' "$C"|head -40; echo "$R last: $(tail -1 $C)"; done
