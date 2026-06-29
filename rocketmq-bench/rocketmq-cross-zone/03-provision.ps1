# =====================================================================
# 03-provision.ps1  —  Provision RocketMQ on every VM via run-command
#   - Name servers first, then brokers (masters + slaves)
#   - namesrvAddr is read from hosts-ip.json (run 02-collect-ips.ps1 first)
# Run:  .\03-provision.ps1
# =====================================================================
. (Join-Path $PSScriptRoot '00-variables.ps1')

if (-not (Test-Path $IP_FILE)) { throw "hosts-ip.json not found. Run .\02-collect-ips.ps1 first." }
$hosts   = Get-Content $IP_FILE -Raw | ConvertFrom-Json
$nsAddr  = $hosts.namesrvAddr
if (-not $nsAddr) { throw "namesrvAddr empty in $IP_FILE" }
Write-Host "namesrvAddr = $nsAddr" -ForegroundColor Yellow

# Pass namesrvAddr comma-separated so the ';' separators survive run-command
# parameter passing; the broker setup script converts ',' back to ';'.
$nsParam = $nsAddr.Replace(';', ',')

az account set --subscription $SUBSCRIPTION | Out-Null

function Invoke-RunCommand {
    param([string]$Vm, [string]$ScriptPath, [string[]]$Params)
    Write-Host "--> $Vm : $([IO.Path]::GetFileName($ScriptPath)) $($Params -join ' ')" -ForegroundColor Gray
    $argList = @(
        'vm','run-command','invoke','--only-show-errors',
        '--subscription', $SUBSCRIPTION,
        '-g', $RG, '-n', $Vm,
        '--command-id','RunShellScript',
        '--scripts', "@$ScriptPath"
    )
    if ($Params -and $Params.Count -gt 0) { $argList += @('--parameters'); $argList += $Params }
    $argList += @('--query','value[0].message','-o','tsv')
    Invoke-Az @argList
}

# --- 1. Name servers (sequential) ---------------------------------------
$nsScript = Join-Path $PSScriptRoot 'setup-nameserver.sh'
foreach ($n in ($NODES | Where-Object { $_.Role -eq 'nameserver' })) {
    Write-Host "`n=== Provision NAME SERVER $($n.Name) ===" -ForegroundColor Green
    Invoke-RunCommand -Vm $n.Name -ScriptPath $nsScript
}

# --- 2. Brokers: masters first, then slaves -----------------------------
$brScript = Join-Path $PSScriptRoot 'setup-broker.sh'
$brokers  = $NODES | Where-Object { $_.Role -eq 'broker' } |
            Sort-Object @{ E = { if ($_.BrokerRole -like '*MASTER*') { 0 } else { 1 } } }, Name
foreach ($b in $brokers) {
    $ip = $hosts.map.$($b.Name)
    Write-Host "`n=== Provision BROKER $($b.Name) ($($b.Group) id=$($b.BrokerId) $($b.BrokerRole)) ===" -ForegroundColor Green
    Invoke-RunCommand -Vm $b.Name -ScriptPath $brScript `
        -Params @($b.Group, "$($b.BrokerId)", $b.BrokerRole, $nsParam, $ip)
}

Write-Host "`nProvisioning launched on all nodes (setup runs detached on each VM)." -ForegroundColor Cyan
Write-Host "Wait a few minutes for downloads/start, then run .\04-verify.ps1" -ForegroundColor Cyan
