# Elasticsearch DSv5 vs DSv6 Benchmark Deployment

Complete Infrastructure-as-Code (IaC) solution for deploying Elasticsearch 6.8.1 on Azure with DSv5 and DSv6 instances for performance comparison across three availability zones.

## Overview

This deployment creates:
- **DSv5 Cluster**: 3 nodes (Standard_D8s_v5) with CentOS 7.9
- **DSv6 Cluster**: 3 nodes (Standard_D8s_v6) with Rocky 9.6  
- **Client VMs**: 2 nodes (Standard_D32s_v6) for Rally benchmarking
- **Storage**: Premium SSD v2 disks (200GB, 3000 IOPS, 125 Mbps) for each node
- **Network**: Azure VNet with subnet-level security groups

Total: **8 virtual machines** distributed across 3 availability zones

## File Structure

```
es-deployment/
├── main.bicep                          # Main Bicep IaC template
├── deploy.sh                           # Deployment execution script
├── scripts/
│   ├── cloud-init-centos7.sh          # CentOS 7.9 initialization
│   ├── cloud-init-rocky9.sh           # Rocky 9.6 initialization + upgrade
│   ├── cloud-init-client.sh           # Client VM (Rally installation)
│   ├── es-config/
│   │   ├── elasticsearch-dsv5.yml     # DSv5 cluster config template
│   │   └── elasticsearch-dsv6.yml     # DSv6 cluster config template
│   └── verify/
│       ├── health-check.sh            # Cluster health verification
│       └── post-deploy.sh             # Post-deployment configuration
└── README.md                           # This file
```

## Prerequisites

### Azure Setup
1. **Subscription**: 166157a8-9ce9-400b-91c7-1d42482b83d6
2. **Resource Group**: es-rg
3. **VNet**: es-vnet
4. **Subnet**: vm-subnet (with security group configured for ports 22, 9200, 9300)

### Tools Required
- **Azure CLI**: Version 2.40+
  ```bash
  # Install: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
  az --version
  ```
- **Bash**: For script execution
- **curl**: For cluster health checks
- **jq** (optional): For JSON parsing

### Azure Quotas
Ensure your subscription has sufficient quota for:
- vCPU: 192 (8×8 + 8×8 + 2×32)
- Data Disks: 8
- Network Interfaces: 8

Check quotas:
```bash
az vm list-usage --location eastus --query "[?name.value=='cores']"
```

## Deployment Steps

### Step 1: Prepare Environment

```bash
# Navigate to deployment directory
cd es-deployment/

# Make scripts executable
chmod +x deploy.sh
chmod +x scripts/verify/*.sh
chmod +x scripts/cloud-init-*.sh

# Login to Azure
az login

# Set default subscription
az account set --subscription "166157a8-9ce9-400b-91c7-1d42482b83d6"

# Verify prerequisites
az group show --name "es-rg"
az network vnet show --resource-group "es-rg" --name "es-vnet"
az network vnet subnet show --resource-group "es-rg" --vnet-name "es-vnet" --name "vm-subnet"
```

### Step 2: Deploy Infrastructure (10-15 minutes)

```bash
# Execute deployment
bash deploy.sh

# This will:
# 1. Verify resource group, VNet, and subnet
# 2. Deploy all 8 VMs with data disks
# 3. Attach custom scripts for initialization
# 4. Return deployment summary
```

### Step 3: Wait for Initialization (5-10 minutes)

The cloud-init scripts run automatically on each VM:
- Format and mount 200GB Premium SSD v2 disk
- Update OS packages
- Install Java 8
- Download and extract Elasticsearch 6.8.1
- Configure systemd service
- Start Elasticsearch

Monitor Azure portal or:
```bash
# Check deployment status
az deployment group show --resource-group "es-rg" --name "es-deployment-*"
```

### Step 4: Verify Cluster Health (5 minutes after start)

```bash
# Run health check script
bash scripts/verify/health-check.sh

# This will:
# 1. Retrieve VM IP addresses from Azure
# 2. Check cluster health status
# 3. Verify node zone attributes
# 4. Print cluster statistics
```

