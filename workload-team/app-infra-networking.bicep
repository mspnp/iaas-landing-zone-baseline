targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional Log Analytics workspace to send all our networking logs to.')
@minLength(79)
param workloadLogWorkspaceResourceId string

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

/*** EXISTING RESOURCES ***/

@description('UDR provided by the platform team to apply to all subnets that egress traffic to the Internet. Platform team owns this resource.')
resource routeNextHopToFirewall 'Microsoft.Network/routeTables@2022-11-01' existing = {
  name: 'route-to-connectivity-${location}-hub-fw'
}

@description('IP Group created by the platform team to help us keep track of what bastion hosts are expected to be used when connecting to our virtual machines.')
resource bastionHostIpGroup 'Microsoft.Network/ipGroups@2022-11-01' existing = {
  name: 'ipg-bastion-hosts'
}

@description('Spoke network provided by the platform team. We\'ll be adding our workload\'s subnets to this. Platform team owns this resource.')
resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: 'vnet-spoke-bu04a42-00'
}

@description('The resource group that contains the workload\'s log analytics workspace.')
resource workloadLoggingResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(workloadLogWorkspaceResourceId, '/')[4]
}

@description('The resource group that contains the workload\'s log analytics workspace.')
resource workloadLogAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  scope: workloadLoggingResourceGroup
  name: last(split(workloadLogWorkspaceResourceId, '/'))
}

/*** RESOURCES ***/

@description('Application Security Group to target the front end virtual machines.')
resource asgVmssFrontend 'Microsoft.Network/applicationSecurityGroups@2022-11-01' = {
  name: 'asg-frontend'
  location: location
}

@description('Application Security Group to target the backend end virtual machines.')
resource asgVmssBackend 'Microsoft.Network/applicationSecurityGroups@2022-11-01' = {
  name: 'asg-backend'
  location: location
}

@description('Application Security Group applied to Key Vault private endpoint.')
resource asgKeyVault 'Microsoft.Network/applicationSecurityGroups@2022-11-01' = {
  name: 'asg-keyvault'
  location: location
}

@description('Network security group for the front end virtual machines subnet. Feel free to constrict further if your workload allows.')
resource frontEndSubnetNsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-frontend'
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
          destinationPortRanges: [
            '443'
          ]
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
          sourceAddressPrefixes: bastionHostIpGroup.properties.ipAddresses
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

@description('Diagnostics settings for the front end NSG.')
resource nsgVmssFrontendSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontEndSubnetNsg
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Network security group for the back end virtual machines subnet. Feel free to constrict further if your workload allows.')
resource nsgVmssBackendSubnet 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-backend'
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
          sourceAddressPrefixes: bastionHostIpGroup.properties.ipAddresses
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
          sourceAddressPrefixes: bastionHostIpGroup.properties.ipAddresses
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

@description('Diagnostics settings for the backend end NSG.')
resource nsgVmssBackendSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgVmssBackendSubnet
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Network security group for the internal load balancer subnet. Feel free to constrict further if your workload allows.')
resource nsgInternalLoadBalancerSubnet 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-ilbs'
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

@description('Diagnostics settings for the load balancer subnet NSG.')
resource nsgInternalLoadBalancerSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgInternalLoadBalancerSubnet
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// NSG on the Application Gateway subnet.
@description('Network security group for the Application Gateway subnet. Feel free to constrict further if your workload allows.')
resource nsgAppGwSubnet 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-appgw'
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

@description('Diagnostics settings for the Application Gateway subnet NSG.')
resource nsgAppGwSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgAppGwSubnet
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Network security group for the private endpoint subnet.')
resource nsgPrivateLinkEndpointsSubnet 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-privatelinkendpoints'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow443ToKeyVaultFromVnet'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
          destinationApplicationSecurityGroups: [
            {
              id: asgKeyVault.id
            }
          ]
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

