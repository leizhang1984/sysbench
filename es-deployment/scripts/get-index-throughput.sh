#!/bin/bash
# Extract indexing (index-append) throughput lines from the rally run log.
LABEL="$1"
echo "===INDEX REPORT $LABEL==="
grep -iE "index-append|Cumulative indexing|Total indexing|docs/s|Min Throughput|Mean Throughput|Median Throughput|Max Throughput" /tmp/rally-$LABEL.log | grep -iE "index-append|indexing|docs/s" | head -n 30
echo "===RAW index-append block==="
awk '/index-append/{p=1} p&&/index-append/{print} /index-stats/{p=0}' /tmp/rally-$LABEL.log | head -n 40
