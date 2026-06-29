# RocketMQ DLedger 测试进度 (报告→C:\Users\leizha\rocketmq-failover\1\1.md)

## 关键事实
- broker-a 3副本: a-0=10.170.0.10(n0), a-1=10.170.0.11(n1,preferredLeader), a-2=10.170.0.12(n2)
- NS: 10.170.0.4/5/6:9876
- 注入前必须定位当前BID=0(Leader),只停Leader单台
- 远程: del msal_http_cache.bin; az vm run-command invoke ... --scripts "@C:\...\x.sh" --parameters ...
- 单VM串行(并发=Conflict); async轮询
- benchmark用direct-java(非producer.sh); topic用 -c RocketMQCluster
- 服务器logback时间=UTC+8; 探针CSV wall=本地; benchmark=date -u

## P1 健康检查: 完成 ✅ 9 broker注册, 客户端就绪, topic BenchTopic_1K+ft_topic建好(跨a/b/c各8写队列)
## P2 性能: 完成 ✅ (0失败)
- 64x300s: avgTPS=33064 min32551 max33543 avgRT1.935 maxRT265
- scan16=9102(RT1.758) / scan32=17992(RT1.778) / scan64=32516(RT1.968) / scan128=55675 min55144 max56666 RT2.299 maxRT501
- DLedger吞吐<master-slave参考84K: 因Raft多数派复制+D4s_v6 4vCPU, 报告需解释

## P3 Fault B (SIGSTOP冻结): retries=0 有效 ✅✅
- runId=ftB1b, 冻结a-1(10.170.0.11) 60s
- T0_STOP=03:55:27.458 UTC (ps=T确认冻住, ledger停增)
- 选举证据(server UTC+8, a-2日志):
  - 11:55:27 a-1冻结
  - 11:55:32 a-2→CANDIDATE term=2 (~5s检测失联)
  - 11:55:35 a-2→LEADER term=3 (选举~3s, STOP→新Leader约8s)
  - 11:56:31 a-1 CONT恢复
  - 11:56:32 a-2→CANDIDATE term=4 (a-1 preferredLeader夺回)
  - 11:56:33 a-2→FOLLOWER, a-1重夺LEADER term=4
- NS视图T+13s: BID=0=a-2(10.170.0.12), BID=1=a-0(10.170.0.10)
- 客户端: 主失败窗口 sec57-93(03:55:30-03:56:06) ~10/s零星(旧路由队列未刷新)
  CONT二次扰动 sec119-120(03:56:32-33) fail尖峰324
  总计 okTotal=111204 failTotal=456 (0.41%)
- 待办(可选): B-1 retries=2 对比展示重试掩盖

## 待办
- P4 fault C: systemctl stop Leader → 看重选举 → 重启rejoin follower
- P5 fault D: sysrq echo b 断电Leader → 测RTO → az vm restart rejoin
- P6 RPO: probe-verify每个runId, DLedger多数派commit→预期RPO=0
- P7 报告1.md(参考new1.md结构, 中文): §0 DLedger vs master-slave, §1环境(mermaid), §2健康, §3性能, §4故障(B/C/D), §5 RTO/RPO汇总, §6结论. 末尾clusterList确认9 broker恢复

## 当前Leader: B注入后a-1重夺(term=4)=10.170.0.11, 每次注入前重新locate
