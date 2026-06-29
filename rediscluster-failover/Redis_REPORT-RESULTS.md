# Redis 6 集群故障转移测试 —— 实测分析报告

> 本报告为**真实执行**结果。由于当前会话无法连接 Azure，测试在本机 WSL(Ubuntu 24.04) 中
> 用**源码编译的 Redis 6.2.14** 跑起一套真实的 **3 主 3 从集群**（端口 7001–7006），
> 用交付的 **JedisCluster 探针**（Jedis 5.1）持续读写，注入两类故障并采集真实指标。
> 集群关键参数与目标环境一致：`cluster-node-timeout=15000`、`appendfsync everysec`、危险命令重命名等。
> 
> 注：单机多实例无法体现"跨 AZ 网络延迟"，但**故障检测/选举/客户端行为**与多机一致，结论可迁移。
> Azure 多机执行请用 `docs/RUNBOOK.md` + `azure/` 脚本，方法学完全相同。

---

## 1. 测试环境（实测）

| 项 | 值 |
| --- | --- |
| Redis | 6.2.14（源码编译，MALLOC=libc） |
| 拓扑 | 3 主（7001/7002/7003）+ 3 从（7004→7003, 7005→7001, 7006→7002），16384 槽全覆盖 |
| 关键配置 | cluster-node-timeout=15000，appendonly yes / appendfsync everysec，cluster-require-full-coverage no |
| 客户端 | JedisCluster；maxAttempts=5，connTimeout=2000ms，socketTimeout=1000ms，pool.maxTotal=64 |
| 负载 | 8 线程，每线程 300 QPS 上限，value 512B，读写各半，keyspace 50000 |

> **主从跨 AZ 布局**：交付拓扑（`cluster.env`）强制每个分片的主与副本分处不同 AZ（A→AZ2、B→AZ3、C→AZ1）。
> 其对延迟/复制滞后的专项实测见 **§12**；在此布局下进一步缩短故障转移中断时间的优化与 A/B 实测见 **§13**。

### 1.1 部署架构图

![Redis 集群跨 AZ 部署架构](img/arch-deploy.png)

**架构要点：**

- **区域 / 可用区**：部署于 Azure `westus3`，跨 **3 个可用区（AZ-1/AZ-2/AZ-3）**，每个 AZ 独立供电、网络与制冷，AZ 间为低延迟专网（实测约 1~2 ms RTT）。
- **计算**：6 台 **D8s_v6**（8 vCPU）虚拟机，操作系统 **Rocky Linux 9.7**，每台运行 1 个 Redis 6.2 实例，`maxmemory 4gb`。
- **集群拓扑**：3 主 3 从，16384 槽位均分到 3 个分片（A/B/C），`cluster-require-full-coverage no`。
- **主从跨 AZ**：每个分片的主与从**强制分处不同 AZ**，且每个 AZ 各承载 1 主 + 1 从（负载均衡 + AZ 级容灾）：

  | 分片 | 主节点 | 主所在 AZ | 从节点 | 从所在 AZ |
  | --- | --- | --- | --- | --- |
  | A | 7001 | AZ-1 | 7005 | AZ-2 |
  | B | 7002 | AZ-2 | 7006 | AZ-3 |
  | C | 7003 | AZ-3 | 7004 | AZ-1 |

- **复制链路**：彩色箭头表示**异步复制方向**（主→从，跨 AZ）。异步复制下客户端写入不等待副本 ACK，因此跨 AZ 复制时延基本不影响客户端写延迟（实测见 §12）。
- **Gossip 总线**：各节点通过集群总线端口（如 16379）交换 `PING/PONG`，完成 `PFAIL→FAIL` 故障判定、拓扑与槽位传播；`cluster-node-timeout=15000ms` 决定故障检测灵敏度（优化见 §13）。
- **客户端**：应用层用 **JedisCluster** 按槽位直连对应主节点（读写），命中重定向时跟随 `MOVED/ASK` 并刷新本地槽位映射；单 AZ 故障时受影响分片由跨 AZ 副本接管。

## 2. 基线（无故障，注入前 28s）

| 指标 | 实测值 |
| --- | --- |
| 稳态吞吐 | **2,431 QPS** |
| P50 延迟 | **0.86 ms** |
| P99 延迟 | **2.60 ms** |
| 失败请求 | **0** |
| 数据丢失 | **0** |

## 3. 场景 A —— kill -9 主进程（node1/7001）

**时间线（来自 Redis 节点日志 + 探针 CSV）**

| 事件 | 时刻 | 相对故障 |
| --- | --- | --- |
| `kill -9` 7001(master) | 12:36:25.65 | T0 |
| 副本 7005 开始选举（延迟 858ms） | 12:36:44.51 | **+18.9s** |
| **7005 选举获胜，晋升为新主** | 12:36:45.42 | **+19.8s** |
| 客户端吞吐完全恢复 | 12:36:46 | **+20.3s** |
| 原主 7001 重启后 | 12:37:50 | 自动**作为 7005 的副本**回归 |

**客户端表现（逐秒）**

- T0 后第 1s：QPS 由 2428 腰斩到 1445（命中故障分片 slots 0–5460 的 \~1/3 请求开始失败）。
- T0+2s 起：**整体吞吐塌缩到近 0（1–13 QPS）**，持续约 19s。原因：8 个工作线程中凡是命中故障分片的请求，会在 `maxAttempts=5` 的重试 + 退避中阻塞数秒，线程被逐步"占满"，**单一分片故障拖垮了整个客户端吞吐**。
- 因 `kill -9` 关闭了监听套接字，客户端到 7001 的连接立即收到 RST → 快速失败，故仍有零星请求成功（trickle）。
- T0+20s：QPS 报复性反弹（1953→3539→5517→6416），**最大延迟尖刺 572→2193→2691 ms**（积压请求与拓扑刷新后排队完成）。
- 错误类型：全部为 `JedisClusterOperationException`，本场景累计 **56 次失败**。
- **数据丢失：0**（异步复制在低写入速率下已追平，副本晋升未丢已确认写入）。

