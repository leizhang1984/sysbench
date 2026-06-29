"""Generate failover timeline charts for the ES DSv6 failover test.
Reads data/failover_scenarioA.csv and data/failover_scenarioB.csv.
Outputs PNGs into images/.
"""
import os
import csv
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# Use a CJK-capable font so Chinese labels render correctly on Windows.
plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "DejaVu Sans"]
plt.rcParams["axes.unicode_minus"] = False

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "images")
DATA = os.path.join(HERE, "data")
os.makedirs(OUT, exist_ok=True)

OK_C = "#54A24B"     # green - success
FAIL_C = "#E45756"   # red - fail
YELLOW = "#F2C744"
GREEN = "#54A24B"

# Fault injection time relative to probe start (seconds)
FAULT_A = 58      # kill -9 at +58s
YELLOW_A = 59     # cluster yellow
GREEN_A = 71      # cluster green again
FAULT_B = 64      # SIGSTOP at +64s
YELLOW_B = 161    # cluster yellow (detection)
RESUME_B = 169    # SIGCONT / recovery


def load(name):
    t, ok, fail, status = [], [], [], []
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        for row in csv.DictReader(f):
            t.append(int(row["t_rel"]))
            ok.append(int(row["ok"]))
            fail.append(int(row["fail"]))
            status.append(row["status"])
    return t, ok, fail, status


def status_band(ax, t, status):
    # shade background by cluster status
    for i in range(len(t)):
        c = None
        if status[i] == "yellow":
            c = YELLOW
        if c:
            ax.axvspan(t[i] - 0.5, t[i] + 0.5, color=c, alpha=0.18, lw=0)


def plot_scenario(name, csvfile, fault, yellow_t, green_t, fault_label, recover_label, outfile):
    t, ok, fail, status = load(csvfile)
    fig, ax = plt.subplots(figsize=(11, 4.2))
    status_band(ax, t, status)
    ax.bar(t, ok, color=OK_C, width=0.9, label="成功请求/秒 (ok)")
    ax.bar(t, fail, bottom=ok, color=FAIL_C, width=0.9, label="失败请求/秒 (fail)")
    ax.axvline(fault, color="#333", ls="--", lw=1.5)
    ax.text(fault + 0.5, ax.get_ylim()[1] * 0.92, fault_label, fontsize=9, color="#333")
    ax.axvline(green_t, color="#1f77b4", ls=":", lw=1.5)
    ax.text(green_t + 0.5, ax.get_ylim()[1] * 0.78, recover_label, fontsize=9, color="#1f77b4")
    ax.set_xlabel("相对探针启动时间 (秒)")
    ax.set_ylabel("请求数 / 秒 (10 Hz 探针)")
    ax.set_title(name)
    ax.legend(loc="upper right", fontsize=9)
    ax.set_xlim(0, max(t))
    plt.tight_layout()
    p = os.path.join(OUT, outfile)
    plt.savefig(p, dpi=130)
    plt.close()
    print("wrote", p)


def plot_compare(outfile):
    ta, oka, faila, sa = load("failover_scenarioA.csv")
    tb, okb, failb, sb = load("failover_scenarioB.csv")
    fig, axes = plt.subplots(2, 1, figsize=(11, 7), sharex=False)

    ax = axes[0]
    ax.bar(ta, oka, color=OK_C, width=0.9)
    ax.bar(ta, faila, bottom=oka, color=FAIL_C, width=0.9)
    ax.axvline(FAULT_A, color="#333", ls="--", lw=1.4)
    ax.text(FAULT_A + 0.5, 9.5, "kill -9", fontsize=9)
    ax.set_title("场景 A — kill -9（干净崩溃，有 RST 快速失败）")
    ax.set_ylabel("请求/秒")
    ax.set_xlim(0, max(ta))

    ax = axes[1]
    for i in range(len(tb)):
        if sb[i] == "yellow":
            ax.axvspan(tb[i] - 0.5, tb[i] + 0.5, color=YELLOW, alpha=0.2, lw=0)
    ax.bar(tb, okb, color=OK_C, width=0.9)
    ax.bar(tb, failb, bottom=okb, color=FAIL_C, width=0.9)
    ax.axvline(FAULT_B, color="#333", ls="--", lw=1.4)
    ax.text(FAULT_B + 0.5, max(okb) * 0.9, "SIGSTOP 冻结", fontsize=9)
    ax.axvline(YELLOW_B, color="#cc8800", ls="-.", lw=1.4)
    ax.text(YELLOW_B - 40, max(okb) * 0.9, "集群检测(yellow)\n~93s 滞后", fontsize=9, color="#cc8800")
    ax.axvline(RESUME_B, color="#1f77b4", ls=":", lw=1.4)
    ax.text(RESUME_B + 0.5, max(okb) * 0.6, "SIGCONT 恢复", fontsize=9, color="#1f77b4")
    ax.set_title("场景 B — SIGSTOP（静默冻结，无 RST，同步客户端吞吐塌缩）")
    ax.set_ylabel("请求/秒")
    ax.set_xlabel("相对探针启动时间 (秒)")
    ax.set_xlim(0, max(tb))

    plt.tight_layout()
    p = os.path.join(OUT, outfile)
    plt.savefig(p, dpi=130)
    plt.close()
    print("wrote", p)


if __name__ == "__main__":
    plot_scenario("场景 A — kill -9 故障转移时间线", "failover_scenarioA.csv",
                  FAULT_A, YELLOW_A, GREEN_A, "kill -9", "集群恢复 green",
                  "failover_A.png")
    plot_scenario("场景 B — SIGSTOP 冻结故障转移时间线", "failover_scenarioB.csv",
                  FAULT_B, YELLOW_B, RESUME_B, "SIGSTOP 冻结", "恢复",
                  "failover_B.png")
    plot_compare("failover_compare.png")
    print("DONE")
