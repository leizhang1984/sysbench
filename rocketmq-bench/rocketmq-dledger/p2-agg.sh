#!/bin/bash
# Aggregate P2 benchmark results from /tmp/p2bench/*.log
OUT=/tmp/p2bench
echo "===== timeline ====="
cat $OUT/timeline.log 2>/dev/null
for tag in main_64x300 scan_16 scan_32 scan_64 scan_128; do
  f=$OUT/$tag.log
  [ -f "$f" ] || { echo "[$tag] missing"; continue; }
  # Send TPS lines; skip first (warmup) sample. Compute avg/min/max TPS, avg/max RT, total failed.
  awk -v tag="$tag" '
    /Send TPS/ {
      n++
      # fields: ... "Send TPS:" V ... "Max RT(ms):" V ... "Average RT(ms):" V ... "Send Failed:" V
      for(i=1;i<=NF;i++){
        if($i=="TPS:"){tps=$(i+1)}
        if($i=="RT(ms):" && prev=="Max"){maxrt=$(i+1)}
        if($i=="RT(ms):" && prev=="Average"){art=$(i+1)}
        if($i=="Failed:" && prev=="Send"){sf=$(i+1)}
        prev=$i
      }
      if(n==1) next   # skip warmup
      c++; sumtps+=tps; sumrt+=art; fail+=sf
      if(mintps==""||tps<mintps)mintps=tps
      if(tps>maxtps)maxtps=tps
      if(maxrt>maxrtall)maxrtall=maxrt
    }
    END{
      if(c>0) printf "[%s] samples=%d avgTPS=%.0f minTPS=%.0f maxTPS=%.0f avgRT=%.3fms maxRT=%.0fms failed=%d\n", tag, c, sumtps/c, mintps, maxtps, sumrt/c, maxrtall, fail
      else printf "[%s] no usable samples\n", tag
    }' "$f"
done
