# =====================================================================
# 02-collect-ips.ps1  —  Collect private IPs and build namesrvAddr
# Writes hosts-ip.json used by the configure step.
# Run:  .\02-collect-ips.ps1
# =====================================================================
. (Join-Path $PSScriptRoot '00-variables.ps1')

az account set --subscription $SUBSCRIPTION | Out-Null

$map = @{}
foreach ($n in $NODES) {
    $vm = $n.Name
    $ip = Invoke-Az vm list-ip-addresses `
        --resource-group $RG `
        --name $vm `
        --query "[0].virtualMachine.network.privateIpAddresses[0]" `
        --only-show-errors -o tsv
    $ip = ($ip | Out-String).Trim()
    if (-not $ip) { Write-Warning "No private IP found for $vm"; continue }
    $map[$vm] = $ip
    Write-Host ("{0,-24} {1}" -f $vm, $ip)
}

# namesrvAddr = all 3 name servers
$nsAddr = ($NODES | Where-Object { $_.Role -eq 'nameserver' } |
    ForEach-Object { "$($map[$_.Name]):$NAMESRV_PORT" }) -join ';'

$result = [ordered]@{
    map         = $map
    namesrvAddr = $nsAddr
}
$result | ConvertTo-Json -Depth 4 | Set-Content -Path $IP_FILE -Encoding UTF8

Write-Host "`nnamesrvAddr = $nsAddr" -ForegroundColor Yellow
Write-Host "Saved -> $IP_FILE" -ForegroundColor Cyan
