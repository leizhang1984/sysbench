#!/bin/bash
# Launch the failover probe + cluster collector as systemd transient units so
# they survive run-command client disconnects. Args via env or positional:
#   $1 rundir (e.g. /opt/probe/run1)  $2 seconds  $3 rate  $4 threads
. /etc/profile.d/rocketmq.sh
RUN="${1:-/opt/probe/run1}"
SECONDS_RUN="${2:-180}"
RATE="${3:-2000}"
THREADS="${4:-8}"
rm -rf "$RUN"; mkdir -p "$RUN"
CP=$(echo /opt/rocketmq-4.9.7/lib/*.jar | tr ' ' ':'):/opt/probe

# cluster collector
systemctl reset-failed probe-collector.service 2>/dev/null || true
systemd-run --unit=probe-collector --description='cluster leader collector' \
  /bin/bash /opt/probe/collect-cluster.sh "$RUN"

# the probe itself
systemctl reset-failed probe-run.service 2>/dev/null || true
systemd-run --unit=probe-run --description='rocketmq failover probe' \
  /usr/bin/java -cp "$CP" \
  -Dnamesrv="$NAMESRV_ADDR" -Dtopic=FailoverTopic \
  -Dthreads="$THREADS" -Drate="$RATE" -Dsize=512 -Dseconds="$SECONDS_RUN" \
  -Doutdir="$RUN" FailoverProbe

echo "probe launched: rundir=$RUN seconds=$SECONDS_RUN rate=$RATE threads=$THREADS"
sleep 6
echo "--- first metrics ---"
sleep 4
tail -n 3 "$RUN/metrics.csv" 2>/dev/null || echo "no metrics yet"
echo "probe-run: $(systemctl is-active probe-run.service)"
