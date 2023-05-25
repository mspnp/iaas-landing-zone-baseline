targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The existing application landing zone network to which this regional hub will peer to. In this deployment guide it\'s assumed to be in the same subscription, but in reality would be in the landing zone subscription')
@minLength(79)
param spokeVirtualNetworkResourceId string

@allowed([
  'australiaeast'
  'canadacentral'
  'centralus'
  'eastus'
  'eastus2'
  'westus2'
  'francecentral'
  'germanywestcentral'
  'northeurope'
  'southafricanorth'
  'southcentralus'
  'uksouth'
  'westeurope'
  'japaneast'
  'southeastasia'
])
@description('The existing hub\'s regional affinity.')
param location string

// A designator that represents a business unit id and application id
var orgAppId = 'bu04a42'

/*** EXISTING HUB RESOURCES ***/

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: 'vnet-${location}-hub'
}

@description('Existing Azure Firewall policy for this regional firewall.')
resource fwPolicy 'Microsoft.Network/firewallPolicies@2022-11-01' existing = {
  name: 'fw-policies-${location}'
}

/*** EXISTING SPOKE RESOURCES ***/

resource spokeVirtualNetworkResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(spokeVirtualNetworkResourceId, '/')[4]
}

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  scope: spokeVirtualNetworkResourceGroup
  name: split(spokeVirtualNetworkResourceId, '/')[8]
}

/*** RESOURCES ***/

resource appLzNetworkRulesCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-11-01' = {
  parent: fwPolicy
  name: 'alz-${orgAppId}'
  properties: {
    priority: 1001
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'alz-${orgAppId}-infra-n'
        action: {
          type: 'Allow'
        }
        priority: 100
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'ubuntu-time-sync'
            description: 'Allow outbound to support NTP time sync'
            destinationFqdns: [
              'ntp.ubuntu.com'
            ]
            ipProtocols: [
              'UDP'
            ]
            // This covers the whole IP space of the spoke virtual network, if you have the ability to work
            // with your application team, ideally restrict this just to the subnets that contain traffic that
            // need this allowance. This this reference implementation, that would be the frontend subnets.
            sourceAddresses: spokeVirtualNetwork.properties.addressSpace.addressPrefixes
            destinationPorts: [
              '123'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'windows-time-sync'
            description: 'Allow outbound to support NTP time sync'
            destinationFqdns: [
              'time.windows.com'
            ]
            ipProtocols: [
              'UDP'
            ]
            // This covers the whole IP space of the spoke virtual network, if you have the ability to work
            // with your application team, ideally restrict this just to the subnets that contain traffic that
            // need this allowance. This this reference implementation, that would be the backend subnet.
            sourceAddresses: spokeVirtualNetwork.properties.addressSpace.addressPrefixes
            destinationPorts: [
              '123'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'alz-${orgAppId}-infra-a'
        action: {
          type: 'Allow'
        }
        priority: 200
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'ubuntu-package-upgrades'
            description: 'Allow outbound to support package upgrades'
            targetFqdns: [
              'azure.archive.ubuntu.com'
            ]
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            httpHeadersToInsert: []
            terminateTLS: false
            sourceAddresses: spokeVirtualNetwork.properties.addressSpace.addressPrefixes
          }
          {
            ruleType: 'ApplicationRule'
            name: 'windows-package-upgrades'
            description: 'Allow outbound to support package upgrades'
            targetFqdns: [
              'WindowsUpdate'
            ]
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            httpHeadersToInsert: []
            terminateTLS: false
            // This covers the whole IP space of the spoke virtual network, if you have the ability to work
            // with your application team, ideally restrict this just to the subnets that contain traffic that
            // need this allowance. This this reference implementation, that would be the backend subnet.
            sourceAddresses: spokeVirtualNetwork.properties.addressSpace.addressPrefixes
          }
          {
            ruleType: 'ApplicationRule'
            name: 'windows-diagnostics'
            description: 'Allow outbound to support windows diagnostics'
            targetFqdns: [
              'WindowsDiagnostics'
            ]
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            httpHeadersToInsert: []
            terminateTLS: false
            // This covers the whole IP space of the spoke virtual network, if you have the ability to work
            // with your application team, ideally restrict this just to the subnets that contain traffic that
            // need this allowance. This this reference implementation, that would be the backend subnet.
            sourceAddresses: spokeVirtualNetwork.properties.addressSpace.addressPrefixes
          }
          {
            ruleType: 'ApplicationRule'
            name: 'azure-monitor-extension'
            description: 'Supports required communication for the Azure Monitor extensions'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            webCategories: []
            targetFqdns: [
              'global.handler.control.monitor.azure.com'
              '${location}.handler.control.monitor.azure.com'
              '*.ods.opinsights.azure.com'
              '*.oms.opinsights.azure.com'
              '${location}.monitoring.azure.com'
            ]
            terminateTLS: false
            // This covers the whole IP space of the spoke virtual network, if you have the ability to work
            // with your application team, ideally restrict this just to the subnets that contain traffic that
            // need this allowance. This this reference implementation, that would be the backend & frontend subnets.
            sourceAddresses: spokeVirtualNetwork.properties.addressSpace.addressPrefixes
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'alz-${orgAppId}-workload-a'
        priority: 250
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'github'
            description: 'Workload specific rule - provided by application team in subscription vending request.'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            webCategories: []
            targetFqdns: [
              'github.com'
              'api.github.com'
              'raw.githubusercontent.com'
              'nginx.org'
            ]
            targetUrls: []
            destinationAddresses: []
            terminateTLS: false
            // This covers the whole IP space of the spoke virtual network, if you have the ability to work
            // with your application team, ideally restrict this just to the subnets that contain traffic that
            // need this allowance. This this reference implementation, that would be the backend & frontend subnets.
            sourceAddresses: spokeVirtualNetwork.properties.addressSpace.addressPrefixes
          }
          {
            ruleType: 'ApplicationRule'
            name: 'nginx'
            description: 'Workload specific rule - provided by application team in subscription vending request.'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            webCategories: []
            targetFqdns: [
              'nginx.org'
            ]
            targetUrls: []
            destinationAddresses: []
            terminateTLS: false
            // This covers the whole IP space of the spoke virtual network, if you have the ability to work
            // with your application team, ideally restrict this just to the subnets that contain traffic that
            // need this allowance. This this reference implementation, that would be the backend & frontend subnets.
            sourceAddresses: spokeVirtualNetwork.properties.addressSpace.addressPrefixes
          }
        ]
      }
    ]
  }
}

// Peer to hub
resource peerToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-11-01' = {
  parent: hubVirtualNetwork
  name: take('peer-${hubVirtualNetwork.name}-to-${spokeVirtualNetwork.name}', 64)
  properties: {
    allowForwardedTraffic: false
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true  // Required for Azure Bastion to reach into the virtual network.
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVirtualNetwork.id
    }
  }
}
