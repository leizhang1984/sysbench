#!/bin/bash
# Background collector: every 1s append leader (BID 0) addrs of both groups.
# Stops when /opt/probe/<rundir>/STOP exists. Arg1: run dir.
. /etc/profile.d/rocketmq.sh
RUN="${1:-/opt/probe/run}"
mkdir -p "$RUN"
CSV="$RUN/cluster.csv"
echo "epoch_ms,wallclock,broker_a_leader,broker_b_leader" > "$CSV"
while [ ! -f "$RUN/STOP" ]; do
  OUT=$(mqadmin clusterList -n "$NAMESRV_ADDR" 2>/dev/null)
  A=$(echo "$OUT" | awk '$2=="broker-a" && $3=="0"{print $4}')
  B=$(echo "$OUT" | awk '$2=="broker-b" && $3=="0"{print $4}')
  printf "%d,%s,%s,%s\n" "$(date +%s%3N)" "$(date +%H:%M:%S.%3N)" "${A:-NONE}" "${B:-NONE}" >> "$CSV"
  sleep 1
done
echo "collector stopped"
