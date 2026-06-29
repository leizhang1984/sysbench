"""Generate DSv5 vs DSv6 host-metric comparison charts for the report.
Data are the per-group TiDB/TiKV averages already collected from Prometheus.
Outputs PNGs into the images/ folder next to the report.
"""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "images")
os.makedirs(OUT, exist_ok=True)

concur = ["50", "100", "200"]
x = np.arange(len(concur))
w = 0.35
C5, C6 = "#4C78A8", "#E45756"  # dsv5 blue, dsv6 red

# ---- aggregated TiDB / TiKV averages (CPU util %, softirq %, RX pps, TX pps) ----
# oltp_read_only
ro_tidb = {
    "util": {"dsv5": [58.82, 84.95, 92.90], "dsv6": [66.14, 91.30, 95.00]},
    "sirq": {"dsv5": [3.10, 5.30, 6.02],   "dsv6": [3.17, 4.10, 4.16]},
    "rx":   {"dsv5": [79177, 119408, 131633], "dsv6": [88979, 132971, 141233]},
    "tx":   {"dsv5": [74525, 110794, 117221], "dsv6": [63826, 91562, 88704]},
}
ro_tikv = {
    "util": {"dsv5": [25.68, 37.74, 40.73], "dsv6": [25.11, 38.32, 39.36]},
    "sirq": {"dsv5": [0.91, 1.54, 1.65],    "dsv6": [1.50, 2.22, 2.16]},
    "rx":   {"dsv5": [28488, 41372, 40485], "dsv6": [31346, 44982, 40839]},
    "tx":   {"dsv5": [43134, 64479, 71026], "dsv6": [24079, 37029, 39182]},
}
# oltp_read_write
rw_tidb = {
    "util": {"dsv5": [70.14, 78.33, 89.47], "dsv6": [74.48, 87.37, 94.32]},
    "sirq": {"dsv5": [3.99, 4.82, 5.81],    "dsv6": [3.63, 4.09, 4.13]},
    "rx":   {"dsv5": [93696, 105541, 119193], "dsv6": [99066, 121837, 132474]},
    "tx":   {"dsv5": [88665, 100520, 110514], "dsv6": [76742, 93280, 92709]},
}
rw_tikv = {
    "util": {"dsv5": [61.41, 70.48, 80.30], "dsv6": [64.49, 80.68, 84.67]},
    "sirq": {"dsv5": [3.07, 3.76, 4.07],    "dsv6": [2.97, 3.32, 3.05]},
    "rx":   {"dsv5": [60688, 67504, 65438], "dsv6": [65317, 78210, 70704]},
    "tx":   {"dsv5": [73686, 82046, 85384], "dsv6": [60328, 72247, 68456]},
}


def grouped_bar(ax, d5, d6, title, ylabel, pps=False):
    b5 = ax.bar(x - w / 2, d5, w, label="DSv5", color=C5)
    b6 = ax.bar(x + w / 2, d6, w, label="DSv6", color=C6)
    ax.set_title(title, fontsize=11)
    ax.set_xticks(x)
    ax.set_xticklabels([f"{c} threads" for c in concur])
    ax.set_ylabel(ylabel)
    ax.grid(axis="y", ls=":", alpha=0.5)
    for b in list(b5) + list(b6):
        v = b.get_height()
        txt = f"{v/1000:.0f}k" if pps else f"{v:.0f}"
        ax.text(b.get_x() + b.get_width() / 2, v, txt, ha="center", va="bottom", fontsize=8)


def make_panel(data, role, case, fname):
    fig, axes = plt.subplots(2, 2, figsize=(11, 7))
    grouped_bar(axes[0, 0], data["util"]["dsv5"], data["util"]["dsv6"],
                f"{case} - {role} CPU Utilization (%)", "%")
    grouped_bar(axes[0, 1], data["sirq"]["dsv5"], data["sirq"]["dsv6"],
                f"{case} - {role} Soft IRQ (%)", "%")
    grouped_bar(axes[1, 0], data["rx"]["dsv5"], data["rx"]["dsv6"],
                f"{case} - {role} NIC Receive PPS", "packets/s", pps=True)
    grouped_bar(axes[1, 1], data["tx"]["dsv5"], data["tx"]["dsv6"],
                f"{case} - {role} NIC Transmit PPS", "packets/s", pps=True)
    h, l = axes[0, 0].get_legend_handles_labels()
    fig.legend(h, l, loc="upper right", ncol=2)
    fig.suptitle(f"DSv5 vs DSv6  |  {case}  |  {role} nodes (3-node avg)", fontsize=13, y=1.02)
    fig.tight_layout()
    path = os.path.join(OUT, fname)
    fig.savefig(path, dpi=130, bbox_inches="tight")
    plt.close(fig)
    print("wrote", path)


make_panel(ro_tidb, "TiDB", "oltp_read_only", "ro_tidb.png")
make_panel(ro_tikv, "TiKV", "oltp_read_only", "ro_tikv.png")
make_panel(rw_tidb, "TiDB", "oltp_read_write", "rw_tidb.png")
make_panel(rw_tikv, "TiKV", "oltp_read_write", "rw_tikv.png")

# ---- summary QPS chart ----
fig, ax = plt.subplots(1, 2, figsize=(11, 4))
ro_q5 = [43481.73, 60454.05, 66311.16]
ro_q6 = [47601.27, 67126.49, 71817.68]
rw_q5 = [36445.16, 48622.19, 57513.23]
rw_q6 = [39212.82, 54803.99, 63565.59]
grouped_bar(ax[0], ro_q5, ro_q6, "oltp_read_only QPS", "QPS")
grouped_bar(ax[1], rw_q5, rw_q6, "oltp_read_write QPS", "QPS")
h, l = ax[0].get_legend_handles_labels()
fig.legend(h, l, loc="upper right", ncol=2)
fig.suptitle("DSv5 vs DSv6  |  sysbench QPS", fontsize=13, y=1.04)
fig.tight_layout()
p = os.path.join(OUT, "qps_summary.png")
fig.savefig(p, dpi=130, bbox_inches="tight")
plt.close(fig)
print("wrote", p)
print("DONE")
