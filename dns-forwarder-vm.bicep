param networkInterface object
param virtualMachine object
param vnet object
param location string
param environment string
param staticIpAddressWest array
param staticIpAddressNorth array
param adminUsername string
@secure()
param adminPassword string
param availabilitySet object
// param applicationSecurityGroups string

var vnetId = resourceId(vnet.resourceGroup, 'Microsoft.Network/virtualNetworks', vnet.name)
// var asgId = resourceId(vnet.resourceGroup,'Microsoft.Network/applicationSecurityGroups', applicationSecurityGroups)
var dnsForwarderStaticIP = location == 'WestEurope' ? staticIpAddressWest :  staticIpAddressNorth

resource dnsForwarderAvailabilitySet 'Microsoft.Compute/availabilitySets@2016-04-30-preview' = {
  name: availabilitySet.name
  location: location
  sku: {
    capacity: 2
    name: 'dnsForwarderAvailabilitySet'
    tier: 'Standard'
  }
  properties: {
    managed: true
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 2
    // proximityPlacementGroup: {
    //   id: 'string'
    // }
    // virtualMachines: [
    //   {
    //     id: 'string'
    //   }
    // ]
  }
}

resource dnsForwarderNetworkInterface 'Microsoft.Network/networkInterfaces@2018-10-01' = [for i in range(0,2) : {
  name: '${networkInterface.name}-0${i+1}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConfig'
        properties: {
          subnet: {
            id: '${vnetId}/subnets/${vnet.subnet}'
          }
          // applicationSecurityGroups: [
          //   {
          //     id: asgId
          //   }
          // ]
          privateIPAllocationMethod: 'Static'
          privateIPAddress: dnsForwarderStaticIP[i]
        }
      }
    ]
    enableAcceleratedNetworking: networkInterface.enableAcceleratedNetworking
  }
  tags: {
    environment: environment
  }
  dependsOn: []
}]

resource dnsForwarderVM 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0,2) : {
  name: '${virtualMachine.Name}0${i+1}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachine.size
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: virtualMachine.diskType
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter-Core'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dnsForwarderNetworkInterface[i].id
        }
      ]
    }
    osProfile: {
      computerName: '${virtualMachine.computerName}0${i+1}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: virtualMachine.enableHotpatching
          patchMode: virtualMachine.patchMode
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    availabilitySet: {
      id: dnsForwarderAvailabilitySet.id
    }
  }
  tags: {
    environment: environment
  }
}]

resource dnsForwarderRole 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for i in range (0,2) :{
  name: '${virtualMachine.Name}0${i+1}/dnsForwarderRole'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe Install-WindowsFeature -Name DNS -IncludeManagementTools; Add-DnsServerForwarder -IPAddress 168.63.129.16'
    }
  }
  dependsOn: [
    dnsForwarderVM
  ]
}]
