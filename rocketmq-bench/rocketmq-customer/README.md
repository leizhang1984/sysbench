# RocketMQ Customer — VM 部署脚本（仅建机阶段）

RocketMQ 4.9.7 经典主从（非 DLedger），3 可用区，10 台 VM：3 NameServer + 6 Broker + 1 压测客户端（rocketmq-client01）。

## 环境
- 资源组 `rocketmq-customer` / VNet `rocketmq-customer-vnet` / 子网 `vm-subnet` / germanywestcentral
- Rocky 9，Standard security type，加速网卡，无公网 IP，私网 IP 自动分配
- 数据盘 Premium SSD v2 500GB / 3000 IOPS / 125 MBps，UUID 挂载 /datadisk
- 网卡不绑 NSG，仅用子网 NSG
- OpenJDK 11.0.25，RocketMQ 4.9.7

## 拓扑
- NameServer: v6rocketmqnamesvr01(z1) / 02(z2) / 03(z3)
- broker-a-0(z1,id0) a-1(z2,id1)；broker-b-0(z1,id0) b-1(z2,id1)；broker-c-0(z1,id0) c-1(z2,id1)
- 客户端: rocketmq-client01(z1)

## 用法（任一 NameServer/客户端或带 az 的 Linux）
```bash
bash _prep.sh        # 校验脚本
bash _run-infra.sh   # 建机 -> 采集NS私网IP(inventory.env) -> 初始化NS/Broker
# 约 5 分钟后
bash verify.sh       # clusterList 应见 a/b/c 各 0/1 共 6 broker
```
单独调用：`deploy-infra.sh`（建机）、`inventory.sh`（生成 namesrvAddr）、`provision-all.sh`（部署服务）。
本阶段不含压测/故障脚本。
