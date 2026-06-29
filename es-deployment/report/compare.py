#!/usr/bin/env python3
# Build a clean comparison from summary.json
import json, os

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
with open(os.path.join(DATA, "summary.json"), encoding="utf-8") as f:
    S = json.load(f)

def gv(label, task, metric):
    t = S["rally"][label].get(task, {})
    v = t.get(metric)
    return v[0] if v else None

QUERY_TASKS = ["default","term","phrase","country_agg_uncached","country_agg_cached",
               "scroll","expression","painless_static","painless_dynamic",
               "large_terms","large_filtered_terms","large_prohibited_terms"]

print("\n=== INDEXING (lower time = better) ===")
for label in ("dsv5","dsv6"):
    g = S["rally"][label]["_global"]
    print(f"{label}: race_dur={S['durations'][label]}s  "
          f"cum_index_time={g['Cumulative indexing time of primary shards'][0]:.3f}min  "
          f"cum_merge_time={g['Cumulative merge time of primary shards'][0]:.3f}min  "
          f"young_gc={g['Total Young Gen GC time'][0]:.2f}s  "
          f"store={g['Store size'][0]:.3f}GB  segs={g['Segment count'][0]:.0f}")

print("\n=== QUERY THROUGHPUT (ops/s, mean) ===")
print(f"{'task':<24}{'dsv5':>10}{'dsv6':>10}")
for t in QUERY_TASKS:
    a = gv('dsv5', t, 'Mean Throughput')
    b = gv('dsv6', t, 'Mean Throughput')
    if a is None: continue
    print(f"{t:<24}{a:>10.2f}{b:>10.2f}")

for pct in ("50th","90th","99th"):
    metric = f"{pct} percentile service time"
    print(f"\n=== {metric} (ms, lower=better; impr% = (v5-v6)/v5) ===")
    print(f"{'task':<24}{'dsv5':>10}{'dsv6':>10}{'impr%':>9}")
    for t in QUERY_TASKS:
        a = gv('dsv5', t, metric)
        b = gv('dsv6', t, metric)
        if a is None or b is None: continue
        impr = (a-b)/a*100
        print(f"{t:<24}{a:>10.2f}{b:>10.2f}{impr:>8.1f}%")

print("\n=== HOST METRICS (avg over window) ===")
for grp in ("dsv5","dsv6"):
    print(f"-- {grp} --")
    for n, h in S["host"][grp].items():
        print(f"  {n}: idle={h['cpu_idle_pct']}% busy={h['cpu_busy_pct']}% "
              f"softirq={h['softirq_pct']}% rx={h['rx_pps']}pps tx={h['tx_pps']}pps "
              f"peak_busy={h['cpu_busy_peak']}% n={h['samples']}")
