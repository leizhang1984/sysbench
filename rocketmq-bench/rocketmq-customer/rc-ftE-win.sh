#!/bin/bash
echo "=== ftE summary ==="
wc -l /opt/probe/ft_ftE.csv
tail -2 /opt/probe/produce_ftE.log
echo "=== rows with fail/err (first 80) ==="
awk -F, 'NR>1 && (($5>0)||($11!="")){print $2" sec="$3" ok="$4" fail="$5" tot="$6" err="$11}' /opt/probe/ft_ftE.csv | head -80
echo "=== tail ==="
tail -12 /opt/probe/ft_ftE.csv
