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
param location string

@description('Optional. A /24 to contain the regional firewall, management, and gateway subnet. Defaults to 10.200.0.0/24')
@maxLength(18)
@minLength(10)
param hubVirtualNetworkAddressSpace string = '10.200.0.0/24'

@description('Optional. A /26 under the virtual network address space for the regional Azure Firewall. Defaults to 10.200.0.0/26')
@maxLength(18)
@minLength(10)
param hubVirtualNetworkAzureFirewallSubnetAddressSpace string = '10.200.0.0/26'

@description('Optional. A /27 under the virtual network address space for our regional cross-premises gateway. Defaults to 10.200.0.64/27')
@maxLength(18)
@minLength(10)
param hubVirtualNetworkGatewaySubnetAddressSpace string = '10.200.0.64/27'

@description('Optional. A /26 under the virtual network address space for regional Azure Bastion. Defaults to 10.200.0.128/26')
@maxLength(18)
@minLength(10)
param hubVirtualNetworkBastionSubnetAddressSpace string = '10.200.0.128/26'

/*** VARIABLES ***/

// TODO: Consider using a connectivity resource group dedicated to these dns zones

@description('Examples of private DNS zones for Private Link that might already exist in a hub.')
var privateDnsZones = [
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.vaultcore.azure.net'
  'privatelink.file.${environment().suffixes.storage}'
]

/*** EXISTING SUBSCRIPTION RESOURCES ***/

@description('Existing network contributor role.')
resource networkContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7'
}

/*** RESOURCES ***/

@description('This Log Analytics workspace stores logs from the regional hub network, its spokes, and bastion. Log analytics is a regional resource, as such there will be one workspace per hub (region).')
resource laHub 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-hub-${location}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    forceCmkForQuery: false
    features: {
      disableLocalAuth: true
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
}

resource laHub_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: laHub
  name: 'default'
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

@description('The network security group for the Azure Bastion subnet.')
resource nsgBastionSubnet 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-${location}-bastion'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowWebExperienceInbound'
        properties: {
          description: 'Allow our users in. Update this to be as restrictive as possible.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowControlPlaneInbound'
        properties: {
          description: 'Service Requirement. Allow control plane access. Regional Tag not yet supported.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Service Requirement. Allow Health Probes.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostToHostInbound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
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
        name: 'AllowSshToVnetOutbound'
        properties: {
          description: 'Allow SSH out to the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '22'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowRdpToVnetOutbound'
        properties: {
          description: 'Allow RDP out to the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '3389'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowControlPlaneOutbound'
        properties: {
          description: 'Required for control plane outbound. Regional prefix not yet supported'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostToHostOutbound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionCertificateValidationOutbound'
        properties: {
          description: 'Service Requirement. Allow Required Session and Certificate Validation.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '80'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          description: 'No further outbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

@description('Azure Diagnostics for Bastion NSG')
resource nsgBastionSubnet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgBastionSubnet
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

@description('Regional hub network')
resource vnetHub 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'vnet-${location}-hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVirtualNetworkAddressSpace
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: hubVirtualNetworkAzureFirewallSubnetAddressSpace
          networkSecurityGroup: null
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          serviceEndpoints: []
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: hubVirtualNetworkGatewaySubnetAddressSpace
          networkSecurityGroup: null
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          serviceEndpoints: []
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: hubVirtualNetworkBastionSubnetAddressSpace
          networkSecurityGroup: {
            id: nsgBastionSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          serviceEndpoints: []
        }
      }
    ]
  }

  resource azureFirewallSubnet 'subnets' existing = {
    name: 'AzureFirewallSubnet'
  }

  resource azureBastionSubnet 'subnets' existing = {
    name: 'azureBastionSubnet'
  }
}

@description('Azure Diagnostics for the regional hub network')
resource vnetHub_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: vnetHub
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

@description('Number of IP addresses to apply to the firewall')
var numFirewallIpAddressesToAssign = 3

@description('Azure Firewall often has multiple IPs associated to avoid port exhaustion on egress. This applies three.')
resource pipsAzureFirewall 'Microsoft.Network/publicIPAddresses@2022-11-01' = [for i in range(0, numFirewallIpAddressesToAssign): {
  name: 'pip-fw-${location}-${padLeft(i, 2, '0')}'
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
}]

@description('Azure Diagnostics for the hub\'s regional Azure Firewall egress IP addresses')
resource pipAzureFirewall_diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for i in range(0, numFirewallIpAddressesToAssign): {
  scope: pipsAzureFirewall[i]
  name: 'default'
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
}]

@description('Azure Firewall configuration. DNS proxy is enabled. The network and application policies are generic and do not account for any specific application landing zones.')
resource fwPolicy 'Microsoft.Network/firewallPolicies@2022-11-01' = {
  name: 'fw-policies-${location}'
  location: location
  properties: {
    sku: {
      tier: 'Premium'
    }
    threatIntelMode: 'Deny'
    insights: {
      isEnabled: true
      retentionDays: 30
      logAnalyticsResources: {
        defaultWorkspaceId: {
          id: laHub.id
        }
        workspaces: [
          {
            region: location
            workspaceId: {
              id: laHub.id
            }
          }
        ]
      }
    }
    threatIntelWhitelist: {
      fqdns: []
      ipAddresses: []
    }
    intrusionDetection: {
      mode: 'Deny'
      configuration: {
        bypassTrafficSettings: []
        signatureOverrides: []
      }
    }
    dnsSettings: {
      servers: []
      enableProxy: true
    }
  }

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
              name: 'azure-dns'
              description: 'Allow Azure DNS outbound (for simplicity, adjust as needed)'
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '168.63.129.16'
              ]
              ipProtocols: [
                'UDP'
              ]
              destinationPorts: [
                '53'
              ]
            }
          ]
        }
      ]
    }
  }

  // Network hub starts out with very few allowances for appliction rules
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
          name: ''
          action: {
            type: 'Allow'
          }
          priority: 100
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'msft-common-http'
              description: 'Allow common connections'
              sourceAddresses: [
                '*'
              ]
              targetUrls: [
                'www.msftconnecttest.com/connecttest.txt'
              ]
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
              ]
              terminateTLS: false
            }
            {
              ruleType: 'ApplicationRule'
              name: 'crl-common-http'
              description: 'Allow common certificate revocation list connections'
              sourceAddresses: [
                '*'
              ]
              targetFqdns: [
                'crl.microsoft.com'
                '*.digicert.com'
              ]
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
              ]
              terminateTLS: false
            }
            {
              ruleType: 'ApplicationRule'
              name: 'msft-common-https'
              description: 'Allow common connections'
              sourceAddresses: [
                '*'
              ]
              targetFqdns: [
                'wdcp.microsoft.com'
                'wdcpalt.microsoft.com'
                'sls.microsoft.com'
                '*.sls.microsoft.com'
                'pas.windows.net'
                'packages.microsoft.com'
                // This cannot be obtained without manipulating environment().authentication.loginEndpoint
                // to remove the https:// and tailing /
                #disable-next-line no-hardcoded-env-urls
                'login.microsoftonline.com'
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              terminateTLS: false
            }
          ]
        }
      ]
    }
  }
}

