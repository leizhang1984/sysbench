# RocketMQ 性能 + 故障转移（RTO/RPO）测试计划（可复用）

> 适用：RocketMQ 4.9.7 经典主从（非 DLedger），SYNC_MASTER + ASYNC_FLUSH，跨 3 组（a/b/c）跨可用区部署。
> 目标：量化 ① 发送性能；② 三类故障（冻结主 / 优雅停 AZ / 断电 AZ）的 RTO、RPO。
> 本计划是 `new1.md` 报告的可重复执行版本，下次直接照此跑即可。

---

## 0. 架构与配置基线（前置约定）

| 项 | 取值 |
| --- | --- |
| 版本 | RocketMQ 4.9.7（经典主从，**非 DLedger**） |
| 集群名 | RocketMQCluster |
| 复制 | `brokerRole=SYNC_MASTER`（主 brokerId=0）/ `SLAVE`（brokerId=1） |
| 刷盘 | `flushDiskType=ASYNC_FLUSH` |
| 端口 | broker `listenPort=10911`、HA `10912`；NameServer `9876` |
| store | `/datadisk/rocketmq/store` |
| systemd | broker=`rmq-broker`，NameServer=`rmq-namesrv` |
| 自动选主 | **无**。高可用靠 topic 跨多组 + 客户端重试改投 |

**节点清单（每次测试按实际环境替换 IP/名称）：**

| 角色 | 主机 | IP | 可用区 |
| --- | --- | --- | --- |
| NameServer×3 | namesvr01/02/03 | .4 / .5 / .6 | z1/z2/z3 |
| broker-a 主/从 | a-0 / a-1 | .10 / .11 | z1 |
| broker-b 主/从 | b-0 / b-1 | .12 / .13 | z2 |
| broker-c 主/从 | c-0 / c-1 | .14 / .15 | z3 |
| 压测客户端 | rocketmq-client01 | .7 | — |

- NAMESRV 串：`"10.161.0.4:9876;10.161.0.5:9876;10.161.0.6:9876"`
- 客户端：JDK11、RocketMQ `/opt/rocketmq-4.9.7`、Probe `/opt/probe`

---

## 1. 关键约定与坑（务必先读）

1. **时区**：客户端 CSV `wall` 列 = **UTC**；服务端 logback 时间戳 = **UTC+8**。对照日志时服务端减 8 换算 UTC。
2. **JDK11**：官方 `runclass.sh` 带 JDK8 CMS 参数会崩，直接用：
   `java -server -Xms2g -Xmx2g -cp "$ROCKETMQ_HOME/lib/*" org.apache.rocketmq.example.benchmark.Producer ...`
   benchmark Producer **无 `-d` 持续时长参数**，用 `timeout <秒>` 包裹。
3. **Azure 执行规范**：
   - 一律 `cmd /c az ...`；脚本用 `--scripts "@文件.sh"`；位置参数用 `--parameters arg1 arg2`。
   - **单台 VM 同一时刻只能有一个 run-command**（否则 Conflict）。
   - 长命令会超时 → 用 `setsid` detached + 轮询日志文件。
   - **一次只跑一个 az**（不要并行 run_in_terminal）。
   - 认证报错时清 `%USERPROFILE%\.azure\msal_http_cache.bin`。
4. **断电/优雅停后 broker 可能 `exit 253` 崩溃循环**（大 store + 非正常中断 → store/index 不一致）。恢复手段：清 store 后干净重启（`heal-broker.sh`，**会删数据**）。
5. **run-command 卡槽**（断电后 guest agent 卡住）：`cmd /c az vm restart -g <rg> -n <vm>` 清槽后再 heal。

---

## 2. 测试矩阵总览

| 阶段 | 用例 | 注入方式 | 度量 |
| --- | --- | --- | --- |
| P1 | 环境与健康检查 | clusterList / 端口 / 路由 | 6 broker 全注册 |
| P2 | 发送性能 | benchmark Producer | TPS、RT、失败 |
| P3 | 故障 B：冻结主 | `SIGSTOP`/`SIGCONT` broker-a 主 | RTO（有/无重试）、RPO |
| P4 | 故障 C：优雅停 AZ1 | `systemctl stop` 主+从 | RTO、RPO |
| P5 | 故障 D：断电 AZ1 | `sysrq` 强制重启 主+从 | RTO、RPO |
| P6 | 汇总报告 + 恢复集群 | — | new1.md / 健康 |

---

## 3. 详细步骤

### P1 环境与健康检查

