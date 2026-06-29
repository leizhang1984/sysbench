. (Join-Path $PSScriptRoot '00-variables.ps1')
$script = Join-Path $PSScriptRoot 'setup-broker-direct.sh'
$ns = '10.162.0.4:9876,10.162.0.5:9876,10.162.0.6:9876'

# name, brokerId, role, ip
$brokers = @(
  @('v6rocketmqbroker-a-0','broker-a','0','SYNC_MASTER','10.162.0.7'),
  @('v6rocketmqbroker-a-1','broker-a','1','SLAVE','10.162.0.8'),
  @('v6rocketmqbroker-b-0','broker-b','0','SYNC_MASTER','10.162.0.9'),
  @('v6rocketmqbroker-b-1','broker-b','1','SLAVE','10.162.0.10'),
  @('v6rocketmqbroker-c-0','broker-c','0','SYNC_MASTER','10.162.0.11'),
  @('v6rocketmqbroker-c-1','broker-c','1','SLAVE','10.162.0.12')
)

$jobs = @()
foreach ($b in $brokers) {
  $jobs += Start-Job -ArgumentList $b[0],$b[1],$b[2],$b[3],$b[4],$ns,$script -ScriptBlock {
    param($vm,$name,$id,$role,$ip,$ns,$script)
    $out = az vm run-command invoke --only-show-errors -g rocketmqnew2-rg -n $vm `
      --command-id RunShellScript --scripts "@$script" `
      --parameters $name $id $role $ns $ip `
      --query "value[0].message" -o tsv 2>&1
    "VM=$vm`n$out"
  }
}
Write-Host "Provisioning 6 brokers in parallel (direct/sync)..." -ForegroundColor Cyan
$jobs | Wait-Job | Out-Null
foreach ($j in $jobs) {
  Write-Host "========================================" -ForegroundColor Yellow
  Receive-Job $j | Select-Object -Last 8
  Remove-Job $j
}
Write-Host "BROKER-PROVISION-DONE" -ForegroundColor Green
