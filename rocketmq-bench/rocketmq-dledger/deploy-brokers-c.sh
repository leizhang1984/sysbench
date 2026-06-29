#!/usr/bin/env bash
# Create v6rocketmqbroker-c-0/1/2 cloned from v6rocketmqbroker-a-0 baseline.
# Each VM goes into a distinct availability zone (1/2/3).
set -euo pipefail

SUBSCRIPTION="166157a8-9ce9-400b-91c7-1d42482b83d6"
RG="rocketmqnew-rg"
LOCATION="germanywestcentral"
VNET="rocketmqnew-vnet"
SUBNET="vm-subnet"
NSG="rocketmq-broker-nsg"
VM_SIZE="Standard_D4s_v6"
IMAGE="resf:rockylinux-x86_64:9-base:9.6.20250531"
PLAN_NAME="9-base"
PLAN_PRODUCT="rockylinux-x86_64"
PLAN_PUBLISHER="resf"
ADMIN_USER="azureadmin"
# Do not hardcode secrets. Export ADMIN_PASSWORD before running:
#   export ADMIN_PASSWORD='your-password'
ADMIN_PASSWORD="${ADMIN_PASSWORD:?Set ADMIN_PASSWORD env var first}"

# name  zone  private-ip
NODES=(
  "v6rocketmqbroker-c-0 1 10.170.0.16"
  "v6rocketmqbroker-c-1 2 10.170.0.17"
  "v6rocketmqbroker-c-2 3 10.170.0.18"
)

for entry in "${NODES[@]}"; do
  read -r NAME ZONE PRIVATE_IP <<<"$entry"
  echo "=== Creating $NAME (zone $ZONE, private IP $PRIVATE_IP) ==="

  az network public-ip create \
    --subscription "$SUBSCRIPTION" -g "$RG" -n "${NAME}-pip" \
    --location "$LOCATION" --sku Standard --allocation-method Static \
    --version IPv4 --zone "$ZONE" -o none

  az network nic create \
    --subscription "$SUBSCRIPTION" -g "$RG" -n "${NAME}-nic" \
    --location "$LOCATION" --vnet-name "$VNET" --subnet "$SUBNET" \
    --network-security-group "$NSG" --private-ip-address "$PRIVATE_IP" \
    --public-ip-address "${NAME}-pip" --accelerated-networking true -o none

  az disk create \
    --subscription "$SUBSCRIPTION" -g "$RG" -n "${NAME}-datadisk" \
    --location "$LOCATION" --sku PremiumV2_LRS --size-gb 100 --zone "$ZONE" -o none

  az vm create \
    --subscription "$SUBSCRIPTION" -g "$RG" -n "$NAME" \
    --location "$LOCATION" --zone "$ZONE" --nics "${NAME}-nic" \
    --size "$VM_SIZE" --image "$IMAGE" \
    --plan-name "$PLAN_NAME" --plan-product "$PLAN_PRODUCT" --plan-publisher "$PLAN_PUBLISHER" \
    --admin-username "$ADMIN_USER" --admin-password "$ADMIN_PASSWORD" \
    --authentication-type password \
    --os-disk-size-gb 30 --storage-sku Standard_LRS \
    --attach-data-disks "${NAME}-datadisk" --disk-controller-type NVMe -o none

  az vm wait --subscription "$SUBSCRIPTION" -g "$RG" -n "$NAME" --created
  echo "=== $NAME created ==="
done

echo "All c-series broker VMs created."