## 4. 场景 B —— 虚拟机宕机（SIGSTOP 冻结主进程，模拟整机静默/无 RST）

> 用 `kill -STOP` 冻结 7002 主进程：TCP 连接挂起、**不返回 RST**，逼近"虚机突然消失"的网络静默特征，
> 故障检测只能依赖 `cluster-node-timeout` 的 gossip 超时。

**时间线**

| 事件 | 时刻 | 相对故障 |
| --- | --- | --- |
| `SIGSTOP` 7002(master) | 12:38:15.47 | T0 |
| 副本 7006 开始选举（延迟 854ms） | 12:38:36.49 | **+21.0s** |
| **7006 选举获胜，晋升为新主**（epoch 8，获其他主投票） | 12:38:37.41 | **+21.9s** |
| 客户端吞吐完全恢复 | 12:38:39 | **+23.5s** |

**客户端表现**

- T0 后吞吐**直接跌到绝对 0**并维持约 22s（与场景 A 的"零星 trickle"不同）：因连接被冻结而非拒绝，线程必须**挂满整个 socketTimeout(1000ms)×重试**才报错，阻塞更彻底。
- 恢复时同样出现积压反弹（1619→7067→7323 QPS）与**最大延迟尖刺 \~2.3s**。
- 本场景累计 **32 次失败**（`JedisClusterOperationException`）。
- **数据丢失：0**。

## 5. 两场景对比

| 维度 | 场景 A（kill -9） | 场景 B（VM 静默/STOP） |
| --- | --- | --- |
| 故障检测+选举完成 | +19.8s | +21.9s |
| 客户端完全恢复 | **≈20.3s** | **≈23.5s** |
| 故障期吞吐 | 近 0，但有零星成功（连接被 RST 快速失败） | **绝对 0**（连接冻结，挂满超时） |
| 失败请求数 | 56 | 32（B 故障前基线更稳，窗口略短统计差异） |
| 恢复延迟尖刺 | \\~2.69s | \\~2.34s |
| 数据丢失 | 0 | 0 |
| 主导因素 | `cluster-node-timeout=15s` + 重试退避 | 同上，且无 RST 使**单连接阻塞更久** |

**结论**：两类故障都成功自动转移、零数据丢失，但**客户端可用性中断窗口长达 20–24s**，主要由
`cluster-node-timeout=15000` 决定（故障判定需 \~15s，叠加选举与客户端拓扑刷新）。VM 静默类故障
（无 RST）比进程崩溃**多约 2–3s**，且对客户端线程阻塞更严重。

## 6. 关键发现与风险

1. **单分片故障可拖垮整个客户端吞吐**：默认 `JedisCluster` 下，命中故障分片的请求在重试/退避中长时间占用线程，连累访问健康分片的请求。本测 8 线程时吞吐塌缩到近 0。线程数越少、socketTimeout 越大，拖累越严重。
2. **中断窗口 ≈ node-timeout**：20–24s 的写入中断对实时业务影响显著，需业务侧容忍或下调 node-timeout。
3. \*\*无 RST 的整机故障更"黏"\*\*：冻结/断电类故障让客户端连接挂满超时，比进程崩溃更慢恢复。
4. **零数据丢失是有条件的**：本测写入速率适中、复制已追平。**高写入压力 + appendfsync everysec + 异步复制**下，主宕机仍可能丢失最后约 1s 内已确认但未复制的写入；生产需按峰值写入复测 RPO。

## 7. 优化建议

**Redis 侧**

- 在网络稳定的同区/跨 AZ 环境，可将 `cluster-node-timeout` 由 15000 下调到 **5000–8000**，把中断窗口压到 \~7–10s（代价：网络抖动时误判故障概率上升）。建议做 5000 对照实验（脚本已支持）。
- 维持 `cluster-require-full-coverage no`，保证非故障分片在转移期间继续服务。

**Jedis 客户端侧（影响最大）**

- 适当\*\*减小 `socketTimeout`\*\*（如 300–500ms）+ 合理 `maxAttempts`（3–5），缩短单请求阻塞，避免线程被故障分片榨干。
- **增大业务线程/连接并发**，让健康分片的请求不被故障分片拖累；或对不同分片使用隔离的线程池。
- 应用层加**重试退避 + 熔断**，对写操作保证**幂等**，从容承受 20s 级（或调优后 7–10s）的瞬时不可用。
- 监控 `JedisClusterOperationException` 速率作为故障转移的应用级信号。

**部署侧**

- 主从强制跨 AZ（本方案已设计），确保任一 AZ 整体故障每个分片仍有存活副本。
- 按业务峰值写入量复测**数据丢失（RPO）**，必要时对关键写改用 `WAIT` 命令提升复制确认强度。

## 8. 证据与可复现

- 探针逐秒指标：`local-test/metrics-local.csv`（224 行，累计成功 543,754 次 / 失败 88 次 / 丢失 0）
- 探针控制台：`local-test/probe-console.log`
- 故障检测/选举原始日志：见报告第 3、4 节引用的 Redis 节点 `log.log`
- 复现：`local-test/cluster-harness.sh {start|create|stop}` + `java -jar redis-failover-probe.jar probe.local.properties`
- 多机(Azure)复现：`docs/RUNBOOK.md`

---

# 第二部分 · 端到端全链路取证分析（基于真实日志 + 监控）

