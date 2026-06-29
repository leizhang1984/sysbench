# RocketMQ 4.9.7 多可用区部署 (经典 master-slave, 无 DLedger)

工作目录: `C:\Users\leizha\rocketmq-failover-new2`
区域: **germanywestcentral** | 资源组: **rocketmqnew2-rg** | 订阅: `166157a8-9ce9-400b-91c7-1d42482b83d6`
VNet/子网: **rocketmqnew2-vnet / vm-subnet** | VM 规格: **Standard_D4s_v6** | OS: Rocky Linux 9 (latest)

## 拓扑 (master/slave 跨可用区)

| VM | 角色 | brokerName | brokerId | brokerRole | Zone |
|----|------|-----------|----------|-----------|------|
| v6rocketmqnamesvr01 | nameserver | - | - | - | 1 |
| v6rocketmqnamesvr02 | nameserver | - | - | - | 2 |
| v6rocketmqnamesvr03 | nameserver | - | - | - | 3 |
| v6rocketmqbroker-a-0 | master | broker-a | 0 | SYNC_MASTER | 1 |
| v6rocketmqbroker-a-1 | slave  | broker-a | 1 | SLAVE | 2 |
| v6rocketmqbroker-b-0 | master | broker-b | 0 | SYNC_MASTER | 2 |
| v6rocketmqbroker-b-1 | slave  | broker-b | 1 | SLAVE | 3 |
| v6rocketmqbroker-c-0 | master | broker-c | 0 | SYNC_MASTER | 3 |
| v6rocketmqbroker-c-1 | slave  | broker-c | 1 | SLAVE | 1 |

## 执行顺序 (PowerShell)

```powershell
cd C:\Users\leizha\rocketmq-failover-new2
az login                       # 如未登录
.\01-create-vms.ps1            # 创建 9 台 VM + Premium SSD v2 数据盘 (加速网卡, 同 zone 挂盘)
.\02-collect-ips.ps1           # 收集私网 IP, 生成 namesrvAddr -> hosts-ip.json
.\03-provision.ps1             # 装盘(UUID挂载)/JDK11/RocketMQ, 先 namesrv 后 broker
# 等待数分钟 (各 VM 上 setsid 后台执行下载与启动)
.\04-verify.ps1                # 校验挂盘/服务/端口 + clusterList
```

## 关键实现说明

- **数据盘**: Premium SSD v2, 100GB, 3000 IOPS, 125 MBps, 与 VM 同 zone; 脚本内 `mkfs.xfs` 后**按 UUID** 写入 `/etc/fstab` 挂载到 `/datadisk`。
- **配置**: 经典 master-slave, `brokerRole=SYNC_MASTER/SLAVE`, `flushDiskType=ASYNC_FLUSH`, **未启用 DLedger**; 每个 broker 写入 `brokerIP1=<本机私网IP>` 避免 Azure 多网卡 IP 误判。
- **namesrvAddr**: 包含全部 3 个 name server, 通过 base64 传参规避 run-command 对 `;` 的解析。
- **防中断**: 各 setup 脚本用 `setsid` 自分离, 避免 run-command 超时发 SIGTERM 中断 dnf。
- **JVM**: broker `-Xms8g -Xmx8g`, namesrv `-Xms2g -Xmx2g` (D4s_v6 = 16GB)。
- **管理通道**: VM 不分配公网 IP, 全程通过 `az vm run-command` 操作。

## 文件

- `00-variables.ps1` — 共享配置 / 节点拓扑 / `Invoke-Az` 辅助函数
- `01-create-vms.ps1` — 创建 VM + 数据盘并挂载
- `02-collect-ips.ps1` — 采集私网 IP, 生成 `hosts-ip.json`
- `03-provision.ps1` — 远程下发安装 (调用下面两个 .sh)
- `setup-nameserver.sh` / `setup-broker.sh` — VM 内安装脚本 (bash)
- `04-verify.ps1` / `clusterlist.sh` — 校验
