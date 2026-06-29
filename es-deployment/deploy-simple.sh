#!/bin/bash
# Simple direct deployment without complex Bicep loops
# This script creates 8 VMs directly using az cli

set -e

echo "Elasticsearch DSv5 vs DSv6 Deployment on Azure"
echo "=============================================="

RESOURCE_GROUP="es-rg"
LOCATION="germanywestcentral"
VNET="es-vnet"
SUBNET="vm-subnet"
ADMIN_USER="azureuser"

# Check prerequisites
echo "[1/8] Verifying prerequisites..."
if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI not installed"
    exit 1
fi

# Create NICs with static IPs
echo "[2/8] Creating network interfaces..."

# DSv5 NICs
az network nic create -g "$RESOURCE_GROUP" -n dsv5esmasterdata01-nic --vnet-name "$VNET" --subnet "$SUBNET" --private-ip-address 10.122.0.4 --accelerated-networking true -o none
az network nic create -g "$RESOURCE_GROUP" -n dsv5esmasterdata02-nic --vnet-name "$VNET" --subnet "$SUBNET" --private-ip-address 10.122.0.5 --accelerated-networking true -o none
az network nic create -g "$RESOURCE_GROUP" -n dsv5esmasterdata03-nic --vnet-name "$VNET" --subnet "$SUBNET" --private-ip-address 10.122.0.6 --accelerated-networking true -o none

# DSv6 NICs
az network nic create -g "$RESOURCE_GROUP" -n dsv6esmasterdata01-nic --vnet-name "$VNET" --subnet "$SUBNET" --private-ip-address 10.122.0.7 --accelerated-networking true -o none
az network nic create -g "$RESOURCE_GROUP" -n dsv6esmasterdata02-nic --vnet-name "$VNET" --subnet "$SUBNET" --private-ip-address 10.122.0.8 --accelerated-networking true -o none
az network nic create -g "$RESOURCE_GROUP" -n dsv6esmasterdata03-nic --vnet-name "$VNET" --subnet "$SUBNET" --private-ip-address 10.122.0.9 --accelerated-networking true -o none

# Client NICs
az network nic create -g "$RESOURCE_GROUP" -n clientvm01-nic --vnet-name "$VNET" --subnet "$SUBNET" --private-ip-address 10.122.0.10 --accelerated-networking true -o none
az network nic create -g "$RESOURCE_GROUP" -n clientvm02-nic --vnet-name "$VNET" --subnet "$SUBNET" --private-ip-address 10.122.0.11 --accelerated-networking true -o none

echo "✓ Network interfaces created"

# Create DSv5 VMs (CentOS 7.9)
echo "[3/8] Creating DSv5 VMs (CentOS 7.9)..."
for i in 01 02 03; do
  vm_name="dsv5esmasterdata$i"
  az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$vm_name" \
    --nics "${vm_name}-nic" \
    --image CentOS:CentOS:7_9:latest \
    --size Standard_D8s_v5 \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values ~/.ssh/id_rsa.pub \
    --zone $((10#$i % 3 + 1)) \
    --os-disk-name "${vm_name}-osdisk" \
    --os-disk-size-gb 128 \
    --storage-sku Premium_LRS \
    --custom-data ./scripts/cloud-init-centos7.sh \
    --no-wait -o none
done

# Create DSv6 VMs (Rocky 9.6)
echo "[4/8] Creating DSv6 VMs (Rocky 9.6)..."
for i in 01 02 03; do
  vm_name="dsv6esmasterdata$i"
  az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$vm_name" \
    --nics "${vm_name}-nic" \
    --image erockyenterprisesoftwarefoundationinc1653071250513:rockylinux-x86_64-base:9-lvm:latest \
    --size Standard_D8s_v6 \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values ~/.ssh/id_rsa.pub \
    --zone $((10#$i % 3 + 1)) \
    --os-disk-name "${vm_name}-osdisk" \
    --os-disk-size-gb 128 \
    --storage-sku Premium_LRS \
    --custom-data ./scripts/cloud-init-rocky9.sh \
    --no-wait -o none
done

# Create Client VMs (Rocky 9.6)
echo "[5/8] Creating Client VMs (Rocky 9.6)..."
for i in 01 02; do
  vm_name="clientvm$i"
  az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$vm_name" \
    --nics "${vm_name}-nic" \
    --image erockyenterprisesoftwarefoundationinc1653071250513:rockylinux-x86_64-base:9-lvm:latest \
    --size Standard_D32s_v6 \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values ~/.ssh/id_rsa.pub \
    --zone $((10#$i % 3 + 1)) \
    --os-disk-name "${vm_name}-osdisk" \
    --os-disk-size-gb 256 \
    --storage-sku Premium_LRS \
    --custom-data ./scripts/cloud-init-client.sh \
    --no-wait -o none
done

echo ""
echo "✓ All VMs creation initiated"
echo ""
echo "========================================="
echo "Deployment in progress..."
echo "========================================="
echo ""
echo "The VMs are being created and will execute cloud-init scripts automatically."
echo "This may take 10-15 minutes."
echo ""
echo "Monitor progress with:"
echo "  az vm list -g $RESOURCE_GROUP --query \"[].{name:name, state:powerState}\" -o table"
echo ""
echo "Next steps:"
echo "1. Wait for all VMs to reach 'Running' state"
echo "2. Run health check: bash scripts/verify/health-check.sh"
echo "3. Verify both ES clusters reach 'green' status"
echo ""
