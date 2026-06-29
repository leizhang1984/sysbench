#!/bin/bash
# Index-only geonames run to measure disk behaviour during bulk indexing.
LABEL="$1"; shift
HOSTS="$1:9200,$2:9200,$3:9200"
source /etc/profile.d/esrally.sh 2>/dev/null
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk}
CSV=/tmp/rally-idx-$LABEL.csv
LOG=/tmp/rally-idx-$LABEL.log
META=/tmp/rally-idx-$LABEL.meta
START=$(date +%s); echo "idx_start=$START" > "$META"
esrally race \
  --track=geonames \
  --challenge=append-no-conflicts \
  --include-tasks="delete-index,create-index,cluster-health,index-append" \
  --pipeline=benchmark-only \
  --target-hosts="$HOSTS" \
  --report-format=csv --report-file="$CSV" \
  --kill-running-processes --on-error=abort > "$LOG" 2>&1
RC=$?
END=$(date +%s); echo "idx_end=$END" >> "$META"; echo "rc=$RC dur=$((END-START))" >> "$META"
echo "=== $LABEL index-only rc=$RC dur=$((END-START))s ==="
tail -n 6 "$LOG"
