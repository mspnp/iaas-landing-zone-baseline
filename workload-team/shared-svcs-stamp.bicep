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
@description('The region for IaaS resources, and supporting managed services (i.e. KeyVault, App Gateway, etc) . This needs to be the same region as the target vnet provided.')
param location string

@description('A common uniquestring reference used for resources that benefit from having a unique component.')
@maxLength(13)
param subComputeRgUniqueString string

/*** RESOURCES ***/

@description('Common log sink across all resources in this architecture that are owned by the workload team.')
resource workloadLogSink 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${subComputeRgUniqueString}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      disableLocalAuth: false
      enableDataExport: false
      enableLogAccessUsingOnlyResourcePermissions: false
    }
    forceCmkForQuery: false
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

/*** OUTPUTS ***/

output logAnalyticsWorkspaceResourceId string = workloadLogSink.id
