# Elasticsearch DSv5 vs DSv6 Deployment - Resource Inventory

## Deployment Summary

**Date**: June 2026  
**Purpose**: Performance benchmarking of Elasticsearch 6.8.1 across VM generations (DSv5 vs DSv6)  
**Region**: East US (eastus)  
**Availability Zones**: 3 (Zone 1, 2, 3)  
**Subscription ID**: 166157a8-9ce9-400b-91c7-1d42482b83d6  
**Resource Group**: es-rg  

---

## Infrastructure Inventory

### Total Resource Count
| Resource Type | Count | Details |
|---|---|---|
| Virtual Machines | 8 | 3x DSv5 + 3x DSv6 + 2x Client |
| Network Interfaces | 8 | One per VM |
| Managed Disks (Data) | 8 | Premium SSD v2, 200GB each |
| Managed Disks (OS) | 8 | Premium SSD, auto-created |
| **Total vCPU** | **192** | 8×8 + 8×8 + 2×32 |
| **Total Memory** | **544 GB** | 8×32 + 8×32 + 2×128 |
| **Total Storage** | **2.4 TB** | 8×200GB data + 8×32GB OS (est.) |

---

## Virtual Machines - DSv5 Cluster

### Compute Specifications
- **VM Size**: Standard_D8s_v5
- **vCPU**: 8 cores
- **Memory**: 32 GB
- **OS Disk**: 128 GB Premium SSD
- **Data Disk**: 200 GB Premium SSD v2
- **Network**: Accelerated Networking enabled
- **Operating System**: CentOS 7.9

### Nodes

| VM Name | Availability Zone | Private IP | Network Interface | Data Disk |
|---|---|---|---|---|
| dsv5esmasterdata01 | Zone 1 | 10.0.0.4 (assigned) | dsv5esmasterdata01-nic | dsv5esmasterdata01-datadisk |
| dsv5esmasterdata02 | Zone 2 | 10.0.0.5 (assigned) | dsv5esmasterdata02-nic | dsv5esmasterdata02-datadisk |
| dsv5esmasterdata03 | Zone 3 | 10.0.0.6 (assigned) | dsv5esmasterdata03-nic | dsv5esmasterdata03-datadisk |

### Elasticsearch Configuration
- **Cluster Name**: es-dsv5-cluster
- **Node Role**: master=true, data=true, ingest=false
- **Version**: 6.8.1
- **Data Directory**: /esdata/data
- **Log Directory**: /var/log/elasticsearch
- **JVM Heap**: 8 GB (configured)
- **Discovery Nodes**: 10.0.0.4, 10.0.0.5, 10.0.0.6
- **Minimum Master Nodes**: 2
- **AZ Awareness**: Enabled (zone1, zone2, zone3)

---

## Virtual Machines - DSv6 Cluster

### Compute Specifications
- **VM Size**: Standard_D8s_v6
- **vCPU**: 8 cores
- **Memory**: 32 GB
- **OS Disk**: 128 GB Premium SSD
- **Data Disk**: 200 GB Premium SSD v2
- **Network**: Accelerated Networking enabled
- **Operating System**: Rocky 9.6 (updated to latest)

### Nodes

| VM Name | Availability Zone | Private IP | Network Interface | Data Disk |
|---|---|---|---|---|
| dsv6esmasterdata01 | Zone 1 | 10.0.0.7 (assigned) | dsv6esmasterdata01-nic | dsv6esmasterdata01-datadisk |
| dsv6esmasterdata02 | Zone 2 | 10.0.0.8 (assigned) | dsv6esmasterdata02-nic | dsv6esmasterdata02-datadisk |
| dsv6esmasterdata03 | Zone 3 | 10.0.0.9 (assigned) | dsv6esmasterdata03-nic | dsv6esmasterdata03-datadisk |

### Elasticsearch Configuration
- **Cluster Name**: es-dsv6-cluster
- **Node Role**: master=true, data=true, ingest=false
- **Version**: 6.8.1
- **Data Directory**: /esdata/data
- **Log Directory**: /var/log/elasticsearch
- **JVM Heap**: 8 GB (configured)
- **Discovery Nodes**: 10.0.0.7, 10.0.0.8, 10.0.0.9
- **Minimum Master Nodes**: 2
- **AZ Awareness**: Enabled (zone1, zone2, zone3)

---

