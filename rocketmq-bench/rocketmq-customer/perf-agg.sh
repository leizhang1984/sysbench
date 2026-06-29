#!/bin/bash
# Aggregate per-run TPS stats (skip first warmup line per run).
for f in main_w64_d300 sweep_w16_d120 sweep_w32_d120 sweep_w64_d120 sweep_w128_d120; do
  L=/opt/perf/$f.log
  [ -f "$L" ] || continue
  echo "=== $f ==="
  grep 'Send TPS' "$L" | awk '
    { tps=$0; sub(/.*Send TPS: /,"",tps); sub(/ .*/,"",tps);
      rt=$0; sub(/.*Average RT\(ms\): */,"",rt); sub(/ .*/,"",rt);
      mx=$0; sub(/.*Max RT\(ms\): /,"",mx); sub(/ .*/,"",mx);
      fail=$0; sub(/.*Send Failed: /,"",fail); sub(/ .*/,"",fail);
      n++; if(n>1){ st+=tps; sc++; if(tps>mxtps)mxtps=tps; if(mintps==0||tps<mintps)mintps=tps; srt+=rt; if(mx>maxrt)maxrt=mx; tf+=fail } }
    END{ if(sc>0) printf "samples=%d avgTPS=%d minTPS=%d maxTPS=%d avgRT=%.3fms maxRT=%dms totalFail(per10s sum)=%d\n", sc, st/sc, mintps, mxtps, srt/sc, maxrt, tf }'
done