Expected output:
```
DSv5 Cluster:
    Status: green
    Nodes: 3
    Active Shards: 9

DSv6 Cluster:
    Status: green
    Nodes: 3
    Active Shards: 9
```

### Step 5: Manual Configuration (Optional)

If you need to apply custom Elasticsearch configuration:

```bash
# SSH into a DSv5 node
ssh azureuser@<dsv5-node-ip>

# Update configuration
sudo cp /tmp/elasticsearch.yml /esdata/elasticsearch-6.8.1/config/elasticsearch.yml
sudo chown elasticsearch:elasticsearch /esdata/elasticsearch-6.8.1/config/elasticsearch.yml
sudo systemctl restart elasticsearch

# Check status
sudo systemctl status elasticsearch
curl http://localhost:9200/_cluster/health?pretty
```

## Cluster Architecture

### Network Layout
```
VNet: es-vnet (10.0.0.0/16)
  └─ Subnet: vm-subnet (10.0.0.0/24)
     ├─ DSv5 Cluster (AZ1, AZ2, AZ3)
     │  ├─ dsv5esmasterdata01 (10.0.0.4, AZ1, CentOS 7.9)
     │  ├─ dsv5esmasterdata02 (10.0.0.5, AZ2, CentOS 7.9)
     │  └─ dsv5esmasterdata03 (10.0.0.6, AZ3, CentOS 7.9)
     │
     ├─ DSv6 Cluster (AZ1, AZ2, AZ3)
     │  ├─ dsv6esmasterdata01 (10.0.0.7, AZ1, Rocky 9.6)
     │  ├─ dsv6esmasterdata02 (10.0.0.8, AZ2, Rocky 9.6)
     │  └─ dsv6esmasterdata03 (10.0.0.9, AZ3, Rocky 9.6)
     │
     └─ Client VMs (Rocky 9.6, Rally)
        ├─ clientvm01 (AZ2)
        └─ clientvm02 (AZ3)
```

### Elasticsearch Configuration

#### Cluster Settings
- **Version**: 6.8.1
- **Master Eligible**: Yes (all nodes)
- **Data Nodes**: Yes (all nodes)
- **Index Shards**: 3 primary + 1 replica
- **Minimum Master Nodes**: 2 (prevents split-brain)
- **Availability Zone Awareness**: Enabled

#### Hardware
- **CPU**: 8 vCPU per node
- **Memory**: 32GB per node (JVM Heap: 8GB)
- **Storage**: 200GB Premium SSD v2 per node
- **IOPS**: 3000 per disk
- **Throughput**: 125 Mbps per disk

## Common Operations

### Check Cluster Status
```bash
# From any cluster node
curl http://localhost:9200/_cluster/health?pretty

# Check all nodes
curl http://localhost:9200/_nodes?pretty | jq '.nodes[] | {name:.name, version:.version, zone:.attributes.zone}'

# Check shard distribution
curl http://localhost:9200/_cat/shards?v
```

### View Logs
```bash
# SSH into node
ssh azureuser@<node-ip>

# Check Elasticsearch logs
sudo journalctl -u elasticsearch -f

# Or read from file
tail -f /var/log/elasticsearch/es-dsv5-cluster.log
```

### Restart Cluster
```bash
# Stop Elasticsearch
sudo systemctl stop elasticsearch

# Verify stopped
curl http://localhost:9200  # Should fail

# Start Elasticsearch
sudo systemctl start elasticsearch

# Verify started
curl http://localhost:9200/_cluster/health
```

### Monitor Disk Usage
```bash
# Check mounted disk
df -h /esdata

# Check disk I/O
iostat -x /dev/sdc 1 10

# Check ES data directory size
du -sh /esdata/data
```

## Benchmarking with Rally

### SSH into Client VM
```bash
ssh azureuser@<client-vm-ip>

# Activate Rally environment
source /opt/rally-env/bin/activate

# Verify Rally is working
rally --version
```

### Run Benchmarks

#### Against DSv5 Cluster
```bash
rally race \
  --track=default \
  --target-hosts=10.0.0.4:9200,10.0.0.5:9200,10.0.0.6:9200 \
  --test-mode  # For quick validation

# Or use helper script
~/run-rally.sh dsv5-cluster default
```

