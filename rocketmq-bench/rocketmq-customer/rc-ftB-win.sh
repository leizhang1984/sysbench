#!/bin/bash
echo "=== SIGSTOP LOG ==="
cat /opt/ft/sigstop.log
echo "=== rows with err/fail (ftB) ==="
awk -F, 'NR==1{next} ($5>0)||($11!=""){print $2" sec="$4" ok="$5" tot="$6" err="$11}' /opt/probe/ft_ftB.csv
echo "=== total lines ==="; wc -l /opt/probe/ft_ftB.csv
