targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional hub network to which this regional spoke will peer to.')
@minLength(79)
param hubVnetResourceId string

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
@description('The spokes\'s regional affinity, must be the same as the hub\'s location. All resources tied to this spoke will also be homed in this region. The network team maintains this approved regional list which is a subset of zones with Availability Zone support.')
param location string

// A designator that represents a business unit id and application id
var orgAppId = 'BU0001A0008'
var clusterVNetName = 'vnet-spoke-${orgAppId}-00'

/*** EXISTING HUB RESOURCES ***/

// This is 'rg-enterprise-networking-hubs' if using the default values in the walkthrough
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: '${split(hubVnetResourceId,'/')[4]}'
}

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  scope: hubResourceGroup
  name: '${last(split(hubVnetResourceId,'/'))}'
}

// This is the firewall that was deployed in 'hub-default.bicep'
resource hubFirewall 'Microsoft.Network/azureFirewalls@2021-05-01' existing = {
  scope: hubResourceGroup
  name: 'fw-${location}'
}

// This is the networking log analytics workspace (in the hub)
resource laHub 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  scope: hubResourceGroup
  name: 'la-hub-${location}'
}

/*** RESOURCES ***/

// Next hop to the regional hub's Azure Firewall
resource routeNextHopToFirewall 'Microsoft.Network/routeTables@2021-05-01' = {
  name: 'route-to-${location}-hub-fw'
  location: location
  properties: {
    routes: [
      {
        name: 'r-nexthop-to-fw'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

// Default ASG on the vmss frontend. Feel free to constrict further.
resource asgVmssFrontend 'Microsoft.Network/applicationSecurityGroups@2022-07-01' = {
  name: 'asg-frontend'
  location: location
}

// Default ASG on the vmss backend. Feel free to constrict further.
resource asgVmssBackend 'Microsoft.Network/applicationSecurityGroups@2022-07-01' = {
  name: 'asg-backend'
  location: location
}

// Default NSG on the vmss frontend. Feel free to constrict further.
resource nsgVmssFrontendSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${clusterVNetName}-frontend'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAppGwToToFrontendInbound'
        properties: {
          description: 'Allow AppGw traffic inbound.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '10.240.5.0/24'
          destinationPortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgVmssFrontend.id
            }
          ]
          direction: 'Inbound'
          access: 'Allow'
          priority: 100
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 110
        }
      }
      {
        name: 'AllowBastionSubnetSshInbound'
        properties: {
          description: 'Allow Azure Azure Bastion in.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '10.200.0.128/26'
          destinationPortRange: '22'
          destinationApplicationSecurityGroups: [
            {
              id: asgVmssFrontend.id
            }
          ]
          direction: 'Inbound'
          access: 'Allow'
          priority: 120
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'Allow all outbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Default NSG on the vmss backend. Feel free to constrict further.
resource nsgVmssBackendSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${clusterVNetName}-backend'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowIlbToToBackenddApplicationSecurityGroupHTTPSInbound'
        properties: {
          description: 'Allow frontend ASG traffic into 443.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceApplicationSecurityGroups: [
            {
              id: asgVmssFrontend.id
            }
          ]
          destinationPortRange: '443'
          destinationApplicationSecurityGroups: [
            {
              id: asgVmssBackend.id
            }
          ]
          direction: 'Inbound'
          access: 'Allow'
          priority: 100
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 110
        }
      }
      {
        name: 'AllowBastionSubnetSshInbound'
        properties: {
          description: 'Allow Azure Azure Bastion in.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '10.200.0.128/26'
          destinationPortRange: '22'
          destinationApplicationSecurityGroups: [
            {
              id: asgVmssBackend.id
            }
          ]
          direction: 'Inbound'
          access: 'Allow'
          priority: 120
        }
      }
      {
        name: 'AllowBastionSubnetRdpInbound'
        properties: {
          description: 'Allow Azure Azure Bastion in.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '10.200.0.128/26'
          destinationPortRange: '3389'
          destinationApplicationSecurityGroups: [
            {
              id: asgVmssBackend.id
            }
          ]
          direction: 'Inbound'
          access: 'Allow'
          priority: 121
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'Allow all outbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgVmssFrontendSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgVmssFrontendSubnet
  name: 'default'
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource nsgVmssBackendSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgVmssBackendSubnet
  name: 'default'
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// Default NSG on the Vmss Backend internal load balancer subnet. Feel free to constrict further.
resource nsgInternalLoadBalancerSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${clusterVNetName}-ilbs'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowFrontendApplicationSecurityGroupHTTPSInbound'
        properties: {
          description: 'Allow Frontend ASG web traffic into 443.'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            {
              id: asgVmssFrontend.id
            }
          ]
          sourcePortRange: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: '10.240.4.4'
          direction: 'Inbound'
          access: 'Allow'
          priority: 100
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 110
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'Allow all outbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgInternalLoadBalancerSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgInternalLoadBalancerSubnet
  name: 'default'
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// NSG on the Application Gateway subnet.
resource nsgAppGwSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${clusterVNetName}-appgw'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow443Inbound'
        properties: {
          description: 'Allow ALL web traffic into 443. (If you wanted to allow-list specific IPs, this is where you\'d list them.)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: 'VirtualNetwork'
          direction: 'Inbound'
          access: 'Allow'
          priority: 100
        }
      }
      {
        name: 'AllowControlPlaneInbound'
        properties: {
          description: 'Allow Azure Control Plane in. (https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '65200-65535'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 110
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in. (https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 120
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'App Gateway v2 requires full outbound access.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgAppGwSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgAppGwSubnet
  name: 'default'
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// NSG on the Private Link subnet.
resource nsgPrivateLinkEndpointsSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${clusterVNetName}-privatelinkendpoints'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAll443InFromVnet'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgPrivateLinkEndpointsSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgPrivateLinkEndpointsSubnet
  name: 'default'
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// The spoke virtual network.
// 65,536 (-reserved) IPs available to the workload, split across subnets four subnets for Compute,
// one for App Gateway and one for Private Link endpoints.
resource vnetSpoke 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: clusterVNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.240.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-frontend'
        properties: {
          addressPrefix: '10.240.0.0/24'
          routeTable: {
            id: routeNextHopToFirewall.id
          }
          networkSecurityGroup: {
            id: nsgVmssFrontendSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-backend'
        properties: {
          addressPrefix: '10.240.1.0/24'
          routeTable: {
            id: routeNextHopToFirewall.id
          }
          networkSecurityGroup: {
            id: nsgVmssBackendSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-ilbs'
        properties: {
          addressPrefix: '10.240.4.0/28'
          routeTable: {
            id: routeNextHopToFirewall.id
          }
          networkSecurityGroup: {
            id: nsgInternalLoadBalancerSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-privatelinkendpoints'
        properties: {
          addressPrefix: '10.240.4.32/28'
          networkSecurityGroup: {
            id: nsgPrivateLinkEndpointsSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-applicationgateway'
        properties: {
          addressPrefix: '10.240.5.0/24'
          networkSecurityGroup: {
            id: nsgAppGwSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }

  resource snetFrontend 'subnets' existing = {
    name: 'snet-frontend'
  }

  resource snetBackend 'subnets' existing = {
    name: 'snet-backend'
  }
}

// Peer to regional hub
module peeringSpokeToHub 'virtualNetworkPeering.bicep' = {
  name: take('Peer-${vnetSpoke.name}To${hubVirtualNetwork.name}', 64)
  params: {
    remoteVirtualNetworkId: hubVirtualNetwork.id
    localVnetName: vnetSpoke.name
  }
}

// Connect regional hub back to this spoke, this could also be handled via the
// hub template or via Azure Policy or Portal. How virtual networks are peered
// may vary from organization to organization. This example simply does it in
// the most direct way.
module peeringHubToSpoke 'virtualNetworkPeering.bicep' = {
  name: take('Peer-${hubVirtualNetwork.name}To${vnetSpoke.name}', 64)
  dependsOn: [
    peeringSpokeToHub
  ]
  scope: hubResourceGroup
  params: {
    remoteVirtualNetworkId: vnetSpoke.id
    localVnetName: hubVirtualNetwork.name
  }
}

resource vnetSpoke_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: vnetSpoke
  name: 'default'
  properties: {
    workspaceId: laHub.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Used as primary public entry point for the workload. Expected to be assigned to an Azure Application Gateway.
// This is a public facing IP, and would be best behind a DDoS Policy (not deployed simply for cost considerations)
resource pipPrimaryWorkloadIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'pip-${orgAppId}-00'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: pickZones('Microsoft.Network', 'publicIPAddresses', location, 3)
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

resource pipPrimaryWorkloadIp_diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' =  {
  name: 'default'
  scope: pipPrimaryWorkloadIp
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

/*** OUTPUTS ***/

output spokeVnetResourceId string = vnetSpoke.id
output vmssSubnetResourceIds array = [
  vnetSpoke::snetFrontend.id
  vnetSpoke::snetBackend.id
]
output appGwPublicIpAddress string = pipPrimaryWorkloadIp.properties.ipAddress
