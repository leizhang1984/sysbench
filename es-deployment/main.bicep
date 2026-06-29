// Elasticsearch DSv5 vs DSv6 Benchmark Deployment
// Bicep template for Azure infrastructure

param subscriptionId string
param resourceGroupName string
param location string = 'eastus'
param vnetName string = 'es-vnet'
param subnetName string = 'vm-subnet'

// VM Configuration Parameters
param dsv5VmSize string = 'Standard_D8s_v5'
param dsv6VmSize string = 'Standard_D8s_v6'
param clientVmSize string = 'Standard_D32s_v6'

param adminUsername string = 'azureuser'
param sshKeyPath string = '/home/azureuser/.ssh/id_rsa.pub'

// OS Image Parameters
param centosPublisher string = 'OpenLogic'
param centosOffer string = 'CentOS'
param centosSkuV7 string = '7_9'

param rockyPublisher string = 'erockyenterprisesoftwarefoundationinc1653071250513'
param rockyOffer string = 'rockylinux-x86_64-base'
param rockySku string = '9-lvm'

// Data Disk Parameters
param diskSizeGB int = 200
param diskIops int = 3000
param diskThroughputMBps int = 125

// Availability Zones
var azones = ['1', '2', '3']

// VM definitions with static IPs
var dsv5Vms = [
  { name: 'dsv5esmasterdata01', ip: '10.122.0.4' }
  { name: 'dsv5esmasterdata02', ip: '10.122.0.5' }
  { name: 'dsv5esmasterdata03', ip: '10.122.0.6' }
]
var dsv6Vms = [
  { name: 'dsv6esmasterdata01', ip: '10.122.0.7' }
  { name: 'dsv6esmasterdata02', ip: '10.122.0.8' }
  { name: 'dsv6esmasterdata03', ip: '10.122.0.9' }
]
var clientVms = [
  { name: 'clientvm01', ip: '10.122.0.10' }
  { name: 'clientvm02', ip: '10.122.0.11' }
]

// Reference existing VNet and Subnet
var vnetId = '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Network/virtualNetworks/${vnetName}'
var subnetId = '${vnetId}/subnets/${subnetName}'

// Get existing NSG from subnet
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  name: '${vnetName}/${subnetName}'
}

// ===== DSv5 Cluster (CentOS 7.9) =====
// Static IP allocation: 10.122.0.4-6
resource dsv5Nics 'Microsoft.Network/networkInterfaces@2023-04-01' = [for i in range(0, 3): {
  name: 'dsv5esmasterdata0${i+1}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: dsv5IPs[i]
        }
      }
    ]
    networkSecurityGroup: {
      id: existingSubnet.properties.networkSecurityGroup?.id ?? null
    }
    enableAcceleratedNetworking: true
  }
}]

resource dsv5Vms 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, 3): {
  name: 'dsv5esmasterdata0${i+1}'
  location: location
  zones: [azones[i]]
  properties: {
    hardwareProfile: {
      vmSize: dsv5VmSize
    }
    securityProfile: {
      securityType: 'Standard'
    }
    osProfile: {
      computerName: 'dsv5esmasterdata0${i+1}'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: sshKeyPath
              keyData: ''  // Will be provided at deployment time
            }
          ]
        }
      }
      customData: base64(loadTextContent('./scripts/cloud-init-centos7.sh'))
    }
    storageProfile: {
      imageReference: {
        publisher: centosPublisher
        offer: centosOffer
        sku: centosSkuV7
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dsv5Nics[i].id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
  dependsOn: [
    dsv5Nics[i]
  ]
}]

// DSv5 Data Disks
resource dsv5DataDisks 'Microsoft.Compute/disks@2023-01-02' = [for i in range(0, 3): {
  name: 'dsv5esmasterdata0${i+1}-datadisk'
  location: location
  zones: [azones[i]]
  sku: {
    name: 'Premium_SSD_v2'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: diskSizeGB
    diskIOPSReadWrite: diskIops
    diskMBpsReadWrite: diskThroughputMBps
  }
}]

resource dsv5DiskAttachments 'Microsoft.Compute/virtualMachines/dataDisks@2023-03-01' = [for i in range(0, 3): {
  parent: dsv5Vms[i]
  name: 'datadisk-${i}'
  properties: {
    lun: 0
    createOption: 'Attach'
    managedDisk: {
      id: dsv5DataDisks[i].id
    }
  }
}]

