#!/bin/bash
# Direct Elasticsearch Deployment Script - Simplified

set -e

echo "========================================"
echo "ES Deployment - Direct Mode"
echo "========================================"

# Configuration
SUBSCRIPTION_ID="166157a8-9ce9-400b-91c7-1d42482b83d6"
RESOURCE_GROUP="es-rg"
LOCATION="germanywestcentral"
VNET_NAME="es-vnet"
SUBNET_NAME="vm-subnet"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BICEP_FILE="$SCRIPT_DIR/main.bicep"

# Check if Bicep file exists
if [ ! -f "$BICEP_FILE" ]; then
    echo "ERROR: Bicep file not found at $BICEP_FILE"
    exit 1
fi

# Deploy Bicep template
echo ""
echo "Deploying infrastructure..."
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
echo "1. Wait 10-15 minutes for VMs to initialize"
echo "2. Run: bash scripts/verify/health-check.sh"
echo "3. Verify both clusters report 'green' status"
echo ""
