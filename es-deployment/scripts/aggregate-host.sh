#!/bin/bash
# Aggregate /tmp/hostmetrics.csv on the node, print small summary (no truncation risk).
# Drops first and last data rows to avoid idle edges.
F=/tmp/hostmetrics.csv
awk -F, 'NR>1{ rows[++n]=$0 }
END{
  if(n<3){ print "host='"$(hostname)"' samples=0"; exit }
  si=0; sb=0; ss=0; srx=0; stx=0; cnt=0; peak=0;
  for(i=2;i<n;i++){            # skip first(i=1) and last(i=n) data rows
    split(rows[i],a,",");
    si+=a[3]; sb+=a[4]; ss+=a[5]; srx+=a[6]; stx+=a[7]; cnt++;
    if(a[4]>peak) peak=a[4];
  }
  printf "host=%s samples=%d idle=%.2f busy=%.2f softirq=%.3f rx=%.1f tx=%.1f peak=%.2f\n",
    "'"$(hostname)"'", cnt, si/cnt, sb/cnt, ss/cnt, srx/cnt, stx/cnt, peak;
}' "$F"