@description('This is the regional Azure Firewall that all regional spoke networks in application landing zones can egress through.')
resource hubFirewall 'Microsoft.Network/azureFirewalls@2022-11-01' = {
  name: 'fw-${location}'
  location: location
  zones: pickZones('Microsoft.Network', 'azureFirewalls', location, 3)
  dependsOn: [
    // This helps prevent multiple PUT updates happening to the firewall causing a CONFLICT race condition
    // Ref: https://learn.microsoft.com/azure/firewall-manager/quick-firewall-policy
    fwPolicy::defaultApplicationRuleCollectionGroup
    fwPolicy::defaultNetworkRuleCollectionGroup
  ]
  properties: {
    sku: {
      tier: 'Premium'
      name: 'AZFW_VNet'
    }
    firewallPolicy: {
      id: fwPolicy.id
    }
    ipConfigurations: [for i in range(0, numFirewallIpAddressesToAssign): {
      name: pipsAzureFirewall[i].name
      properties: {
        subnet: (0 == i) ? {
          id: vnetHub::azureFirewallSubnet.id
        } : null
        publicIPAddress: {
          id: pipsAzureFirewall[i].id
        }
      }
    }]
  }
}

@description('Azure Diagnostics for the hub\'s regional Azure Firewall')
resource hubFirewall_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: hubFirewall
  name: 'default'
  properties: {
    workspaceId: laHub.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'allLogs' // TODO: Cost Optimization Tip: tune as necessary
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

@description('Deploy all private DNS zones expected to be used in application landing zones. This is just a subset for example purposes. This is not a "per hub" deployment, but is included in here for simplicity.')
resource allPrivateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for privateDnsZone in privateDnsZones: {
  name: privateDnsZone
  location: 'global'
  properties: {}
}]

@description('Link the private DNS zones to all the regional hub networks. There is only one hub in this example.')
resource allPrivateDnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (privateDnsZone, index) in privateDnsZones: {
  parent: allPrivateDnsZones[index]
  name: 'link-to-${vnetHub.name}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetHub.id
    }
  }
}]

@description('The public IP for the regional hub\'s Azure Bastion service.')
resource pipRegionalBastionHost 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'pip-ab-${location}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: pickZones('Microsoft.Network', 'publicIPAddresses', location, 3)
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

@description('Azure Diagnostics for the hub\'s regional Azure Bastion ingress IP addresses')
resource pipRegionalBastionHost_diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: pipRegionalBastionHost
  name: 'default'
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

@description('This regional hub\'s Azure Bastion service.')
resource regionalBastionHost 'Microsoft.Network/bastionHosts@2022-11-01' = {
  name: 'ab-${location}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    disableCopyPaste: false
    enableFileCopy: true
    enableIpConnect: true
    enableKerberos: false
    enableShareableLink: false
    enableTunneling: true
    scaleUnits: 2
    ipConfigurations: [
      {
        name: 'hub-subnet'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipRegionalBastionHost.id
          }
          subnet: {
            id: vnetHub::azureBastionSubnet.id
          }
        }
      }
    ]
  }
}

@description('Azure Diagnostics for the hub\'s regional Azure Bastion host')
resource regionalBastionHost_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: regionalBastionHost
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

@description('This is an identity that can be used by Azure Policies to perform private DNS zone management.')
resource dinePrivateDnsZoneIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-privatednszoneadmin-dinepolicies'
  location: location
}

@description('Ensure the managed identity for DINE policies in DNS can manage the zones.')
resource dinePolicyAssignmentToDnsZones 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (privateDnsZone, index) in privateDnsZones: {
  scope: allPrivateDnsZones[index]
  name: guid(allPrivateDnsZones[index].id, networkContributorRole.id, dinePrivateDnsZoneIdentity.id)
  properties: {
    principalId: dinePrivateDnsZoneIdentity.properties.principalId
    roleDefinitionId: networkContributorRole.id
    principalType: 'ServicePrincipal'
  }
}]

/*** OUTPUTS ***/

output hubVnetId string = vnetHub.id

output regionalBastionHostName string = regionalBastionHost.name