// ===== DSv6 Cluster (Rocky 9.6) =====
// Static IP allocation: 10.122.0.7-9
resource dsv6Nics 'Microsoft.Network/networkInterfaces@2023-04-01' = [for i in range(0, 3): {
  name: 'dsv6esmasterdata0${i+1}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: dsv6IPs[i]
        }
      }
    ]
    networkSecurityGroup: {
      id: existingSubnet.properties.networkSecurityGroup?.id ?? null
    }
    enableAcceleratedNetworking: true
  }
}]

resource dsv6Vms 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, 3): {
  name: 'dsv6esmasterdata0${i+1}'
  location: location
  zones: [azones[i]]
  properties: {
    hardwareProfile: {
      vmSize: dsv6VmSize
    }
    securityProfile: {
      securityType: 'Standard'
    }
    osProfile: {
      computerName: 'dsv6esmasterdata0${i+1}'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: sshKeyPath
              keyData: ''  // Will be provided at deployment time
            }
          ]
        }
      }
      customData: base64(loadTextContent('./scripts/cloud-init-rocky9.sh'))
    }
    storageProfile: {
      imageReference: {
        publisher: rockyPublisher
        offer: rockyOffer
        sku: rockySku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dsv6Nics[i].id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
  dependsOn: [
    dsv6Nics[i]
  ]
}]

// DSv6 Data Disks
resource dsv6DataDisks 'Microsoft.Compute/disks@2023-01-02' = [for i in range(0, 3): {
  name: 'dsv6esmasterdata0${i+1}-datadisk'
  location: location
  zones: [azones[i]]
  sku: {
    name: 'Premium_SSD_v2'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: diskSizeGB
    diskIOPSReadWrite: diskIops
    diskMBpsReadWrite: diskThroughputMBps
  }
}]

resource dsv6DiskAttachments 'Microsoft.Compute/virtualMachines/dataDisks@2023-03-01' = [for i in range(0, 3): {
  parent: dsv6Vms[i]
  name: 'datadisk-${i}'
  properties: {
    lun: 0
    createOption: 'Attach'
    managedDisk: {
      id: dsv6DataDisks[i].id
    }
  }
}]

// ===== Client VMs (Rocky 9.6) =====
// Static IP allocation: 10.122.0.10-11
resource clientNics 'Microsoft.Network/networkInterfaces@2023-04-01' = [for i in range(0, 2): {
  name: 'clientvm0${i+1}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: clientIPs[i]
        }
      }
    ]
    networkSecurityGroup: {
      id: existingSubnet.properties.networkSecurityGroup?.id ?? null
    }
    enableAcceleratedNetworking: true
  }
}]

resource clientVms 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, 2): {
  name: 'clientvm0${i+1}'
  location: location
  zones: [(i + 1) % 3 == 0 ? '3' : string((i + 1) % 3)]  // Distribute across zones
  properties: {
    hardwareProfile: {
      vmSize: clientVmSize
    }
    securityProfile: {
      securityType: 'Standard'
    }
    osProfile: {
      computerName: 'clientvm0${i+1}'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: sshKeyPath
              keyData: ''  // Will be provided at deployment time
            }
          ]
        }
      }
      customData: base64(loadTextContent('./scripts/cloud-init-client.sh'))
    }
    storageProfile: {
      imageReference: {
        publisher: rockyPublisher
        offer: rockyOffer
        sku: rockySku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: clientNics[i].id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
  dependsOn: [
    clientNics[i]
  ]
}]

// ===== Outputs =====
output dsv5NodeIps array = [for i in range(0, 3): {
  vmName: dsv5Vms[i].name
  privateIp: dsv5Nics[i].properties.ipConfigurations[0].properties.privateIPAddress
}]

output dsv6NodeIps array = [for i in range(0, 3): {
  vmName: dsv6Vms[i].name
  privateIp: dsv6Nics[i].properties.ipConfigurations[0].properties.privateIPAddress
}]

output clientNodeIps array = [for i in range(0, 2): {
  vmName: clientVms[i].name
  privateIp: clientNics[i].properties.ipConfigurations[0].properties.privateIPAddress
}]
