#!/bin/bash
# Phase 1 - Azure infrastructure for RocketMQ 4.9.7 three-AZ cluster.
# Creates: NSG (+ subnet association), 9 VMs (zonal, accelerated networking,
# Standard security type, static private IPs, no public IP), and one
# Premium SSD v2 (100GB/3000 IOPS/125 MBps) data disk per VM.
#
# Idempotent-ish: skips resources that already exist.
set -euo pipefail
cd "$(dirname "$0")"
source ./00-vars.sh

az account set --subscription "$SUBSCRIPTION"

echo "=== Accepting marketplace image terms (Rocky Linux 9) ==="
az vm image terms accept --urn "$IMAGE" -o none || true

echo "=== 1. NSG ==="
if ! az network nsg show -g "$RG" -n "$NSG" -o none 2>/dev/null; then
  az network nsg create -g "$RG" -n "$NSG" -l "$LOCATION" -o none
fi

# Allow RocketMQ traffic inside the VNet only.
az network nsg rule create -g "$RG" --nsg-name "$NSG" -n "Allow-RocketMQ-VNet" \
  --priority 200 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes VirtualNetwork --destination-address-prefixes VirtualNetwork \
  --destination-port-ranges 9876 10909 10911 10912 -o none 2>/dev/null || true

# SSH: restrict to your management network. Replace 0.0.0.0/0 with your office/VPN CIDR.
SSH_SRC="${SSH_SRC:-VirtualNetwork}"
az network nsg rule create -g "$RG" --nsg-name "$NSG" -n "Allow-SSH" \
  --priority 300 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes "$SSH_SRC" --destination-port-ranges 22 -o none 2>/dev/null || true

echo "=== Associate NSG to subnet ==="
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET" \
  --network-security-group "$NSG" -o none

create_vm () {
  local NAME="$1" IP="$2" ZONE="$3"
  local NIC="${NAME}-nic" DISK="${NAME}-datadisk"

  if az vm show -g "$RG" -n "$NAME" -o none 2>/dev/null; then
    echo "  VM $NAME already exists, skipping create"
  else
    echo "=== Create NIC $NIC (static $IP, accelerated networking) ==="
    if ! az network nic show -g "$RG" -n "$NIC" -o none 2>/dev/null; then
      az network nic create -g "$RG" -n "$NIC" --vnet-name "$VNET" --subnet "$SUBNET" \
        --private-ip-address "$IP" --accelerated-networking true -o none
    fi

    echo "=== Create VM $NAME (zone $ZONE) ==="
    az vm create -g "$RG" -n "$NAME" \
      --image "$IMAGE" \
      --size "$VM_SIZE" \
      --zone "$ZONE" \
      --nics "$NIC" \
      --admin-username "$ADMIN_USER" \
      --admin-password "$ADMIN_PASS" \
      --authentication-type password \
      --security-type Standard \
      --os-disk-name "${NAME}-osdisk" \
      --public-ip-address "" \
      -o none
  fi

  echo "=== Create Premium SSD v2 data disk $DISK (zone $ZONE) ==="
  if ! az disk show -g "$RG" -n "$DISK" -o none 2>/dev/null; then
    az disk create -g "$RG" -n "$DISK" -l "$LOCATION" --zone "$ZONE" \
      --sku "$DISK_SKU" --size-gb "$DISK_SIZE_GB" \
      --disk-iops-read-write "$DISK_IOPS" --disk-mbps-read-write "$DISK_MBPS" -o none
  fi

  echo "=== Attach data disk $DISK -> $NAME (lun 0) ==="
  if ! az vm show -g "$RG" -n "$NAME" --query "storageProfile.dataDisks[?name=='${DISK}']" -o tsv | grep -q .; then
    az vm disk attach -g "$RG" --vm-name "$NAME" --name "$DISK" --lun 0 -o none
  fi
}

echo "########## NameServers ##########"
for entry in "${NS_NODES[@]}"; do
  IFS='|' read -r NAME IP ZONE <<< "$entry"
  create_vm "$NAME" "$IP" "$ZONE"
done

echo "########## Brokers ##########"
for entry in "${BROKER_NODES[@]}"; do
  IFS='|' read -r NAME IP ZONE BNAME BID ROLE <<< "$entry"
  create_vm "$NAME" "$IP" "$ZONE"
done

echo "=== Infrastructure provisioning complete ==="
az vm list -g "$RG" -d --query "[].{name:name,zone:zones[0],privateIp:privateIps,size:hardwareProfile.vmSize}" -o table
