param(
  [string]$Sub = "166157a8-9ce9-400b-91c7-1d42482b83d6",
  [string]$Rg = "tidb-rg"
)
$nodes = @("dv6tidb01","dv6tidb02","dv6tidb03","dv6tikv01","dv6tikv02","dv6tikv03")
$pubMsg = az vm run-command invoke -g $Rg -n clientvm01 --subscription $Sub --command-id RunShellScript --scripts "cat /root/.ssh/id_rsa.pub" --query "value[0].message" -o tsv 2>&1
$pub = ($pubMsg -split "`n" | Where-Object { $_ -match "^ssh-rsa" } | Select-Object -First 1).Trim()
if (-not $pub.StartsWith("ssh-rsa")) { throw "cannot get pubkey from clientvm01" }
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pub))
$scriptPath = "C:\Users\leizha\tidb-bench\scripts\_tmp\add-c1-key-dv6.sh"
$sh = @"
#!/bin/bash
set -e
PUB=`$(echo '$b64' | base64 -d)
mkdir -p /home/azureadmin/.ssh
chmod 700 /home/azureadmin/.ssh
touch /home/azureadmin/.ssh/authorized_keys
grep -qF "`$PUB" /home/azureadmin/.ssh/authorized_keys || echo "`$PUB" >> /home/azureadmin/.ssh/authorized_keys
chmod 600 /home/azureadmin/.ssh/authorized_keys
chown -R azureadmin:azureadmin /home/azureadmin/.ssh
command -v restorecon >/dev/null 2>&1 && restorecon -R /home/azureadmin/.ssh || true
echo OK
"@
[IO.File]::WriteAllText($scriptPath, ($sh -replace "`r`n","`n"))
foreach ($n in $nodes) {
  $r = az vm run-command invoke -g $Rg -n $n --subscription $Sub --command-id RunShellScript --scripts "@$scriptPath" --query "value[0].message" -o tsv 2>&1
  $ok = (($r -split "`n" | Where-Object {$_ -match "OK|denied|rror"} | Select-Object -First 1))
  Write-Host "[$n] $ok"
}