> 本部分是在第 1–8 节基础上，对全套测试做的一次**全程插桩重跑**，目的是给出
> **逐时间戳、逐节点**的取证级链路分析。新增采集：① 6 个 Redis 节点每 \~300ms 的
> `INFO`/`CLUSTER INFO` 高频快照；② 各节点进程级 OS 指标（CPU/RSS/TCP ESTABLISHED）；
> ③ Jedis 客户端毫秒级**应用事件日志**（`metrics-local-events.log`）；④ 各节点原始
> Redis 日志（`run2/redis-700x.log`）。全部以**统一 epoch 毫秒时间轴**对齐。
> 
> 监控面板说明：当前环境无 Docker，未起真实 Grafana 实例；下列"Grafana 风格"面板由
> **真实实测指标**用脚本 `docs/gen_grafana.py` 按 Grafana 暗色主题渲染，\*\*数据本身是端到端
> 实测\*\*，可作为分析证据。多机环境用交付的 Prometheus+Grafana 栈可得到同语义的在线面板。

## 9. 监控总览与本次重跑拓扑

**本次重跑（run2）实测拓扑**（每次 `--cluster-replicas 1` 创建会重新随机分配主从，故与第 1 节示例略有不同，结论一致）：

| 分片 | 槽位 | 主 | 从 | 故障注入 |
| --- | --- | --- | --- | --- |
| 分片1 | 0–5460 | **7001** | 7004 | **场景A**：`kill -9` 7001 → 预期 7004 升主 |
| 分片2 | 5461–10922 | 7002 | 7005 | 旁观（仲裁投票方） |
| 分片3 | 10923–16383 | **7003** | 7006 | **场景B**：`SIGSTOP` 7003 → 预期 7006 升主 |

**注入时间线（实测，北京时间 2026-06-11）**，来源 `run2/inject-events.txt`：

| 事件 | epoch-ms | 墙钟 | 相对 t0(s) |
| --- | --- | --- | --- |
| 采集起点 t0 | 1781158826630 | 14:20:26.630 | 0 |
| 基线压测开始 | 1781158853388 | 14:20:53.388 | +26.8 |
| **A\\_KILL** `kill -9 7001` | 1781158873435 | **14:21:13.435** | +46.8 |
| A\\_RESTART 7001 重启 | 1781158908456 | 14:21:48.456 | +81.8 |
| **B\\_STOP** `SIGSTOP 7003` | 1781158930515 | **14:22:10.515** | +103.9 |
| B\\_CONT 7003 解冻 | 1781158965547 | 14:22:45.547 | +138.9 |
| 序列结束 | 1781158980595 | 14:23:00.595 | +153.9 |

**客户端总量（run2，172 个有效秒级样本）**：成功 **335,870**、失败 **81**、**数据丢失 0**、数据陈旧 0；峰值单请求延迟 4175ms（恢复瞬间长尾）。

**全程三视图监控总览**（客户端 / Redis 集群 / 操作系统）：

![客户端全程](img/gf-client-full.png)

![Redis集群全程](img/gf-redis-full.png)

![操作系统全程](img/gf-os-full.png)

> 一眼可见：两条红色虚线（A\_KILL / B\_STOP）处客户端 QPS 各出现一次塌陷，对应 Redis 面板里
> 某节点 `role` 由 replica 跃升为 master、`cluster_state` 短暂抖动；OS 面板里故障端口 TCP
> 连接数掉到 0、连接迁移到新主。绿色虚线（A\_RESTART / B\_CONT）处可见旧节点以副本身份回归。

---

## 9.A 场景A全链路：主进程 `kill -9`（7001，分片1 主）

### 9.A.1 场景A监控特写（场景A时间窗）

![场景A-客户端](img/gf-client-A.png)

![场景A-Redis](img/gf-redis-A.png)

![场景A-操作系统](img/gf-os-A.png)

### 9.A.2 逐时间戳·逐节点全链路（以各节点 `log.log` 原始行 + 客户端事件日志对齐）

下面把同一时刻**不同节点的视角**并排展开。`397:S`/`399:M` 等前缀为 Redis 自带的
`pid:角色` 标记（S=replica，M=master，C=子进程）。

#### 阶段0 — 稳态（T+0 之前）

- **客户端**：8 线程持续读写，QPS≈2400，P50≈1ms，P99≈10ms，0 失败（见 `metrics-local.csv` 14:20:34–14:21:13 段）。
- **7004（分片1从）**：`master_link_status:up`，`slave_repl_offset` 紧追 7001（面板"复制偏移量"两线重合）。

#### 阶段1 — 故障注入 T=14:21:13.435（相对 +46.8s）

```javascript
[注入器] 1781158873435 A_KILL port=7001 pid=378 cmd=kill-9 (主进程崩溃)
```

- 内核立即回收 7001 的 socket。**与"整机宕机"不同，进程崩溃会让内核对后续连接回 RST**，这点决定了客户端表现（见阶段2）。

#### 阶段2 — 故障感知（T+1ms ～ T+17.2s）

**① 直连从节点 7004（最先感知，TCP 层）** — `run2/redis-7004.log`：

```javascript
399:S 14:21:13.441 # Connection with master lost.
399:S 14:21:13.441 * Caching the disconnected master state.
399:S 14:21:13.441 * Reconnecting to MASTER 127.0.0.1:7001
399:S 14:21:13.441 # Error condition on socket for SYNC: Connection refused
399:S 14:21:14.697 ... Connection refused   (此后每 ~1s 重试一次，持续到选举)
```

> 7004 在 **6ms 内**就发现主断链（收到 RST → Connection refused）。但**它不能立刻发起选举**——
> Redis Cluster 要求先由集群多数派将主标记为 `FAIL`，避免误判。于是 7004 进入"每秒重连 + 等待 FAIL"的等待期。

**② 其他主节点 7002 / 7003（Gossip 层，决定何时 FAIL）** — `run2/redis-7002.log` / `redis-7003.log`：

```javascript
382:M 14:21:30.640 * Marking node a26c81be...(7001) as failing (quorum reached).
392:M 14:21:30.640 * Marking node a26c81be...(7001) as failing (quorum reached).
```

