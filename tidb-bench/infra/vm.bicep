// =============================================================================
// VM 模块: 公网IP + 网卡(加速网络) + Premium SSD v2 数据盘(可选) + 虚拟机
// =============================================================================

@description('部署区域')
param location string

@description('VM 名称')
param vmName string

@description('VM 规格')
param vmSize string

@description('可用区')
param zone string

@description('内网静态 IP')
param privateIp string

@description('子网资源 ID')
param subnetId string

@description('网络安全组资源 ID')
param nsgId string

@description('是否挂载 Premium SSD v2 数据盘')
param hasDataDisk bool

param adminUsername string

@secure()
param adminPassword string

@description('镜像引用')
param imageReference object

@description('市场镜像 plan (Rocky 需要, CentOS 传 null)')
param plan object?

@description('LB 后端池 ID (TiDB 节点传入, 其它传空字符串)')
param backendPoolId string

param dataDiskSizeGB int
param dataDiskIops int
param dataDiskMbps int

// ---------- 公网 IP (Standard / 静态) ----------
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${vmName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    zone
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ---------- 网卡 (加速网络) ----------
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    enableAcceleratedNetworking: true
    networkSecurityGroup: {
      id: nsgId
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAddress: privateIp
          privateIPAllocationMethod: 'Static'
          publicIPAddress: {
            id: publicIp.id
          }
          loadBalancerBackendAddressPools: empty(backendPoolId) ? [] : [
            {
              id: backendPoolId
            }
          ]
        }
      }
    ]
  }
}

// ---------- Premium SSD v2 数据盘 (仅集群节点) ----------
resource dataDisk 'Microsoft.Compute/disks@2023-10-02' = if (hasDataDisk) {
  name: '${vmName}-datadisk'
  location: location
  sku: {
    name: 'PremiumV2_LRS'
  }
  zones: [
    zone
  ]
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: dataDiskSizeGB
    diskIOPSReadWrite: dataDiskIops
    diskMBpsReadWrite: dataDiskMbps
  }
}

// ---------- 虚拟机 ----------
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  zones: [
    zone
  ]
  plan: plan
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 64
      }
      dataDisks: hasDataDisk ? [
        {
          lun: 0
          createOption: 'Attach'
          managedDisk: {
            id: dataDisk.id
          }
        }
      ] : []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    securityProfile: {
      securityType: 'Standard'
    }
  }
}

output publicIpAddress string = publicIp.properties.ipAddress
output privateIpAddress string = privateIp
