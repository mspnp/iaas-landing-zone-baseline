/* 

    IDEMPOTENCY WARNING

    Subscription vending is typically done as a "one shot" process to bootstrap a subscription.
    There is no expectation that this bicep file is idempotent once the application team has started
    to apply subnets to the virtual network. It is idempotent up until that point though. Once the
    workload team deploys subnets you cannot run this script again.

*/

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
@description('The spokes\'s regional affinity, must be the same as the existing hub\'s location.')
param location string

/*** EXISTING RESOURCES ***/

@description('This is rg-plz-connectivity-regional-hubs if using the default values in this deployment guide. In practice, this likely would be in a different subscription.')
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(hubVnetResourceId,'/')[4]
}

@description('This is rg-alz-bu04a42-compute, which doesn\'t technically exist. We need a fake reference to it to scope Azure Policy assignments to simulate policies being applied from the Online management group.')
resource knownFutureResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: 'rg-alz-bu04a42-compute'
}

var landingZoneSubscriptionResourceGroups = [
  knownFutureResourceGroup.name
  appLandingZoneSpokeResourceGroup.name
]

/*** RESOURCES ***/

@description('Spoke resource group. This typically would be in a dedicated subscription for the workload.')
resource appLandingZoneSpokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-alz-bu04a42-spoke'
  location: location
}

@description('Apply a sampling of Online management group policies to the application landing zone for a more realistic goverance experience in this deployment guide. These are NOT workload specific.')
module deployAlzPolicy 'management-group-proxy.bicep' = [for resourceGroupToEnrollInPolicy in landingZoneSubscriptionResourceGroups: {
  scope: resourceGroup(resourceGroupToEnrollInPolicy)
  name: 'deploy-alzpolicy-to-${resourceGroupToEnrollInPolicy}'
  params: {
    location: location
  }
}]

@description('Deploy the application landing zone (specifically just the network part)')
module deployApplicationLandingZone 'app-landing-zone-bu04a42.bicep' = {
  scope: appLandingZoneSpokeResourceGroup
  name: 'deploy-alz-bu04a42'
  params: {
    hubVnetResourceId: hubVnetResourceId
    location: location
  }
}

@description('Update the hub to account for the new application landing zone spoke')
module deployHubUpdate 'hub-updates-bu04a42.bicep' = {
  scope: hubResourceGroup
  name: 'connect-alz-bu04a42'
  params: {
    spokeVirtualNetworkResourceId: deployApplicationLandingZone.outputs.spokeVnetResourceId
    location: location
  }
}

/*** OUPUTS ***/

output spokeVirtualNetworkResourceId string = deployApplicationLandingZone.outputs.spokeVnetResourceId
