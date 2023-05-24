targetScope = 'subscription'

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

/*** EXISTING RESOURCES ***/

// A designator that represents a business unit id and application id
var orgAppId = 'bu04a42'

/*** EXISTING RESOURCES ***/

@description('This is rg-plz-enterprise-networking-hubs if using the default values in this deployment guide. In practice, this likely would be in a different subscription.')
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: split(hubVnetResourceId,'/')[4]
}

/*** RESOURCES ***/

@description('Spoke resource group. This typically would be in a dedicated subscription for the workload.')
resource appLandingZoneSpokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-alz-bu04a42-spoke'
  location: location
}

@description('Deploy the application landing zone (specifically just the network part)')
module deployApplicationLandingZone 'app-landing-zone-bu04a42.bicep' = {
  scope: appLandingZoneSpokeResourceGroup
  name: 'deployApplicationLandingZone${orgAppId}'
  params: {
    hubVnetResourceId: hubVnetResourceId
    location: location
  }
}

@description('Update the hub to account for the new application landing zone spoke')
module deployHubUpdate 'hub-updates-bu04a42.bicep' = {
  scope: hubResourceGroup
  name: 'deployUpdatesForApplicationLandingZone${orgAppId}'
  params: {
    spokeVirtualNetworkResourceId: deployApplicationLandingZone.outputs.spokeVnetResourceId
    location: location
  }
}