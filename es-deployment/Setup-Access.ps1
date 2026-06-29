$RG = "es-rg"
$ErrorActionPreference = "Continue"

# VM -> zone mapping
$vms = @(
  @{name="dsv5esmasterdata01"; zone="2"},
  @{name="dsv5esmasterdata02"; zone="3"},
  @{name="dsv5esmasterdata03"; zone="1"},
  @{name="dsv6esmasterdata01"; zone="2"},
  @{name="dsv6esmasterdata02"; zone="3"},
  @{name="dsv6esmasterdata03"; zone="1"},
  @{name="clientvm01"; zone="1"},
  @{name="clientvm02"; zone="2"}
)

Write-Host "========================================"
Write-Host "STEP 1: Create public IPs"
Write-Host "========================================"
foreach ($v in $vms) {
  $pip = "$($v.name)-pip"
  Write-Host "Creating $pip (zone $($v.zone))..."
  az network public-ip create -g $RG -n $pip --sku Standard --zone $v.zone --allocation-method Static --output none
  if ($LASTEXITCODE -eq 0) { Write-Host "  OK" } else { Write-Host "  FAILED" }
}

Write-Host ""
Write-Host "========================================"
Write-Host "STEP 2: Associate public IPs to NIC ipconfigs"
Write-Host "========================================"
foreach ($v in $vms) {
  $nic = "$($v.name)-nic"
  $pip = "$($v.name)-pip"
  # discover ipconfig name
  $ipcfg = az network nic ip-config list -g $RG --nic-name $nic --query "[0].name" -o tsv
  Write-Host "Associating $pip -> $nic ($ipcfg)..."
  az network nic ip-config update -g $RG --nic-name $nic -n $ipcfg --public-ip-address $pip --output none
  if ($LASTEXITCODE -eq 0) { Write-Host "  OK" } else { Write-Host "  FAILED" }
}

Write-Host ""
Write-Host "========================================"
Write-Host "STEP 3: Add azureadmin user with password (VMAccess)"
Write-Host "========================================"
foreach ($v in $vms) {
  Write-Host "Setting azureadmin on $($v.name)..."
  az vm user update -g $RG -n $v.name -u azureadmin -p "Zhanglei@123456" --output none
  if ($LASTEXITCODE -eq 0) { Write-Host "  OK" } else { Write-Host "  FAILED" }
}

Write-Host ""
Write-Host "========================================"
Write-Host "RESULT: VM public + private IPs"
Write-Host "========================================"
az vm list-ip-addresses -g $RG --query "[].{VM:virtualMachine.name, PrivateIP:virtualMachine.network.privateIpAddresses[0], PublicIP:virtualMachine.network.publicIpAddresses[0].ipAddress}" -o table
