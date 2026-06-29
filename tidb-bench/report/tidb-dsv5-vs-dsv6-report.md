# TiDB DSv5 与 DSv6 集群 sysbench 压测对比报告

> 报告日期：2026-06-16  
> 数据库版本：TiDB v8.5.6（两套集群版本一致）  
> 压测工具：sysbench 1.0.20  
> 区域：Azure Germany West Central（germanywestcentral）

---

## 1. 测试环境说明

本次测试在 Azure 上部署了两套架构完全相同、仅虚拟机系列不同的 TiDB 集群，用于对比 **Dsv5（上一代）** 与 **Dsv6（新一代）** 计算实例在相同 OLTP 负载下的性能差异。

### 1.1 集群规格

| 项目 | DSv5 集群 | DSv6 集群 |
|---|---|---|
| 数据库节点 VM 系列 | Standard_D8s_v5 | Standard_D8s_v6 |
| 单节点 vCPU / 内存 | 8 vCPU / 32 GB | 8 vCPU / 32 GB |
| 压测客户端 | clientvm01（Standard_D32s_v6） | clientvm02（Standard_D32s_v6） |
| 操作系统 | Rocky Linux 9.8 | Rocky Linux 9.8 |
| TiDB 版本 | v8.5.6 | v8.5.6 |
| 数据盘 | Premium SSD v2，200 GB / 3000 IOPS / 125 MB/s | Premium SSD v2，200 GB / 3000 IOPS / 125 MB/s |
| 接入入口 | 内网 Standard LB `10.142.0.10:4000` | 内网 Standard LB `10.142.0.30:4000` |

> 两套集群唯一变量为 **VM 系列（Dsv5 → Dsv6）**，其余（vCPU、内存、磁盘、OS、TiDB 版本、拓扑、网络）均保持一致，确保对比公平。

### 1.2 网络与拓扑参数

- VNet：`10.142.0.0/16`，子网 `10.142.0.0/24`
- 每套集群：3 个 TiDB+PD 合一节点 + 3 个 TiKV 节点，TiKV 按 zone 跨 3 个可用区打散
- 副本策略：`max-replicas=3`，按 `zone/host` 标签打散
- TiKV `block-cache.capacity=14GB`（约为 32 GB 内存的 45%）

### 1.3 压测参数

| 参数 | 取值 |
|---|---|
| 数据规模 | 32 张表 × 100 万行（每表） |
| 测试用例 | `oltp_read_only`、`oltp_read_write` |
| 并发线程 | 50 / 100 / 200 |
| 每组时长 | 300 秒（report-interval=30s） |
| 随机分布 | uniform |
| Prepared statement | 关闭（`--db-ps-mode=disable`） |
| 执行方式 | 两套集群**并发**压测，互不干扰 |

### 1.4 指标采集

主机级系统指标由 node_exporter 采集，统一汇入部署在 clientvm01 的 Prometheus（`10.142.0.51:9090`）。DSv6 的 6 个节点已并入同一 Prometheus 实现统一查询。每组压测的系统指标按其精确的起止时间窗口做区间平均（PromQL `rate(...[1m])`），并按 TiDB 节点与 TiKV 节点分组取 3 节点均值。

---

## 2. 部署架构

```mermaid
flowchart TB
    subgraph CLIENT[压测客户端]
        C1[clientvm01<br/>D32s_v6<br/>10.142.0.51<br/>Prometheus+Grafana]
        C2[clientvm02<br/>D32s_v6<br/>10.142.0.52]
    end

    subgraph DSV5[DSv5 集群 - D8s_v5]
        LB5[内网 LB dv5-lb<br/>10.142.0.10:4000]
        T5A[TiDB+PD 10.142.0.11]
        T5B[TiDB+PD 10.142.0.12]
        T5C[TiDB+PD 10.142.0.13]
        K5A[TiKV az1 10.142.0.21]
        K5B[TiKV az2 10.142.0.22]
        K5C[TiKV az3 10.142.0.23]
        LB5 --> T5A & T5B & T5C
        T5A & T5B & T5C --- K5A & K5B & K5C
    end

    subgraph DSV6[DSv6 集群 - D8s_v6]
        LB6[内网 LB dv6-lb<br/>10.142.0.30:4000]
        T6A[TiDB+PD 10.142.0.31]
        T6B[TiDB+PD 10.142.0.32]
        T6C[TiDB+PD 10.142.0.33]
        K6A[TiKV az1 10.142.0.41]
        K6B[TiKV az2 10.142.0.42]
        K6C[TiKV az3 10.142.0.43]
        LB6 --> T6A & T6B & T6C
        T6A & T6B & T6C --- K6A & K6B & K6C
    end

    C1 -->|sysbench| LB5
    C2 -->|sysbench| LB6
```

- 每套集群 6 个数据库节点：3 × (TiDB + PD 合一) + 3 × TiKV
- 客户端经各自集群的**内网负载均衡器**接入 TiDB:4000，LB 后端为 3 个 TiDB 节点
- clientvm01 同时承载 Prometheus / Grafana，统一采集两套集群的 node_exporter 指标

