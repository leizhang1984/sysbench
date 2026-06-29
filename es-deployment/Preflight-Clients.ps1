$RG = "es-rg"
$SCRIPT = "C:\Users\leizha\es-deployment\scripts\preflight-client.sh"

Write-Host "======================== clientvm01 -> es-dsv5-cluster ========================"
az vm run-command invoke -g $RG -n clientvm01 --command-id RunShellScript `
  --scripts "@$SCRIPT" --parameters "10.122.0.4" "10.122.0.5" "10.122.0.6" `
  --query "value[0].message" -o tsv
Write-Host ""

Write-Host "======================== clientvm02 -> es-dsv6-cluster ========================"
az vm run-command invoke -g $RG -n clientvm02 --command-id RunShellScript `
  --scripts "@$SCRIPT" --parameters "10.122.0.7" "10.122.0.8" "10.122.0.9" `
  --query "value[0].message" -o tsv
