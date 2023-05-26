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

@description('Since we know that our solution involves Virtual Machines, add the Azure Monitor solution up front.')
resource omsVMInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'VMInsights(${workloadLogSink.name})'
  location: location
  properties: {
    workspaceResourceId: workloadLogSink.id
  }
  plan: {
    name: 'VMInsights(${workloadLogSink.name})'
    product: 'OMSGallery/VMInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

/*** OUTPUTS ***/

output logAnalyticsWorkspaceResourceId string = workloadLogSink.id
