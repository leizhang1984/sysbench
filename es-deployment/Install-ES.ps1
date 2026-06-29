$RG = "es-rg"
$SCRIPT = "C:\Users\leizha\es-deployment\scripts\install-es.sh"
$ErrorActionPreference = "Continue"

# ES node definitions: name, cluster, seeds, zone(attr), pkg manager
$nodes = @(
  @{name="dsv5esmasterdata01"; cluster="es-dsv5-cluster"; seeds="10.122.0.4,10.122.0.5,10.122.0.6"; zone="zone2"; pkg="yum"},
  @{name="dsv5esmasterdata02"; cluster="es-dsv5-cluster"; seeds="10.122.0.4,10.122.0.5,10.122.0.6"; zone="zone3"; pkg="yum"},
  @{name="dsv5esmasterdata03"; cluster="es-dsv5-cluster"; seeds="10.122.0.4,10.122.0.5,10.122.0.6"; zone="zone1"; pkg="yum"},
  @{name="dsv6esmasterdata01"; cluster="es-dsv6-cluster"; seeds="10.122.0.7,10.122.0.8,10.122.0.9"; zone="zone2"; pkg="dnf"},
  @{name="dsv6esmasterdata02"; cluster="es-dsv6-cluster"; seeds="10.122.0.7,10.122.0.8,10.122.0.9"; zone="zone3"; pkg="dnf"},
  @{name="dsv6esmasterdata03"; cluster="es-dsv6-cluster"; seeds="10.122.0.7,10.122.0.8,10.122.0.9"; zone="zone1"; pkg="dnf"}
)

$HEAP = "16g"

foreach ($n in $nodes) {
  Write-Host "============================================================"
  Write-Host "Installing ES on $($n.name)  [$($n.cluster) / $($n.zone) / $($n.pkg)]"
  Write-Host "============================================================"
  az vm run-command invoke -g $RG -n $n.name --command-id RunShellScript `
    --scripts "@$SCRIPT" `
    --parameters $n.cluster $n.seeds $n.zone $n.pkg $HEAP `
    --query "value[0].message" -o tsv
  Write-Host ""
}

Write-Host "All ES install commands dispatched."