## Virtual Machines - Client/Benchmarking

### Compute Specifications
- **VM Size**: Standard_D32s_v6
- **vCPU**: 32 cores
- **Memory**: 128 GB
- **OS Disk**: 128 GB Premium SSD
- **Network**: Accelerated Networking enabled
- **Operating System**: Rocky 9.6 (updated to latest)

### Nodes

| VM Name | Availability Zone | Private IP | Network Interface | Purpose |
|---|---|---|---|---|
| clientvm01 | Zone 2 (auto) | 10.0.0.10 (assigned) | clientvm01-nic | Rally benchmarking |
| clientvm02 | Zone 3 (auto) | 10.0.0.11 (assigned) | clientvm02-nic | Rally benchmarking |

### Software Configuration
- **Rally Version**: Latest stable (installed via pip)
- **Python Version**: 3.9+
- **Virtual Environment**: /opt/rally-env
- **Helper Script**: ~/run-rally.sh

---

## Storage Configuration

### Data Disks (Premium SSD v2)

| VM | Disk Name | Size | IOPS | Throughput | Mount Point | Filesystem |
|---|---|---|---|---|---|---|
| dsv5esmasterdata01 | dsv5esmasterdata01-datadisk | 200 GB | 3000 | 125 Mbps | /esdata | XFS |
| dsv5esmasterdata02 | dsv5esmasterdata02-datadisk | 200 GB | 3000 | 125 Mbps | /esdata | XFS |
| dsv5esmasterdata03 | dsv5esmasterdata03-datadisk | 200 GB | 3000 | 125 Mbps | /esdata | XFS |
| dsv6esmasterdata01 | dsv6esmasterdata01-datadisk | 200 GB | 3000 | 125 Mbps | /esdata | XFS |
| dsv6esmasterdata02 | dsv6esmasterdata02-datadisk | 200 GB | 3000 | 125 Mbps | /esdata | XFS |
| dsv6esmasterdata03 | dsv6esmasterdata03-datadisk | 200 GB | 3000 | 125 Mbps | /esdata | XFS |

**Mount Configuration**: UUID-based via `/etc/fstab`

**Estimated Capacity per Cluster**:
- Raw: 600 GB (3 nodes × 200 GB)
- Usable with ES overhead: ~560 GB per cluster
- **Both clusters combined**: ~1.12 TB

---

## Network Configuration

### VNet & Subnet
- **VNet Name**: es-vnet
- **VNet CIDR**: 10.0.0.0/16
- **Subnet Name**: vm-subnet
- **Subnet CIDR**: 10.0.0.0/24
- **Security Group**: Applied at subnet level

### Network Interfaces

| VM | NIC Name | Subnet | Accelerated Networking | IP Allocation |
|---|---|---|---|---|
| dsv5esmasterdata01 | dsv5esmasterdata01-nic | vm-subnet | Enabled | Dynamic |
| dsv5esmasterdata02 | dsv5esmasterdata02-nic | vm-subnet | Enabled | Dynamic |
| dsv5esmasterdata03 | dsv5esmasterdata03-nic | vm-subnet | Enabled | Dynamic |
| dsv6esmasterdata01 | dsv6esmasterdata01-nic | vm-subnet | Enabled | Dynamic |
| dsv6esmasterdata02 | dsv6esmasterdata02-nic | vm-subnet | Enabled | Dynamic |
| dsv6esmasterdata03 | dsv6esmasterdata03-nic | vm-subnet | Enabled | Dynamic |
| clientvm01 | clientvm01-nic | vm-subnet | Enabled | Dynamic |
| clientvm02 | clientvm02-nic | vm-subnet | Enabled | Dynamic |

### Security Group Rules (Required)
```
Rule 1: Allow SSH (port 22) from admin networks
Rule 2: Allow ES HTTP (port 9200) between cluster nodes and clients
Rule 3: Allow ES Node communication (port 9300) between cluster nodes
Rule 4: Deny all other inbound traffic (default)
```

### Expected IP Assignments
```
10.0.0.1-3       - Reserved/Gateway
10.0.0.4-6       - DSv5 Cluster (dsv5esmasterdata01-03)
10.0.0.7-9       - DSv6 Cluster (dsv6esmasterdata01-03)
10.0.0.10-11     - Client VMs (clientvm01-02)
10.0.0.12-254    - Available for future use
```

