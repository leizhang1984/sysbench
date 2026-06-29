"""Generate a simple, no-crossing architecture diagram for ES DSv5 vs DSv6 report."""
import os
import matplotlib
matplotlib.use("Agg")
matplotlib.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "DejaVu Sans"]
matplotlib.rcParams["axes.unicode_minus"] = False
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "images", "architecture.png")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

fig, ax = plt.subplots(figsize=(16, 9))
ax.set_xlim(0, 100)
ax.set_ylim(0, 100)
ax.axis("off")


def panel(x, y, w, h, edge, fill, title, title_color):
    p = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.8,rounding_size=8",
                       linewidth=2.0, edgecolor=edge, facecolor=fill)
    ax.add_patch(p)
    ax.text(x + 1.5, y + h - 4.0, title, ha="left", va="center",
            fontsize=14, fontweight="bold", color=title_color)


def node(x, y, w, h, title, detail, edge, fill="#ffffff"):
    b = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.5,rounding_size=4",
                       linewidth=1.4, edgecolor=edge, facecolor=fill)
    ax.add_patch(b)
    ax.text(x + w / 2, y + h * 0.63, title, ha="center", va="center", fontsize=10.5, fontweight="bold")
    ax.text(x + w / 2, y + h * 0.30, detail, ha="center", va="center", fontsize=9)


def arrow(x1, y1, x2, y2, color, text=None):
    a = FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=12,
                        linewidth=1.5, color=color, alpha=0.9)
    ax.add_patch(a)
    if text:
        ax.text((x1 + x2) / 2, (y1 + y2) / 2 + 1.2, text, fontsize=8.5, color=color, ha="center")


def draw_env_lane(y0, title, title_color, panel_edge, panel_fill, client_name, client_ip,
                  node1_ip, node2_ip, node3_ip, color):
    panel(4, y0, 92, 40, edge=panel_edge, fill=panel_fill, title=title, title_color=title_color)

    # Left: client
    node(8, y0 + 11, 18, 16, client_name, f"{client_ip}\nesrally", edge="#7aa1cf", fill="#eef5ff")

    # Middle: target-hosts gateway (single split point)
    node(35, y0 + 13, 16, 12, "target-hosts", "3 endpoints", edge=color, fill="#ffffff")

    # Right: three nodes stacked vertically, no crossing arrows
    node(64, y0 + 24, 24, 8.5, "node01 / zone2", f"{node1_ip}:9200", edge=color)
    node(64, y0 + 14.5, 24, 8.5, "node02 / zone3", f"{node2_ip}:9200", edge=color)
    node(64, y0 + 5, 24, 8.5, "node03 / zone1", f"{node3_ip}:9200", edge=color)

    # One ingress arrow + three split arrows (kept parallel / non-crossing)
    arrow(26, y0 + 19, 35, y0 + 19, color, "esrally")
    arrow(51, y0 + 19, 64, y0 + 28, color)
    arrow(51, y0 + 19, 64, y0 + 18.5, color)
    arrow(51, y0 + 19, 64, y0 + 9, color)


draw_env_lane(
    y0=54,
    title="环境 A: DSv5 压测环境 (D8s_v5 / CentOS 7.9)",
    title_color="#2f5f8f",
    panel_edge="#4C78A8",
    panel_fill="#F2F7FC",
    client_name="clientvm01",
    client_ip="10.122.0.10",
    node1_ip="10.122.0.4",
    node2_ip="10.122.0.5",
    node3_ip="10.122.0.6",
    color="#4C78A8",
)

draw_env_lane(
    y0=10,
    title="环境 B: DSv6 压测环境 (D8s_v6 / Rocky Linux 9.8)",
    title_color="#b23b3a",
    panel_edge="#E45756",
    panel_fill="#FFF3F3",
    client_name="clientvm02",
    client_ip="10.122.0.11",
    node1_ip="10.122.0.7",
    node2_ip="10.122.0.8",
    node3_ip="10.122.0.9",
    color="#E45756",
)


ax.text(50, 3.5, "VNet 10.122.0.0/16  |  子网 vm-subnet 10.122.0.0/24  |  两套环境并行压测，互不干扰",
        ha="center", fontsize=10.5, color="#4d4d4d")

fig.savefig(OUT, dpi=150, bbox_inches="tight")
print(f"WROTE: {OUT}")
