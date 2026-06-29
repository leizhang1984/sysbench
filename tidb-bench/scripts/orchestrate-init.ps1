# =============================================================================
# Orchestrate: initialize all nodes via Azure Run Command (parallel jobs)
#   - Rocky machines (6 dv6 cluster + 2 clients): dnf update first
#   - 12 cluster nodes: mount data disk + OS tuning (01-init-node.sh)
# =============================================================================
param(
  [string]$Sub = "166157a8-9ce9-400b-91c7-1d42482b83d6",
  [string]$Rg  = "tidb-rg"
)

$ErrorActionPreference = "Continue"
$scriptDir = "C:\Users\leizha\tidb-bench\scripts"
$initScript   = Join-Path $scriptDir "01-init-node.sh"
$updateScript = Join-Path $scriptDir "02-rocky-update.sh"

$dv5Cluster = @("dv5tidb01","dv5tidb02","dv5tidb03","dv5tikv01","dv5tikv02","dv5tikv03")  # CentOS
$dv6Cluster = @("dv6tidb01","dv6tidb02","dv6tidb03","dv6tikv01","dv6tikv02","dv6tikv03")  # Rocky
$clients    = @("clientvm01","clientvm02")                                                # Rocky

$jobScript = {
  param($vm, $rg, $sub, $scripts)
  $out = ""
  foreach ($s in $scripts) {
    $r = az vm run-command invoke -g $rg -n $vm --subscription $sub `
          --command-id RunShellScript --scripts "@$s" `
          --query "value[0].message" -o tsv 2>&1
    $out += "`n##### [$vm] ran $(Split-Path $s -Leaf) #####`n$r`n"
  }
  return $out
}

$jobs = @()
Write-Host ">>> Starting parallel init (Rocky: update+init, CentOS: init)..."

foreach ($vm in $dv6Cluster) {
  $jobs += Start-Job -ScriptBlock $jobScript -ArgumentList $vm,$Rg,$Sub,@($updateScript,$initScript)
}
foreach ($vm in $dv5Cluster) {
  $jobs += Start-Job -ScriptBlock $jobScript -ArgumentList $vm,$Rg,$Sub,@($initScript)
}
foreach ($vm in $clients) {
  $jobs += Start-Job -ScriptBlock $jobScript -ArgumentList $vm,$Rg,$Sub,@($updateScript)
}

Write-Host ">>> $($jobs.Count) jobs running, waiting (dnf update is slow)..."
$jobs | Wait-Job | Out-Null

Write-Host "`n==================== Per-node result (tail) ===================="
foreach ($j in $jobs) {
  $res = Receive-Job $j
  $tail = ($res -split "`n" | Select-Object -Last 14) -join "`n"
  Write-Host "JOB $($j.Id):"
  Write-Host $tail
  Write-Host "------------------------------------------------------------"
}
$jobs | Remove-Job
Write-Host ">>> Init orchestration done"
