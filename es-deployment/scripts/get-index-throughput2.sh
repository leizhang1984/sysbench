#!/bin/bash
LABEL="$1"
echo "===FULL SUMMARY TABLE $LABEL==="
# Print from the metrics summary table to end; covers throughput rows.
awk '/Metric/{p=1} p{print}' /tmp/rally-$LABEL.log | grep -iE "Throughput|index-append|indexing|Error|docs/s" | head -n 40
echo "===tail of log==="
tail -n 60 /tmp/rally-$LABEL.log | grep -iE "index-append|Throughput|indexing" | head -n 30