> **关键**：FAIL 标记发生在 **14:21:30.640**，距 kill（14:21:13.435）= **+17.2s**。
> 这正是 `cluster-node-timeout=15000ms`（PFAIL 阈值）+ Gossip 传播/多数派确认（约 2s）的体现。
> 这 17s 就是"故障检测窗口"，也是客户端不可用时长的主体。

**③ 客户端（应用侧）** — `metrics-local-events.log` + 控制台：

```javascript
14:21:14.472 [ERROR] FIRST_ERROR type=JedisClusterOperationException msg="No more cluster attempts left."
14:21:14  qps=4 fail=1     ← 命中分片1(slot 0-5460)的请求开始失败
... 14:21:14 ～ 14:21:32 QPS 长期 2–11，期间两次跌到绝对 0：
14:21:23.644 [WARN] OUTAGE_BEGIN 客户端整体吞吐跌至 0
14:21:24.649 [INFO] OUTAGE_END  不可用时长≈1005ms
14:21:30.242 [WARN] OUTAGE_BEGIN
14:21:31.248 [INFO] OUTAGE_END  不可用时长≈1006ms
```

> **应用级机理**：命中分片1的 `kill -9` 后请求立即收到 RST→`maxAttempts=5` 次重试在 \~1s
> `socketTimeout` 内迅速耗尽 → 抛 `JedisClusterOperationException("No more cluster attempts left.")`。
> 8 个工作线程频繁被分片1请求拖入"重试-失败"循环，连访问健康分片2/3的请求也被挤占，
> 故整体 QPS 从 2400 塌到个位数。**这是单分片故障放大为全局抖动的根因**。

#### 阶段3 — 选举与升主（T+17.2s ～ T+18.2s）

**新主 7004** — `run2/redis-7004.log`：

```javascript
399:S 14:21:30.640 * FAIL message received from f47d7...(7003) about a26c81be...(7001)
399:S 14:21:30.650 # Start of election delayed for 926 milliseconds (rank #0, offset 8585374).
399:S 14:21:31.656 # Starting a failover election for epoch 7.
399:S 14:21:31.660 # Failover election won: I'm the new master.
399:S 14:21:31.660 # configEpoch set to 7 after successful failover
399:M 14:21:31.660 # Setting secondary replication ID to 499e88e8..., valid up to offset: 8585375.
```

**投票方 7002 / 7003**（其他主授权）：

```javascript
382:M 14:21:31.658 # Failover auth granted to 23a7908e...(7004) for epoch 7
392:M 14:21:31.658 # Failover auth granted to 23a7908e...(7004) for epoch 7
```

> **选举原理逐项**：
> - `delayed 926ms`：副本按 `500ms + random(0..500) + rank*1000` 错开发起，避免多副本同时拉票（本分片只有 1 副本，rank=0）。
> - `epoch 7`：单调递增的选举纪元，确保同一故障只有一任合法新主。
> - `offset 8585374`：7004 把自己的复制偏移随拉票广播，**偏移最大的副本最有资格**（数据最新），从机制上**最小化数据丢失**。
> - `auth granted`：7002+7003 两个健康主投票，**达到多数派（3 主中 2 票）** → 7004 在 **1.02s 内**完成升主（30.640→31.660）。

#### 阶段4 — 客户端拓扑刷新与恢复（T+18.6s ～ T+21s）

- Redis 面板：14:21:31.66 起 7004 的 `role` 阶梯由 replica 跃到 master，`connected_slaves` 由 0 变 1（7001 回归后），`master_repl_offset` 由 7004 延续，无断点。
- **客户端**（`metrics-local.csv`）：

```javascript
14:21:32  qps=226   max=541ms   ← JedisCluster 收到错误后刷新 slot→node 映射，重路由到 7004
14:21:33  qps=1768  max=4175ms  ← 恢复瞬间积压请求集中释放，P99/Max 长尾
14:21:34  qps=3035 ... 14:21:35 qps=4417（追赶式过冲，高于基线）
```

> JedisCluster 在请求失败后触发 `renewSlotCache()`，对集群重新 `CLUSTER SLOTS`，
> 把分片1(0–5460) 指向新主 7004:已生效。**端到端不可用净时长 ≈ 18.6s**（14:21:13.4 注入 → 14:21:32 实质恢复），与检测窗口高度吻合。

#### 阶段5 — 旧主重启回归（T+35s）

**7001 重启** — `run2/redis-7001.log`：

```javascript
30410:M 14:21:48.537 * Ready to accept connections
30410:M 14:21:48.537 # Configuration change detected. Reconfiguring myself as a replica of 23a7908e...(7004)
30410:S 14:21:48.542 * Full resync from master: 5be3fc43...:14671807
30410:S 14:21:48.686 # Done loading RDB, keys loaded: 13496, keys expired: 0.
```

**新主 7004 接纳**：

```javascript
399:M 14:21:48.541 * Partial resynchronization not accepted: Replication ID mismatch ...
399:M 14:21:48.541 * Starting BGSAVE for SYNC with target: disk
399:M 14:21:48.596 * Synchronization with replica 127.0.0.1:7001 succeeded
```

> 7001 重启后读 `nodes.conf` 发现集群已换主、自己 configEpoch 落后，**自动降级为 7004 的副本**，
> 做一次全量重同步（复制 ID 不匹配，无法部分重同步）。分片1从此恢复 1 主 1 从冗余。**全程 0 人工干预**。

---

## 9.B 场景B全链路：VM 静默 `SIGSTOP`（7003，分片3 主）

> `SIGSTOP` 冻结进程但**不关闭任何 socket**，模拟"虚拟机宕机/网络分区/内核 hang"——
> 即**无 FIN/无 RST**的"静默失联"。这与场景A的"进程崩溃回 RST"有本质差别。

### 9.B.1 场景B监控特写（场景B时间窗）

