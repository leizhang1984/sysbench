# Deployment Package Summary

## Overview

Complete Infrastructure-as-Code solution for deploying Elasticsearch 6.8.1 across Azure DSv5 and DSv6 VM generations for performance benchmarking.

**Generated**: June 2026  
**Location**: C:\Users\leizha\es-deployment  
**Status**: ✅ Ready for deployment

---

## File Structure

```
C:\Users\leizha\es-deployment/
│
├── main.bicep                          ← Main IaC template (Bicep)
├── deploy.sh                           ← One-command deployment script
├── parameters.json                     ← Deployment parameters
│
├── scripts/
│   ├── cloud-init-centos7.sh          ← CentOS 7.9 initialization
│   ├── cloud-init-rocky9.sh           ← Rocky 9.6 initialization
│   ├── cloud-init-client.sh           ← Client VM initialization (Rally)
│   │
│   ├── es-config/
│   │   ├── elasticsearch-dsv5.yml     ← DSv5 cluster configuration
│   │   └── elasticsearch-dsv6.yml     ← DSv6 cluster configuration
│   │
│   └── verify/
│       ├── health-check.sh            ← Cluster health verification
│       └── post-deploy.sh             ← Post-deployment configuration
│
├── README.md                           ← Full documentation
├── QUICKSTART.md                       ← 5-minute quick start
├── INVENTORY.md                        ← Detailed resource inventory
└── DEPLOY-SUMMARY.md                   ← This file

Total: 14 files
```

---

## What Gets Deployed

### Infrastructure
- **8 Virtual Machines**
  - 3x Standard_D8s_v5 (DSv5, CentOS 7.9)
  - 3x Standard_D8s_v6 (DSv6, Rocky 9.6)
  - 2x Standard_D32s_v6 (Client, Rocky 9.6)

- **8 Data Disks**
  - Premium SSD v2
  - 200 GB each
  - 3000 IOPS, 125 Mbps throughput
  - Mounted to /esdata via UUID

- **Network**
  - Existing VNet: es-vnet
  - Existing Subnet: vm-subnet
  - All VMs in same subnet, 3 availability zones

### Software
- **Elasticsearch 6.8.1**
  - DSv5 cluster: es-dsv5-cluster
  - DSv6 cluster: es-dsv6-cluster
  - Master + Data nodes on all
  - 3 shards, 1 replica per index
  - AZ-aware shard allocation

- **Rally**
  - Installed on 2 client VMs
  - Python virtual environment: /opt/rally-env
  - Ready for benchmarking

---

## Quick Start (5 minutes)

```bash
# 1. Navigate to deployment directory
cd C:\Users\leizha\es-deployment

# 2. Login to Azure
az login
az account set --subscription "166157a8-9ce9-400b-91c7-1d42482b83d6"

# 3. Deploy
bash deploy.sh

# 4. Wait 10-15 minutes for VMs to initialize

# 5. Verify
bash scripts/verify/health-check.sh
```

---

## File Descriptions

### Core Deployment Files

#### `main.bicep` (400+ lines)
- **Purpose**: Infrastructure template using Bicep language
- **Defines**:
  - 8 VMs across 3 AZs with zones specified
  - 8 NICs with subnet reference (no NIC-level NSG)
  - 8 data disks (Premium SSD v2)
  - VM extensions for cloud-init scripts
  - Dynamic property references (private IPs)
  - Parameterized for reusability
- **Key Features**:
  - Zone-aware VM placement
  - Disk attachment via managed disks
  - Extension-based initialization
  - Simplified network (relies on existing subnet NSG)

#### `parameters.json` (40+ lines)
- **Purpose**: Deployment parameters reference
- **Contains**: All input parameters for Bicep template
- **Usage**: Can be extended with additional parameter sets for different environments

#### `deploy.sh` (80+ lines)
- **Purpose**: One-command deployment automation
- **Performs**:
  1. Prerequisites check (CLI, resource group, VNet, subnet)
  2. Subscription verification
  3. Bicep template deployment via `az deployment group create`
  4. Deployment summary and next steps
- **Usage**: `bash deploy.sh`

### Initialization Scripts

#### `cloud-init-centos7.sh` (200+ lines)
- **Target**: DSv5 VMs running CentOS 7.9
- **Executes on VM startup via Azure VM Extension**
- **Tasks**:
  1. Wait for /dev/sdc to appear (max 60s)
  2. Format disk with XFS
  3. Get UUID and add to /etc/fstab
  4. Mount /esdata
  5. Update yum packages
  6. Install Java 8 (required for ES 6.8.1)
  7. Download and extract ES 6.8.1
  8. Create elasticsearch user
  9. Configure system limits (file descriptors, memory)
  10. Create systemd service file
  11. Start ES, verify with curl

