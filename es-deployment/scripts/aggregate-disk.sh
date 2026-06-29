#!/bin/bash
# Stop disk sampler and aggregate stats over the active (non-idle) window.
touch /tmp/diskmetrics.stop
pkill -f diskmetrics-sampler.sh 2>/dev/null
sleep 2
F=/tmp/diskmetrics.csv
awk -F, 'NR>1{
  wio[++n]=$3; wmb[n]=$4; util[n]=$6; cpu[n]=$7;
}
END{
  if(n==0){ print "host='"$(hostname)"' no_data"; exit }
  # active window = rows where wr_mbps>1 (real indexing IO)
  amax_util=0; amax_mb=0; amax_iops=0; sumutil=0; summb=0; sumiops=0; sumcpu=0; ac=0;
  for(i=1;i<=n;i++){
    if(wmb[i]>1){
      ac++; sumutil+=util[i]; summb+=wmb[i]; sumiops+=wio[i]; sumcpu+=cpu[i];
      if(util[i]>amax_util) amax_util=util[i];
      if(wmb[i]>amax_mb) amax_mb=wmb[i];
      if(wio[i]>amax_iops) amax_iops=wio[i];
    }
  }
  if(ac==0){ ac=1 }
  printf "host=%s total_s=%d active_s=%d | AVG util=%.1f%% wr=%.1fMBps iops=%.0f cpu=%.1f%% | PEAK util=%.1f%% wr=%.1fMBps iops=%.0f\n",
    "'"$(hostname)"'", n, ac, sumutil/ac, summb/ac, sumiops/ac, sumcpu/ac, amax_util, amax_mb, amax_iops;
}' "$F"
