targetScope = 'subscription'

/*** PARAMETERS ***/

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
@description('The region for IaaS resources, and supporting managed services (i.e. Key Vault, Application Gateway, etc). This needs to be the same region as the target virtual network provided.')
param location string

@description('The existing regional network spoke resource ID, provided by the landing zone platform team, that will host the virtual machines.')
@minLength(79)
param targetVnetResourceId string

@description('The certificate data for Azure Application Gateway TLS termination. It is Base64 encoded.')
@secure()
param appGatewayListenerCertificate string

@description('The Base64 encoded VMSS web server public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
param vmssWildcardTlsPublicCertificate string

@description('The Base64 encoded VMSS web server public and private certificates (formatterd as .pem or .pfx) to be stored in Azure Key Vault as secret and downloaded into the frontend and backend Vmss instances for the workloads ssl certificate configuration.')
@secure()
param vmssWildcardTlsPublicAndKeyCertificates string

@description('The admin password for the virtual machines machines. This account will not be used for access.')
@minLength(12)
@secure()
param adminPassword string

@description('The Entra ID group/user object id (guid) that will be assigned as the admin users for all deployed virtual machines.')
@minLength(36)
param adminSecurityPrincipalObjectId string

@description('The principal type of the adminSecurityPrincipalObjectId ID.')
@allowed([
  'User'
  'Group'
])
param adminSecurityPrincipalType string

@description('A cloud init file (starting with #cloud-config) as a Base64 encoded string used to perform OS configuration on the VMs as part of bootstrapping. Used for network configuration in this context.')
@minLength(100)
param frontendCloudInitAsBase64 string

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
  name: 'rg-alz-bu04a42-compute-${location}'
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
    adminSecurityPrincipalObjectId: adminSecurityPrincipalObjectId
    adminSecurityPrincipalType: adminSecurityPrincipalType
    frontendCloudInitAsBase64: frontendCloudInitAsBase64
  }
  dependsOn: [
    applySubnetsAndUdrs
  ]
}

/*** OUTPUTS ***/

output frontendVmssResourceId string = deployWorkloadInfrastructure.outputs.frontendVmssResourceId

output backendVmssResourceId string = deployWorkloadInfrastructure.outputs.backendVmssResourceId