---

## Elasticsearch Cluster Details

### DSv5 Cluster Topology
```
es-dsv5-cluster
├── dsv5esmasterdata01 (Zone 1, 10.0.0.4)
│   ├── Role: master=true, data=true
│   ├── Data: /esdata/data
│   └── Shards: P0, R1, R2
├── dsv5esmasterdata02 (Zone 2, 10.0.0.5)
│   ├── Role: master=true, data=true
│   ├── Data: /esdata/data
│   └── Shards: P1, R2, R0
└── dsv5esmasterdata03 (Zone 3, 10.0.0.6)
    ├── Role: master=true, data=true
    ├── Data: /esdata/data
    └── Shards: P2, R0, R1
```

### DSv6 Cluster Topology
```
es-dsv6-cluster
├── dsv6esmasterdata01 (Zone 1, 10.0.0.7)
│   ├── Role: master=true, data=true
│   ├── Data: /esdata/data
│   └── Shards: P0, R1, R2
├── dsv6esmasterdata02 (Zone 2, 10.0.0.8)
│   ├── Role: master=true, data=true
│   ├── Data: /esdata/data
│   └── Shards: P1, R2, R0
└── dsv6esmasterdata03 (Zone 3, 10.0.0.9)
    ├── Role: master=true, data=true
    ├── Data: /esdata/data
    └── Shards: P2, R0, R1
```

### Default Index Settings
```
number_of_shards: 3
number_of_replicas: 1
refresh_interval: 1s
awareness.attributes: zone
```

---

## Access Information

### SSH Credentials
- **Username**: azureuser
- **Authentication**: SSH key pair (public key in VM, private key locally)
- **Port**: 22

### Elasticsearch Access
- **Protocol**: HTTP
- **Port**: 9200 (REST API)
- **Node Communication Port**: 9300 (internal)
- **Authentication**: None (default, no X-Pack)

### Example Access Commands
```bash
# SSH into DSv5 node 1
ssh azureuser@10.0.0.4

# Check ES cluster health (from client VM)
curl http://10.0.0.4:9200/_cluster/health?pretty

# Access Rally (from client VM)
source /opt/rally-env/bin/activate
rally --version
```

---

## Deployment Timeline

| Phase | Duration | Activities |
|---|---|---|
| Infrastructure Creation | 5-10 min | VM provisioning, disk attachment |
| OS Initialization | 2-5 min | CentOS/Rocky updates, Java installation |
| Elasticsearch Setup | 2-3 min | Download, extract, configure |
| Cluster Formation | 1-2 min | Discovery, quorum election |
| Health Check Ready | 15-20 min | **Total to fully operational** |
| Rally Installation | 2-3 min | Python env, pip install |

**Total Deployment Time**: ~20 minutes from `az deployment group create`

---

## Validation Checklist

- [ ] All 8 VMs in "Running" state
- [ ] All 8 data disks attached and mounted
- [ ] DSv5 cluster status = "green" with 3 nodes
- [ ] DSv6 cluster status = "green" with 3 nodes
- [ ] Rally installed on client VMs
- [ ] SSH access working for all VMs
- [ ] Cluster health checkable via curl
- [ ] Node AZ attributes correctly set

---

## Cost Estimation (Approximate)

### Compute
- 6x D8s (DSv5 + DSv6): 96 vCPU-hours/month
- 2x D32s (Client): 64 vCPU-hours/month
- **Monthly Compute**: ~$3,500-4,500 (East US pricing)

### Storage
- 8 disks × 200 GB = 1.6 TB: ~$100-150/month
- OS disks (est. 1 TB): ~$50-70/month
- **Monthly Storage**: ~$150-220

### Network
- Cross-AZ data transfer: ~$50-100/month
- **Total Monthly**: ~$3,700-4,820

**Note**: Exact pricing depends on Azure region, reserved instances, and current rates.

---

## References

- Elasticsearch 6.8.1 Documentation: https://www.elastic.co/guide/en/elasticsearch/reference/6.8/
- Azure VM Sizes: https://learn.microsoft.com/en-us/azure/virtual-machines/sizes
- Elasticsearch Rally: https://esrally.readthedocs.io/
- Azure Availability Zones: https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview

---

**Document Version**: 1.0  
**Last Updated**: June 2026  
**Maintained By**: DevOps/Infrastructure Team