@description('Diagnostics settings for the Private Endpoint subnet NSG.')
resource nsgPrivateLinkEndpointsSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgPrivateLinkEndpointsSubnet
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Network security group for the build/deployment agents subnet. Since this is just a placeholder and no resources are deployed, NSG is on full lock down.')
resource nsgBuildAgentSubnet 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-deploymentagents'
  location: location
  properties: {
    securityRules: [
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

@description('Diagnostics settings for the build agent subnet NSG.')
resource nsgBuildAgentSubnet_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: nsgBuildAgentSubnet
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('The subnet that contains our front end compute. UDR applied for egress traffic. NSG applied as well.')
resource frontendSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: spokeVirtualNetwork
  name: 'snet-frontend'
  properties: {
    addressPrefix: '10.240.0.0/24' // Enough to hold about 250 virtual machine NICs.
    routeTable: {
      id: routeNextHopToFirewall.id
    }
    networkSecurityGroup: {
      id: frontEndSubnetNsg.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    delegations: []
    natGateway: null
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
}

@description('The subnet that contains our back end compute. UDR applied for egress traffic. NSG applied as well.')
resource backendSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: spokeVirtualNetwork
  name: 'snet-backend'
  properties: {
    addressPrefix: '10.240.1.0/24' // Enough to hold about 250 virtual machine NICs.
    routeTable: {
      id: routeNextHopToFirewall.id
    }
    networkSecurityGroup: {
      id: nsgVmssBackendSubnet.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    delegations: []
    natGateway: null
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
  dependsOn: [
    frontendSubnet // single thread these subnet creations
  ]
}

@description('The subnet that contains a load balancer to communicate from front end to back end. UDR applied for egress traffic. NSG applied as well.')
resource internalLoadBalancerSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: spokeVirtualNetwork
  name: 'snet-ilbs'
  properties: {
    addressPrefix: '10.240.4.0/28' // Just large enough to hold a few internal load balancers, one is all that is deployed.
    routeTable: {
      id: routeNextHopToFirewall.id
    }
    networkSecurityGroup: {
      id: nsgInternalLoadBalancerSubnet.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    delegations: []
    natGateway: null
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
  dependsOn: [
    backendSubnet // single thread these subnet creations
  ]
}

@description('The subnet that contains private endpoints for PaaS services used in this architecture. UDR applied for egress traffic. NSG applied as well.')
resource privateEndpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: spokeVirtualNetwork
  name: 'snet-privatelinkendpoints' // Just large enough to hold a few private endpoints, one is all that is deployed.
  properties: {
    addressPrefix: '10.240.4.32/28'
    routeTable: {
      id: routeNextHopToFirewall.id // No internet traffic is expected, but routing just for added security.
    }
    networkSecurityGroup: {
      id: nsgPrivateLinkEndpointsSubnet.id
    }
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    delegations: []
    natGateway: null
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
  dependsOn: [
    internalLoadBalancerSubnet // single thread these subnet creations
  ]
}

@description('The dedicated subnet that contains application gateway used for ingress in this architecture. UDR not applied for egress traffic, per requirements of the service. NSG applied as well.')
resource applicationGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: spokeVirtualNetwork
  name: 'snet-applicationgateway'
  properties: {
    addressPrefix: '10.240.5.0/24' // Azure Application Gateway recommended subnet size.
    networkSecurityGroup: {
      id: nsgAppGwSubnet.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    delegations: []
    natGateway: null
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
  dependsOn: [
    privateEndpointsSubnet // single thread these subnet creations
  ]
}

@description('The subnet that contains private build agents for last-mile deployments into this architecture. UDR applied for egress traffic. NSG applied as well.')
resource deploymentAgentsSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  parent: spokeVirtualNetwork
  name: 'snet-deploymentagents'
  properties: {
    addressPrefix: '10.240.4.96/28' // Enough to hold about 10 virtual machine NICs or delegated to ACI
    routeTable: {
      id: routeNextHopToFirewall.id
    }
    networkSecurityGroup: {
      id: nsgBuildAgentSubnet.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    delegations: []
    natGateway: null
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
  dependsOn: [
    applicationGatewaySubnet // single thread these subnet creations
  ]
}

@description('While the platform team probably has their own monitoring, as a workload team, we\'ll want metrics as well.')
resource vnetSpoke_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: spokeVirtualNetwork
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('This IP is used as the primary public entry point for the workload. Expected to be assigned to an Azure Application Gateway.')
resource pipPrimaryWorkloadIp 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'pip-bu04a42-00'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: pickZones('Microsoft.Network', 'publicIPAddresses', location, 3)
  properties: {
    publicIPAllocationMethod: 'Static' // Application Gateway v2 requires Static
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
    ddosSettings: {
      protectionMode: 'Disabled' // Cost Optimization: DDoS protection should be enabled with all public IPs.
    }
  }
}

@description('Azure Diagnostics for the Application Gateway public IP.')
resource pipPrimaryWorkloadIp_diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: pipPrimaryWorkloadIp
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
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

output appGwPublicIpAddress string = pipPrimaryWorkloadIp.properties.ipAddress
