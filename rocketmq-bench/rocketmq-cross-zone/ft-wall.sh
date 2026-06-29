#!/bin/bash
for R in ftC ftD ftB1; do
  C=/opt/probe/ft_${R}.csv
  [ -f "$C" ] || { echo "===== $R : NO CSV ====="; continue; }
  echo "===== $R ====="
  echo "header: $(head -1 $C)"
  echo "first-data: $(awk -F, 'NR==2{print}' $C)"
  echo "--- rows with fail/s>0 : sec | wall | ok/s | fail/s | fail_total ---"
  awk -F, 'NR>1 && ($5+0)>0 {print $3" | "$2" | ok="$4" | fail="$5" | ftot="$7}' $C | head -60
  echo "last-data: $(awk -F, 'END{print $3" | "$2" | ftot="$7}' $C)"
done
