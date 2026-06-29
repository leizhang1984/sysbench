#!/usr/bin/env bash
# Per-second aggregate for a scenario, compact output for charting.
# Usage: fo-aggregate.sh <tag> <fault_epoch_hint_ignored>
TAG="$1"
F=/tmp/fo_requests_${TAG}.csv
S=/tmp/fo_state_${TAG}.csv
# Build per-second status map from state CSV (floor of ts_epoch -> status)
awk -F, 'NR>1{sec=int($2); st[sec]=$3}
  END{for(s in st) print s","st[s]}' "$S" > /tmp/agg_state_${TAG}.txt
# Per-second ok/fail from requests, join status
awk -F, -v sf=/tmp/agg_state_${TAG}.txt '
  BEGIN{ while((getline line < sf)>0){ split(line,a,","); status[a[1]]=a[2] } }
  NR>1{ sec=int($2); tot[sec]++; if($4==1) ok[sec]++; else fail[sec]++ }
  END{
    n=0; for(s in tot){ secs[n++]=s }
    # sort
    for(i=0;i<n;i++) for(j=i+1;j<n;j++) if(secs[j]<secs[i]){t=secs[i];secs[i]=secs[j];secs[j]=t}
    base=secs[0];
    for(i=0;i<n;i++){ s=secs[i];
      printf "%d,%d,%d,%s\n", s-base, (ok[s]?ok[s]:0), (fail[s]?fail[s]:0), (status[s]?status[s]:"-")
    }
  }' "$F"
