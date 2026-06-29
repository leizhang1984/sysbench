@description('Azure region (inherited from resource group).')
param location string = resourceGroup().location

@description('Admin username for the VMs.')
param adminUsername string = 'azureadmin'

@description('Admin password for the VMs.')
@secure()
param adminPassword string

@description('Existing virtual network name.')
param vnetName string = 'rocketmqnew-vnet'

@description('Existing subnet name.')
param subnetName string = 'vm-subnet'

@description('VM size.')
param vmSize string = 'Standard_D4s_v6'

@description('Rocky Linux image (Gen2, Standard security type).')
param imageReference object = {
  publisher: 'resf'
  offer: 'rockylinux-x86_64'
  sku: '9-base'
  version: '9.6.20250531'
}

@description('VNet address space allowed to reach broker ports.')
param vnetCidr string = '10.170.0.0/16'

var cloudInit = loadFileAsBase64('cloud-init-broker.yaml')

// 6 DLedger broker nodes: 2 groups (broker-a, broker-b) x 3 replicas, one per zone.
// Static private IPs so dLegerPeers can be predetermined.
var brokers = [
  { name: 'v6rocketmqbroker-a-0', group: 'broker-a', selfId: 'n0', zone: '1', ip: '10.170.0.10' }
  { name: 'v6rocketmqbroker-a-1', group: 'broker-a', selfId: 'n1', zone: '2', ip: '10.170.0.11' }
  { name: 'v6rocketmqbroker-a-2', group: 'broker-a', selfId: 'n2', zone: '3', ip: '10.170.0.12' }
  { name: 'v6rocketmqbroker-b-0', group: 'broker-b', selfId: 'n0', zone: '1', ip: '10.170.0.13' }
  { name: 'v6rocketmqbroker-b-1', group: 'broker-b', selfId: 'n1', zone: '2', ip: '10.170.0.14' }
  { name: 'v6rocketmqbroker-b-2', group: 'broker-b', selfId: 'n2', zone: '3', ip: '10.170.0.15' }
]

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  name: '${vnetName}/${subnetName}'
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'rocketmq-broker-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-Broker-Ports-VNet'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '10909'
            '10911'
            '10912'
            '40911'
          ]
          sourceAddressPrefix: vnetCidr
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2023-09-01' = [for b in brokers: {
  name: '${b.name}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    b.zone
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

resource nics 'Microsoft.Network/networkInterfaces@2023-09-01' = [for (b, i) in brokers: {
  name: '${b.name}-nic'
  location: location
  properties: {
    enableAcceleratedNetworking: true
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: b.ip
          subnet: {
            id: subnet.id
          }
          publicIPAddress: {
            id: publicIps[i].id
          }
        }
      }
    ]
  }
}]

resource dataDisks 'Microsoft.Compute/disks@2023-04-02' = [for b in brokers: {
  name: '${b.name}-datadisk'
  location: location
  sku: {
    name: 'PremiumV2_LRS'
  }
  zones: [
    b.zone
  ]
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 100
    diskIOPSReadWrite: 3000
    diskMBpsReadWrite: 125
  }
}]

resource virtualMachines 'Microsoft.Compute/virtualMachines@2023-09-01' = [for (b, i) in brokers: {
  name: b.name
  location: location
  zones: [
    b.zone
  ]
  plan: {
    name: imageReference.sku
    product: imageReference.offer
    publisher: imageReference.publisher
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: b.name
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: cloudInit
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: '${b.name}-osdisk'
        createOption: 'FromImage'
        diskSizeGB: 30
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          lun: 0
          createOption: 'Attach'
          managedDisk: {
            id: dataDisks[i].id
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
  }
}]

output brokerNames array = [for b in brokers: b.name]
output brokerIps array = [for b in brokers: b.ip]