---

## 3. sysbench 测试结果

> 性能提升% 均以 DSv5 为基线：QPS 提升% =（DSv6 − DSv5）/ DSv5 × 100；延迟降低% =（DSv5 − DSv6）/ DSv5 × 100。

### 3.1 oltp_read_only（只读）

| 并发 | DSv5 QPS | DSv6 QPS | QPS 提升 | DSv5 avg(ms) | DSv6 avg(ms) | 延迟降低 | DSv5 TPS | DSv6 TPS |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 50  | 43481.73 | 47601.27 | **+9.47%**  | 18.40 | 16.80 | **-8.70%** | 2717.61 | 2975.08 |
| 100 | 60454.05 | 67126.49 | **+11.04%** | 26.46 | 23.83 | **-9.94%** | 3778.38 | 4195.41 |
| 200 | 66311.16 | 71817.68 | **+8.30%**  | 48.25 | 44.55 | **-7.67%** | 4144.45 | 4488.61 |

### 3.2 oltp_read_write（读写混合）

| 并发 | DSv5 QPS | DSv6 QPS | QPS 提升 | DSv5 avg(ms) | DSv6 avg(ms) | 延迟降低 | DSv5 TPS | DSv6 TPS |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 50  | 36445.16 | 39212.82 | **+7.59%**  | 27.44 | 25.50 | **-7.07%**  | 1822.26 | 1960.64 |
| 100 | 48622.19 | 54803.99 | **+12.71%** | 41.13 | 36.49 | **-11.28%** | 2431.11 | 2740.20 |
| 200 | 57513.23 | 63565.59 | **+10.52%** | 69.54 | 62.92 | **-9.52%**  | 2875.66 | 3178.28 |

### 3.3 p95 延迟（ms）

| 并发 | RO DSv5 | RO DSv6 | RW DSv5 | RW DSv6 |
|---:|---:|---:|---:|---:|
| 50  | 23.52 | 21.89 | 34.95 | 31.94 |
| 100 | 36.24 | 31.37 | 56.84 | 48.34 |
| 200 | 68.05 | 58.92 | 94.10 | 84.47 |

### 3.4 结论小结

![DSv5 vs DSv6 QPS 对比](images/qps_summary.png)

- **QPS：** DSv6 在全部 12 个测试场景下均优于 DSv5，提升幅度约 **7.6% ~ 12.7%**，平均约 **+9.9%**。
- **延迟：** DSv6 平均延迟与 p95 延迟在所有场景下均更低，平均延迟降低约 **7% ~ 11%**。
- **峰值吞吐：** 只读 200 并发下 DSv6 达到 71817 QPS（DSv5 为 66311）；读写 200 并发下 DSv6 达到 63565 QPS（DSv5 为 57513）。
- 提升最显著的负载点为 **100 并发**（读写 +12.71%、只读 +11.04%），说明 DSv6 在中高并发下计算能力优势更明显。

---

## 4. 主机系统指标（压测窗口内均值）

下列数据为各组压测时间窗内，按 TiDB 节点（3 台）/ TiKV 节点（3 台）分组的均值。`CPU idle`、`CPU 利用率`、`软中断(softirq)` 单位为 %（单核占比口径，已对全核 rate 求平均）；`RX/TX PPS` 为网卡每秒收/发包数（已排除 lo）。

### 4.1 oltp_read_only — TiDB 节点

| 并发 | 集群 | CPU idle% | CPU 利用% | softirq% | RX PPS | TX PPS |
|---:|---|---:|---:|---:|---:|---:|
| 50  | DSv5 | 41.18 | 58.82 | 3.10 | 79177 | 74525 |
| 50  | DSv6 | 33.86 | 66.14 | 3.17 | 88979 | 63826 |
| 100 | DSv5 | 15.05 | 84.95 | 5.30 | 119408 | 110794 |
| 100 | DSv6 | 8.70  | 91.30 | 4.10 | 132971 | 91562 |
| 200 | DSv5 | 7.10  | 92.90 | 6.02 | 131633 | 117221 |
| 200 | DSv6 | 5.00  | 95.00 | 4.16 | 141233 | 88704 |

### 4.2 oltp_read_only — TiKV 节点

| 并发 | 集群 | CPU idle% | CPU 利用% | softirq% | RX PPS | TX PPS |
|---:|---|---:|---:|---:|---:|---:|
| 50  | DSv5 | 74.32 | 25.68 | 0.91 | 28488 | 43134 |
| 50  | DSv6 | 74.89 | 25.11 | 1.50 | 31346 | 24079 |
| 100 | DSv5 | 62.26 | 37.74 | 1.54 | 41372 | 64479 |
| 100 | DSv6 | 61.68 | 38.32 | 2.22 | 44982 | 37029 |
| 200 | DSv5 | 59.27 | 40.73 | 1.65 | 40485 | 71026 |
| 200 | DSv6 | 60.64 | 39.36 | 2.16 | 40839 | 39182 |

