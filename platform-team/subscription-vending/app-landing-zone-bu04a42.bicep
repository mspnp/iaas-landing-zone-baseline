targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional hub network to which this regional spoke will peer to. In this deployment guide it\'s assumed to be in the same subscription, but in reality would be in the connectivity subscription')
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
@description('The spokes\'s regional affinity, must be the same as the hub\'s location.')
param location string

/*** EXISTING HUB RESOURCES ***/

@description('This is rg-plz-enterprise-networking-hubs if using the default values in this deployment guide. In practice, this likely would be in a different subscription.')
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(hubVnetResourceId,'/')[4]
}

@description('The regional hub network in the Connectivity subscription.')
resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  scope: hubResourceGroup
  name: last(split(hubVnetResourceId,'/'))

  resource bastionHostSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

@description('The regional firewall in the Connectivity subscription.')
resource hubFirewall 'Microsoft.Network/azureFirewalls@2022-11-01' existing = {
  scope: hubResourceGroup
  name: 'fw-${location}'
}

@description('The regional log analytics workspace in the Connectivity subscription.')
resource laHub 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  scope: hubResourceGroup
  name: 'la-hub-${location}'
}

/*** RESOURCES ***/

@description('Deploy the UDR to force tunnel traffic to the Azure Firewall')
resource routeNextHopToFirewall 'Microsoft.Network/routeTables@2022-11-01' = {
  name: 'route-to-connectivity-${location}-hub-fw'
  location: location
  properties: {
    disableBgpRoutePropagation: true
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

@description('Application landing zone network, sized to the application team\'s vending request. No subnets, as expected.')
resource vnetSpoke 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'vnet-spoke-bu04a42-00'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.240.0.0/21'   // Allocating just over 2,000 IPs for this landing zone. These would be registered in your platform team's IPAM system.
      ]
    }
    dhcpOptions: {
      dnsServers: [
        hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress
      ]
    }
    enableDdosProtection: false // Cost optimization: this should be enabled, as there will be a public IP for ingress in this virtual network as indicated in the subscription vending request

    // Do not deploy any subnets. Subnets are owned by the application team.
  }
}

@description('Peer the spoke to the hub.')
resource peerToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-11-01' = {
  name: take('peer-${vnetSpoke.name}-to-${hubVirtualNetwork.name}', 64)
  parent: vnetSpoke
  properties: {
    allowForwardedTraffic: false
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVirtualNetwork.id
    }
  }
}

@description('Azure Diagnostics for the spoke virtual network, to the hub workspace for platform team visibility. Workload team may also wish to apply their own.')
resource vnetSpoke_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: vnetSpoke
  name: 'to-hub'
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

@description('IP Group that contains this landing zone\'s bastion host IP ranges to allow in their NSGs.')
resource ipGroupBastionRangesInHub 'Microsoft.Network/ipGroups@2022-11-01' = {
  name: 'ipg-bastion-hosts'
  location: location
  properties: {
    ipAddresses: [
      hubVirtualNetwork::bastionHostSubnet.properties.addressPrefix
    ]
  }
}

/*** OUTPUTS ***/

output spokeVnetResourceId string = vnetSpoke.id