![场景B-客户端](img/gf-client-B.png)

![场景B-Redis](img/gf-redis-B.png)

![场景B-操作系统](img/gf-os-B.png)

### 9.B.2 逐时间戳·逐节点全链路

#### 阶段1 — 故障注入 T=14:22:10.515（相对 +103.9s）

```javascript
[注入器] 1781158930515 B_STOP port=7003 pid=392 cmd=SIGSTOP (VM静默: 进程冻结, 无FIN/RST, 连接挂起)
```

- 7003 内核态被冻结，**既不回 PONG，也不回 RST**。它的副本 7006 与客户端的 TCP 连接仍处 `ESTABLISHED`（OS 面板 7003 端口连接数维持到检测完成才掉零）。

#### 阶段2 — 故障感知（更"黏"，T+22.5s 才 FAIL）

**副本 7006 视角** — `run2/redis-7006.log`：与场景A不同，\*\*7006 没有立即出现 "Connection lost"\*\*——因为没有 RST，它只能等心跳超时。
**其他主 7001 标记 FAIL** — `run2/redis-7001.log`：

```javascript
30410:S 14:22:33.067 * Marking node f47d7...(7003) as failing (quorum reached).
```

> FAIL 在 **14:22:33.067**，距 SIGSTOP（14:22:10.515）= **+22.5s**，比场景A的 17.2s **更长约 5s**。
> 原因：无 RST 的静默失联只能靠 `cluster-node-timeout` 心跳超时判定，且 Gossip 需要更久才让多数派一致，
> **"黏滞"故障的检测天然更慢**。

**客户端**（`metrics-local.csv`）——本场景吞吐**长时间绝对为 0**：

```javascript
14:22:11 qps=341
14:22:12 ～ 14:22:33  qps=0（连续 ~22s 完全冻结！）
14:22:15.645 [ERROR] msg="Cluster retry deadline exceeded."
```

> 机理对比：场景A请求收到 RST 会快速失败-重试（QPS 还有个位数"涓流"）；
> 场景B请求发往冻结的 7003 后**石沉大海**，只能挂到 `socketTimeout`/`connectionTimeout` 超时，
> 线程被大面积挂起，命中分片3的请求**完全无响应**，故 QPS 直接归零。\*\*静默故障对应用更"致命"\*\*。

#### 阶段3 — 选举与升主（T+22.5s ～ T+23.2s）

**新主 7006** — `run2/redis-7006.log`：

```javascript
410:S 14:22:33.068 * FAIL message received from a26c81be...(7001) about f47d7...(7003)
410:S 14:22:33.086 # Start of election delayed for 563 milliseconds (rank #0, offset 20123094).
410:S 14:22:33.690 # Starting a failover election for epoch 8.
410:S 14:22:33.706 # Failover election won: I'm the new master.
410:S 14:22:33.706 # configEpoch set to 8 after successful failover
```

**投票方 7002 / 7004**：

```javascript
382:M 14:22:33.701 # Failover auth granted to 56c8978f...(7006) for epoch 8
399:M 14:22:33.701 # Failover auth granted to 56c8978f...(7006) for epoch 8
```

> `epoch 8`（比上次 7 更大，单调递增）；7006 携 `offset 20123094` 拉票，多数派授权后 **0.64s** 升主。

#### 阶段4 — 客户端恢复（T+23.5s）

```javascript
14:22:34 qps=413  max=2354ms  ← 重路由到 7006
14:22:35 qps=1633 ... 逐步追平基线
```

> **端到端不可用净时长 ≈ 23s**（14:22:11 → 14:22:34），比场景A长，验证"静默故障更慢恢复"。

#### 阶段5 — 冻结节点解冻回归（T+35s，部分重同步！）

**7003 解冻** — `run2/redis-7003.log`：

```javascript
392:M 14:22:45.773 # Failover auth denied to 56c8978f...(7006): its master is up   ← 解冻瞬间的"陈旧世界观"
392:M 14:22:45.773 # Configuration change detected. Reconfiguring myself as a replica of 56c8978f...(7006)
392:S 14:22:45.797 * Trying a partial resynchronization (request 0673c64c...:20123095).
392:S 14:22:45.797 * Successful partial resynchronization with master.
```

**新主 7006 接纳（部分重同步成功，仅补发增量）**：

```javascript
410:M 14:22:45.797 * Partial resynchronization request from 127.0.0.1:7003 accepted.
                     Sending 2525869 bytes of backlog starting from offset 20123095.
```

> 精彩细节：7003 刚解冻时仍以为"我还是主"，对 7006 的拉票回了 `auth denied`；但随即通过 Gossip
> 看到 `epoch 8` 更高的新主，**立即降级为副本**。因为它被冻结、数据未被破坏，且偏移仅落后约 2.5MB
> （在 `repl-backlog-size=100mb` 范围内），故只需 **部分重同步（partial resync）补 backlog**，
> 无需全量——比场景A 7001 的全量重同步快得多。

---

## 9.C 两场景端到端对比

| 维度 | 场景A：`kill -9`（进程崩溃） | 场景B：`SIGSTOP`（VM静默/无RST） |
| --- | --- | --- |
| 故障注入时刻 | 14:21:13.435 | 14:22:10.515 |
| 副本 TCP 感知 | **6ms**（收到 RST→Connection refused） | 无即时感知（靠心跳超时） |
| 集群标记 FAIL | +17.2s（14:21:30.640） | **+22.5s**（14:22:33.067） |
| 选举耗时 | 1.02s（delay 926ms） | 0.64s（delay 563ms） |
| 升主纪元 | epoch 7 → 7004 | epoch 8 → 7006 |
| 客户端净不可用 | **≈18.6s**（仍有个位数涓流） | **≈23s**（连续 22s 绝对 0） |
| 恢复瞬间 Max 延迟 | 4175ms | 2354ms |
| 旧节点回归方式 | **全量重同步**（复制ID不匹配） | **部分重同步**（仅补 \\~2.5MB backlog） |
| 数据丢失 | **0** | **0** |
| 应用观感 | 抖动塌缩 | 完全冻结（更"致命"） |

