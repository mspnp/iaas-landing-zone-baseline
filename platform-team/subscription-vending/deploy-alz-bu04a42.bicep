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

/*** RESOURCES ***/

@description('Spoke resource group. This typically would be in a dedicated subscription for the workload.')
resource appLandingZoneSpokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-alz-bu04a42-spoke'
  location: location
}

@description('Deploy common Azure Policies to apply to the application landing zone. These are NOT workload specific, but instead examples of some common Azure Landing Zone policies.')
module deployManagementGroupProxy 'management-group-proxy.bicep' = {
  scope: subscription()
  name: 'deploy-management-group-proxy'
  params: {
    applicationLandingZoneResourceGroups: [
      appLandingZoneSpokeResourceGroup.name
      'rg-alz-bu04a42-compute'
    ]
    location: location
  }
}

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
