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

@description('VNet address space allowed to reach NameServer port 9876.')
param vnetCidr string = '10.170.0.0/16'

var cloudInit = loadFileAsBase64('cloud-init.yaml')

var vms = [
  { name: 'v6rocketmqnameserver01', zone: '1' }
  { name: 'v6rocketmqnameserver02', zone: '2' }
  { name: 'v6rocketmqnameserver03', zone: '3' }
]

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  name: '${vnetName}/${subnetName}'
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'rocketmq-ns-nsg'
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
        name: 'Allow-NameServer-9876-VNet'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '9876'
          sourceAddressPrefix: vnetCidr
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2023-09-01' = [for vm in vms: {
  name: '${vm.name}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    vm.zone
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

resource nics 'Microsoft.Network/networkInterfaces@2023-09-01' = [for (vm, i) in vms: {
  name: '${vm.name}-nic'
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
          privateIPAllocationMethod: 'Dynamic'
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

resource dataDisks 'Microsoft.Compute/disks@2023-04-02' = [for vm in vms: {
  name: '${vm.name}-datadisk'
  location: location
  sku: {
    name: 'PremiumV2_LRS'
  }
  zones: [
    vm.zone
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

resource virtualMachines 'Microsoft.Compute/virtualMachines@2023-09-01' = [for (vm, i) in vms: {
  name: vm.name
  location: location
  zones: [
    vm.zone
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
      computerName: vm.name
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
        name: '${vm.name}-osdisk'
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

output vmNames array = [for vm in vms: vm.name]
output publicIpIds array = [for (vm, i) in vms: publicIps[i].id]
