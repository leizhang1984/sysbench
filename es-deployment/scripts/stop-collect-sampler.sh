#!/bin/bash
# Stop the sampler and emit hostmetrics.csv as gzip+base64.
touch /tmp/hostmetrics.stop
pkill -f hostmetrics-sampler.sh 2>/dev/null
sleep 6
echo "===HOST=== $(hostname)"
echo "===LINES=== $(wc -l < /tmp/hostmetrics.csv 2>/dev/null)"
echo "===CSV_B64==="
gzip -c /tmp/hostmetrics.csv 2>/dev/null | base64 -w0
echo ""
echo "===END==="
