#!/bin/bash
# Shared variables for RocketMQ 4.9.7 three-AZ master/slave deployment.
# Target: rocketmq-customer. Non-DLedger. Dynamic private IPs (subnet NSG only).
# Source from other scripts: source ./00-vars.sh
set -euo pipefail

export SUBSCRIPTION="166157a8-9ce9-400b-91c7-1d42482b83d6"
export RG="rocketmq-customer"
export LOCATION="germanywestcentral"
export VNET="rocketmq-customer-vnet"
export SUBNET="vm-subnet"

export VM_SIZE="Standard_D4s_v6"
export IMAGE="resf:rockylinux-x86_64:9-base:latest"
export ADMIN_USER="azureadmin"
# NOTE: password passed at runtime; do not commit real secrets to source control.
export ADMIN_PASS=""

# Data disk (Premium SSD v2): 500GB / 3000 IOPS / 125 MBps, mounted by UUID at /datadisk
export DISK_SKU="PremiumV2_LRS"
export DISK_SIZE_GB="500"
export DISK_IOPS="3000"
export DISK_MBPS="125"

# RocketMQ / JDK
export RMQ_VERSION="4.9.7"
export JDK_VER="11.0.25.0.9"
export CLUSTER_NAME="RocketMQCluster"

# NameServer address list is generated at runtime from actual private IPs.
# inventory.sh resolves it and writes ./inventory.env (NAMESRV_ADDR=...).
export NS_FILE="./inventory.env"

# ---- Node inventory: name|zone (private IPs assigned dynamically by subnet) ----
# NameServers (one per zone)
export NS_NODES=(
  "v6rocketmqnamesvr01|1"
  "v6rocketmqnamesvr02|2"
  "v6rocketmqnamesvr03|3"
)
# Brokers: name|zone|brokerName|brokerId|role
export BROKER_NODES=(
  "broker-a-0|1|broker-a|0|master"
  "broker-a-1|2|broker-a|1|slave"
  "broker-b-0|1|broker-b|0|master"
  "broker-b-1|2|broker-b|1|slave"
  "broker-c-0|1|broker-c|0|master"
  "broker-c-1|2|broker-c|1|slave"
)
# Benchmark client (deployed, not provisioned with RocketMQ services in this phase)
export CLIENT_NODES=(
  "rocketmq-client01|1"
)
