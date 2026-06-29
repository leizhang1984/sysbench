#!/bin/bash
RUNDIR="${1:-/opt/probe/run1}"
systemctl reset-failed probe-collector.service 2>/dev/null
systemctl stop probe-collector.service 2>/dev/null
sleep 1
source /etc/profile.d/rocketmq.sh
systemd-run --unit=probe-collector --setenv=NAMESRV_ADDR="$NAMESRV_ADDR" /bin/bash /opt/probe/collect-cluster.sh "$RUNDIR"
sleep 3
echo "collector_active=$(systemctl is-active probe-collector.service)"
echo "cluster_csv_tail:"
tail -n 5 "$RUNDIR/cluster.csv" 2>/dev/null
