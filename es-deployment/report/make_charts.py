"""Generate DSv5 vs DSv6 esrally benchmark comparison charts for the ES report.
Reads summary.json produced by parse_results.py. Outputs PNGs into images/.
"""
import os, json
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "images")
os.makedirs(OUT, exist_ok=True)
with open(os.path.join(HERE, "data", "summary.json"), encoding="utf-8") as f:
    S = json.load(f)

C5, C6 = "#4C78A8", "#E45756"  # dsv5 blue, dsv6 red

def gv(label, task, metric):
    t = S["rally"][label].get(task, {})
    v = t.get(metric)
    return v[0] if v else None

# tasks grouped by latency scale for readability
LIGHT = ["default", "term", "phrase", "country_agg_cached", "index-stats", "node-stats"]
HEAVY = ["country_agg_uncached", "scroll", "expression", "painless_static",
         "painless_dynamic", "large_terms", "large_filtered_terms", "large_prohibited_terms"]
LABELS = {
    "country_agg_uncached": "country_agg\nuncached",
    "country_agg_cached": "country_agg\ncached",
    "large_filtered_terms": "large_filtered\nterms",
    "large_prohibited_terms": "large_prohib\nterms",
    "painless_static": "painless\nstatic",
    "painless_dynamic": "painless\ndynamic",
}

def lbl(t):
    return LABELS.get(t, t)

def grouped_bar(ax, tasks, metric, title, ylabel, log=False):
    d5 = [gv("dsv5", t, metric) or 0 for t in tasks]
    d6 = [gv("dsv6", t, metric) or 0 for t in tasks]
    x = np.arange(len(tasks)); w = 0.38
    b5 = ax.bar(x - w/2, d5, w, label="DSv5", color=C5)
    b6 = ax.bar(x + w/2, d6, w, label="DSv6", color=C6)
    ax.set_title(title, fontsize=11)
    ax.set_xticks(x); ax.set_xticklabels([lbl(t) for t in tasks], fontsize=8, rotation=0)
    ax.set_ylabel(ylabel)
    if log: ax.set_yscale("log")
    ax.grid(axis="y", ls=":", alpha=0.5)
    for b in list(b5)+list(b6):
        v = b.get_height()
        ax.text(b.get_x()+b.get_width()/2, v, f"{v:.0f}" if v>=10 else f"{v:.1f}",
                ha="center", va="bottom", fontsize=7)

# ---- 1. Service time percentiles for light queries ----
fig, axes = plt.subplots(3, 1, figsize=(11, 11))
for ax, pct in zip(axes, ("50th", "90th", "99th")):
    grouped_bar(ax, LIGHT, f"{pct} percentile service time",
                f"Light queries - {pct} pct service time (ms)", "ms")
h, l = axes[0].get_legend_handles_labels()
fig.legend(h, l, loc="upper right", ncol=2)
fig.suptitle("DSv5 vs DSv6 | Service time | Light queries (lower=better)", fontsize=13, y=1.0)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "svc_light.png"), dpi=130, bbox_inches="tight"); plt.close(fig)
print("wrote svc_light.png")

# ---- 2. Service time percentiles for heavy queries ----
fig, axes = plt.subplots(3, 1, figsize=(11, 12))
for ax, pct in zip(axes, ("50th", "90th", "99th")):
    grouped_bar(ax, HEAVY, f"{pct} percentile service time",
                f"Heavy queries - {pct} pct service time (ms)", "ms")
h, l = axes[0].get_legend_handles_labels()
fig.legend(h, l, loc="upper right", ncol=2)
fig.suptitle("DSv5 vs DSv6 | Service time | Heavy queries (lower=better)", fontsize=13, y=1.0)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "svc_heavy.png"), dpi=130, bbox_inches="tight"); plt.close(fig)
print("wrote svc_heavy.png")

# ---- 3. Improvement split into two clear charts ----
ALL = LIGHT[:4] + HEAVY  # skip index/node-stats meta for the improvement view
x = np.arange(len(ALL)); w = 0.38
imp90, imp99 = [], []
d5_p99, d6_p99 = [], []
for t in ALL:
    a90, b90 = gv("dsv5", t, "90th percentile service time"), gv("dsv6", t, "90th percentile service time")
    a99, b99 = gv("dsv5", t, "99th percentile service time"), gv("dsv6", t, "99th percentile service time")
    imp90.append((a90-b90)/a90*100 if a90 else 0)
    imp99.append((a99-b99)/a99*100 if a99 else 0)
    d5_p99.append(a99 or 0)
    d6_p99.append(b99 or 0)

# 3a) Improvement percentages only
fig, ax = plt.subplots(1, 1, figsize=(12, 5.6))
b1 = ax.bar(x - w/2, imp90, w, label="p90 improvement", color="#54A24B")
b2 = ax.bar(x + w/2, imp99, w, label="p99 improvement", color="#B279A2")
ax.axhline(0, color="#444", lw=0.8)
ax.set_xticks(x); ax.set_xticklabels([lbl(t) for t in ALL], fontsize=8)
ax.set_ylabel("DSv6 service-time reduction vs DSv5 (%)")
ax.set_title("Per-task DSv6 improvement over DSv5 (higher=better)", fontsize=12)
ax.grid(axis="y", ls=":", alpha=0.5)
ax.legend(loc="upper right", fontsize=9)
for b in list(b1)+list(b2):
    v = b.get_height()
    ax.text(b.get_x()+b.get_width()/2, v, f"{v:.0f}%", ha="center",
            va="bottom" if v>=0 else "top", fontsize=7)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "improvement_pct.png"), dpi=130, bbox_inches="tight"); plt.close(fig)
