// =============================================================================
// TiDB DSv5 vs DSv6 性能对比测试环境 - 主部署模板
// =============================================================================
// 部署内容:
//   - 2 个网络安全组 (集群节点 / 压测机)
//   - 2 个内网标准负载均衡器 (dv5-lb / dv6-lb, 后端只挂各自 3 个 TiDB:4000)
//   - 14 台虚拟机 (6 台 DSv5 + 6 台 DSv6 + 2 台压测机), 每台带 Standard 静态公网IP
//   - 12 块 Premium SSD v2 数据盘 (集群节点), 挂载点 /tidb
// 复用现有: VNet tidb-vnet / 子网 vm-subnet (不新建)
// =============================================================================

targetScope = 'resourceGroup'

// ---------- 参数 ----------
@description('部署区域')
param location string = 'germanywestcentral'

@description('现有虚拟网络名称')
param vnetName string = 'tidb-vnet'

@description('现有子网名称')
param subnetName string = 'vm-subnet'

@description('VM 管理员用户名')
param adminUsername string = 'azureadmin'

@description('VM 管理员密码')
@secure()
param adminPassword string

@description('允许 SSH 访问的来源 IP (按要求全开)')
param sshSourceAddressPrefix string = '*'

// 数据盘规格 (Premium SSD v2)
param dataDiskSizeGB int = 200
param dataDiskIops int = 3000
param dataDiskMbps int = 125

// ---------- 镜像引用 ----------
var centosImage = {
  publisher: 'OpenLogic'
  offer: 'CentOS'
  sku: '7_9'
  version: '7.9.2023030700'
}
var rockyImage = {
  publisher: 'resf'
  offer: 'rockylinux-x86_64'
  sku: '9-base'
  version: '9.6.20250531'
}
// Rocky Linux 市场镜像需要 plan 信息
var rockyPlan = {
  name: '9-base'
  publisher: 'resf'
  product: 'rockylinux-x86_64'
}

// ---------- 现有网络引用 ----------
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: subnetName
}

// ---------- 网络安全组: 集群节点 ----------
resource nsgCluster 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-cluster'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: sshSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-Intra-VNet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// ---------- 网络安全组: 压测机 ----------
resource nsgClient 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-client'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: sshSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-Grafana'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3000'
          sourceAddressPrefix: sshSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-Intra-VNet'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// ---------- 内网负载均衡器 (dv5 / dv6) ----------
var lbConfigs = [
  {
    name: 'dv5-lb'
    privateIp: '10.142.0.10'
  }
  {
    name: 'dv6-lb'
    privateIp: '10.142.0.30'
  }
]

resource loadBalancers 'Microsoft.Network/loadBalancers@2023-11-01' = [for lb in lbConfigs: {
  name: lb.name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAddress: lb.privateIp
          privateIPAllocationMethod: 'Static'
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'tidb-pool'
      }
    ]
    probes: [
      {
        name: 'tidb-probe'
        properties: {
          protocol: 'Tcp'
          port: 4000
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'tidb-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lb.name, 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lb.name, 'tidb-pool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lb.name, 'tidb-probe')
          }
          protocol: 'Tcp'
          frontendPort: 4000
          backendPort: 4000
          idleTimeoutInMinutes: 30
          enableFloatingIP: false
        }
      }
    ]
  }
}]

// ---------- 虚拟机定义 ----------
// role: cluster=集群节点(带数据盘+集群NSG), client=压测机(无数据盘+压测NSG)
// lbPool: TiDB 节点加入对应 LB 后端池; 其它为空
var vms = [
  // DSv5 集群 (CentOS 7.9)
  { name: 'dv5tidb01', size: 'Standard_D8s_v5',  zone: '1', os: 'centos', ip: '10.142.0.11', role: 'cluster', lb: 'dv5-lb' }
  { name: 'dv5tidb02', size: 'Standard_D8s_v5',  zone: '2', os: 'centos', ip: '10.142.0.12', role: 'cluster', lb: 'dv5-lb' }
  { name: 'dv5tidb03', size: 'Standard_D8s_v5',  zone: '3', os: 'centos', ip: '10.142.0.13', role: 'cluster', lb: 'dv5-lb' }
  { name: 'dv5tikv01', size: 'Standard_D8s_v5',  zone: '1', os: 'centos', ip: '10.142.0.21', role: 'cluster', lb: '' }
  { name: 'dv5tikv02', size: 'Standard_D8s_v5',  zone: '2', os: 'centos', ip: '10.142.0.22', role: 'cluster', lb: '' }
  { name: 'dv5tikv03', size: 'Standard_D8s_v5',  zone: '3', os: 'centos', ip: '10.142.0.23', role: 'cluster', lb: '' }
  // DSv6 集群 (Rocky 9.6)
  { name: 'dv6tidb01', size: 'Standard_D8s_v6',  zone: '1', os: 'rocky',  ip: '10.142.0.31', role: 'cluster', lb: 'dv6-lb' }
  { name: 'dv6tidb02', size: 'Standard_D8s_v6',  zone: '2', os: 'rocky',  ip: '10.142.0.32', role: 'cluster', lb: 'dv6-lb' }
  { name: 'dv6tidb03', size: 'Standard_D8s_v6',  zone: '3', os: 'rocky',  ip: '10.142.0.33', role: 'cluster', lb: 'dv6-lb' }
  { name: 'dv6tikv01', size: 'Standard_D8s_v6',  zone: '1', os: 'rocky',  ip: '10.142.0.41', role: 'cluster', lb: '' }
  { name: 'dv6tikv02', size: 'Standard_D8s_v6',  zone: '2', os: 'rocky',  ip: '10.142.0.42', role: 'cluster', lb: '' }
  { name: 'dv6tikv03', size: 'Standard_D8s_v6',  zone: '3', os: 'rocky',  ip: '10.142.0.43', role: 'cluster', lb: '' }
  // 压测机 (Rocky 9.6)
  { name: 'clientvm01', size: 'Standard_D32s_v6', zone: '1', os: 'rocky', ip: '10.142.0.51', role: 'client', lb: '' }
  { name: 'clientvm02', size: 'Standard_D32s_v6', zone: '1', os: 'rocky', ip: '10.142.0.52', role: 'client', lb: '' }
]

module vmModule 'vm.bicep' = [for vm in vms: {
  name: 'deploy-${vm.name}'
  params: {
    location: location
    vmName: vm.name
    vmSize: vm.size
    zone: vm.zone
    privateIp: vm.ip
    subnetId: subnet.id
    nsgId: vm.role == 'cluster' ? nsgCluster.id : nsgClient.id
    hasDataDisk: vm.role == 'cluster'
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: vm.os == 'centos' ? centosImage : rockyImage
    plan: vm.os == 'rocky' ? rockyPlan : null
    backendPoolId: vm.lb == '' ? '' : resourceId('Microsoft.Network/loadBalancers/backendAddressPools', vm.lb, 'tidb-pool')
    dataDiskSizeGB: dataDiskSizeGB
    dataDiskIops: dataDiskIops
    dataDiskMbps: dataDiskMbps
  }
  dependsOn: [
    loadBalancers
  ]
}]

// ---------- 输出 ----------
output dv5LbPrivateIp string = '10.142.0.10'
output dv6LbPrivateIp string = '10.142.0.30'
output vmPublicIps array = [for (vm, i) in vms: {
  name: vm.name
  publicIp: vmModule[i].outputs.publicIpAddress
}]
