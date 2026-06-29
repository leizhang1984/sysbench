# =====================================================================
# 01-create-vms.ps1  —  Create 9 zonal VMs + Premium SSD v2 data disks
# Run:  . .\00-variables.ps1 ; .\01-create-vms.ps1
# =====================================================================
. (Join-Path $PSScriptRoot '00-variables.ps1')

az account set --subscription $SUBSCRIPTION | Out-Null

# --- Accept the Rocky Linux marketplace image terms (idempotent) ---------
Write-Host "Accepting marketplace image terms for $IMAGE ..." -ForegroundColor Yellow
Invoke-Az vm image terms accept --urn $IMAGE --subscription $SUBSCRIPTION --only-show-errors | Out-Null

foreach ($n in $NODES) {
    $vm   = $n.Name
    $zone = $n.Zone
    $disk = "$vm-datadisk"

    Write-Host "`n=== Creating VM $vm (zone $zone) ===" -ForegroundColor Green

    # 1) Create the VM: zonal, accelerated networking, no public IP (managed via run-command)
    Invoke-Az vm create `
        --resource-group $RG `
        --name $vm `
        --image $IMAGE `
        --size $VM_SIZE `
        --zone $zone `
        --vnet-name $VNET `
        --subnet $SUBNET `
        --public-ip-address '""' `
        --nsg '""' `
        --accelerated-networking true `
        --admin-username $ADMIN_USER `
        --admin-password $ADMIN_PASS `
        --authentication-type password `
        --storage-sku os=Premium_LRS `
        --only-show-errors | Out-Null

    # 2) Create the Premium SSD v2 data disk in the SAME zone
    Write-Host "    creating Premium SSD v2 disk $disk ($DISK_SIZE_GB GB / $DISK_IOPS IOPS / $DISK_MBPS MBps)" -ForegroundColor Gray
    Invoke-Az disk create `
        --resource-group $RG `
        --name $disk `
        --location $LOCATION `
        --zone $zone `
        --sku $DISK_SKU `
        --size-gb $DISK_SIZE_GB `
        --disk-iops-read-write $DISK_IOPS `
        --disk-mbps-read-write $DISK_MBPS `
        --only-show-errors | Out-Null

    # 3) Attach the data disk
    Invoke-Az vm disk attach `
        --resource-group $RG `
        --vm-name $vm `
        --name $disk `
        --only-show-errors | Out-Null

    Write-Host "    $vm ready." -ForegroundColor Green
}

Write-Host "`nAll 9 VMs + data disks created. Next: .\02-collect-ips.ps1" -ForegroundColor Cyan