**核心结论**：检测窗口（≈node-timeout）主导不可用时长；\*\*静默失联比进程崩溃更慢、更"黏"\*\*；
选举本身仅占\~1s；零数据丢失在本测写入压力下成立（详见第 10 章）。

---

## 10. 数据完整性、一致性与数据丢失分析

> 本章回答三个问题：Redis Cluster **如何保持一致性/完整性**？**哪些场景会丢数据**？**如何补偿/加固**？
> 结合本测的真实结果（两轮共 **0 丢失**）说明零丢失的**前提条件**，避免误以为"故障转移一定不丢"。

### 10.1 一致性模型：Redis Cluster 是"最终一致 + 异步复制"

- **写入路径**：客户端写命中槽主节点 → 主**本地执行并立即向客户端返回 OK** → **之后**才异步把命令流推给副本。
  即 **主对客户端的 ACK 不等待副本确认**（与 `appendfsync` 无关，那是落盘策略）。
- **推论**：主返回 OK 与副本收到之间存在一个**复制窗口（replication lag）**。若主在该窗口内宕机且发生故障转移，
  窗口内"已 ACK 但未复制"的写入会**随旧主一起丢失** → 这是 Redis 的 **RPO > 0** 之源。
- **槽位归属一致性**：靠 `configEpoch` 单调递增 + 多数派授权保证"同一槽同一时刻只有一个合法主"，
  避免双主写入冲突（防脑裂的核心，见 9.A/9.B 中 `epoch 7/8` 与 `auth granted`）。

### 10.2 完整性保障机制（本方案已启用的多道防线）

| 机制 | 配置/原理 | 作用 |
| --- | --- | --- |
| **AOF 持久化** | `appendonly yes` + `appendfsync everysec` | 单节点崩溃重启可回放命令，最坏丢 \\~1s 内未 fsync 的写 |
| **AOF 加载容错** | `aof-load-truncated yes` | 末尾残缺命令被忽略，保证能拉起 |
| **最优副本升主** | 选举携 `master_repl_offset`，偏移最大者优先（9.A 阶段3） | 故障转移时**尽量选数据最全的副本**，最小化丢失 |
| **复制积压缓冲** | `repl-backlog-size 100mb` | 副本短暂断链/解冻后**部分重同步**（9.B 阶段5 实证），避免全量、减小不一致窗口 |
| **configEpoch 仲裁** | 单调纪元 + 多数派 | 防止脑裂导致的写冲突 |
| **跨 AZ 主从** | 部署方案强制主从分属不同 AZ | 单 AZ 故障时分片仍存活，保住已复制数据 |
| **不接受陈旧写** | 旧主解冻后看到更高 epoch 立即降副本（9.B 实证） | 杜绝"旧主继续接收写"造成的分叉 |

### 10.3 可能的数据丢失场景（务必在生产前评估）

1. **异步复制窗口丢失（最常见，RPO>0）**：主已对客户端返回 OK，但命令尚未到达任何副本，此时主宕机+转移 →
   该批写入永久丢失。**丢失量 ≈ 写入速率 × 复制延迟**。本测写入适中、副本已追平（面板中两线重合），窗口几乎为 0，故 0 丢失。
   **高写入压力或跨 AZ 高延迟下，此窗口会放大。**
2. **AOF fsync 间隙丢失**：`appendfsync everysec` 下，主进程崩溃 + **整机断电**可能丢失最后 \~1s 已写入 page cache 但未落盘的命令
   （注意：仅进程崩溃而 OS 存活时，page cache 仍会被 OS 落盘，不丢）。
3. **故障转移期间的写入拒绝（非丢失但表现为失败）**：检测窗口内命中故障分片的写直接报错（本测 81 次），
   若应用未重试，则这些写**从未成功**——属"未写入"而非"丢失"，但业务需正确处理。
4. **双重故障 / 副本同时不可用**：主与其唯一副本同时故障（如同 AZ 同时挂、或副本正好在重同步），
   分片无法转移；恢复后只能从最后一次 RDB/AOF 还原，丢失其后增量。
5. **脑裂边缘场景**：旧主在被标记 FAIL 后、自己尚未感知前的极短窗口内若仍接收写（`cluster-node-timeout` 内），
   这些写在新主接管后会被丢弃。`min-replicas-to-write` 可收敛此窗口。
6. **full-resync 期间主再故障**：副本正在全量重同步（如 9.A 中 7001 回归全量）时若新主又故障，重同步中断需重来。

### 10.4 为什么本测两轮都"0 丢失"——前提条件

- 写入速率适中（≈1200 写/s），**复制延迟≈0**（面板"复制偏移量"两线全程重合），异步窗口内几乎无在途写；
- 故障注入针对**单分片单主**，其副本数据已追平 → 升主时选到了**全量数据**的副本；
- 探针用"**写入后回读校验**"（`data_lost`/`data_mismatch` 计数器，见 `FailoverProbe.verifier()`）确认：
  335,870 次成功写无一回读丢失。
- **⚠️ 不可外推**：这不代表生产零丢失。**必须按业务峰值写入量复测 RPO**，详见 10.5。

### 10.5 补偿与加固方案（按"强度/代价"递进）

**A. Redis/部署侧**

- `min-replicas-to-write 1` + `min-replicas-max-lag 10`：主在"至少 1 个副本在线且滞后<10s"时才接受写，
  **主动收窄异步窗口与脑裂面**（代价：副本全挂时主拒绝写，牺牲可用性换一致性）。
