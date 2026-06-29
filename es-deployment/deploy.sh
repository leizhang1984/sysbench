#!/bin/bash
# Elasticsearch DSv5 vs DSv6 Deployment Script

set -e

echo "========================================"
echo "ES Deployment - DSv5 vs DSv6"
echo "========================================"

# Configuration
SUBSCRIPTION_ID="166157a8-9ce9-400b-91c7-1d42482b83d6"
RESOURCE_GROUP="es-rg"
LOCATION="germanywestcentral"
VNET_NAME="es-vnet"
SUBNET_NAME="vm-subnet"

# Check prerequisites
echo ""
echo "[1/5] Checking prerequisites..."

if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI (az) is not installed"
    echo "Install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "WARNING: jq is not installed, some output parsing may not work"
fi

# Set subscription
echo "[2/5] Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"
az account show

# Verify resource group exists
echo ""
echo "[3/5] Verifying resource group..."
if ! az group show --name "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" &> /dev/null; then
    echo "ERROR: Resource group '$RESOURCE_GROUP' does not exist"
    exit 1
fi
echo "Resource group '$RESOURCE_GROUP' found"

# Verify VNet and Subnet exist
echo ""
echo "[4/5] Verifying network resources..."
if ! az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" &> /dev/null; then
    echo "ERROR: VNet '$VNET_NAME' does not exist"
    exit 1
fi
echo "VNet '$VNET_NAME' found"

if ! az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "$SUBNET_NAME" &> /dev/null; then
    echo "ERROR: Subnet '$SUBNET_NAME' does not exist"
    exit 1
fi
echo "Subnet '$SUBNET_NAME' found"

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BICEP_FILE="$SCRIPT_DIR/main.bicep"

if [ ! -f "$BICEP_FILE" ]; then
    echo "ERROR: Bicep file not found at $BICEP_FILE"
    exit 1
fi

# Deploy Bicep template
echo ""
echo "[5/5] Deploying infrastructure..."
echo "This may take 10-15 minutes..."
echo ""

DEPLOYMENT_NAME="es-deployment-$(date +%s)"

az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$BICEP_FILE" \
  --parameters \
      subscriptionId="$SUBSCRIPTION_ID" \
      resourceGroupName="$RESOURCE_GROUP" \
      location="$LOCATION" \
      vnetName="$VNET_NAME" \
      subnetName="$SUBNET_NAME"

echo ""
echo "========================================"
echo "Deployment Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Wait 5-10 minutes for VMs to start and initialize"
echo "2. Run verify script: bash scripts/verify/health-check.sh"
echo "3. Check cluster health: curl http://<node-ip>:9200/_cluster/health"
echo ""
