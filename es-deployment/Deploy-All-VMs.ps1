# Complete Elasticsearch DSv5 vs DSv6 Deployment
# Strictly following the specification:
# - DSv5: 3x CentOS 7.9
# - DSv6: 3x Rocky 9.6
# - Client: 2x Rocky 9.6

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Elasticsearch Deployment - All 8 VMs" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

$RESOURCE_GROUP = "es-rg"
$CENTOS_IMAGE = "OpenLogic:CentOS:7_9:latest"
$ROCKY_IMAGE = "erockyenterprisesoftwarefoundationinc1653071250513:rockylinux-x86_64-base:9-lvm:latest"
$ADMIN_USER = "azureuser"

Write-Host "[1/8] Creating dsv5esmasterdata01 (CentOS 7.9, DSv5, Zone 2)..."
az vm create --resource-group $RESOURCE_GROUP --name dsv5esmasterdata01 --nics dsv5esmasterdata01-nic --image $CENTOS_IMAGE --size Standard_D8s_v5 --admin-username $ADMIN_USER --zone 2 --os-disk-name dsv5esmasterdata01-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait --output none

Write-Host "[2/8] Creating dsv5esmasterdata02 (CentOS 7.9, DSv5, Zone 3)..."
az vm create --resource-group $RESOURCE_GROUP --name dsv5esmasterdata02 --nics dsv5esmasterdata02-nic --image $CENTOS_IMAGE --size Standard_D8s_v5 --admin-username $ADMIN_USER --zone 3 --os-disk-name dsv5esmasterdata02-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait --output none

Write-Host "[3/8] Creating dsv5esmasterdata03 (CentOS 7.9, DSv5, Zone 1)..."
az vm create --resource-group $RESOURCE_GROUP --name dsv5esmasterdata03 --nics dsv5esmasterdata03-nic --image $CENTOS_IMAGE --size Standard_D8s_v5 --admin-username $ADMIN_USER --zone 1 --os-disk-name dsv5esmasterdata03-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait --output none

Write-Host "[4/8] Creating dsv6esmasterdata01 (Rocky 9.6, DSv6, Zone 2)..."
az vm create --resource-group $RESOURCE_GROUP --name dsv6esmasterdata01 --nics dsv6esmasterdata01-nic --image $ROCKY_IMAGE --size Standard_D8s_v6 --admin-username $ADMIN_USER --zone 2 --os-disk-name dsv6esmasterdata01-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait --output none

Write-Host "[5/8] Creating dsv6esmasterdata02 (Rocky 9.6, DSv6, Zone 3)..."
az vm create --resource-group $RESOURCE_GROUP --name dsv6esmasterdata02 --nics dsv6esmasterdata02-nic --image $ROCKY_IMAGE --size Standard_D8s_v6 --admin-username $ADMIN_USER --zone 3 --os-disk-name dsv6esmasterdata02-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait --output none

Write-Host "[6/8] Creating dsv6esmasterdata03 (Rocky 9.6, DSv6, Zone 1)..."
az vm create --resource-group $RESOURCE_GROUP --name dsv6esmasterdata03 --nics dsv6esmasterdata03-nic --image $ROCKY_IMAGE --size Standard_D8s_v6 --admin-username $ADMIN_USER --zone 1 --os-disk-name dsv6esmasterdata03-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait --output none

Write-Host "[7/8] Creating clientvm01 (Rocky 9.6, D32s_v6, Zone 1)..."
az vm create --resource-group $RESOURCE_GROUP --name clientvm01 --nics clientvm01-nic --image $ROCKY_IMAGE --size Standard_D32s_v6 --admin-username $ADMIN_USER --zone 1 --os-disk-name clientvm01-osdisk --os-disk-size-gb 256 --storage-sku Premium_LRS --no-wait --output none

Write-Host "[8/8] Creating clientvm02 (Rocky 9.6, D32s_v6, Zone 2)..."
az vm create --resource-group $RESOURCE_GROUP --name clientvm02 --nics clientvm02-nic --image $ROCKY_IMAGE --size Standard_D32s_v6 --admin-username $ADMIN_USER --zone 2 --os-disk-name clientvm02-osdisk --os-disk-size-gb 256 --storage-sku Premium_LRS --no-wait --output none

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✓ All 8 VMs creation initiated!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Deployment Summary:"
Write-Host "  DSv5 Cluster (CentOS 7.9):"
Write-Host "    - dsv5esmasterdata01 (Zone 2)"
Write-Host "    - dsv5esmasterdata02 (Zone 3)"
Write-Host "    - dsv5esmasterdata03 (Zone 1)"
Write-Host "  DSv6 Cluster (Rocky 9.6):"
Write-Host "    - dsv6esmasterdata01 (Zone 2)"
Write-Host "    - dsv6esmasterdata02 (Zone 3)"
Write-Host "    - dsv6esmasterdata03 (Zone 1)"
Write-Host "  Client VMs (Rocky 9.6):"
Write-Host "    - clientvm01 (Zone 1)"
Write-Host "    - clientvm02 (Zone 2)"
Write-Host ""
Write-Host "Monitor VM creation progress:"
Write-Host "  az vm list -g $RESOURCE_GROUP --query `"[].{name:name, powerState:powerState, provisioningState:provisioningState}`" -o table"
Write-Host ""
Write-Host "Wait for all VMs to reach 'PowerState: VM running' and 'ProvisioningState: Succeeded'"
Write-Host ""