print("wrote improvement_pct.png")

# 3b) Absolute DSv5/DSv6 p99 baseline only
fig, ax = plt.subplots(1, 1, figsize=(12, 5.6))
l1, = ax.plot(x, d5_p99, color=C5, marker="o", lw=2.0, ms=5, label="DSv5 p99 (ms)")
l2, = ax.plot(x, d6_p99, color=C6, marker="o", lw=2.0, ms=5, label="DSv6 p99 (ms)")
ax.fill_between(x, d5_p99, d6_p99, where=np.array(d5_p99) >= np.array(d6_p99), color="#54A24B", alpha=0.12)
ax.set_xticks(x); ax.set_xticklabels([lbl(t) for t in ALL], fontsize=8)
ax.set_ylabel("p99 service time (ms)")
ax.set_title("Per-task p99 baseline: DSv5 vs DSv6 (lower=better)", fontsize=12)
ax.grid(axis="y", ls=":", alpha=0.5)
ax.legend(loc="upper right", fontsize=9)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "improvement_baseline.png"), dpi=130, bbox_inches="tight"); plt.close(fig)
print("wrote improvement_baseline.png")

# Keep compatibility export for existing references
fig, axes = plt.subplots(2, 1, figsize=(12, 9), gridspec_kw={"height_ratios": [1.25, 1.0]})
ax_top, ax_bottom = axes
ax_top.bar(x - w/2, imp90, w, label="p90 improvement", color="#54A24B")
ax_top.bar(x + w/2, imp99, w, label="p99 improvement", color="#B279A2")
ax_top.axhline(0, color="#444", lw=0.8)
ax_top.set_xticks(x); ax_top.set_xticklabels([lbl(t) for t in ALL], fontsize=8)
ax_top.set_ylabel("Improvement (%)")
ax_top.set_title("DSv6 improvement percentages", fontsize=11)
ax_top.grid(axis="y", ls=":", alpha=0.5)
ax_top.legend(loc="upper right", fontsize=8)

ax_bottom.plot(x, d5_p99, color=C5, marker="o", lw=2.0, ms=5, label="DSv5 p99 (ms)")
ax_bottom.plot(x, d6_p99, color=C6, marker="o", lw=2.0, ms=5, label="DSv6 p99 (ms)")
ax_bottom.set_xticks(x); ax_bottom.set_xticklabels([lbl(t) for t in ALL], fontsize=8)
ax_bottom.set_ylabel("p99 (ms)")
ax_bottom.set_title("DSv5 vs DSv6 p99 baseline", fontsize=11)
ax_bottom.grid(axis="y", ls=":", alpha=0.5)
ax_bottom.legend(loc="upper right", fontsize=8)

fig.suptitle("Service-time improvement (split view)", fontsize=13)
fig.tight_layout(rect=[0, 0, 1, 0.97])
fig.savefig(os.path.join(OUT, "improvement.png"), dpi=130, bbox_inches="tight"); plt.close(fig)
print("wrote improvement.png")

# ---- 4. Indexing & cluster summary ----
fig, axes = plt.subplots(1, 3, figsize=(12, 4))
def gg(label, m): return S["rally"][label]["_global"][m][0]
metrics = [
    ("Cumulative indexing time of primary shards", "Cumulative indexing time (min)", "min"),
    ("Cumulative merge time of primary shards", "Cumulative merge time (min)", "min"),
    ("Total Young Gen GC time", "Young Gen GC time (s)", "s"),
]
for ax, (mk, title, unit) in zip(axes, metrics):
    vals = [gg("dsv5", mk), gg("dsv6", mk)]
    bars = ax.bar(["DSv5", "DSv6"], vals, color=[C5, C6], width=0.5)
    ax.set_title(title, fontsize=10); ax.grid(axis="y", ls=":", alpha=0.5)
    for b in bars:
        ax.text(b.get_x()+b.get_width()/2, b.get_height(), f"{b.get_height():.2f}",
                ha="center", va="bottom", fontsize=9)
fig.suptitle("DSv5 vs DSv6 | Indexing & GC (lower=better)", fontsize=13, y=1.03)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "indexing.png"), dpi=130, bbox_inches="tight"); plt.close(fig)
print("wrote indexing.png")

# ---- 5. Host metrics 3-node average ----
def host_avg(grp, key):
    vals = [h[key] for h in S["host"][grp].values()]
    return sum(vals)/len(vals)

fig, axes = plt.subplots(1, 4, figsize=(13, 4))
panels = [
    ("cpu_busy_pct", "CPU Utilization (%)", "%"),
    ("softirq_pct", "Soft IRQ (%)", "%"),
    ("rx_pps", "NIC Receive (pps)", "pps"),
    ("tx_pps", "NIC Transmit (pps)", "pps"),
]
for ax, (key, title, unit) in zip(axes, panels):
    vals = [host_avg("dsv5", key), host_avg("dsv6", key)]
    bars = ax.bar(["DSv5", "DSv6"], vals, color=[C5, C6], width=0.5)
    ax.set_title(title, fontsize=10); ax.grid(axis="y", ls=":", alpha=0.5)
    for b in bars:
        v = b.get_height()
        ax.text(b.get_x()+b.get_width()/2, v, f"{v:.2f}" if v < 10 else f"{v:.0f}",
                ha="center", va="bottom", fontsize=9)
fig.suptitle("DSv5 vs DSv6 | Host metrics (3-node avg over benchmark window)", fontsize=13, y=1.03)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "host_metrics.png"), dpi=130, bbox_inches="tight"); plt.close(fig)
print("wrote host_metrics.png")
print("DONE")
