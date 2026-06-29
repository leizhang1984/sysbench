"""Generate before/after failover architecture diagram for DSv6 ES cluster."""
import os
import matplotlib
matplotlib.use("Agg")
matplotlib.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "DejaVu Sans"]
matplotlib.rcParams["axes.unicode_minus"] = False
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "images", "failover_architecture_before_after.png")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

fig, axes = plt.subplots(1, 2, figsize=(18, 8))


def draw_box(ax, x, y, w, h, title, detail, edge="#4C78A8", fill="#FFFFFF", title_size=10.5):
    box = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.4,rounding_size=3",
                         linewidth=1.5, edgecolor=edge, facecolor=fill)
    ax.add_patch(box)
    ax.text(x + w / 2, y + h * 0.63, title, ha="center", va="center", fontsize=title_size, fontweight="bold")
    ax.text(x + w / 2, y + h * 0.28, detail, ha="center", va="center", fontsize=9)


def draw_arrow(ax, x1, y1, x2, y2, color="#4C78A8", label=None, lw=1.6):
    arr = FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=12,
                          linewidth=lw, color=color, alpha=0.95)
    ax.add_patch(arr)
    if label:
        ax.text((x1 + x2) / 2, (y1 + y2) / 2 + 1.2, label, fontsize=8.5, color=color, ha="center")


def base_canvas(ax, title):
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis("off")
    ax.text(50, 96, title, ha="center", va="center", fontsize=15, fontweight="bold")


# Left panel: before failure
ax = axes[0]
base_canvas(ax, "故障前（正常）: dsv6 三节点均在线")

# App/client side
draw_box(ax, 5, 70, 22, 18, "业务应用", "读写请求\n(HTTP 9200)", edge="#5B8A3C", fill="#F3FAEE")
draw_box(ax, 5, 45, 22, 18, "clientvm02", "ES 客户端连接池\n轮询 01/02/03", edge="#7AA1CF", fill="#EEF5FF")

# Cluster nodes
draw_box(ax, 38, 74, 25, 14, "dsv6esmasterdata01", "10.122.0.7\nmaster+data", edge="#E45756", fill="#FFF3F3")
draw_box(ax, 38, 54, 25, 14, "dsv6esmasterdata02", "10.122.0.8\n当前 master", edge="#E45756", fill="#FFF3F3")
draw_box(ax, 38, 34, 25, 14, "dsv6esmasterdata03", "10.122.0.9\nmaster+data", edge="#E45756", fill="#FFF3F3")

# Shard placement (example from report)
draw_box(ax, 68, 74, 27, 14, "分片布局", "shard1-P, shard0-R\n位于 01", edge="#A06AB4", fill="#F8F2FC")
draw_box(ax, 68, 54, 27, 14, "分片布局", "shard0-P, shard1-R, shard2-R\n位于 02", edge="#A06AB4", fill="#F8F2FC")
draw_box(ax, 68, 34, 27, 14, "分片布局", "shard2-P ...\n位于 03", edge="#A06AB4", fill="#F8F2FC")

# Data persistence
draw_box(ax, 30, 10, 65, 14, "持久化", "每节点本地数据盘 /esdata + translog；写入主分片后复制到副本分片", edge="#666666", fill="#F6F6F6")

# Arrows
for y in (81, 61, 41):
    draw_arrow(ax, 27, 54, 38, y, color="#2F5F8F", label="target-hosts")

for y1, y2 in ((81, 81), (61, 61), (41, 41)):
    draw_arrow(ax, 63, y1, 68, y2, color="#8D55A5")

draw_arrow(ax, 16, 70, 16, 63, color="#3E7A2A", label="业务请求")
draw_arrow(ax, 50, 34, 50, 24, color="#666666", label="commit + flush/translog")

ax.text(50, 4, "状态: cluster=green, active_shards=6（3P+3R）", ha="center", fontsize=10, color="#333333")


# Right panel: after node01 failure
ax = axes[1]
base_canvas(ax, "故障后（01 宕机）: 自动故障转移与连续性")

draw_box(ax, 5, 70, 22, 18, "业务应用", "继续读写\n客户端自动重试", edge="#5B8A3C", fill="#F3FAEE")
draw_box(ax, 5, 45, 22, 18, "clientvm02", "剔除 01 后\n仅路由 02/03", edge="#7AA1CF", fill="#EEF5FF")

# Failed node + survivors
draw_box(ax, 38, 74, 25, 14, "dsv6esmasterdata01", "宕机/不可达\n10.122.0.7", edge="#A94442", fill="#FDECEC")
ax.text(50.5, 80.5, "X", fontsize=26, color="#A94442", ha="center", va="center", fontweight="bold")

draw_box(ax, 38, 54, 25, 14, "dsv6esmasterdata02", "存活 + 继续担任 master", edge="#E45756", fill="#FFF3F3")
draw_box(ax, 38, 34, 25, 14, "dsv6esmasterdata03", "存活", edge="#E45756", fill="#FFF3F3")

# Failover effects
draw_box(ax, 68, 68, 27, 16, "副本升主", "原 01 上主分片故障\n副本在 02/03 提升为主", edge="#A06AB4", fill="#F8F2FC")
draw_box(ax, 68, 47, 27, 16, "集群恢复", "green -> yellow -> green\n重建缺失副本", edge="#A06AB4", fill="#F8F2FC")
draw_box(ax, 68, 26, 27, 16, "一致性与持久化", "已确认写入通过主+副本保证\n数据仍在存活节点磁盘", edge="#666666", fill="#F6F6F6")

# Arrows
for y in (61, 41):
    draw_arrow(ax, 27, 54, 38, y, color="#2F5F8F", label="target-hosts")

draw_arrow(ax, 16, 70, 16, 63, color="#3E7A2A", label="业务连续")
draw_arrow(ax, 63, 61, 68, 76, color="#8D55A5", label="promote replica")
draw_arrow(ax, 63, 41, 68, 55, color="#8D55A5", label="reallocate")
draw_arrow(ax, 63, 41, 68, 34, color="#666666", label="disk persistence")

ax.text(50, 4, "状态: 可容忍单节点故障（在 replicas>=1 的索引上）", ha="center", fontsize=10, color="#333333")

fig.tight_layout()
fig.savefig(OUT, dpi=150, bbox_inches="tight")
print(f"WROTE: {OUT}")
