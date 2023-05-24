targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke VNet Resource ID that will host the VMs ')
@minLength(79)
param targetVnetResourceId string

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
@description('The region for IaaS resources, and supporting managed services (i.e. KeyVault, App Gateway, etc) . This needs to be the same region as the target vnet provided.')
param location string = 'eastus2'

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('vmss', subscription().subscriptionId, resourceGroup().id)

/*** EXISTING RESOURCES ***/

/*** RESOURCES ***/

// This Log Analytics workspace will be the dedicated shared spoke log sink for all resources in the BU0001A0008. This includes the Vmss instances, Key Vault, etc. It also is the VM Insights log sink for the Vmss instances.
resource laVmss 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'la-vmss-${subRgUniqueString}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

/*** OUTPUTS ***/
