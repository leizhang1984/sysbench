# Elasticsearch DSv5 vs DSv6 Deployment
# PowerShell deployment script

$ErrorActionPreference = "Stop"

Write-Host "Elasticsearch DSv5 vs DSv6 Deployment on Azure" -ForegroundColor Green
Write-Host "=============================================`n"

$RESOURCE_GROUP = "es-rg"
$LOCATION = "germanywestcentral"
$VNET = "es-vnet"
$SUBNET = "vm-subnet"
$ADMIN_USER = "azureuser"

Write-Host "[1/5] Verifying Azure CLI..."
az account show | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Not logged into Azure"
    exit 1
}

Write-Host "[2/5] Creating network interfaces..."

# DSv5 NICs
Write-Host "Creating DSv5 NICs..."
az network nic create -g $RESOURCE_GROUP -n dsv5esmasterdata01-nic --vnet-name $VNET --subnet $SUBNET --private-ip-address 10.122.0.4 --accelerated-networking true -o none
az network nic create -g $RESOURCE_GROUP -n dsv5esmasterdata02-nic --vnet-name $VNET --subnet $SUBNET --private-ip-address 10.122.0.5 --accelerated-networking true -o none
az network nic create -g $RESOURCE_GROUP -n dsv5esmasterdata03-nic --vnet-name $VNET --subnet $SUBNET --private-ip-address 10.122.0.6 --accelerated-networking true -o none

# DSv6 NICs
Write-Host "Creating DSv6 NICs..."
az network nic create -g $RESOURCE_GROUP -n dsv6esmasterdata01-nic --vnet-name $VNET --subnet $SUBNET --private-ip-address 10.122.0.7 --accelerated-networking true -o none
az network nic create -g $RESOURCE_GROUP -n dsv6esmasterdata02-nic --vnet-name $VNET --subnet $SUBNET --private-ip-address 10.122.0.8 --accelerated-networking true -o none
az network nic create -g $RESOURCE_GROUP -n dsv6esmasterdata03-nic --vnet-name $VNET --subnet $SUBNET --private-ip-address 10.122.0.9 --accelerated-networking true -o none

# Client NICs
Write-Host "Creating Client NICs..."
az network nic create -g $RESOURCE_GROUP -n clientvm01-nic --vnet-name $VNET --subnet $SUBNET --private-ip-address 10.122.0.10 --accelerated-networking true -o none
az network nic create -g $RESOURCE_GROUP -n clientvm02-nic --vnet-name $VNET --subnet $SUBNET --private-ip-address 10.122.0.11 --accelerated-networking true -o none

Write-Host "✓ All NICs created`n"

# Read SSH public key
$sshKeyPath = "$HOME\.ssh\id_rsa.pub"
if (-not (Test-Path $sshKeyPath)) {
    Write-Host "WARNING: SSH key not found at $sshKeyPath"
    $sshKeyPath = ""
}

Write-Host "[3/5] Creating DSv5 VMs (CentOS 7.9)..."
foreach ($i in @("01", "02", "03")) {
    $vmName = "dsv5esmasterdata$i"
    $zone = [int]$i % 3 + 1
    Write-Host "  Creating $vmName in zone $zone..."
    
    $cmd = @(
        "az", "vm", "create",
        "--resource-group", $RESOURCE_GROUP,
        "--name", $vmName,
        "--nics", "$vmName-nic",
        "--image", "CentOS:CentOS:7_9:latest",
        "--size", "Standard_D8s_v5",
        "--admin-username", $ADMIN_USER,
        "--zone", $zone,
        "--os-disk-name", "$vmName-osdisk",
        "--os-disk-size-gb", "128",
        "--storage-sku", "Premium_LRS",
        "--no-wait",
        "-o", "none"
    )
    
    if ($sshKeyPath) {
        $cmd += "--ssh-key-values", $sshKeyPath
    }
    
    & $cmd
}

Write-Host "`n[4/5] Creating DSv6 VMs (Rocky 9.6)..."
foreach ($i in @("01", "02", "03")) {
    $vmName = "dsv6esmasterdata$i"
    $zone = [int]$i % 3 + 1
    Write-Host "  Creating $vmName in zone $zone..."
    
    $cmd = @(
        "az", "vm", "create",
        "--resource-group", $RESOURCE_GROUP,
        "--name", $vmName,
        "--nics", "$vmName-nic",
        "--image", "erockyenterprisesoftwarefoundationinc1653071250513:rockylinux-x86_64-base:9-lvm:latest",
        "--size", "Standard_D8s_v6",
        "--admin-username", $ADMIN_USER,
        "--zone", $zone,
        "--os-disk-name", "$vmName-osdisk",
        "--os-disk-size-gb", "128",
        "--storage-sku", "Premium_LRS",
        "--no-wait",
        "-o", "none"
    )
    
    if ($sshKeyPath) {
        $cmd += "--ssh-key-values", $sshKeyPath
    }
    
    & $cmd
}

Write-Host "`n[5/5] Creating Client VMs (Rocky 9.6)..."
foreach ($i in @("01", "02")) {
    $vmName = "clientvm$i"
    $zone = [int]$i % 3 + 1
    Write-Host "  Creating $vmName in zone $zone..."
    
    $cmd = @(
        "az", "vm", "create",
        "--resource-group", $RESOURCE_GROUP,
        "--name", $vmName,
        "--nics", "$vmName-nic",
        "--image", "erockyenterprisesoftwarefoundationinc1653071250513:rockylinux-x86_64-base:9-lvm:latest",
        "--size", "Standard_D32s_v6",
        "--admin-username", $ADMIN_USER,
        "--zone", $zone,
        "--os-disk-name", "$vmName-osdisk",
        "--os-disk-size-gb", "256",
        "--storage-sku", "Premium_LRS",
        "--no-wait",
        "-o", "none"
    )
    
    if ($sshKeyPath) {
        $cmd += "--ssh-key-values", $sshKeyPath
    }
    
    & $cmd
}

Write-Host "`n========================================="
Write-Host "Deployment initiated successfully!" -ForegroundColor Green
Write-Host "========================================="
Write-Host ""
Write-Host "All VMs are being created. This may take 10-15 minutes."
Write-Host ""
Write-Host "Monitor progress with:"
Write-Host "  az vm list -g $RESOURCE_GROUP --query `"[].{name:name, state:powerState}`" -o table"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Wait for all VMs to reach 'Running' state and initialize"
Write-Host "2. Attach data disks: bash scripts/attach-datadisks.sh"
Write-Host "3. Run health check: bash scripts/verify/health-check.sh"
Write-Host ""
