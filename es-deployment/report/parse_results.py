#!/usr/bin/env python3
# Parse esrally CSV (gzip+b64) and host metrics CSV (gzip+b64) collected from VMs.
# Emits summary.json for the report generator.
import base64, gzip, io, json, re, csv, os

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
OUT  = os.path.join(DATA, "summary.json")

def extract_block(text, marker):
    # returns the single-line base64 after the marker line
    lines = text.splitlines()
    for i, ln in enumerate(lines):
        if marker in ln:
            # next non-empty line is the b64 payload
            for j in range(i+1, len(lines)):
                if lines[j].strip() and "===" not in lines[j]:
                    return lines[j].strip()
    return None

def b64gz_to_text(b64):
    raw = base64.b64decode(b64)
    return gzip.decompress(raw).decode("utf-8", errors="replace")

def parse_rally_csv(text):
    # esrally csv: Metric,Task,Value,Unit  (no header)
    metrics = {}
    rdr = csv.reader(io.StringIO(text))
    for row in rdr:
        if len(row) < 4:
            continue
        metric, task, value, unit = row[0].strip(), row[1].strip(), row[2].strip(), row[3].strip()
        try:
            v = float(value)
        except ValueError:
            continue
        metrics.setdefault(task or "_global", {})[metric] = (v, unit)
    return metrics

def parse_host_agg(path):
    # lines: host=NAME samples=N idle=.. busy=.. softirq=.. rx=.. tx=.. peak=..
    out = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for ln in f:
            ln = ln.strip()
            if not ln.startswith("host="):
                continue
            kv = {}
            for tok in ln.split():
                if "=" in tok:
                    k, v = tok.split("=", 1)
                    kv[k] = v
            name = kv.get("host")
            if not name:
                continue
            out[name] = {
                "samples": int(kv.get("samples", 0)),
                "cpu_idle_pct": round(float(kv.get("idle", 0)), 2),
                "cpu_busy_pct": round(float(kv.get("busy", 0)), 2),
                "softirq_pct": round(float(kv.get("softirq", 0)), 3),
                "rx_pps": round(float(kv.get("rx", 0)), 1),
                "tx_pps": round(float(kv.get("tx", 0)), 1),
                "cpu_busy_peak": round(float(kv.get("peak", 0)), 2),
            }
    return out

def avg(xs):
    return sum(xs)/len(xs) if xs else 0.0

def load_rally(label, fname):
    with open(os.path.join(DATA, fname), encoding="utf-8", errors="replace") as f:
        text = f.read()
    b64 = extract_block(text, "CSV_B64")
    csv_text = b64gz_to_text(b64)
    return parse_rally_csv(csv_text), csv_text

result = {"durations": {"dsv5": 2247, "dsv6": 2223}, "rally": {}, "host": {}}

HOST_AGG = parse_host_agg(os.path.join(DATA, "host-agg.txt"))

for label, fname in [("dsv5", "rally-dsv5-b64.txt"), ("dsv6", "rally-dsv6-b64.txt")]:
    metrics, raw = load_rally(label, fname)
    result["rally"][label] = metrics
    # save decoded csv for the appendix
    with open(os.path.join(DATA, f"rally-{label}.csv"), "w", encoding="utf-8") as f:
        f.write(raw)

host_nodes = {
    "dsv5": ["dsv5esmasterdata01","dsv5esmasterdata02","dsv5esmasterdata03"],
    "dsv6": ["dsv6esmasterdata01","dsv6esmasterdata02","dsv6esmasterdata03"],
}
for grp, nodes in host_nodes.items():
    result["host"][grp] = {}
    for n in nodes:
        result["host"][grp][n] = HOST_AGG.get(n, {})

with open(OUT, "w", encoding="utf-8") as f:
    json.dump(result, f, indent=2, default=str)

# quick console dump of key metrics
def g(metrics, task, metric):
    return metrics.get(task, {}).get(metric, (None,None))[0]

print("=== RALLY KEY METRICS ===")
for label in ("dsv5","dsv6"):
    m = result["rally"][label]
    # index throughput task is usually 'index-append'
    print(f"\n--- {label} tasks: {sorted(m.keys())}")
print("\nWrote", OUT)
