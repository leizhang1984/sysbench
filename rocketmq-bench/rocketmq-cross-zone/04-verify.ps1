# =====================================================================
# 04-verify.ps1  —  Verify the RocketMQ cluster
#   - per-node: data disk mount, java version, service state, ports
#   - cluster:  mqadmin clusterList from a name server
# Run:  .\04-verify.ps1
# =====================================================================
. (Join-Path $PSScriptRoot '00-variables.ps1')

az account set --subscription $SUBSCRIPTION | Out-Null

# small inline health probe per node
$probe = @'
echo "host: $(hostname)"
echo -n "java: "; java -version 2>&1 | head -1
echo -n "datadisk: "; findmnt -no SOURCE,FSTYPE /datadisk 2>/dev/null || echo "NOT MOUNTED"
if systemctl list-unit-files | grep -q rocketmq-namesrv; then
  echo -n "namesrv: "; systemctl is-active rocketmq-namesrv 2>/dev/null
fi
if systemctl list-unit-files | grep -q rocketmq-broker; then
  echo -n "broker:  "; systemctl is-active rocketmq-broker 2>/dev/null
fi
ss -lnt | grep -E "9876|10911|10909|10912" || echo "no rmq ports listening"
'@
$probeFile = Join-Path $PSScriptRoot '_probe.sh'
$probe | Set-Content -Path $probeFile -Encoding ASCII

foreach ($n in $NODES) {
    Write-Host "`n=== $($n.Name) ===" -ForegroundColor Green
    Invoke-Az vm run-command invoke --only-show-errors `
        --subscription $SUBSCRIPTION -g $RG -n $n.Name `
        --command-id RunShellScript --scripts "@$probeFile" `
        --query "value[0].message" -o tsv
}

Remove-Item $probeFile -ErrorAction SilentlyContinue

# cluster list from the first name server
$ns1 = ($NODES | Where-Object { $_.Role -eq 'nameserver' } | Select-Object -First 1).Name
Write-Host "`n=== Cluster list (from $ns1) ===" -ForegroundColor Cyan
Invoke-Az vm run-command invoke --only-show-errors `
    --subscription $SUBSCRIPTION -g $RG -n $ns1 `
    --command-id RunShellScript --scripts "@$(Join-Path $PSScriptRoot 'clusterlist.sh')" `
    --query "value[0].message" -o tsv
