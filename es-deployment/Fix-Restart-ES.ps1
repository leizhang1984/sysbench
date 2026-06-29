$RG = "es-rg"
$nodes = @(
  "dsv5esmasterdata01","dsv5esmasterdata02","dsv5esmasterdata03",
  "dsv6esmasterdata01","dsv6esmasterdata02","dsv6esmasterdata03"
)
$fix = @'
# remove invalid setting (not valid in ES 6.8.1) and restart
sed -i '/bootstrap.ignore_system_bootstrap_checks/d' /etc/elasticsearch/elasticsearch.yml
systemctl restart elasticsearch
sleep 12
systemctl is-active elasticsearch && echo "ACTIVE" || echo "FAILED"
curl -s http://localhost:9200/_cat/health 2>/dev/null || echo "(health not ready yet)"
'@
foreach ($n in $nodes) {
  Write-Host "======================== $n ========================"
  az vm run-command invoke -g $RG -n $n --command-id RunShellScript `
    --scripts $fix --query "value[0].message" -o tsv
  Write-Host ""
}
