# Quick Start Guide - ES DSv5 vs DSv6 Deployment

## 5-Minute Setup

### Prerequisites ✓
- Azure CLI installed: `az --version`
- Azure account with sufficient permissions
- Bash shell access
- Existing VNet and Subnet in Azure

### Step 1: Navigate to Deployment Directory (30 seconds)
```bash
cd c:\Users\leizha\es-deployment

# Make scripts executable (Windows users may skip)
chmod +x deploy.sh scripts/verify/*.sh
```

### Step 2: Login to Azure (1 minute)
```bash
# Authenticate
az login

# Set default subscription
az account set --subscription "166157a8-9ce9-400b-91c7-1d42482b83d6"

# Verify
az account show
```

### Step 3: Deploy Everything (2 minutes)
```bash
# Run deployment
bash deploy.sh

# This will:
# ✓ Verify prerequisites (resource group, VNet, subnet)
# ✓ Deploy 8 VMs (3x DSv5 + 3x DSv6 + 2x Client)
# ✓ Attach 8 data disks
# ✓ Configure networking
# ✓ Trigger initialization scripts
# 
# Total deployment time: 10-15 minutes (runs in background)
```

### Step 4: Wait and Verify (10-15 minutes)
```bash
# Wait for VMs to initialize (watch Azure portal or check via CLI)
# Monitor: az deployment group show -g es-rg -n es-deployment-*

# After 10 minutes, run health check
bash scripts/verify/health-check.sh

# Expected output:
# ✓ All 8 VMs retrieved
# ✓ DSv5 cluster status: green, nodes: 3
# ✓ DSv6 cluster status: green, nodes: 3
```

### Done! 🎉
Your Elasticsearch clusters are ready for benchmarking.

---

## Common Next Steps

### Option A: SSH into a Node
```bash
# Get IP from health-check output, e.g., 10.0.0.4
ssh azureuser@10.0.0.4

# Once connected
curl http://localhost:9200/_cluster/health?pretty
df -h /esdata
```

### Option B: Run Rally Benchmark
```bash
# SSH into client VM (e.g., 10.0.0.10)
ssh azureuser@10.0.0.10

# Activate Rally
source /opt/rally-env/bin/activate

# Quick test against DSv5
rally race --track=default --target-hosts=10.0.0.4:9200 --test-mode

# Full benchmark
rally race --track=default --target-hosts=10.0.0.4:9200,10.0.0.5:9200,10.0.0.6:9200
```

### Option C: Create Test Data
```bash
# From any node or client
# Create a test index
curl -X PUT "http://10.0.0.4:9200/test-index" -H 'Content-Type: application/json' -d'
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  }
}'

# Insert sample documents
curl -X POST "http://10.0.0.4:9200/test-index/_doc/1" -H 'Content-Type: application/json' -d'
{"message":"test message 1","timestamp":"2026-06-17T00:00:00Z"}'

# Verify
curl "http://10.0.0.4:9200/test-index/_search"
```

---

## Architecture at a Glance

```
┌─────────────────────────────────────────┐
│         Azure VNet: es-vnet             │
│           Subnet: vm-subnet             │
├─────────────────────────────────────────┤
│                                         │
│  Zone 1          Zone 2          Zone 3 │
│  ───────         ───────         ───── │
│  DSv5-01         DSv5-02         DSv5-03│
│  (10.0.0.4)      (10.0.0.5)      (10.0.0.6)
│  ↓               ↓               ↓      │
│  ┌──────────────────────────────────┐  │
│  │   es-dsv5-cluster (green)        │  │
│  │   3 nodes, 3 shards, 1 replica   │  │
│  │   6.8.1 on CentOS 7.9            │  │
│  └──────────────────────────────────┘  │
│                                         │
│  DSv6-01         DSv6-02         DSv6-03│
│  (10.0.0.7)      (10.0.0.8)      (10.0.0.9)
│  ↓               ↓               ↓      │
│  ┌──────────────────────────────────┐  │
│  │   es-dsv6-cluster (green)        │  │
│  │   3 nodes, 3 shards, 1 replica   │  │
│  │   6.8.1 on Rocky 9.6             │  │
│  └──────────────────────────────────┘  │
│                                         │
│                    Client-01    Client-02
│                    (10.0.0.10)  (10.0.0.11)
│                    Rally / d32sv6      │
│                                         │
└─────────────────────────────────────────┘
```

