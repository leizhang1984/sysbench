#!/bin/bash
RUNDIR="${1:-/opt/probe/run1}"
echo "metrics_tail:"
tail -n 3 "$RUNDIR/metrics.csv" 2>/dev/null
echo "cluster_tail:"
tail -n 3 "$RUNDIR/cluster.csv" 2>/dev/null
echo "run_active=$(systemctl is-active probe-run.service)"
echo "collector_active=$(systemctl is-active probe-collector.service)"
echo "metrics_lines=$(wc -l < "$RUNDIR/metrics.csv" 2>/dev/null)"
