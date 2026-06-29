@description('Azure region (inherited from resource group).')
param location string = resourceGroup().location

@description('Admin username for the VM.')
param adminUsername string = 'azureadmin'

@description('Admin password for the VM.')
@secure()
param adminPassword string

@description('Existing virtual network name.')
param vnetName string = 'rocketmqnew-vnet'

@description('Existing subnet name.')
param subnetName string = 'vm-subnet'

@description('VM size.')
param vmSize string = 'Standard_D4s_v6'

@description('VM name.')
param vmName string = 'v6rocketmqclient'

@description('Availability zone.')
param zone string = '1'

@description('Rocky Linux image (Gen2, Standard security type).')
param imageReference object = {
  publisher: 'resf'
  offer: 'rockylinux-x86_64'
  sku: '9-base'
  version: '9.6.20250531'
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  name: '${vnetName}/${subnetName}'
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'rocketmq-client-nsg'
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
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
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

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vmName}-nic'
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
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  zones: [
    zone
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
        diskSizeGB: 30
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output vmName string = vm.name
output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIp string = publicIp.properties.ipAddress
