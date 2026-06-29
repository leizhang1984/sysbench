# =============================================================================
# Fix DSv6: clientvm02 has no internet to TiUP CDN. Copy clientvm01's ready
# ~/.tiup over the private network, then deploy tidb-dsv6 from clientvm02.
# =============================================================================
param(
  [string]$Sub = "166157a8-9ce9-400b-91c7-1d42482b83d6",
  [string]$Rg  = "tidb-rg"
)
$ErrorActionPreference = "Continue"
$tmpDir = "C:\Users\leizha\tidb-bench\scripts\_tmp"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

# 1) get clientvm01 root pubkey
Write-Host ">>> fetch clientvm01 pubkey"
$pubMsg = az vm run-command invoke -g $Rg -n clientvm01 --subscription $Sub `
  --command-id RunShellScript --scripts "cat /root/.ssh/id_rsa.pub" `
  --query "value[0].message" -o tsv 2>&1
$pub = ($pubMsg -split "`n" | Where-Object { $_ -match "^ssh-rsa" } | Select-Object -First 1).Trim()
if (-not $pub.StartsWith("ssh-rsa")) { Write-Host "!!! no pubkey"; exit 1 }
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pub))

# 2) add clientvm01 pubkey to clientvm02 azureadmin authorized_keys
Write-Host ">>> authorize clientvm01 -> clientvm02"
$addScript = @"
#!/bin/bash
set -e
mkdir -p /home/azureadmin/.ssh && chmod 700 /home/azureadmin/.ssh
PUB=`$(echo '$b64' | base64 -d)
touch /home/azureadmin/.ssh/authorized_keys
grep -qF "`$PUB" /home/azureadmin/.ssh/authorized_keys || echo "`$PUB" >> /home/azureadmin/.ssh/authorized_keys
chmod 600 /home/azureadmin/.ssh/authorized_keys
chown -R azureadmin:azureadmin /home/azureadmin/.ssh
command -v restorecon >/dev/null 2>&1 && restorecon -R /home/azureadmin/.ssh || true
echo OK_AUTH
"@
$p = Join-Path $tmpDir "auth-c1-to-c2.sh"
[IO.File]::WriteAllText($p, ($addScript -replace "`r`n","`n"))
$r = az vm run-command invoke -g $Rg -n clientvm02 --subscription $Sub `
  --command-id RunShellScript --scripts "@$p" --query "value[0].message" -o tsv 2>&1
Write-Host (($r -split "`n" | Where-Object { $_ -match "OK_AUTH|denied|rror" }) -join " ")

# 3) on clientvm01: tar ~/.tiup and scp to clientvm02:/tmp
Write-Host ">>> tar + scp ~/.tiup from clientvm01 to clientvm02 (private net)"
$xfer = @"
#!/bin/bash
set -e
export HOME=/root
tar czf /tmp/tiup.tgz -C /root .tiup
ls -lh /tmp/tiup.tgz
scp -o StrictHostKeyChecking=no -o BatchMode=yes -i /root/.ssh/id_rsa /tmp/tiup.tgz azureadmin@10.142.0.52:/tmp/tiup.tgz
echo OK_XFER
"@
$p2 = Join-Path $tmpDir "xfer-tiup.sh"
[IO.File]::WriteAllText($p2, ($xfer -replace "`r`n","`n"))
$r2 = az vm run-command invoke -g $Rg -n clientvm01 --subscription $Sub `
  --command-id RunShellScript --scripts "@$p2" --query "value[0].message" -o tsv 2>&1
Write-Host (($r2 -split "`n" | Select-Object -Last 6) -join "`n")

# 4) on clientvm02: extract to /root/.tiup
Write-Host ">>> extract on clientvm02"
$ext = @"
#!/bin/bash
set -e
export HOME=/root
rm -rf /root/.tiup
tar xzf /tmp/tiup.tgz -C /root
chown -R root:root /root/.tiup
/root/.tiup/bin/tiup --version 2>&1 | head -1
/root/.tiup/bin/tiup cluster list 2>&1 | head -3 || true
echo OK_EXTRACT
"@
$p3 = Join-Path $tmpDir "extract-tiup.sh"
[IO.File]::WriteAllText($p3, ($ext -replace "`r`n","`n"))
$r3 = az vm run-command invoke -g $Rg -n clientvm02 --subscription $Sub `
  --command-id RunShellScript --scripts "@$p3" --query "value[0].message" -o tsv 2>&1
Write-Host (($r3 -split "`n" | Select-Object -Last 8) -join "`n")
Write-Host ">>> tiup transfer done"
