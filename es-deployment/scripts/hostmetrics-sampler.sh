#!/bin/bash
# Dependency-free host metrics sampler. Reads /proc/stat and /proc/net/dev.
# Writes CSV: epoch,cpu_idle_pct,cpu_busy_pct,softirq_pct,rx_pps,tx_pps
# Works on CentOS7 and Rocky9. Samples every 5s until 'stop' file appears.
OUT=/tmp/hostmetrics.csv
STOP=/tmp/hostmetrics.stop
INTERVAL=5
rm -f "$STOP"

# detect primary NIC via default route
NIC=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
[ -z "$NIC" ] && NIC=eth0

read_cpu() {
  # returns: total idle softirq
  awk '/^cpu /{
    total=0; for(i=2;i<=NF;i++) total+=$i;
    idle=$5+$6; softirq=$8;
    print total, idle, softirq; exit
  }' /proc/stat
}
read_net() {
  # returns: rx_packets tx_packets for $NIC
  awk -v nic="$NIC:" '$1==nic{print $3, $11; exit}' /proc/net/dev
}

echo "epoch,nic,cpu_idle_pct,cpu_busy_pct,softirq_pct,rx_pps,tx_pps" > "$OUT"

read pt pi ps < <(read_cpu)
read prx ptx < <(read_net)

while [ ! -f "$STOP" ]; do
  sleep "$INTERVAL"
  read ct ci cs < <(read_cpu)
  read crx ctx < <(read_net)
  dt=$((ct-pt)); di=$((ci-pi)); ds=$((cs-ps))
  if [ "$dt" -gt 0 ]; then
    idle_pct=$(awk -v a=$di -v b=$dt 'BEGIN{printf "%.2f", 100*a/b}')
    busy_pct=$(awk -v a=$di -v b=$dt 'BEGIN{printf "%.2f", 100*(b-a)/b}')
    sirq_pct=$(awk -v a=$ds -v b=$dt 'BEGIN{printf "%.2f", 100*a/b}')
  else
    idle_pct=0; busy_pct=0; sirq_pct=0
  fi
  rx_pps=$(awk -v a=$((crx-prx)) -v t=$INTERVAL 'BEGIN{printf "%.1f", a/t}')
  tx_pps=$(awk -v a=$((ctx-ptx)) -v t=$INTERVAL 'BEGIN{printf "%.1f", a/t}')
  echo "$(date +%s),$NIC,$idle_pct,$busy_pct,$sirq_pct,$rx_pps,$tx_pps" >> "$OUT"
  pt=$ct; pi=$ci; ps=$cs; prx=$crx; ptx=$ctx
done