---

## Key Endpoints

### DSv5 Cluster
- **Cluster Health**: http://10.0.0.4:9200/_cluster/health
- **Nodes**: http://10.0.0.4:9200/_nodes
- **Shards**: http://10.0.0.4:9200/_cat/shards?v

### DSv6 Cluster
- **Cluster Health**: http://10.0.0.7:9200/_cluster/health
- **Nodes**: http://10.0.0.7:9200/_nodes
- **Shards**: http://10.0.0.7:9200/_cat/shards?v

### Rally (from client VM)
```bash
source /opt/rally-env/bin/activate
rally --version
rally info  # See available tracks
```

---

## Troubleshooting

### "Cluster not ready" or "yellow" status?
1. Wait another 2-3 minutes for full initialization
2. Check node status: `curl http://10.0.0.4:9200/_nodes?pretty | jq '.nodes | length'`
3. Check logs: `ssh azureuser@10.0.0.4 && sudo journalctl -u elasticsearch -n 50`

### Can't SSH to VMs?
1. Verify security group allows SSH (port 22)
2. Check Azure portal → VMs → Networking → Inbound Rules
3. Ensure subnet has NSG rules: `az network nsg rule list -g es-rg --nsg-name <nsg-name>`

### High memory usage on nodes?
1. Check JVM settings: `curl http://10.0.0.4:9200/_nodes/jvm?pretty`
2. Adjust if needed (edit `/esdata/elasticsearch-6.8.1/config/jvm.options`, restart)

### Benchmark not running?
1. Activate Rally: `source /opt/rally-env/bin/activate`
2. Verify connectivity: `curl http://10.0.0.4:9200`
3. Run with verbose: `rally race --track=default --target-hosts=10.0.0.4:9200 --verbose`

---

## Important Notes

⚠️ **Before You Benchmark**:
- [ ] All 3 nodes in each cluster show "green" status
- [ ] Shards are properly distributed across zones
- [ ] Disk I/O is under baseline (check `iostat`)
- [ ] Network latency between nodes is < 5ms

⚠️ **Cost Awareness**:
- VMs cost ~$3,500-4,500/month
- Consider stopping when not in use: `az vm deallocate -g es-rg -n dsv5esmasterdata01`
- Full cleanup: `az group delete -g es-rg`

---

## File Reference

| File | Purpose |
|------|---------|
| `main.bicep` | Main IaC template (VM, disk, network) |
| `deploy.sh` | One-command deployment script |
| `parameters.json` | Deployment parameters |
| `scripts/cloud-init-*.sh` | VM initialization scripts |
| `scripts/es-config/*.yml` | Elasticsearch configurations |
| `scripts/verify/health-check.sh` | Cluster validation script |
| `README.md` | Comprehensive documentation |
| `INVENTORY.md` | Detailed resource inventory |

---

## Getting Help

| Issue | Solution |
|-------|----------|
| Deployment fails | Check Azure CLI version and permissions |
| VMs not starting | Verify subscription quota (`az vm list-usage --location eastus`) |
| ES not running | SSH and check: `sudo systemctl status elasticsearch` |
| Rally won't install | Verify Python 3.9+ installed: `python3.9 --version` |

---

**Ready to benchmark?** Proceed to `README.md` for detailed performance testing guide.

---

**Deployment Created**: June 2026  
**Elasticsearch Version**: 6.8.1  
**Azure Region**: East US  