```bash
# 客户端或任一 NameServer 上：
mqadmin clusterList -n 10.161.0.4:9876         # 期望 6 个 broker 全在
# 建/确认故障转移用 topic（跨 a/b/c，读写各 8 队列）
mqadmin updateTopic -t ft_topic -w 8 -r 8 -c RocketMQCluster -n <namesrv>
```
判定：clusterList 显示 a-0/a-1/b-0/b-1/c-0/c-1 全部在线；ft_topic 在三组均有 QueueData。

### P2 发送性能（基线 + 线程扫描）

```bash
export ROCKETMQ_HOME=/opt/rocketmq-4.9.7
NS="10.161.0.4:9876;10.161.0.5:9876;10.161.0.6:9876"
run() {  # 参数: 线程数 时长秒
  timeout "$2" java -server -Xms2g -Xmx2g -cp "$ROCKETMQ_HOME/lib/*" \
    org.apache.rocketmq.example.benchmark.Producer \
    -n "$NS" -t perf_topic -w "$1" -s 1024 -m 0
}
# 主测：64 线程 × 300s
run 64 300
# 扫描：16 / 32 / 64 / 128 线程各 ~120s
for w in 16 32 64 128; do run $w 120; done
```
采集：benchmark 每 10s 打印 `Send TPS / Max RT / Average RT / Send Failed`。记录 avgTPS、min/max TPS、avgRT、maxRT、失败数。
判定：失败=0；记录推荐工作点。

> 上次结果参考：64线程≈8.4万/s、avgRT0.76ms、0失败；128线程≈12万/s。

### P3 故障 B —— 冻结主（SIGSTOP）

目的：模拟主进程假死（TCP 不断、不返回 RST），验证 NameServer 心跳超时（≈120s）行为与客户端重试效果。

```bash
# 在客户端启动 Probe 持续产消（ft_topic，约 400/s），记录逐秒 CSV：
#   CSV 头: epoch_ms,wall,sec,ok,fail,ok_total,fail_total,p50_ms,p99_ms,max_ms,err
# 跑两轮做对照：
#   ftB  : retryTimesWhenSendFailed=2（开重试）
#   ftB1 : retries=0（关重试，看真实失败窗口）

# 注入（在 broker-a 主节点 a-0 上）：
PID=$(pgrep -f 'broker.*broker-a.*id=0' || pgrep -f BrokerStartup)
kill -STOP $PID            # 冻结 ~50s
sleep 50
kill -CONT $PID           # 解冻
```
采集：客户端逐秒 CSV（取 fail>0 片段）；a-0 上记录 STOP/CONT 时刻；NameServer `namesrv.log` 查 broker-a channel destroyed（**预期：冻结<120s → 无摘除记录**，这是关键反证）。
判定：
- 开重试：客户端失败应**完全掩盖**（fail≈0）。
- 关重试：失败窗口 ≈ 冻结时长，每 3s 稳定若干 fail，解冻后恢复（可能一次 RT 尖峰）。RPO=0。

### P4 故障 C —— 优雅停 AZ1（systemctl stop）

目的：模拟可用区计划内维护，验证主动注销路由的快速转移。

```bash
# 客户端启动 Probe（ft_topic，约 400/s，retries=0，runId=ftC），记录 T0
# 注入（先主后从）：
ssh a-0 'sudo systemctl stop rmq-broker'      # T0
sleep 40
ssh a-1 'sudo systemctl stop rmq-broker'
# 验证后恢复：
ssh a-0 'sudo systemctl start rmq-broker'; ssh a-1 'sudo systemctl start rmq-broker'
```
采集：客户端逐秒 CSV；NameServer `namesrv.log` 查 `channelUnregistered` + `the broker's channel destroyed`（**预期 TCP FIN → 1s 内摘除**）；heal/重启后查 `new broker registered`。
判定：RTO ≈ 一个路由刷新周期（≈10s，部分降级非全停，b/c 持续成功）；RPO=0（优雅停会刷盘）。

> 上次：T0=08:21:54Z，NameServer 08:21:55Z 摘除（1s），客户端 sec81–90 降级、sec91 恢复，failTotal≈1197。

### P5 故障 D —— 断电 AZ1（sysrq 强制重启）★ 重点

目的：模拟真实断电（不 sync、不刷 page cache），量化断电 RTO 与 RPO 风险。

