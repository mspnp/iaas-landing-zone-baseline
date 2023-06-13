targetScope = 'subscription'

/*
    This single-subscription deployment is not going to be living under a management group 
    as part of this deployment guide. As such, we'll apply some common Azure Landing Zone policies
    to the resource groups that will be standing in for the application landing zone subscription.

    These policies are applied at the resource group level here, but in reality would have been applied
    to the whole subscription via the management group structure.  The resource groups that we deploy
    as part of this deployment guide that are realted to the application landing zone are all prefixed
    with rg-alz-, and as such we are only appling the policies to those well-known resource groups.

    Not all the resource groups even exist yet, but we need to fake that so we can honor a more realistic
    Azure Policy environment in this reference implementation.
*/

@minLength(1)
param applicationLandingZoneResourceGroups array

param location string

/*** EXISTING HUB RESOURCES ***/

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: 'vnet-${location}-hub'
  scope: resourceGroup('rg-plz-connectivity-regional-hubs')
}

// TODO-CK: Fill this up!


