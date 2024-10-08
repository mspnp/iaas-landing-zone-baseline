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
  // Only those regions that support all deployed resources, and have a paired region that
  // also supports the deployed resources, and both regions support availability zones.
  // Data as of: 27-June-2023
  'brazilsouth'    // paired to: southcentralus
  'centralus'      // paired to: eastus2
  'eastasia'       // paired to: southeastasia
  'eastus'         // paired to: westus
  'eastus2'        // paired to: centralus
  'northcentralus' // paired to: southcentralus
  'northeurope'    // paired to: westeurope
  'southcentralus' // paired to: northcentralus
  'southeastasia'  // paired to: eastasia
  'westeurope'     // paired to: northeurope
  'westus'         // paired to: eastus
  'westus3'        // paired to: eastus

  // The following regions all support availability zones, but their paired regions do not.
  // Consider your architectral impact in selecting one of these regions in a failover situation.
  // 'australiaeast'      // paired to: australiasoutheast
  // 'canadacentral'      // paired to: canadaeast
  // 'westus2'            // paired to: westcentralus
  // 'francecentral'      // paired to: francesouth
  // 'germanywestcentral' // paired to: germanynorth
  // 'southafricanorth'   // paired to: southafericawest
  // 'swedencentral'      // paired to: swedensouth
  // 'uksouth'            // paired to: ukwest
  // 'japaneast'          // paired to: japanwest
  // 'centralindia'       // paired to: southindia
  // 'koreacentral'       // paired to: koreasouth
  // 'norwayeast'         // paired to: norwaywest
  // 'switzerlandnorth'   // paired to: switzerlandwest
  // 'uaenorth'           // paired to: uaecentral
])
@description('The spokes\'s regional affinity, must be the same as the existing hub\'s location.')
param location string

/*** EXISTING RESOURCES ***/

@description('This is rg-plz-connectivity-regional-hubs if using the default values in this deployment guide. In practice, this likely would be in a different subscription.')
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(hubVnetResourceId, '/')[4]
}

@description('This is the existing hub virtual network found in rg-plz-connectivity-regional-hubs.')
resource regionalHubVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  scope: hubResourceGroup
  name: (last(split(hubVnetResourceId, '/')))
}

/*** RESOURCES ***/

@description('Spoke resource group. This typically would be in a dedicated subscription for the workload.')
resource appLandingZoneSpokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-alz-bu04a42-spoke-${location}'
  location: location
}

@description('This is rg-alz-bu04a42-compute, which wouldn\'t technically exist at this point. We need a fake reference to it to scope Azure Policy assignments to simulate policies being applied from the Online management group.')
resource knownFutureAppResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-alz-bu04a42-compute-${location}'
  location: location
}

@description('Deploy the application landing zone (specifically just the network part)')
module deployApplicationLandingZone 'app-landing-zone-bu04a42.bicep' = {
  scope: appLandingZoneSpokeResourceGroup
  name: 'deploy-alz-bu04a42'
  params: {
    hubVnetResourceId: regionalHubVirtualNetwork.id
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

@description('Apply a sampling of Online management group policies to the application landing zone for a more realistic goverance experience in this deployment guide. These are NOT workload specific.')
module deployAlzOnlinePoliciesToSpoke './management-group-proxy.bicep' = {
  scope: appLandingZoneSpokeResourceGroup
  name: 'deploy-alzonlinepolicy-${appLandingZoneSpokeResourceGroup.name}'
  params: {
    location: location
    dnsZoneResourceGroupId: hubResourceGroup.id
  }
}

@description('Apply a sampling of Online management group policies to the application landing zone for a more realistic goverance experience in this deployment guide. These are NOT workload specific.')
module deployAlzOnlinePoliciesToApp './management-group-proxy.bicep' = {
  scope: knownFutureAppResourceGroup
  name: 'deploy-alzonlinepolicy-${knownFutureAppResourceGroup.name}'
  params: {
    location: location
    dnsZoneResourceGroupId: hubResourceGroup.id
  }
}

/*** OUPUTS ***/

output spokeVirtualNetworkResourceId string = deployApplicationLandingZone.outputs.spokeVnetResourceId
