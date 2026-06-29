# Phase 1 - Azure infrastructure for RocketMQ 4.9.7 three-AZ cluster (PowerShell port).
# Creates NSG, 9 zonal VMs (accelerated networking, Standard security type,
# static private IPs, no public IP), and one Premium SSD v2 data disk per VM.
# Created by GitHub Copilot.
$ErrorActionPreference = "Continue"

$SUB      = "166157a8-9ce9-400b-91c7-1d42482b83d6"
$RG       = "rocketmqnew1-rg"
$LOCATION = "germanywestcentral"
$VNET     = "rocketmqnew1-vnet"
$SUBNET   = "vm-subnet"
$NSG      = "rocketmqnew1-nsg"
$VM_SIZE  = "Standard_D4s_v6"
$IMAGE    = "resf:rockylinux-x86_64:9-base:latest"
$ADMIN_USER = "azureadmin"
$ADMIN_PASS = ""
$DISK_SKU = "PremiumV2_LRS"
$SSH_SRC  = "VirtualNetwork"   # restrict SSH to your mgmt CIDR if desired

# name, ip, zone
$NODES = @(
  @{ name="v6rocketmqnamesvr01"; ip="10.161.0.4";  zone="1" },
  @{ name="v6rocketmqnamesvr02"; ip="10.161.0.5";  zone="2" },
  @{ name="v6rocketmqnamesvr03"; ip="10.161.0.6";  zone="3" },
  @{ name="broker-a-0";          ip="10.161.0.10"; zone="1" },
  @{ name="broker-a-1";          ip="10.161.0.11"; zone="1" },
  @{ name="broker-b-0";          ip="10.161.0.12"; zone="2" },
  @{ name="broker-b-1";          ip="10.161.0.13"; zone="2" },
  @{ name="broker-c-0";          ip="10.161.0.14"; zone="3" },
  @{ name="broker-c-1";          ip="10.161.0.15"; zone="3" }
)

# Use the real CLI launcher to avoid resolving back into any 'az' function.
$AZ = (Get-Command az.cmd -ErrorAction SilentlyContinue).Source
if (-not $AZ) { $AZ = "az" }

function Invoke-Az {
  & $AZ @args
  if ($LASTEXITCODE -ne 0) { throw "az failed: $($args -join ' ')" }
}
function Try-Az {
  & $AZ @args 2>&1 | Out-Null
  return ($LASTEXITCODE -eq 0)
}

Invoke-Az account set --subscription $SUB

Write-Host "=== Accept marketplace image terms (Rocky 9) ==="
Try-Az vm image terms accept --urn $IMAGE -o none | Out-Null

Write-Host "=== NSG ==="
if (-not (Try-Az network nsg show -g $RG -n $NSG -o none)) {
  Invoke-Az network nsg create -g $RG -n $NSG -l $LOCATION -o none
}
Try-Az network nsg rule create -g $RG --nsg-name $NSG -n "Allow-RocketMQ-VNet" `
  --priority 200 --direction Inbound --access Allow --protocol Tcp `
  --source-address-prefixes VirtualNetwork --destination-address-prefixes VirtualNetwork `
  --destination-port-ranges 9876 10909 10911 10912 -o none | Out-Null
Try-Az network nsg rule create -g $RG --nsg-name $NSG -n "Allow-SSH" `
  --priority 300 --direction Inbound --access Allow --protocol Tcp `
  --source-address-prefixes $SSH_SRC --destination-port-ranges 22 -o none | Out-Null

Write-Host "=== Associate NSG to subnet ==="
Invoke-Az network vnet subnet update -g $RG --vnet-name $VNET -n $SUBNET --network-security-group $NSG -o none

foreach ($n in $NODES) {
  $NAME = $n.name; $IP = $n.ip; $ZONE = $n.zone
  $NIC = "$NAME-nic"; $DISK = "$NAME-datadisk"

  if (-not (Try-Az vm show -g $RG -n $NAME -o none)) {
    Write-Host "=== NIC $NIC (static $IP, accel net) ==="
    if (-not (Try-Az network nic show -g $RG -n $NIC -o none)) {
      Invoke-Az network nic create -g $RG -n $NIC --vnet-name $VNET --subnet $SUBNET `
        --private-ip-address $IP --accelerated-networking true -o none
    }
    Write-Host "=== VM $NAME (zone $ZONE) ==="
    Invoke-Az vm create -g $RG -n $NAME --image $IMAGE --size $VM_SIZE --zone $ZONE `
      --nics $NIC --admin-username $ADMIN_USER --admin-password $ADMIN_PASS `
      --authentication-type password --security-type Standard `
      --os-disk-name "$NAME-osdisk" --public-ip-address '""' -o none
  } else {
    Write-Host "VM $NAME exists, skip create"
  }

  Write-Host "=== Premium SSD v2 disk $DISK (zone $ZONE) ==="
  if (-not (Try-Az disk show -g $RG -n $DISK -o none)) {
    Invoke-Az disk create -g $RG -n $DISK -l $LOCATION --zone $ZONE --sku $DISK_SKU `
      --size-gb 100 --disk-iops-read-write 3000 --disk-mbps-read-write 125 -o none
  }

  $attached = & $AZ vm show -g $RG -n $NAME --query "storageProfile.dataDisks[?name=='$DISK'].name" -o tsv
  if (-not $attached) {
    Write-Host "=== Attach $DISK -> $NAME (lun 0) ==="
    Invoke-Az vm disk attach -g $RG --vm-name $NAME --name $DISK --lun 0 -o none
  }
}

Write-Host "=== Infrastructure complete ==="
& $AZ vm list -g $RG -d --query "[].{name:name,zone:zones[0],ip:privateIps,size:hardwareProfile.vmSize}" -o table
