#!/bin/bash
# Phase 1 - Azure infrastructure for RocketMQ 4.9.7 three-AZ cluster (rocketmq-customer).
# Creates: 10 VMs (3 NameServers + 6 brokers + 1 client), zonal, accelerated networking,
# Standard security type, dynamic private IPs, no public IP, NO NIC-level NSG
# (subnet NSG only), one Premium SSD v2 (500GB/3000 IOPS/125 MBps) data disk per VM.
# Idempotent-ish: skips resources that already exist.
set -euo pipefail
cd "$(dirname "$0")"
source ./00-vars.sh

az account set --subscription "$SUBSCRIPTION"

echo "=== Accepting marketplace image terms (Rocky Linux 9) ==="
az vm image terms accept --urn "$IMAGE" -o none || true

create_vm () {
  local NAME="$1" ZONE="$2" WITH_DISK="${3:-no}"
  local NIC="${NAME}-nic" DISK="${NAME}-datadisk"

  if az vm show -g "$RG" -n "$NAME" -o none 2>/dev/null; then
    echo "  VM $NAME already exists, skipping create"
  else
    echo "=== Create NIC $NIC (dynamic private IP, accelerated networking, no NIC NSG) ==="
    if ! az network nic show -g "$RG" -n "$NIC" -o none 2>/dev/null; then
      az network nic create -g "$RG" -n "$NIC" --vnet-name "$VNET" --subnet "$SUBNET" \
        --accelerated-networking true -o none
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

  if [ "$WITH_DISK" != "yes" ]; then
    echo "  $NAME: no data disk (NS/client)"; return 0
  fi

  echo "=== Create Premium SSD v2 data disk $DISK (zone $ZONE, 500GB/3000/125) ==="
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
  IFS='|' read -r NAME ZONE <<< "$entry"
  create_vm "$NAME" "$ZONE" no
done

echo "########## Brokers ##########"
for entry in "${BROKER_NODES[@]}"; do
  IFS='|' read -r NAME ZONE BNAME BID ROLE <<< "$entry"
  create_vm "$NAME" "$ZONE" yes
done

echo "########## Client ##########"
for entry in "${CLIENT_NODES[@]}"; do
  IFS='|' read -r NAME ZONE <<< "$entry"
  create_vm "$NAME" "$ZONE" no
done

echo "=== Infrastructure provisioning complete ==="
az vm list -g "$RG" -d --query "[].{name:name,zone:zones[0],privateIp:privateIps,size:hardwareProfile.vmSize}" -o table
