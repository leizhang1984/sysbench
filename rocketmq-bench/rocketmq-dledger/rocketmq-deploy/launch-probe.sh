#!/bin/bash
# Clean previous run units/dirs and launch a fresh probe + collector.
# args: <rundir> <seconds> <rate> <threads>
RUNDIR="${1:-/opt/probe/run1}"
SECONDS_RUN="${2:-300}"
RATE="${3:-2000}"
THREADS="${4:-8}"

systemctl stop probe-run.service 2>/dev/null
systemctl stop probe-collector.service 2>/dev/null
systemctl reset-failed probe-run.service 2>/dev/null
systemctl reset-failed probe-collector.service 2>/dev/null
sleep 2
rm -rf "$RUNDIR"
mkdir -p "$RUNDIR"
source /etc/profile.d/rocketmq.sh
CP="/opt/rocketmq-4.9.7/lib/*:/opt/probe"

systemd-run --unit=probe-collector --setenv=NAMESRV_ADDR="$NAMESRV_ADDR" \
  /bin/bash /opt/probe/collect-cluster.sh "$RUNDIR"

systemd-run --unit=probe-run \
  /usr/bin/java -cp "$CP" \
    -Dnamesrv="$NAMESRV_ADDR" -Dtopic=FailoverTopic -Dthreads=$THREADS \
    -Drate=$RATE -Dsize=512 -Dseconds=$SECONDS_RUN -Doutdir="$RUNDIR" \
    FailoverProbe

sleep 5
echo "launched rundir=$RUNDIR seconds=$SECONDS_RUN rate=$RATE threads=$THREADS"
echo "run_active=$(systemctl is-active probe-run.service)"
echo "collector_active=$(systemctl is-active probe-collector.service)"
echo "first_metrics:"
tail -n 3 "$RUNDIR/metrics.csv" 2>/dev/null