#### `cloud-init-rocky9.sh` (220+ lines)
- **Target**: DSv6 VMs and Client VMs using Rocky 9.6
- **Difference from CentOS**:
  - Uses `dnf` instead of `yum`
  - Upgrades to latest Rocky 9 version
  - Everything else similar to CentOS version

#### `cloud-init-client.sh` (120+ lines)
- **Target**: 2 Client VMs (clientvm01, clientvm02)
- **Tasks**:
  1. Upgrade Rocky to latest
  2. Install Python 3.9 and pip
  3. Create Python virtual environment at /opt/rally-env
  4. Install esrally via pip
  5. Create Rally configuration
  6. Create helper script ~/run-rally.sh
  7. Verify installation

### Elasticsearch Configuration

#### `elasticsearch-dsv5.yml`
- **Target**: DSv5 cluster
- **Cluster Name**: es-dsv5-cluster
- **Settings**:
  - Discovery nodes: 10.0.0.4, 10.0.0.5, 10.0.0.6
  - Master/data/ingest roles
  - JVM heap: 8GB
  - AZ awareness: zones 1, 2, 3
  - Index defaults: 3 shards, 1 replica
  - Minimum master nodes: 2

#### `elasticsearch-dsv6.yml`
- **Target**: DSv6 cluster
- **Cluster Name**: es-dsv6-cluster
- **Settings**: Same as DSv5 except:
  - Discovery nodes: 10.0.0.7, 10.0.0.8, 10.0.0.9

### Verification & Admin Scripts

#### `health-check.sh` (150+ lines)
- **Purpose**: Post-deployment cluster validation
- **Checks**:
  1. Retrieves VM NICs from Azure and extracts private IPs
  2. Queries DSv5 cluster health (green status, 3 nodes)
  3. Queries DSv6 cluster health
  4. Verifies node zone attributes
  5. Documents next steps
- **Usage**: `bash scripts/verify/health-check.sh`

#### `post-deploy.sh` (150+ lines)
- **Purpose**: Node configuration updates after deployment
- **Functions**:
  - Configure node-specific settings (zone attributes)
  - Generate per-node elasticsearch.yml
  - Initialize cluster templates
  - Create index templates with AZ awareness
- **Usage**: `bash scripts/verify/post-deploy.sh` (optional, for manual tweaks)

### Documentation

#### `README.md` (600+ lines)
- **Comprehensive deployment guide**
- **Sections**:
  - Overview and architecture
  - Prerequisites and setup
  - Step-by-step deployment
  - Common operations (status, logs, restart)
  - Benchmarking with Rally
  - Troubleshooting guide
  - Cleanup instructions
  - Cost optimization
  - Performance notes

#### `QUICKSTART.md` (250+ lines)
- **5-minute quick start guide**
- **For users who want to**:
  - Get running fast
  - See visual architecture
  - Quick troubleshooting
  - Common endpoints

#### `INVENTORY.md` (400+ lines)
- **Detailed resource inventory**
- **Lists all**:
  - VMs (compute specs)
  - Network interfaces
  - Storage (disk configs)
  - Elasticsearch cluster details
  - Expected IP assignments
  - Access credentials
  - Deployment timeline
  - Cost estimation

#### `DEPLOY-SUMMARY.md` (This file)
- **Package overview and file guide**

---

## Deployment Workflow

### Phase 1: Preparation (5 minutes)
1. Ensure Azure CLI is installed
2. Review configuration (parameters.json)
3. Verify prerequisites (VNet, subnet exist)

### Phase 2: Deployment (15 minutes)
1. Run `bash deploy.sh`
2. Bicep template creates 8 VMs
3. Data disks attached
4. Cloud-init scripts queued on each VM

### Phase 3: VM Initialization (10 minutes)
1. Cloud-init scripts execute in parallel
2. Disks formatted, mounted, configured
3. Java installed
4. Elasticsearch downloaded, extracted
5. Services started
6. Clusters form and elect leaders

### Phase 4: Verification (1 minute)
1. Run `bash scripts/verify/health-check.sh`
2. Confirm both clusters report "green"
3. Confirm 3 nodes in each cluster
4. Ready for benchmarking

**Total Time**: ~20 minutes

---

## Key Variables & Defaults

| Variable | Value | Used In |
|----------|-------|---------|
| Subscription ID | 166157a8-9ce9-400b-91c7-1d42482b83d6 | deploy.sh |
| Resource Group | es-rg | deploy.sh, parameters |
| VNet | es-vnet | main.bicep |
| Subnet | vm-subnet | main.bicep |
| Region | eastus | main.bicep, deploy.sh |
| ES Version | 6.8.1 | cloud-init scripts |
| DSv5 Size | Standard_D8s_v5 | parameters.json |
| DSv6 Size | Standard_D8s_v6 | parameters.json |
| Client Size | Standard_D32s_v6 | parameters.json |
| Disk Size | 200 GB | parameters.json |
| Disk Type | Premium SSD v2 | parameters.json |
| IOPS | 3000 | parameters.json |
| Throughput | 125 Mbps | parameters.json |
| JVM Heap | 8 GB | cloud-init scripts |

