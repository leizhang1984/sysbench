#!/bin/bash
# Disk + CPU sampler for the data device. Reads /proc/diskstats and /proc/stat every 1s.
# CSV: epoch,dev,wr_iops,wr_mbps,rd_mbps,util_pct,cpu_busy_pct
OUT=/tmp/diskmetrics.csv
STOP=/tmp/diskmetrics.stop
INTERVAL=1
rm -f "$STOP" "$OUT"

# detect data device backing /esdata
SRC=$(findmnt -no SOURCE /esdata 2>/dev/null)      # e.g. /dev/sdb or /dev/nvme0n2
DEV=$(basename "$SRC")
[ -z "$DEV" ] && DEV=sdb

read_disk() {
  # fields after name: $4 rd_ios .. $6 rd_sectors .. $8 wr_ios .. $10 wr_sectors .. $13 io_ticks_ms
  awk -v d="$DEV" '$3==d{print $8, $10, $6, $13; exit}' /proc/diskstats
}
read_cpu() {
  awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; idle=$5+$6; print t, idle; exit}' /proc/stat
}

echo "epoch,dev,wr_iops,wr_mbps,rd_mbps,util_pct,cpu_busy_pct" > "$OUT"
read pw psw prs pticks < <(read_disk)
read pct pidle < <(read_cpu)

while [ ! -f "$STOP" ]; do
  sleep "$INTERVAL"
  read cw csw crs cticks < <(read_disk)
  read cct cidle < <(read_cpu)
  d_wios=$((cw-pw)); d_wsec=$((csw-psw)); d_rsec=$((crs-prs)); d_ticks=$((cticks-pticks))
  wr_iops=$(awk -v a=$d_wios -v t=$INTERVAL 'BEGIN{printf "%.1f", a/t}')
  wr_mbps=$(awk -v a=$d_wsec 'BEGIN{printf "%.2f", a*512/1048576}')   # per 1s interval
  rd_mbps=$(awk -v a=$d_rsec 'BEGIN{printf "%.2f", a*512/1048576}')
  util=$(awk -v a=$d_ticks -v t=$INTERVAL 'BEGIN{printf "%.1f", (a/(t*1000))*100}')
  dct=$((cct-pct)); didle=$((cidle-pidle))
  cpu=$(awk -v b=$dct -v i=$didle 'BEGIN{ if(b>0) printf "%.1f", 100*(b-i)/b; else print 0}')
  echo "$(date +%s),$DEV,$wr_iops,$wr_mbps,$rd_mbps,$util,$cpu" >> "$OUT"
  pw=$cw; psw=$csw; prs=$crs; pticks=$cticks; pct=$cct; pidle=$cidle
done
