targetScope = 'subscription'

/*** PARAMETERS ***/

@allowed([
  'brazilsouth'    // paired to: southcentralus which also supports availability zones
  'centralus'      // paired to: eastus2 which also supports availability zones
  'eastasia'       // paired to: southeastasia' which also supports availability zones
  'eastus'         // paired to: westus which also supports availability zones
  'eastus2'        // paired to: centralus which also supports availability zones
  'northcentralus' // paired to: southcentralus which also supports availability zones
  'northeurope'    // paired to: westeurope which also supports availability zones
  'southcentralus' // paired to: northcentralus which also supports availability zones
  'southeastasia'  // paired to: eastasia which also supports availability zones
  'westeurope'     // paired to: northeurope which also supports availability zones
  'westus'         // paired to: eastus which also supports availability zones
  'westus3'        // paired to: eastus which also supports availability zones

  // The following regions all support availability zones, but their paired regions do not.
  // Consider your architectral impact in selecting one of these regions in a failover situation.
  // 'australiaeast'      // paired to: australiasoutheast which doesn't support availability zones
  // 'canadacentral'      // paired to: canadaeast which doesn't support availability zones
  // 'westus2'            // paired to: westcentralus which doesn't support availability zones
  // 'francecentral'      // paired to: francesouth which doesn't support availability zones
  // 'germanywestcentral' // paired to: germanynorth which doesn't support availability zones
  // 'southafricanorth'   // paired to: southafericawest which doesn't support availability zones
  // 'swedencentral'      // paired to: swedensouth which doesn't support availability zones
  // 'uksouth'            // paired to: ukwest which doesn't support availability zones
  // 'japaneast'          // paired to: japanwest which doesn't support availability zones
  // 'centralindia'       // paired to: southindia which doesn't support availability zones
  // 'koreacentral'       // paired to: koreasouth which doesn't support availability zones
  // 'norwayeast'         // paired to: norwaywest which doesn't support availability zones
  // 'switzerlandnorth'   // paired to: switzerlandwest which doesn't support availability zones
  // 'uaenorth'           // paired to: uaecentral which doesn't support availability zones  
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

@description('The admin password for the virtual machines machines. This account will not be used for access.')
@minLength(12)
@secure()
param adminPassword string

@description('The Azure Active Directory group/user object id (guid) that will be assigned as the admin users for all deployed virtual machines.')
@minLength(36)
param adminAadSecurityPrincipalObjectId string

@description('The principal type of the adminAadSecurityPrincipalObjectId ID.')
@allowed([
  'User'
  'Group'
])
param adminAddSecurityPrincipalType string

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
    adminAadSecurityPrincipalObjectId: adminAadSecurityPrincipalObjectId
    adminAddSecurityPrincipalType: adminAddSecurityPrincipalType
  }
  dependsOn: [
    applySubnetsAndUdrs
  ]
}

/*** OUTPUTS ***/

output frontendVmssResourceId string = deployWorkloadInfrastructure.outputs.frontendVmssResourceId

output backendVmssResourceId string = deployWorkloadInfrastructure.outputs.backendVmssResourceId
