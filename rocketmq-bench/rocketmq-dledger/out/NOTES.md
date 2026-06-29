# RocketMQ 故障转移测试 - 数据记录

## 环境
- 集群 RocketMQCluster, RocketMQ 4.9.7 DLedger, 2 broker 组 (broker-a, broker-b), 每组 3 副本 (n0/n1/n2) 跨 z1/z2/z3。
- preferredLeaderId=n1 (zone 2: a-1=10.170.0.11, b-1=10.170.0.14)。
- NameServer: 10.170.0.4(z1);10.170.0.6(z2);10.170.0.5(z3) :9876
- 客户端 v6rocketmqclient 10.170.0.7(z1)。官方 rocketmq-client (Java), 并发 producer, 重试关闭 (raw failover 测量)。

## 基线 (baseline)
- ~1005 msg/s, 0 失败, p99=2ms, 30s 发送 29957 条。

## 测试1: kill -9 (双 master 同 zone=2 同时 kill)
- runId=killA, topic=ft_kill, 10线程×100/s ≈1000/s, 时长240s。
- 两个 zone-2 master (.11 broker-a, .14 broker-b) 在 16:01:40~42 UTC 同时 kill -9。
- okTotal=226001, failTotal=13051。

### 故障转移时间线 (UTC)
| sec | wall | ok/s | fail/s | 说明 |
|-----|------|------|--------|------|
| 126-133 | 16:01:31~38 | ~1005-1011 | 0 | 稳态, p99=2ms |
| 134 | 16:01:39.984 | 972 | 0 | kill 触发, max=73ms 抖动 |
| 135 | 16:01:40.984 | 911 | 77 | 故障开始 |
| 136 | 16:01:41.985 | 470 | 479 | 两 master 下线 |
| 137 | 16:01:42.985 | 60 | 809 | |
| 138-149 | 16:01:43~54 | 0 | ~818-940 | 完全中断 ~12s |
| 150 | 16:01:55.987 | 56 | 870 | 恢复开始 |
| 151 | 16:01:56.987 | 1013 | 0 | **完全恢复** |
| 152-240 | 16:01:57~ | ~1005 | 0 | 稳态, p99=2-4ms |

### 关键指标 (Test 1)
- 故障检测+切换窗口: 16:01:40.984 (首个失败) → 16:01:56.987 (完全恢复) ≈ **16 秒**
- 完全零吞吐黑屏期: sec 138-149 ≈ **12 秒**
- 失败(被拒)消息数: 13051 (重试关闭; 真实带重试客户端会在切换后成功)
- 恢复后吞吐/延迟与基线一致 (~1005/s, p99=2-4ms)
- kill -9 → 立即 RST → DLedger 快速选举 → preferred n1 不可用时从存活 z1/z3 节点选新 leader

### Test 1 数据完整性 (verify)
- VERIFY_DONE unique=226002 dup=0 (okTotal=226001)
- **RPO=0, 无已提交消息丢失**。unique 比 okTotal 多 1 = 客户端超时判失败但 broker 实际已提交 (at-least-once)。
- 13051 个"失败"是被拒绝的发送 (重试关闭); 真实带重试客户端会在切换后成功。

### Test 1 后集群状态
- 自动选举新 leader: broker-a → 10.170.0.10 (a-0, **zone 1**), broker-b → 10.170.0.13 (b-0, **zone 1**)。
- 被 kill 的 .11/.14 经 recover-node.sh 擦除存储+重新同步恢复 (398M/425M)。
- 关键: graceful restart 会损坏 DLedger 存储导致 crash-loop, 必须擦除 store 重新同步。

## 测试2: SIGSTOP (冻结主进程, 模拟整机静默/无 RST)
- 恢复 .11/.14 后, 因 preferredLeaderId=n1, leader 自动交还回 .11 (broker-a, z2) 和 .14 (broker-b, z2)。两 master 同 zone (zone 2)。

### ⚠️ Test 2 首次尝试无效 (重要排错记录)
- scheduled-freeze.sh 用 `pgrep -f BrokerStartup | head -1` 选中的是**包装 shell `sh runbroker.sh ...` (pid 84416)**, 真正的 broker JVM 是其子进程 `java ...BrokerStartup` (pid 84441)。
- SIGSTOP 冻结了无关的 shell, JVM 继续服务 → producer 全程 0 失败、p99=2ms、无故障转移。证据: .11 stat=T 但 broker.log 在 16:29:56 仍在写入并 register broker[0]。
- 对比: Test 1 的 kill -9 仍然有效, 因为 systemd (KillMode=control-group) 在 MainPID(shell) 退出时连带 kill 整个 cgroup 内的 JVM。
- 修复: freeze 脚本改用 `pgrep -f 'java.*BrokerStartup'` 精确命中 JVM。已 SIGCONT 恢复被误冻的 shell。Test 2 重做 (runId=stopB, topic=ft_stop2)。

### Test 2 (有效): SIGSTOP 冻结两个 z2 master 的 JVM
- runId=stopB, topic=ft_stop2, 10线程×100/s≈1000/s, 时长360s。
- 冻结 JVM (pid .11=84441, .14=101780) at 16:39:12.653 UTC (同时)。
- okTotal=333966, failTotal=99。

#### 故障转移时间线 (UTC)
| sec | wall | ok/s | fail/s | 说明 |
|-----|------|------|--------|------|
| 154-155 | 16:39:10~11 | ~1003 | 0 | 稳态 |
| 156 | 16:39:12.215 | 944 | 0 | 冻结触发 (16:39:12.653) |
| 157-158 | 16:39:13~14 | 0 | 0 | 发送阻塞 (in-flight 等待冻结 broker, 未超时) |
| 159 | 16:39:15 | 0 | 10 | 首批超时失败 (3s sendMsgTimeout) |
| 159-182 | 16:39:15~38 | 0 | ~10/3s | 写入完全中断, 失败缓慢累积 (线程阻塞在超时) |
| 183 | 16:39:39 | 80 | 10 | 恢复开始 |
| 184 | 16:39:40 | 1009 | 0 | **完全恢复** |
| 185-360 | 16:39:41~ | ~1003 | 0 | 稳态, p99=2ms |

#### 关键指标 (Test 2)
- 写入中断窗口: 16:39:13 (ok=0) → 16:39:39 (恢复) ≈ **26-27 秒**
- 失败(超时)消息数: **仅 99** (远低于 kill -9 的 13051)
- 原因: SIGSTOP 无 RST, 发送线程阻塞在 3s 超时, 每线程每 3s 才失败一次; DLedger 通过心跳超时检测到冻结 leader 并选举新 leader, 客户端超时后刷新路由恢复。
- nameserver ~120s 过期不是瓶颈: DLedger 选举+新 leader 注册驱动了 ~27s 恢复。
- 解冻 (SIGCONT) 后 .11/.14 以 follower 身份重新加入。
