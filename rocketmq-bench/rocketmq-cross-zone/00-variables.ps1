# =====================================================================
# 00-variables.ps1  —  Shared configuration for RocketMQ 4.9.7 multi-AZ
# Classic master-slave (SYNC_MASTER / SLAVE), NO DLedger.
# Dot-source this file from the other scripts:  . .\00-variables.ps1
# =====================================================================

# --- Azure context -------------------------------------------------------
$Global:SUBSCRIPTION = '166157a8-9ce9-400b-91c7-1d42482b83d6'
$Global:RG           = 'rocketmqnew2-rg'
$Global:LOCATION     = 'germanywestcentral'
$Global:VNET         = 'rocketmqnew2-vnet'
$Global:SUBNET       = 'vm-subnet'

# --- VM / image ----------------------------------------------------------
$Global:VM_SIZE      = 'Standard_D4s_v6'
# Rocky Linux 9 (latest) from the marketplace (publisher resf)
$Global:IMAGE        = 'resf:rockylinux-x86_64:9-base:latest'
$Global:ADMIN_USER   = 'azureadmin'
$Global:ADMIN_PASS   = 'Zhanglei@123456'

# --- Data disk (Premium SSD v2) ------------------------------------------
$Global:DISK_SKU     = 'PremiumV2_LRS'
$Global:DISK_SIZE_GB = 100
$Global:DISK_IOPS    = 3000
$Global:DISK_MBPS    = 125

# --- RocketMQ ------------------------------------------------------------
$Global:RMQ_VERSION       = '4.9.7'
$Global:RMQ_CLUSTER       = 'RocketMQCluster'
$Global:NAMESRV_PORT      = 9876

# --- Topology ------------------------------------------------------------
# role: nameserver | broker
# For brokers: group (brokerName), brokerId, brokerRole, zone.
# Master/slave pairs are split across two zones for AZ resilience:
#   broker-a: master z1 / slave z2
#   broker-b: master z2 / slave z3
#   broker-c: master z3 / slave z1
$Global:NODES = @(
    @{ Name='v6rocketmqnamesvr01'; Role='nameserver'; Zone=1 }
    @{ Name='v6rocketmqnamesvr02'; Role='nameserver'; Zone=2 }
    @{ Name='v6rocketmqnamesvr03'; Role='nameserver'; Zone=3 }

    @{ Name='v6rocketmqbroker-a-0'; Role='broker'; Group='broker-a'; BrokerId=0; BrokerRole='SYNC_MASTER'; Zone=1 }
    @{ Name='v6rocketmqbroker-a-1'; Role='broker'; Group='broker-a'; BrokerId=1; BrokerRole='SLAVE';       Zone=2 }
    @{ Name='v6rocketmqbroker-b-0'; Role='broker'; Group='broker-b'; BrokerId=0; BrokerRole='SYNC_MASTER'; Zone=2 }
    @{ Name='v6rocketmqbroker-b-1'; Role='broker'; Group='broker-b'; BrokerId=1; BrokerRole='SLAVE';       Zone=3 }
    @{ Name='v6rocketmqbroker-c-0'; Role='broker'; Group='broker-c'; BrokerId=0; BrokerRole='SYNC_MASTER'; Zone=3 }
    @{ Name='v6rocketmqbroker-c-1'; Role='broker'; Group='broker-c'; BrokerId=1; BrokerRole='SLAVE';       Zone=1 }
)

# --- Paths ---------------------------------------------------------------
$Global:WORKDIR  = $PSScriptRoot
$Global:IP_FILE  = Join-Path $PSScriptRoot 'hosts-ip.json'

# --- Helper: run an az command, clearing the MSAL cache lock first --------
# NOTE: no param block / no [CmdletBinding] so that args like -o / -g are passed
# straight through to az (avoids clashing with PowerShell common parameters).
function Invoke-Az {
    Remove-Item -Force "$env:USERPROFILE\.azure\msal_http_cache.bin" -ErrorAction SilentlyContinue
    & az @args
}

Write-Host "Loaded variables: RG=$RG LOCATION=$LOCATION VM_SIZE=$VM_SIZE ($($NODES.Count) nodes)" -ForegroundColor Cyan