```bash
# 客户端启动 Probe（ft_topic，约 3000/s，retries=0，runId=ftD），记录 T0
# 注入（power-fault.sh，setsid 后台，先主后从）：
#   echo 1 > /proc/sys/kernel/sysrq ; echo b > /proc/sysrq-trigger
bash power-fault.sh 0      # a-0 立即断电  = T0
sleep 47
bash power-fault.sh 0      # a-1 断电（在 a-1 上执行）
```
采集：
- 客户端逐秒 CSV（fail>0 片段，记首秒失败与恢复秒）。
- NameServer `namesrv.log`（**预期无 FIN → 靠 idle 超时 ≈108–120s 才 channel destroyed + remove brokerAddr/brokerName + remove topic[ft_topic]**）。
- broker `journalctl -u rmq-broker`（预期 `exit 253` 崩溃循环、restart counter 增长）。
判定：
- **RTO ≈ 心跳超时摘除 + 客户端路由刷新 ≈ 132s**（与 broker 是否回来无关；恢复靠改投 b/c）。
- **RPO**：理论上 `SYNC_MASTER`+`ASYNC_FLUSH` 主从同时断电存在 RPO>0 风险（已 ack 但未刷盘的内存消息丢失）。
  本次若从节点比主多活数十秒（≫500ms 刷盘周期）则大概率已落盘、不易复现。
  **要量化 RPO 见 P5-补充。**
恢复：`az vm restart` 清 run-command 卡槽 → `heal-broker.sh` 清 store 干净重启。

### P5-补充（可选）—— 量化 RPO 的严谨实验

要把"理论丢失"变成"实测数字"，按下面做对照：

1. **严格同时断电**：主、从用同一条预约命令同秒触发（如 `at`/计划任务），消除 47s 缓冲。
2. **关闭刷盘缓冲对照组**：A 组 `ASYNC_FLUSH`（现状）、B 组 `flushDiskType=SYNC_FLUSH`。
3. **可核对的发送**：producer 带单调递增序号；客户端记录"已收到 ack 的最大序号 N_ack"。
4. **断电后不清 store**：先尝试只读挂载/拷贝 commitlog 离线解析，统计实际落盘最大序号 N_disk。
   - 实测丢失条数 ≈ `N_ack - N_disk`。
   - 预期：`ASYNC_FLUSH` 组 >0；`SYNC_FLUSH` 组 =0。
5. 若 store 损坏无法解析，则记为"不可量化，仅定性确认风险"，并在报告注明。

### P6 汇总与恢复

- 产出报告（结构同 `new1.md`）：每个用例内含 **时间线(UTC) + 逐秒客户端表 + 服务端日志证据**。
- 第 5 章 RTO/RPO 汇总表 + C vs D 时序对比图。
- 恢复集群：clusterList 确认 6 broker 全部回到在线。

---

## 4. 采集脚本清单（复用 new1 目录现有脚本）

| 脚本 | 作用 |
| --- | --- |
| `clusterlist.sh` | mqadmin clusterList |
| `recreate-ft-topic.sh` | 建/重建 ft_topic（跨集群 -w8 -r8） |
| `ft-produce.sh` / `ft-verify.sh` / `ft-wait.sh` | Probe 产/消/校验 |
| `ft-wall.sh` | 导出 fail>0 的逐秒行（sec\|wall\|ok\|fail\|fail_total） |
| `ft-failwin.sh` | 仅显示 fail/s>0 的失败窗口 |
| `ns-log.sh` / `ns-log2.sh` | 抽取 NameServer broker-a 生命周期事件（LOG=/data/rocketmq/logs/namesrv.log） |
| `power-fault.sh <delay>` | setsid 后台 sysrq 模拟断电 |
| `check-broker.sh` | 轮询 is-active/10911/NRestarts/uptime + 日志 tail |
| `heal-broker.sh` | **清 store** 干净重启（恢复 exit-253 崩溃循环；删数据） |

---

## 5. 判定基线（上次实测，作下次对比参照）

| 用例 | RTO | 累计失败 | RPO |
| --- | --- | --- | --- |
| B 冻结+重试 | 0（完全掩盖） | 0 | 0 |
| B 冻结-无重试 | ≈47–49s | 128 | 0 |
| C 优雅停 AZ1 | ≈10s（部分降级） | 1,197 | 0 |
| D 断电 AZ1 | ≈132s | 716 | 理论>0，本次未量化 |

性能：64线程≈8.4万/s、avgRT0.76ms、0失败；扫描 16/32/64/128 ≈ 2.7万/5.2万/8.1万/12.1万 TPS。

---

## 6. 执行检查清单（Run Sheet）

- [ ] P1 clusterList 6/6 在线、ft_topic 跨三组就绪
- [ ] P2 性能：64×300 + 16/32/64/128 扫描，0 失败
- [ ] P3 故障 B：ftB(重试) + ftB1(无重试) 两轮，取 NameServer 反证
- [ ] P4 故障 C：优雅停主→从，NameServer 1s 摘除证据
- [ ] P5 故障 D：断电主→从，NameServer 108s 摘除 + broker exit253 证据
- [ ] （可选）P5-补充 RPO 量化对照（同时断电 + SYNC_FLUSH 对照 + 序号核对）
- [ ] P6 出报告 + clusterList 恢复 6/6
