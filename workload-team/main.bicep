targetScope = 'subscription'

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
@description('The region for IaaS resources, and supporting managed services (i.e. Key Vault, Application Gateway, etc). This needs to be the same region as the target virtual network provided.')
param location string

@description('The existing regional network spoke resource ID, provided by the landing zone platform team, that will host the virtual machines.')
@minLength(79)
param targetVnetResourceId string

@description('The certificate data for Azure Application Gateway TLS termination. It is Base64 encoded.')
param appGatewayListenerCertificate string

@description('The Base64 encoded VMSS web server public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
param vmssWildcardTlsPublicCertificate string

@description('The Base64 encoded VMSS web server public and private certificates (formatterd as .pem or .pfx) to be stored in Azure Key Vault as secret and downloaded into the frontend and backend Vmss instances for the workloads ssl certificate configuration.')
param vmssWildcardTlsPublicAndKeyCertificates string

@description('The admin password for the virtual machines machines.')
@minLength(12)
@secure()
param adminPassword string

/*** VARIABLES ***/

var subComputeRgUniqueString = uniqueString('bu04a42', computeResourceGroup.id)

/*** EXISTING RESOURCES ***/

@description('The resource group in our landing zone subscription that contains the virtual network.')
resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: split(targetVnetResourceId, '/')[4]
}

@description('The existing application landing zone virtual network. We do not have full access to this virtual network, just subnets.')
resource landingZoneVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  scope: networkResourceGroup
  name: last(split(targetVnetResourceId, '/'))
}

/*** RESOURCES ***/

@description('The resource group that holds most of the resources in this architecture not provided by the platform landing zone team.')
resource computeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-alz-bu04a42-compute'
  location: location
}

@description('Deploy any long-lived resources to the compute resource group. In this architecture, it\'s just a Log Analytics resource and Azure Policy assignments.')
module sharedServices 'app-infra-shared-svcs.bicep' = {
  scope: computeResourceGroup
  name: 'deploy-shared-services'
  params: {
    location: location
    subComputeRgUniqueString: subComputeRgUniqueString
  }
}

@description('Deploy network configuration.')
module applySubnetsAndUdrs 'app-infra-networking.bicep' = {
  scope: networkResourceGroup
  name: 'apply-networking'
  params: {
    workloadLogWorkspaceResourceId: sharedServices.outputs.logAnalyticsWorkspaceResourceId
    location: location
  }
}

@description('Deploy the application platform and its adjacent resources.')
module deployWorkloadInfrastructure 'app-infra-stamp.bicep' = {
  scope: computeResourceGroup
  name: 'deploy-workload-infrastructure'
  params: {
    location: location
    adminPassword: adminPassword
    appGatewayListenerCertificate: appGatewayListenerCertificate
    targetVnetResourceId: landingZoneVirtualNetwork.id
    vmssWildcardTlsPublicAndKeyCertificates: vmssWildcardTlsPublicAndKeyCertificates
    vmssWildcardTlsPublicCertificate: vmssWildcardTlsPublicCertificate
    subComputeRgUniqueString: subComputeRgUniqueString
  }
  dependsOn: [
    applySubnetsAndUdrs
  ]
}

/*** OUTPUTS ***/

output frontendVmssResourceId string = deployWorkloadInfrastructure.outputs.frontendVmssResourceId

output backendVmssResourceId string = deployWorkloadInfrastructure.outputs.backendVmssResourceId
