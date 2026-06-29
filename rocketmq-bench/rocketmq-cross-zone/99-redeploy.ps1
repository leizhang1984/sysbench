. (Join-Path $PSScriptRoot '00-variables.ps1')

$cleanup = Join-Path $PSScriptRoot 'cleanup-stale.sh'
$nodes = @(
  'v6rocketmqnamesvr01','v6rocketmqnamesvr02','v6rocketmqnamesvr03',
  'v6rocketmqbroker-a-0','v6rocketmqbroker-a-1',
  'v6rocketmqbroker-b-0','v6rocketmqbroker-b-1',
  'v6rocketmqbroker-c-0','v6rocketmqbroker-c-1'
)

Write-Host '########## STEP 1: cleanup stale procs / dnf state ##########' -ForegroundColor Cyan
foreach ($n in $nodes) {
    Write-Host "===== cleanup $n =====" -ForegroundColor Yellow
    Invoke-Az vm run-command invoke --only-show-errors -g $RG -n $n `
        --command-id RunShellScript --scripts "@$cleanup" `
        --query 'value[0].message' -o tsv
}

Write-Host "`n########## STEP 2: re-provision (no distro-sync) ##########" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot '03-provision.ps1')

Write-Host "`nALL-DONE: cleanup + provisioning launched." -ForegroundColor Green
