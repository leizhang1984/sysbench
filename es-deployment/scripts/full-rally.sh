#!/bin/bash
# Full geonames benchmark. Args: $1=cluster-label $2,$3,$4=node IPs
LABEL="$1"; shift
HOSTS="$1:9200,$2:9200,$3:9200"
source /etc/profile.d/esrally.sh 2>/dev/null
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk}

CSV=/tmp/rally-$LABEL.csv
LOG=/tmp/rally-$LABEL.log
META=/tmp/rally-$LABEL.meta

START=$(date +%s)
echo "race_start_epoch=$START" > "$META"
echo "cluster=$LABEL" >> "$META"
echo "hosts=$HOSTS" >> "$META"

esrally race \
  --track=geonames \
  --challenge=append-no-conflicts \
  --pipeline=benchmark-only \
  --target-hosts="$HOSTS" \
  --report-format=csv \
  --report-file="$CSV" \
  --kill-running-processes \
  --on-error=abort > "$LOG" 2>&1
RC=$?

END=$(date +%s)
echo "race_end_epoch=$END" >> "$META"
echo "exit_code=$RC" >> "$META"
echo "duration_sec=$((END-START))" >> "$META"
echo "=== $LABEL done rc=$RC dur=$((END-START))s ==="
tail -n 5 "$LOG"