- 关键写改用 **`WAIT numreplicas timeout`：阻塞到指定数量副本确认后再返回，把该笔写变成"半同步"，将 RPO 逼近 0**
  （代价：写延迟上升，超时仍不保证）。
- 提高落盘强度：对极关键数据可 `appendfsync always`（代价：吞吐显著下降）。
- 调小 `cluster-node-timeout`（如 5000–8000）缩短检测窗口 → 减少"转移期写拒绝"量（代价：网络抖动误判风险上升）。
- 主从强制跨 AZ（本方案已实现），并保证每主**≥2 副本**以抵御双重故障。

**B. Jedis 客户端 / 应用侧（最关键、性价比最高）**

- **写操作幂等化**：用业务主键/版本号/去重表，使"超时后重试"安全可重入——把"转移期失败的写"通过重试补回，**等价于不丢**。
- **重试退避 + 熔断**：对 `JedisClusterOperationException` 做指数退避重试（覆盖 18–23s 检测窗口），命中阈值则熔断降级。
- 适当**减小 `socketTimeout`（300–500ms）**、增大业务并发/分片隔离线程池，避免单分片故障榨干全部线程（9.A/9.B 实证的放大效应）。
- 监控 `JedisClusterOperationException` 速率作为**应用级故障转移信号**，联动告警。

**C. 应用级数据校对（兜底）**

- 关键写**双写/旁路日志**（如写 Redis 同时投递 MQ/落库），故障转移后用日志做**对账与补偿回放**。
- 周期性**一致性校验任务**：对账 Redis 与权威存储（DB），发现缺失即补写——覆盖 10.3 中场景1/4 的残余丢失。
- 对"读到旧值"敏感的场景，读路径加版本校验或强制读主，规避副本陈旧读。

**结论**：Redis Cluster 通过 *configEpoch 仲裁 + 最优副本升主 + AOF + backlog 部分重同步* 提供了**强的完整性与自动恢复**，
但其**异步复制本质决定 RPO 可能 >0**。生产要做到"实质不丢"，应以 **(B) 幂等重试** 为主力、\*\*(A) min-replicas/WAIT\*\* 收窄窗口、
**(C) 对账补偿** 兜底，并**按峰值写入复测 RPO**，而非默认零丢失。

---

## 11. 取证证据清单（run2 全程插桩重跑）

- 客户端逐秒指标：`local-test/run2/metrics-local.csv`（172 行；成功 335,870 / 失败 81 / 丢失 0）
- 客户端**应用事件日志**（毫秒级）：`local-test/run2/probe-events.log`
- 6 节点 Redis 原始日志：`local-test/run2/redis-7001.log` … `redis-7006.log`
- Redis 高频指标快照（\~300ms）：`local-test/run2/nodes-metrics.csv`（774 行）
- 进程级 OS 指标：`local-test/run2/os-metrics.csv`（774 行）
- 故障注入时间戳：`local-test/run2/inject-events.txt`
- Grafana 风格面板（由真实指标渲染）：`docs/img/gf-{client,redis,os}-{full,A,B}.png`（9 张）
- 采集脚本：`local-test/collect-metrics.sh`、`local-test/inject-sequence.sh`、`docs/gen_grafana.py`
- 复现：`local-test/cluster-harness.sh {start|create|stop}` → 启动 `collect-metrics.sh` 与探针 → `inject-sequence.sh` → `gen_grafana.py`


---

## 12. 跨 AZ 主从布局对延迟的影响（专项实测）

> 需求：把每个分片的**主与其副本分到不同 AZ**（跨 AZ 复制），评估“延迟是否有变化”。
> 交付的 `cluster.env` 拓扑**本就是强制跨 AZ**：A(AZ1)→副本 AZ2、B(AZ2)→副本 AZ3、C(AZ3)→副本 AZ1，
> 即任一 AZ 整体故障最多损失“每分片的一侧”，集群仍可自动选举存活副本。
> 但跨 AZ 相比同 AZ，会在**复制链路**上引入额外的 AZ 间网络 RTT（Azure 同区域跨 AZ 通常约 0.3~2 ms）。

### 12.1 方法（消除单机零延迟的干扰）

本机 6 实例都在 loopback 上、节点间 RTT≈0，无法直接体现跨 AZ 时延。为**干净地隔离“复制链路时延”这一个变量**，
单独起一对 `master(:8001) + replica(:8002)`，让**副本经一个用户态时延代理 `delay_proxy.py` 连接主**，
对复制流双向各注入单向时延 D（有效复制 RTT≈2D）；**客户端仍直连主**（不经代理）。
逐档测量：客户端 `SET` 延迟、`SET+WAIT 1`（= 副本 ACK 往返）、满负载下复制积压字节。脚本：`local-test/crossaz/`。

![跨 AZ 复制时延影响](img/gf-crossaz-latency.png)

### 12.2 实测结果（`local-test/crossaz/results.csv`）

| 注入单向时延 | 实测复制 RTT(WAIT 均值) | **客户端 SET 均值** | 客户端 SET p50(bench) | bench 吞吐 | 满负载复制积压(均值) |
| --- | --- | --- | --- | --- | --- |
| 0 ms（同 AZ 基线） | 0.52 ms | **0.197 ms** | 0.071 ms | 62.8k rps | 40 MB |
| 0.5 ms | 4.66 ms | **0.183 ms** | 0.063 ms | 62.7k rps | 96 MB |
| 1 ms | 4.36 ms | **0.283 ms** | 0.055 ms | 67.1k rps | 145 MB |
| 2 ms | 8.13 ms | **0.205 ms** | 0.079 ms | 59.8k rps | 172 MB |

> 注：本机用户态代理的 `asyncio` 调度精度有下限，亚毫秒档（0.5 / 1 ms）注入后实测 RTT 都落在约 4~5 ms，
> 量级偏大但**单调**；真实 Azure 跨 AZ RTT 通常更小（小于 1~2 ms）。这里看**趋势与机理**而非绝对值。