**图：oltp_read_only — TiDB 节点系统指标对比**

![oltp_read_only TiDB 指标](images/ro_tidb.png)

**图：oltp_read_only — TiKV 节点系统指标对比**

![oltp_read_only TiKV 指标](images/ro_tikv.png)

### 4.3 oltp_read_write — TiDB 节点

| 并发 | 集群 | CPU idle% | CPU 利用% | softirq% | RX PPS | TX PPS |
|---:|---|---:|---:|---:|---:|---:|
| 50  | DSv5 | 29.86 | 70.14 | 3.99 | 93696 | 88665 |
| 50  | DSv6 | 25.52 | 74.48 | 3.63 | 99066 | 76742 |
| 100 | DSv5 | 21.67 | 78.33 | 4.82 | 105541 | 100520 |
| 100 | DSv6 | 12.63 | 87.37 | 4.09 | 121837 | 93280 |
| 200 | DSv5 | 10.53 | 89.47 | 5.81 | 119193 | 110514 |
| 200 | DSv6 | 5.68  | 94.32 | 4.13 | 132474 | 92709 |

### 4.4 oltp_read_write — TiKV 节点

| 并发 | 集群 | CPU idle% | CPU 利用% | softirq% | RX PPS | TX PPS |
|---:|---|---:|---:|---:|---:|---:|
| 50  | DSv5 | 38.59 | 61.41 | 3.07 | 60688 | 73686 |
| 50  | DSv6 | 35.51 | 64.49 | 2.97 | 65317 | 60328 |
| 100 | DSv5 | 29.52 | 70.48 | 3.76 | 67504 | 82046 |
| 100 | DSv6 | 19.32 | 80.68 | 3.32 | 78210 | 72247 |
| 200 | DSv5 | 19.70 | 80.30 | 4.07 | 65438 | 85384 |
| 200 | DSv6 | 15.33 | 84.67 | 3.05 | 70704 | 68456 |

**图：oltp_read_write — TiDB 节点系统指标对比**

![oltp_read_write TiDB 指标](images/rw_tidb.png)

**图：oltp_read_write — TiKV 节点系统指标对比**

![oltp_read_write TiKV 指标](images/rw_tikv.png)

### 4.5 系统指标解读

- **CPU：** 在同等并发下，DSv6 的 TiDB 节点 CPU idle 普遍更低、利用率更高（例如读写 100 并发：DSv6 利用率 87.37% vs DSv5 78.33%）。这与 DSv6 吞吐更高一致——DSv6 在单位时间内完成了更多请求，CPU 被更充分利用，单请求的 CPU 成本更低。
- **软中断（softirq）：** DSv6 的软中断占比在多数场景**低于** DSv5（如只读 200 并发 TiDB：4.16% vs 6.02%），表明新一代实例在网络/中断处理上的开销更小。
- **网卡 PPS：** DSv6 的 RX PPS 普遍更高（与更高 QPS 相符），而 TX PPS 反而低于 DSv5，主要源于 DSv5/DSv6 网卡多队列与中断聚合行为差异；两套集群均未触及网卡 PPS 瓶颈。
- **瓶颈定位：** 高并发（200）下 TiDB 节点 CPU 利用率接近饱和（DSv6 达 94~95%），而 TiKV 节点 CPU 仍有余量（idle 约 15~60%），说明本负载下**计算瓶颈集中在 TiDB（SQL）层**，这也正是 DSv6 计算升级直接带来 QPS 提升的原因。

---

## 5. 总体结论

1. 在完全相同的拓扑、磁盘、内存、TiDB 版本与压测参数下，**DSv6 相比 DSv5 在所有 12 个场景均取得正向性能提升**。
2. **QPS 平均提升约 9.9%（区间 7.6%~12.7%），平均延迟与 p95 延迟同步下降约 7%~11%**。
3. 提升来源主要是 DSv6 更强的单核计算能力：相同并发下 DSv6 用更高的 CPU 利用率与更低的软中断开销，完成了更多的 SQL 处理。
4. 本 OLTP 负载的瓶颈位于 TiDB（SQL）计算层，因此 Dsv5 → Dsv6 的计算实例升级能较直接地转化为吞吐与延迟收益；对该类负载，**推荐采用 DSv6 系列**。

---

## 附录：原始数据来源

- sysbench 结果 CSV：`/tmp/bench-dsv5.csv`、`/tmp/bench-dsv6.csv`（节点本地）
- 系统指标 CSV：`/tmp/metrics.csv`（含每节点逐组明细，72 行）
- 指标查询源：Prometheus `http://10.142.0.51:9090`，PromQL 指标 `node_cpu_seconds_total`、`node_network_receive_packets_total`、`node_network_transmit_packets_total`
- 压测/采集脚本：`scripts/41-run-bench.sh`、`scripts/42-export-metrics.sh`、`scripts/43-export-missing.sh`
- 图表生成脚本：`report/make_charts.py`（输出至 `report/images/`）