---

## Customization Guide

### Change VM Sizes
Edit `parameters.json`:
```json
"dsv5VmSize": { "value": "Standard_D8s_v5" },
"dsv6VmSize": { "value": "Standard_D8s_v6" },
"clientVmSize": { "value": "Standard_D32s_v6" }
```

### Change Elasticsearch Version
Edit both `cloud-init-*.sh` files:
```bash
ES_VERSION="6.8.1"  # Change to desired version
```

### Change Disk Configuration
Edit `parameters.json`:
```json
"diskSizeGB": { "value": 200 },
"diskIops": { "value": 3000 },
"diskThroughputMBps": { "value": 125 }
```

### Change Cluster Names
Edit `elasticsearch-dsv5.yml` and `elasticsearch-dsv6.yml`:
```yaml
cluster.name: es-dsv5-cluster  # Change name
```

### Add More Nodes
Edit `main.bicep` and change loop ranges:
```bicep
for i in range(0, 3)  # Change 3 to desired count
```

---

## Verification Checklist

After deployment completes:

- [ ] **Portal**: All 8 VMs show "Running" status
- [ ] **Portal**: All 8 data disks show "Attached" status
- [ ] **Health Check**: `bash scripts/verify/health-check.sh` shows both clusters "green"
- [ ] **DSv5 Cluster**: 3 nodes, correct IPs (10.0.0.4-6)
- [ ] **DSv6 Cluster**: 3 nodes, correct IPs (10.0.0.7-9)
- [ ] **SSH Access**: Can connect to at least one node
- [ ] **Disk Mount**: `/esdata` visible with 200GB on nodes
- [ ] **Elasticsearch**: Responds to `curl http://10.0.0.4:9200`
- [ ] **Rally**: Installed on client VMs, `rally --version` works
- [ ] **Zone Distribution**: Nodes have zone attributes (zone1/2/3)

---

## Next Steps

1. **For Immediate Testing**:
   - See `QUICKSTART.md`
   - Run health check in 15 minutes
   - Start benchmarking

2. **For Detailed Configuration**:
   - See `README.md` sections 4-7
   - SSH to nodes, review logs
   - Customize `elasticsearch.yml` if needed

3. **For Benchmarking**:
   - See `README.md` sections 8-9
   - SSH to client VM
   - Run Rally performance tests

4. **For Cost Management**:
   - Review `INVENTORY.md` cost section
   - Consider stopping VMs when not in use
   - Plan cleanup timeline

---

## Support Resources

- **Elasticsearch 6.8.1**: https://www.elastic.co/guide/en/elasticsearch/reference/6.8/
- **Azure VM SKUs**: https://learn.microsoft.com/en-us/azure/virtual-machines/sizes-compute
- **Azure Bicep**: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/
- **Rally Docs**: https://esrally.readthedocs.io/
- **Azure CLI**: https://learn.microsoft.com/en-us/cli/azure/

---

## Troubleshooting Quick Reference

| Problem | Solution |
|---------|----------|
| Bicep file not found | Ensure you're in `C:\Users\leizha\es-deployment` |
| Permission denied on deploy.sh | Run `chmod +x deploy.sh` |
| Deployment fails | Check `az account show` returns correct subscription |
| Health check shows "NOT_FOUND" IPs | Wait 5 more minutes for VMs to fully initialize |
| Cluster shows "yellow" status | Normal during first 2-3 minutes, wait for "green" |
| Can't SSH to VM | Verify security group rules allow port 22 |
| Rally won't start | Verify Python 3.9: `python3.9 --version` |

---

## Summary

You now have a **production-ready deployment package** containing:
- ✅ Infrastructure-as-Code (Bicep template)
- ✅ Automated initialization scripts
- ✅ Pre-configured Elasticsearch setups
- ✅ Verification and validation tools
- ✅ Comprehensive documentation
- ✅ Benchmarking framework (Rally)

**Ready to deploy?** Start with:
```bash
cd C:\Users\leizha\es-deployment
bash QUICKSTART.md  # Or read it for understanding
bash deploy.sh
```

---

**Package Version**: 1.0  
**Created**: June 2026  
**Elasticsearch**: 6.8.1  
**Azure Region**: East US  
**Availability Zones**: 3  
**Total Resources**: 8 VMs + 8 Disks + Networking

