#!/usr/bin/env bash
# =============================================================================
# Rocky Linux 9.6 升级到最新 + 基础工具安装
# 适用: DSv6 集群 6 节点 + 2 台压测机 (clientvm01/02), 均为 Rocky 9.6
# 执行: 在每台 Rocky 机器上以 root 运行  ->  sudo bash 02-rocky-update.sh
# 注意: dnf update 会升级内核, 建议执行后 reboot
# =============================================================================
set -euo pipefail

echo "==================== 当前版本 ===================="
cat /etc/rocky-release || cat /etc/redhat-release

echo "==================== dnf update -y (升级到最新 Rocky) ===================="
dnf clean all
dnf -y update

echo "==================== 安装常用工具 ===================="
# numactl/tuned 供 TiDB 调优; sysbench 仅压测机需要(集群节点装了无妨)
dnf -y install numactl tar curl wget chrony tuned sysstat || true

echo "==================== 启用时间同步 (chrony) ===================="
systemctl enable --now chronyd
chronyc sources || true

echo "==================== 完成 ===================="
echo "已升级到: $(cat /etc/rocky-release)"
echo ">>> 建议执行 reboot 使新内核生效, 然后再运行 01-init-node.sh (集群节点) <<<"
