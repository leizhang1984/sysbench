#!/bin/bash
echo "=== SIGSTOP LOG ==="; cat /opt/ft/sigstop.log
echo "=== ftB1 raw fail rows ==="
awk -F, 'NR==1{next} ($5>0){print $2" sec="$3" ok="$4" fail="$5" tot="$6" errc="$7" err="$11}' /opt/probe/ft_ftB1.csv
echo "=== totals ==="; tail -1 /opt/probe/ft_ftB1.csv; tail -2 /opt/probe/produce_ftB1.log