#### Against DSv6 Cluster
```bash
rally race \
  --track=default \
  --target-hosts=10.0.0.7:9200,10.0.0.8:9200,10.0.0.9:9200

# Or use helper script
~/run-rally.sh dsv6-cluster default
```

### Custom Rally Parameters
```bash
rally race \
  --track=default \
  --target-hosts=10.0.0.4:9200 \
  --challenge=append-no-conflicts \
  --report-file=report.json \
  --show-in-browser
```

## Troubleshooting

### Nodes Not Joining Cluster
1. **Check Discovery Settings**
   ```bash
   sudo grep discovery.zen.ping /esdata/elasticsearch-6.8.1/config/elasticsearch.yml
   ```

2. **Check Network Connectivity**
   ```bash
   ssh azureuser@<node1-ip>
   telnet <node2-ip> 9300
   ```

3. **Review Logs**
   ```bash
   sudo journalctl -u elasticsearch -n 100 | grep -i discovery
   ```

### High Memory Usage
1. **Check JVM Heap**
   ```bash
   ps aux | grep elasticsearch | grep -o "\-Xm[sx][^ ]*"
   ```

2. **Check Memory Actual Usage**
   ```bash
   curl http://localhost:9200/_nodes?human&pretty | grep jvm.mem
   ```

3. **Adjust if needed**
   - Edit: `/esdata/elasticsearch-6.8.1/config/jvm.options`
   - Restart: `sudo systemctl restart elasticsearch`

### Disk Space Issues
1. **Check Disk Usage**
   ```bash
   df -h /esdata
   du -sh /esdata/data
   ```

2. **Delete Old Indices**
   ```bash
   curl -X DELETE http://localhost:9200/index-name-*
   ```

### SSH Connection Issues
1. **Verify Security Group Rules**
   ```bash
   az network nsg rule list --resource-group "es-rg" --nsg-name "<nsg-name>" --query "[?destinationPortRange=='22']"
   ```

2. **Check SSH Key**
   ```bash
   ssh -v -i ~/.ssh/id_rsa azureuser@<vm-ip>
   ```

3. **Get Public IP for Debugging** (if needed)
   ```bash
   az vm list-ip-addresses --resource-group "es-rg" --output table
   ```

## Cleanup

To delete all resources:

```bash
# Delete resource group (all resources within will be deleted)
az group delete --name "es-rg" --yes --no-wait

# Verify deletion
az group wait --deleted --name "es-rg"
```

**WARNING**: This will delete all VMs, disks, and data. Make sure to backup any important data first.

## Performance Notes

### Expected Performance (Baseline)
- **DSv5 CPUs**: Intel Xeon (5th gen, Cascade Lake)
- **DSv6 CPUs**: Intel Xeon (6th gen, Ice Lake)
- **Network Latency** (same AZ): < 1ms
- **Cross-AZ Latency**: 1-5ms
- **Disk I/O**: ~3000 IOPS per disk

### Key Metrics to Monitor
1. **Cluster Health**: Status (green/yellow/red)
2. **Index Performance**: QPS, latency (P50/P95/P99)
3. **GC Pauses**: Young/Old generation collections
4. **Disk I/O**: Read/write throughput and queue depth
5. **Network**: Intra-cluster traffic and packet loss

## Cost Optimization Tips

1. **Stop VMs when not in use**
   ```bash
   az vm deallocate --resource-group "es-rg" --name "dsv5esmasterdata01"
   ```

2. **Monitor actual resource usage** and adjust VM sizes if needed

3. **Use Reserved Instances** for long-running deployments

4. **Enable auto-shutdown** in Azure portal

## Support & Documentation

- **Elasticsearch 6.8.1 Docs**: https://www.elastic.co/guide/en/elasticsearch/reference/6.8/index.html
- **Azure VM Types**: https://learn.microsoft.com/en-us/azure/virtual-machines/sizes
- **Azure CLI Reference**: https://learn.microsoft.com/en-us/cli/azure/
- **Elasticsearch Rally**: https://esrally.readthedocs.io/

## License

This deployment template is provided as-is for benchmarking purposes.

---

**Last Updated**: June 2026
**Elasticsearch Version**: 6.8.1
**Azure Region**: East US
**Supported AZ Count**: 3
