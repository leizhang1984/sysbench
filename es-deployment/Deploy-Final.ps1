# Simplified Elasticsearch DSv5 vs DSv6 Deployment
# PowerShell deployment script - Using Rocky Linux instead of deprecated CentOS

$ErrorActionPreference = "Stop"

Write-Host "Elasticsearch DSv5 vs DSv6 Deployment on Azure" -ForegroundColor Green
Write-Host "=============================================`n"

$RESOURCE_GROUP = "es-rg"
$LOCATION = "germanywestcentral"
$ADMIN_USER = "azureuser"
$ROCKY_IMAGE = "erockyenterprisesoftwarefoundationinc1653071250513:rockylinux-x86_64-base:9-lvm:latest"

Write-Host "[3/5] Creating DSv5 VMs (Rocky 9.6 - replacing CentOS)..."
az vm create --resource-group $RESOURCE_GROUP --name dsv5esmasterdata01 --nics dsv5esmasterdata01-nic --image $ROCKY_IMAGE --size Standard_D8s_v5 --admin-username $ADMIN_USER --zone 2 --os-disk-name dsv5esmasterdata01-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait -o none

az vm create --resource-group $RESOURCE_GROUP --name dsv5esmasterdata02 --nics dsv5esmasterdata02-nic --image $ROCKY_IMAGE --size Standard_D8s_v5 --admin-username $ADMIN_USER --zone 3 --os-disk-name dsv5esmasterdata02-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait -o none

az vm create --resource-group $RESOURCE_GROUP --name dsv5esmasterdata03 --nics dsv5esmasterdata03-nic --image $ROCKY_IMAGE --size Standard_D8s_v5 --admin-username $ADMIN_USER --zone 1 --os-disk-name dsv5esmasterdata03-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait -o none

Write-Host "`n[4/5] Creating DSv6 VMs (Rocky 9.6)..."
az vm create --resource-group $RESOURCE_GROUP --name dsv6esmasterdata01 --nics dsv6esmasterdata01-nic --image $ROCKY_IMAGE --size Standard_D8s_v6 --admin-username $ADMIN_USER --zone 2 --os-disk-name dsv6esmasterdata01-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait -o none

az vm create --resource-group $RESOURCE_GROUP --name dsv6esmasterdata02 --nics dsv6esmasterdata02-nic --image $ROCKY_IMAGE --size Standard_D8s_v6 --admin-username $ADMIN_USER --zone 3 --os-disk-name dsv6esmasterdata02-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait -o none

az vm create --resource-group $RESOURCE_GROUP --name dsv6esmasterdata03 --nics dsv6esmasterdata03-nic --image $ROCKY_IMAGE --size Standard_D8s_v6 --admin-username $ADMIN_USER --zone 1 --os-disk-name dsv6esmasterdata03-osdisk --os-disk-size-gb 128 --storage-sku Premium_LRS --no-wait -o none

Write-Host "`n[5/5] Creating Client VMs (Rocky 9.6)..."
az vm create --resource-group $RESOURCE_GROUP --name clientvm01 --nics clientvm01-nic --image $ROCKY_IMAGE --size Standard_D32s_v6 --admin-username $ADMIN_USER --zone 1 --os-disk-name clientvm01-osdisk --os-disk-size-gb 256 --storage-sku Premium_LRS --no-wait -o none

az vm create --resource-group $RESOURCE_GROUP --name clientvm02 --nics clientvm02-nic --image $ROCKY_IMAGE --size Standard_D32s_v6 --admin-username $ADMIN_USER --zone 2 --os-disk-name clientvm02-osdisk --os-disk-size-gb 256 --storage-sku Premium_LRS --no-wait -o none

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "✓ All VM creation commands initiated!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "VMs are being created in the background (--no-wait mode)."
Write-Host "This typically takes 10-15 minutes per VM."
Write-Host ""
Write-Host "Monitor progress with:"
Write-Host "  az vm list -g $RESOURCE_GROUP --query `"[].{name:name, state:powerState}`" -o table"
Write-Host ""
Write-Host "Check individual VM status with:"
Write-Host "  az vm show -g $RESOURCE_GROUP -n dsv5esmasterdata01 --query provisioningState"
Write-Host ""
Write-Host "Next steps after all VMs are in 'Running' state:"
Write-Host "1. Attach data disks: bash scripts/attach-datadisks.sh"
Write-Host "2. Run health check: bash scripts/verify/health-check.sh"
Write-Host ""
