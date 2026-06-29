#!/usr/bin/env bash
# =============================================================================
# 数据盘挂载 & 数据落盘校验脚本
# 用途: 部署集群后, 一键确认 12 个集群节点的:
#        1) /tidb 是否挂载在 Premium SSD v2 数据盘 (而非系统盘)
#        2) 文件系统为 xfs、fstab 含 nofail
#        3) TiKV/PD 数据是否真实写入 /tidb/data
#        4) 日志是否写入 /tidb/log
# 执行: 在中控机上运行 (能 SSH 到各节点)  ->  bash 03-verify-storage.sh
# 前提: 中控机到各节点 SSH 互通 (用 azureadmin + 密码或已配置免密)
# =============================================================================
set -uo pipefail

SSH_USER="azureadmin"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=8"
MOUNT_POINT="/tidb"

# 两套集群全部 12 个节点 (内网 IP)
DV5_NODES=(10.142.0.11 10.142.0.12 10.142.0.13 10.142.0.21 10.142.0.22 10.142.0.23)
DV6_NODES=(10.142.0.31 10.142.0.32 10.142.0.33 10.142.0.41 10.142.0.42 10.142.0.43)

# 远程巡检命令: 输出关键事实, 便于汇总判断
REMOTE_CHECK='
  DEV=$(findmnt -no SOURCE /tidb 2>/dev/null || echo "NOT_MOUNTED");
  FSTYPE=$(findmnt -no FSTYPE /tidb 2>/dev/null || echo "-");
  SIZE=$(df -h --output=size /tidb 2>/dev/null | tail -1 | tr -d " " || echo "-");
  USED=$(df -h --output=used /tidb 2>/dev/null | tail -1 | tr -d " " || echo "-");
  FSTAB=$(grep -q "[[:space:]]/tidb[[:space:]]" /etc/fstab && grep -q "nofail" <(grep "[[:space:]]/tidb[[:space:]]" /etc/fstab) && echo "OK(nofail)" || echo "MISSING");
  DATASZ=$(du -sh /tidb/data 2>/dev/null | cut -f1 || echo "-");
  LOGSZ=$(du -sh /tidb/log 2>/dev/null | cut -f1 || echo "-");
  # 判断挂载设备是否系统盘 (系统盘根分区所在盘)
  ROOTDEV=$(findmnt -no SOURCE / | sed "s/[0-9]*$//");
  case "$DEV" in
    "$ROOTDEV"*) ONSSD="NO(系统盘!)";;
    NOT_MOUNTED) ONSSD="NO(未挂载!)";;
    *) ONSSD="YES";;
  esac;
  echo "$DEV|$FSTYPE|$SIZE|$USED|$FSTAB|$DATASZ|$LOGSZ|$ONSSD";
'

check_cluster() {
  local cluster_name="$1"; shift
  local nodes=("$@")
  echo ""
  echo "================== 集群: $cluster_name =================="
  printf "%-15s %-12s %-7s %-6s %-6s %-13s %-7s %-7s %-12s\n" \
    "节点IP" "挂载设备" "FS" "容量" "已用" "fstab" "数据量" "日志量" "在SSDv2?"
  printf '%.0s-' {1..100}; echo ""
  for ip in "${nodes[@]}"; do
    result=$(ssh $SSH_OPTS "${SSH_USER}@${ip}" "$REMOTE_CHECK" 2>/dev/null || echo "SSH_FAIL|-|-|-|-|-|-|SSH失败")
    IFS='|' read -r dev fstype size used fstab datasz logsz onssd <<< "$result"
    printf "%-15s %-12s %-7s %-6s %-6s %-13s %-7s %-7s %-12s\n" \
      "$ip" "$dev" "$fstype" "$size" "$used" "$fstab" "$datasz" "$logsz" "$onssd"
  done
}

echo "############################################################"
echo "#   TiDB 存储落盘校验  ($(date '+%Y-%m-%d %H:%M:%S'))"
echo "#   期望: 挂载设备=/dev/sdc(非系统盘), FS=xfs,"
echo "#         fstab=OK(nofail), 在SSDv2?=YES, 数据量>0"
echo "############################################################"

check_cluster "DSv5 (CentOS 7.9)" "${DV5_NODES[@]}"
check_cluster "DSv6 (Rocky 9.6)"  "${DV6_NODES[@]}"

echo ""
echo "================== 判读说明 =================="
echo "✅ 正常:   在SSDv2?=YES, FS=xfs, fstab=OK(nofail), TiKV节点 数据量 持续>0"
echo "❌ 异常:   在SSDv2?=NO(系统盘!)  -> /tidb 未挂数据盘, 数据写到了OS盘, 需重挂"
echo "❌ 异常:   在SSDv2?=NO(未挂载!)  -> 未执行 01-init-node.sh, 先挂盘再部署"
echo "❌ 异常:   fstab=MISSING         -> 重启后挂载会丢失, 需补 fstab"
echo "提示:      TiDB+PD 节点 数据量较小(PD元数据); TiKV 节点 数据量应明显增长"
