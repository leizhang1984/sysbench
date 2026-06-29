#!/bin/bash
# Shared variables for RocketMQ 4.9.7 three-AZ master/slave deployment (Option A).
# Source this file from the other scripts: source ./00-vars.sh
set -euo pipefail

export SUBSCRIPTION="166157a8-9ce9-400b-91c7-1d42482b83d6"
export RG="rocketmqnew1-rg"
export LOCATION="germanywestcentral"
export VNET="rocketmqnew1-vnet"
export SUBNET="vm-subnet"
export NSG="rocketmqnew1-nsg"

export VM_SIZE="Standard_D4s_v6"
export IMAGE="resf:rockylinux-x86_64:9-base:latest"
export ADMIN_USER="azureadmin"
# NOTE: password is passed at runtime; do not commit real secrets to source control.
export ADMIN_PASS="Zhanglei@123456"

# Data disk (Premium SSD v2)
export DISK_SKU="PremiumV2_LRS"
export DISK_SIZE_GB="100"
export DISK_IOPS="3000"
export DISK_MBPS="125"

# RocketMQ / JDK
export RMQ_VERSION="4.9.7"
export JDK_VER="11.0.25.0.9"
export CLUSTER_NAME="DefaultCluster"

# NameServer address list (static private IPs assigned below)
export NAMESRV_ADDR="10.161.0.4:9876;10.161.0.5:9876;10.161.0.6:9876"

# ---- Node inventory: name|ip|zone|role|brokerName|brokerId ----
# NameServers
export NS_NODES=(
  "v6rocketmqnamesvr01|10.161.0.4|1"
  "v6rocketmqnamesvr02|10.161.0.5|2"
  "v6rocketmqnamesvr03|10.161.0.6|3"
)
# Brokers: name|ip|zone|brokerName|brokerId|role
export BROKER_NODES=(
  "broker-a-0|10.161.0.10|1|broker-a|0|master"
  "broker-a-1|10.161.0.11|1|broker-a|1|slave"
  "broker-b-0|10.161.0.12|2|broker-b|0|master"
  "broker-b-1|10.161.0.13|2|broker-b|1|slave"
  "broker-c-0|10.161.0.14|3|broker-c|0|master"
  "broker-c-1|10.161.0.15|3|broker-c|1|slave"
)
