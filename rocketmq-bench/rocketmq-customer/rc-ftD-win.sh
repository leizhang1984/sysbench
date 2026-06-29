#!/bin/bash
echo "=== GRACEFUL LOG ==="; cat /opt/ft/graceful.log
echo "=== ftD rows fail/err ==="
awk -F, 'NR==1{next} ($5>0)||($11!=""){print $2" sec="$3" ok="$4" fail="$5" tot="$6" err="$11}' /opt/probe/ft_ftD.csv | head -40
echo "=== ftD tail ==="; tail -1 /opt/probe/ft_ftD.csv; tail -2 /opt/probe/produce_ftD.log; wc -l /opt/probe/ft_ftD.csv