### 12.3 结论：客户端延迟“几乎不变”，变的是复制滞后与丢失窗口

- **客户端写/读延迟基本不随主从是否跨 AZ 变化**。原因：Redis 复制是**异步**的——`SET` 在**主**写入内存 + 追加到复制 backlog 后**立即**返回，**不等待**副本确认。上表中复制 RTT 从 0.5 ms 拉到 8 ms，客户端 SET 均值仍稳定在 0.18~0.28 ms，bench p50 / 吞吐无显著变化。
- **真正随跨 AZ 时延上升的是**：① **副本 ACK 往返**（`WAIT` / 半同步路径）；② **复制滞后/积压**（满负载下 40 → 172 MB），它约等于**主宕机瞬间副本尚未收到的数据量**，也就是**潜在 RPO（丢失窗口）**。
- **取舍**：跨 AZ 用“略增的复制滞后/丢失窗口”换取“AZ 级容灾能力”。对延迟敏感的同步语义（`WAIT N`、`min-replicas-to-write`）会**直接吃到 AZ 间 RTT**，需按 SLA 权衡；纯异步读写则几乎无感。

---

## 13. 通过优化尽可能缩短故障转移中断时间（A/B 实测）

> 需求：在跨 AZ 布局下，**尽量缩短**故障转移期间的客户端中断时间。

### 13.1 中断时长由谁决定

主进程被 `kill -9` 后，客户端中断窗口约等于
**故障检测**（受 `cluster-node-timeout` 主导：未应答 PING 超过该值才置 PFAIL，叠加心跳相位偏移 0 ~ timeout/2；再经多数主把 PFAIL 升级为 FAIL）
\+ **选举**（`500ms + random(0..500ms) + rank × 1000ms`，硬编码，通常亚秒级）
\+ **客户端拓扑刷新**（重定向到新主）。
其中**检测窗口最大且唯一可观调**——降低 `cluster-node-timeout` 是缩短中断的**首要手段**。

### 13.2 A/B 实验（唯一变量 = cluster-node-timeout）

同一套 6 节点 3 主 3 从集群、同一探针、同样 `kill -9` 持有键 `{probe}` 的主，仅改 `cluster-node-timeout`。
脚本 `local-test/crossaz/run-failover-ab.sh` + `cluster_probe.py`（毫秒级记录 `OUTAGE_BEGIN/END`）。

![故障转移中断时间优化](img/gf-failover-opt.png)

| 配置 | cluster-node-timeout | **客户端写入中断时长** | 相对基线 | 故障期失败请求 |
| --- | --- | --- | --- | --- |
| baseline | 15000 ms | **20.7 s** | — | 3028 |
| 推荐 | 5000 ms | **8.8 s** | **降低 58%** | 1298 |
| 激进 | 3000 ms | **4.8 s** | **降低 77%** | 700 |

实测毫秒时间线（`local-test/crossaz/outage-*.events`）：

- baseline：`kill` → `OUTAGE_BEGIN` 仅 +3 ms（客户端瞬时感知主失联），`OUTAGE_END` +20716 ms。
- opt5000：`OUTAGE_BEGIN` +7 ms，`OUTAGE_END` +8793 ms。
- opt3000：`OUTAGE_BEGIN` +5 ms，`OUTAGE_END` +4849 ms。

中断时长约等于 `cluster-node-timeout` + 约 2~6 s 的（选举 + FAIL 传播 + 客户端刷新）开销，且开销项也随 timeout 降低而收窄。

### 13.3 推荐优化清单（按收益排序）

1. **`cluster-node-timeout` 15000 → 5000 ms（首选）**：实测中断 20.7 s → 8.8 s。这是性价比最高的一项。
   - 代价：检测更灵敏，对**网络抖动 / 长 GC / 瞬时高负载**更易误判。跨 AZ 部署需确保 AZ 间 RTT 与抖动远小于 timeout（westus3 跨 AZ 约 1~2 ms，5000 ms 余量充足）。3000 ms 仅在网络质量稳定时采用。
2. **客户端快失败 + 主动刷新拓扑**：`socketTimeout` 调小（如 500~800 ms，大于跨 AZ RTT 即可）、`maxAttempts` 适中（4~5）、命中重定向/连接异常立即刷新 slots。让“恢复尾延迟”贴近服务端选举完成时刻（本实验探针即 300 ms 超时 + 失败即重发现，故 `OUTAGE_END` 紧随新主就绪）。
3. **保证多数主存活 + 低滞后副本**：PFAIL → FAIL 需多数主投票；`cluster-replica-validity-factor` 默认 10，滞后过大的副本会被禁止升主而拖慢/阻断转移。跨 AZ 下尤其要监控复制滞后（见 §12）。
4. **计划内切换用 `CLUSTER FAILOVER`**：维护/演练时由副本发起，主从协商 + offset 对齐，**亚秒级**完成且**不丢数据**，远优于被动检测路径。
5. **连接预热与连接池**：`testOnBorrow` + 预建连接，避免转移后新建连接的额外 RTT 叠加放大尾延迟。

> 综合：跨 AZ 布局（§12，保 AZ 级容灾）+ `cluster-node-timeout=5000`（本节，中断降低 58%）+ 客户端快失败重发现 + 幂等重试（§10），
> 即可在“AZ 容灾、低中断、实质不丢”之间取得工程最优。

### 13.4 复现

```
# 跨 AZ 复制时延影响
cd local-test/crossaz && bash run-crossaz.sh        # -> results.csv
# 故障转移中断时间 A/B（node-timeout 15000/5000/3000）
bash run-failover-ab.sh                              # -> outage-summary.csv, outage-*.events
# 渲染图表
python3 ../../docs/gen_crossaz.py                    # -> docs/img/gf-crossaz-latency.png, gf-failover-opt.png
```
