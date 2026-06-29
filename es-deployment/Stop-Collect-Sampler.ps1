$RG = "es-rg"
$SCRIPT = "C:\Users\leizha\es-deployment\scripts\stop-collect-sampler.sh"
$dir = "C:\Users\leizha\es-bench\report\data"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$nodes = @(
  "dsv5esmasterdata01","dsv5esmasterdata02","dsv5esmasterdata03",
  "dsv6esmasterdata01","dsv6esmasterdata02","dsv6esmasterdata03"
)
foreach ($n in $nodes) {
  Write-Host "======================== $n ========================"
  az vm run-command invoke -g $RG -n $n --command-id RunShellScript `
    --scripts "@$SCRIPT" --query "value[0].message" -o tsv |
    Out-File -Encoding ascii "$dir\host-$n-b64.txt"
  Write-Host "saved host-$n-b64.txt size:" (Get-Item "$dir\host-$n-b64.txt").Length
}
