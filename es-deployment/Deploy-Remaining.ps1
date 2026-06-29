# Deploy remaining 3 VMs + 6 data disks
$RG = "es-rg"
$IMG = "resf:rockylinux-x86_64:9-lvm:9.6.20250531"
$PLAN_NAME = "9-lvm"
$PLAN_PROD = "rockylinux-x86_64"
$PLAN_PUB  = "resf"

Write-Host "=== [1/3] dsv6esmasterdata03 (Zone 1) ==="
az vm create -g $RG -n dsv6esmasterdata03 `
  --nics dsv6esmasterdata03-nic `
  --image $IMG `
  --plan-name $PLAN_NAME --plan-product $PLAN_PROD --plan-publisher $PLAN_PUB `
  --size Standard_D8s_v6 --admin-username azureuser --zone 1 `
  --os-disk-name dsv6esmasterdata03-osdisk --os-disk-size-gb 128 `
  --storage-sku Premium_LRS --generate-ssh-keys --no-wait --output none
Write-Host "  -> submitted"

Write-Host "=== [2/3] clientvm01 (Zone 1) ==="
az vm create -g $RG -n clientvm01 `
  --nics clientvm01-nic `
  --image $IMG `
  --plan-name $PLAN_NAME --plan-product $PLAN_PROD --plan-publisher $PLAN_PUB `
  --size Standard_D32s_v6 --admin-username azureuser --zone 1 `
  --os-disk-name clientvm01-osdisk --os-disk-size-gb 256 `
  --storage-sku Premium_LRS --generate-ssh-keys --no-wait --output none
Write-Host "  -> submitted"

Write-Host "=== [3/3] clientvm02 (Zone 2) ==="
az vm create -g $RG -n clientvm02 `
  --nics clientvm02-nic `
  --image $IMG `
  --plan-name $PLAN_NAME --plan-product $PLAN_PROD --plan-publisher $PLAN_PUB `
  --size Standard_D32s_v6 --admin-username azureuser --zone 2 `
  --os-disk-name clientvm02-osdisk --os-disk-size-gb 256 `
  --storage-sku Premium_LRS --generate-ssh-keys --no-wait --output none
Write-Host "  -> submitted"

Write-Host ""
Write-Host "=== Creating 6 data disks (PremiumV2_LRS, 200GB, 3000 IOPS, 125 MBps) ==="
$disks = @(
  @{name="dsv5esmasterdata01-datadisk"; zone="2"},
  @{name="dsv5esmasterdata02-datadisk"; zone="3"},
  @{name="dsv5esmasterdata03-datadisk"; zone="1"},
  @{name="dsv6esmasterdata01-datadisk"; zone="2"},
  @{name="dsv6esmasterdata02-datadisk"; zone="3"},
  @{name="dsv6esmasterdata03-datadisk"; zone="1"}
)
foreach ($d in $disks) {
  Write-Host "  Creating $($d.name) in zone $($d.zone)..."
  az disk create -g $RG -n $d.name `
    --size-gb 200 --sku PremiumV2_LRS `
    --disk-iops-read-write 3000 --disk-mbps-read-write 125 `
    --zone $d.zone --no-wait --output none
  Write-Host "  -> submitted"
}

Write-Host ""
Write-Host "========================================"
Write-Host "All VM + disk submissions complete."
Write-Host "========================================"
Write-Host ""
Write-Host "Waiting 3 min for VMs to finish provisioning..."
Start-Sleep -Seconds 180

Write-Host ""
Write-Host "=== Final VM Status ==="
az vm list -g $RG --query "[].{name:name, zone:zones[0], state:provisioningState}" -o table

Write-Host ""
Write-Host "=== Data Disk Status ==="
az disk list -g $RG --query "[?contains(name,'datadisk')].{name:name, zone:zones[0], sku:sku.name, state:provisioningState}" -o table
