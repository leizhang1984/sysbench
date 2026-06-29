$RG = "es-rg"
$nodes = @("dsv6esmasterdata02","dsv6esmasterdata03")
foreach ($n in $nodes) {
  Write-Host "======================== $n ========================"
  az vm run-command invoke -g $RG -n $n --command-id RunShellScript `
    --scripts "journalctl -u elasticsearch --no-pager | tail -n 40; echo '--- ES LOG ---'; tail -n 40 /var/log/elasticsearch/*.log 2>/dev/null" `
    --query "value[0].message" -o tsv
  Write-Host ""
}
