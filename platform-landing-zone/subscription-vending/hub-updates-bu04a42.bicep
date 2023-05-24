targetScope = 'resourceGroup'

/*** PARAMETERS ***/

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
@description('The hub\'s regional affinity. All resources tied to this hub will also be homed in this region. The network team maintains this approved regional list which is a subset of zones with Availability Zone support.')
param location string = 'eastus2'

@description('TODO')
@minLength(70)
param spokeVirtualNetworkResourceId string

// A designator that represents a business unit id and application id
var orgAppId = 'bu04a42'

/*** EXISTING RESOURCES ***/

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: 'vnet-hub-${location}'
}

resource fwPolicy2 'Microsoft.Network/firewallPolicies@2022-11-01' existing = {
  name: 'fw-policies-${location}'

  resource defaultNetworkRuleCollectionGroup 'ruleCollectionGroups' = {
    name: 'DefaultNetworkRuleCollectionGroup'
  }

  resource defaultApplicationRuleCollectionGroup 'ruleCollectionGroups' = {
    name: 'DefaultApplicationRuleCollectionGroup'
  }
}

resource ipGroupTemp 'Microsoft.Network/ipGroups@2022-11-01' existing = {
  name: 'temp'
}

/*** RESOURCES ***/

resource appLzNetworkRulesCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-11-01' = {
  parent: fwPolicy2
  name: 'alz-${orgAppId}-1'
  properties: {
    priority: 210
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'alz-1'
        action: {
          type: 'Allow'
        }
        priority: 100
        rules: [
          {
            ruleType: 'NetworkRule'
          }
        ]

      }
    ]
  }
}

// Peer to hub
resource peerToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-11-01' = {
  parent: hubVirtualNetwork
  name: take('peer-${hubVirtualNetwork.name}-to-${split(spokeVirtualNetworkResourceId, '/')[4]}', 64)
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVirtualNetworkResourceId
    }
  }
}
/*
resource appLzAppRulesCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-11-01' = {
  parent: fwPolicy2
  name: 'alz-${orgAppId}-2'
  properties: {
    priority: 210
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'alz-2'
        action: {
          type: 'Allow'
        }
        priority: 100
        rules: [
          {
            ruleType: 'ApplicationRule'
          }
        ]
      }
    ]
  }
}*/


/*

  // Network hub starts out with only supporting DNS. This is only being done for
  // simplicity in this deployment and is not guidance, please ensure all firewall
  // rules are aligned with your security standards.
  resource defaultNetworkRuleCollectionGroup 'ruleCollectionGroups@2021-05-01' = {
    name: 'DefaultNetworkRuleCollectionGroup'
    properties: {
      priority: 200
      ruleCollections: [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'org-wide-allowed'
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'NetworkRule'
              name: 'DNS'
              description: 'Allow DNS outbound (for simplicity, adjust as needed)'
              ipProtocols: [
                'UDP'
              ]
              sourceAddresses: [
                '*'
              ]
              sourceIpGroups: []
              destinationAddresses: [
                '*'
              ]
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '53'
              ]
            }
          ]
        }
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'Vmss-Workload-Requirements'
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'NetworkRule'
              name: 'AllowAzureUbuntuArchive'
              description: 'Allow 80/443 outbound to azure.archive.ubuntu.com'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: []
              sourceIpGroups: [
                ipgVmssSubnets.id
              ]
              destinationAddresses: []
              destinationIpGroups: []
              destinationFqdns: [
                'azure.archive.ubuntu.com'
              ]
              destinationPorts: [
                '80'
                '443'
              ]
            }
            {
              ruleType: 'NetworkRule'
              name: 'AllowAzureUbuntuArchiveUDP'
              description: 'Allow UDP outbound to azure.archive.ubuntu.com'
              ipProtocols: [
                'UDP'
              ]
              sourceAddresses: []
              sourceIpGroups: [
                ipgVmssSubnets.id
              ]
              destinationAddresses: []
              destinationIpGroups: []
              destinationFqdns: [
                'azure.archive.ubuntu.com'
              ]
              destinationPorts: [
                '123'
              ]
            }
          ]
        }
      ]
    }
  }

  // Network hub starts out with no allowances for appliction rules
  resource defaultApplicationRuleCollectionGroup 'ruleCollectionGroups@2021-05-01' = {
    name: 'DefaultApplicationRuleCollectionGroup'
    dependsOn: [
      defaultNetworkRuleCollectionGroup
    ]
    properties: {
      priority: 300
      ruleCollections: [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'Vmss-Global-Requirements'
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'azure-monitor-extension'
              description: 'Supports required communication for the Azure Monitor extensions in Vmss'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              fqdnTags: []
              webCategories: []
              targetFqdns: [
                'global.handler.control.monitor.azure.com'
                '${location}.handler.control.monitor.azure.com'
                '*.ods.opinsights.azure.com'
                '*.oms.opinsights.azure.com'
                '${location}.monitoring.azure.com'
              ]
              targetUrls: []
              destinationAddresses: []
              terminateTLS: false
              sourceAddresses: []
              sourceIpGroups: [
                ipgVmssSubnets.id
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'azure-policy'
              description: 'Supports required communication for the Azure Policy in Vmss'
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              fqdnTags: []
              webCategories: []
              targetFqdns: [
                'data.policy.${environment().suffixes.storage}'
                'store.policy.${environment().suffixes.storage}'
              ]
              targetUrls: []
              destinationAddresses: []
              terminateTLS: false
              sourceAddresses: []
              sourceIpGroups: [
                ipgVmssSubnets.id
              ]
            }
          ]
        }
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'GitOps-Traffic'
          priority: 300
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'github-origin'
              description: 'Supports pulling gitops configuration from GitHub.'
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
              sourceAddresses: []
              sourceIpGroups: [
                ipgVmssSubnets.id
              ]
            }
          ]
        }
      ]
    }
  }
}

*/
/*** OUTPUTS ***/
/*
output hubVnetId string = vnetHub.id
output abName string = azureBastion.name*/
