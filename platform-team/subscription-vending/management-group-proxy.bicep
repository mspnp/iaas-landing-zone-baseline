targetScope = 'resourceGroup'

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

    Also, please be aware that this deployment guide is only deploying a handful of common policies, this is
    about 20% all of the policies that your workload would be subject to under an "Online" (or "Corp") management
    group. For example, none of the custom Azure Landing Zone policies or policy initaitives are deployed.

    To see all 100+ of the policies recommended by Azure Landing Zone implementations, please see:
    https://github.com/Azure/Enterprise-Scale/wiki/ALZ-Policies
*/

param location string = resourceGroup().location

@description('The ID of the resource group that contains the private DNS zones. In this deployment, it\'s the hub resource group.')
param dnsZoneResourceGroupId string

/*** EXISITING TENANT RESOURCES ***/

@description('Built-in: No App Gateway without WAF.')
resource appGwShouldHaveWafEnabledPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  scope: tenant()
  name: '564feb30-bf6a-4854-b4bb-0d2d2d1e6c66'
}

@description('Built-in: Not allowed resources.')
resource notAllowedResourceTypesPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  scope: tenant()
  name: '6c112d4e-5bc7-47ae-a041-ea2d9dccd749'
}

@description('Built-in: Deny IP forwarding on NICs.')
resource denyIPForwardingPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '88c0b9da-ce96-4b03-9635-f29a937e2900'
}

@description('Built-in: Secure transfer to storage accounts should be enabled.')
resource secureStorageCommunicationPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '404c3081-a854-4457-ae30-26a93ef643f9'
}

@description('Built-in: NICs should not have public IPs.')
resource noPublicIpsOnNicsPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '83a86a26-fd1f-447c-b59d-e51f44264114'
}

@description('Built-in: No unmanaged virtual machine disks.')
resource noUnmanagedVirtualMachineDisksPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '06a78e20-9358-41c9-923c-fb736d382a4d'
}

@description('Built-in: Linux virtual machine scale sets should have Azure Monitor Agent installed')
resource noLinuxVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '32ade945-311e-4249-b8a4-a549924234d7'
}

@description('Built-in: Windows virtual machine scale sets should have Azure Monitor Agent installed')
resource noWindowsVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '3672e6f7-a74d-4763-b138-fcf332042f8f'
}

@description('Built-in: Legacy Log Analytics extension should not be installed on Linux virtual machine scale sets.')
resource noLinuxVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '383c45fa-8b64-4d1c-aa9f-e69d2d879aa4'
}

@description('Built-in: Legacy Log Analytics extension should not be installed on Windows virtual machine scale sets.')
resource noWindowsVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: 'ba6881f9-ab93-498b-8bad-bb91b1d755bf'
}

@description('Built-in: Azure Security agent should be installed on your Linux virtual machine scale sets.')
resource noLinuxVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '62b52eae-c795-44e3-94e8-1b3d264766fb'
}

@description('Built-in: Azure Security agent should be installed on your Windows virtual machine scale sets.')
resource noWindowsVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: 'e16f967a-aa57-4f5e-89cd-8d1434d0a29a'
}

@description('Built-in: ChangeTracking extension should be installed on your Linux virtual machine scale sets.')
resource noLinuxVirtualMachinesWithoutChangeTrackingPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: 'e71c1e29-9c76-4532-8c4b-cb0573b0014c'
}

@description('Built-in: ChangeTracking extension should be installed on your Windows virtual machine scale sets.')
resource noWindowsVirtualMachinesWithoutChangeTrackingPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '4bb303db-d051-4099-95d2-e3e1428a4d00'
}

@description('Built-in: System updates on virtual machine scale sets should be installed.')
resource noVirtualMachinesWithoutSystemUpdatesPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: 'c3f317a7-a95c-4547-b7e7-11017ebdf2fe'
}

@description('Built-in: Vulnerabilities in security configuration on your virtual machine scale sets should be remediated.')
resource noVirtualMachinesWithVulnerabilitiesPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '3c735d8a-a4ba-4a3a-b7cf-db7754cf57f4'
}

@description('Built-in: Azure Backup should be enabled for Virtual Machines.')
resource noVirtualMachinesWithoutAzureBackupPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '013e242c-8828-4970-87b3-ab247555486d'
}

@description('Built-in: Network traffic data collection agent should be installed on Linux virtual machines.')
resource noLinuxVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '04c4380f-3fae-46e8-96c9-30193528f602'
}

@description('Built-in: Network traffic data collection agent should be installed on Windows virtual machines.')
resource noWindowsVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '2f2ee1de-44aa-4762-b6bd-0893fc3f306d'
}

// TODO: Managed disk access should be via private link: https://aka.ms/disksprivatelinksdoc
@description('Built-in: Managed disks should disable public network access.')
resource noManagedDisksWithPublicNetworkAccessPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: '8405fdab-1faf-48aa-b702-999c9c172094'
}

@description('Built-in: DINE - Configure private DNS zone for Azure Key Vault.')
resource deployPrivateDnsForAzureKeyVaultPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: 'ac673a9a-f77d-4846-b2d8-a57f8e1c01d4'
}

@description('Built-in: DINE - Configure private DNS zone for managed Disk access.')
resource deployPrivateDnsForManagedDiskAccessPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: tenant()
  name: 'bc05b96c-0b36-4ca9-82f0-5c53f96ce05a'
}

/*** EXISITING SUBSCRIPTION RESOURCES ***/

@description('Existing resourse group that contains the Private DNS Zones expected to be used by application landing zones.')
resource privateDnsZoneResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription(split(dnsZoneResourceGroupId, '/')[2])
  name: split(dnsZoneResourceGroupId, '/')[4]
}

@description('Existing network contributor role.')
resource networkContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7'
}

@description('Existing managed identity that can update private DNS zones for PaaS services.')
resource privateDnsManagementIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: privateDnsZoneResourceGroup
  name: 'mi-privatednszoneadmin-dinepolicies'
}

/*** EXISTING PRIVATE DNS ZONES ***/

resource azureKeyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: privateDnsZoneResourceGroup
  name: 'privatelink.vaultcore.azure.net'
}

/*** POLICY ASSIGNMENTS ***/

@description('Consistent prefix on all assignments to facilitate deleting assignments in the cleanup process.')
var policyAssignmentNamePrefix = '[IaaS baseline Online] -'

@description('Deny deploying hybrid networking resources.')
resource noHybridNetworkingResourcesPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', 'nohybridnetworking', notAllowedResourceTypesPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} No hybrid connectivity resources allowed.', 120)
    description: take(notAllowedResourceTypesPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: notAllowedResourceTypesPolicyDefinition.id
    parameters: {
      effect: {
        value: 'Deny'
      }
      listOfResourceTypesNotAllowed: {
        value: [
          'microsoft.network/expressroutecircuits'
          'microsoft.network/expressroutegateways'
          'microsoft.network/expressrouteports'
          'microsoft.network/virtualwans'
          'microsoft.network/virtualhubs'
          'microsoft.network/vpngateways'
          'microsoft.network/p2svpngateways'
          'microsoft.network/vpnsites'
          'microsoft.network/virtualnetworkgateways'
        ]
      }
    }
  }
}

@description('Deny deploying Application Gateway without WAF.')
resource noAppGwWithoutWafPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', appGwShouldHaveWafEnabledPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${appGwShouldHaveWafEnabledPolicyDefinition.properties.displayName}', 120)
    description: take(appGwShouldHaveWafEnabledPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: appGwShouldHaveWafEnabledPolicyDefinition.id
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

@description('Deny deploying NICs with IP forwarding.')
resource noIpForwardingOnNicsPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', denyIPForwardingPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${denyIPForwardingPolicyDefinition.properties.displayName}', 120)
    description: take(denyIPForwardingPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: denyIPForwardingPolicyDefinition.id
    parameters: {}
  }
}

@description('Deny deploying storage accounts that support non-https communication.')
resource noHttpCommunicationOnStorageAccountsPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', secureStorageCommunicationPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${secureStorageCommunicationPolicyDefinition.properties.displayName}', 120)
    description: take(secureStorageCommunicationPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: secureStorageCommunicationPolicyDefinition.id
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

@description('Deny deploying NICs with public IPs.')
resource noPublicIpsOnNicsPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noPublicIpsOnNicsPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noPublicIpsOnNicsPolicyDefinition.properties.displayName}', 120)
    description: take(noPublicIpsOnNicsPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noPublicIpsOnNicsPolicyDefinition.id
    parameters: {}
  }
}

@description('Deny virtual machines with unmanaged disks.')
resource noUnmanagedVirtualMachineDisksPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noUnmanagedVirtualMachineDisksPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noUnmanagedVirtualMachineDisksPolicyDefinition.properties.displayName}', 120)
    description: take(noUnmanagedVirtualMachineDisksPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noUnmanagedVirtualMachineDisksPolicyDefinition.id
    parameters: {}
    overrides: [
      {
        kind: 'policyEffect'
        value: 'Deny'
      }
    ]
  }
}

@description('Audit deploying public IP resources.')
resource auditPublicIpsPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', 'nopublicips', notAllowedResourceTypesPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} Audit public IP usage in Online application landing zone.', 120)
    description: take(notAllowedResourceTypesPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: notAllowedResourceTypesPolicyDefinition.id
    parameters: {
      effect: {
        value: 'Audit'
      }
      listOfResourceTypesNotAllowed: {
        value: [
          'microsoft.network/publicipaddresses'
        ]
      }
    }
  }
}

@description('Audit Linux virtual machine scale sets should have Azure Monitor Agent installed.')
resource noLinuxVirtualMachinesWithoutAzureMonitorAgentPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noLinuxVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noLinuxVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition.properties.displayName}', 120)
    description: take(noLinuxVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noLinuxVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
      scopeToSupportedImages: {
        value: false
      }
    }
  }
}

@description('Audit Windows virtual machine scale sets should have Azure Monitor Agent installed.')
resource noWindowsVirtualMachinesWithoutAzureMonitorAgentPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noWindowsVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noWindowsVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition.properties.displayName}', 120)
    description: take(noWindowsVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noWindowsVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
      scopeToSupportedImages: {
        value: false
      }
    }
  }
}

@description('Deny legacy Log Analytics extension installed on Linux virtual machine scale sets.')
resource noLinuxVirtualMachinesWithLegacyLaAgentPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noLinuxVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noLinuxVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition.properties.displayName}', 120)
    description: take(noLinuxVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noLinuxVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition.id
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

@description('Deny legacy Log Analytics extension installed on Windows virtual machine scale sets.')
resource noWindowsVirtualMachinesWithLegacyLaAgentPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noWindowsVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noWindowsVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition.properties.displayName}', 120)
    description: take(noWindowsVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noWindowsVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition.id
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

@description('Audit Linux virtual machines without Azure Security agent.')
resource noLinuxVirtualMachinesWithoutAzureSecurityAgentPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noLinuxVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noLinuxVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition.properties.displayName}', 120)
    description: take(noLinuxVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noLinuxVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
    }
  }
}

@description('Audit Windows virtual machines without Azure Security agent.')
resource noWindowsVirtualMachinesWithoutAzureSecurityAgentPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noWindowsVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noWindowsVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition.properties.displayName}', 120)
    description: take(noWindowsVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noWindowsVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
    }
  }
}

@description('Audit Linux virtual machines without Change Tracking agent.')
resource noLinuxVirtualMachinesWithoutChangeTrackingPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noLinuxVirtualMachinesWithoutChangeTrackingPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noLinuxVirtualMachinesWithoutChangeTrackingPolicyDefinition.properties.displayName}', 120)
    description: take(noLinuxVirtualMachinesWithoutChangeTrackingPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noLinuxVirtualMachinesWithoutChangeTrackingPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
    }
  }
}

@description('Audit Windows virtual machines without Change Tracking agent.')
resource noWindowsVirtualMachinesWithoutChangeTrackingPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noWindowsVirtualMachinesWithoutChangeTrackingPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noWindowsVirtualMachinesWithoutChangeTrackingPolicyDefinition.properties.displayName}', 120)
    description: take(noWindowsVirtualMachinesWithoutChangeTrackingPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noWindowsVirtualMachinesWithoutChangeTrackingPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
    }
  }
}

@description('Audit virtual machines without system updates applied.')
resource noVirtualMachinesWithoutSystemUpdatesPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noVirtualMachinesWithoutSystemUpdatesPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noVirtualMachinesWithoutSystemUpdatesPolicyDefinition.properties.displayName}', 120)
    description: take(noVirtualMachinesWithoutSystemUpdatesPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noVirtualMachinesWithoutSystemUpdatesPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
    }
  }
}

@description('Audit virtual machines with vulnerabilities in security configuation applied.')
resource noVirtualMachinesWithSystemVulnerabilitiesPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noVirtualMachinesWithVulnerabilitiesPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noVirtualMachinesWithVulnerabilitiesPolicyDefinition.properties.displayName}', 120)
    description: take(noVirtualMachinesWithVulnerabilitiesPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noVirtualMachinesWithVulnerabilitiesPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
    }
  }
}

@description('Audit virtual machines without Azure Backup configuration applied.')
resource noVirtualMachinesWithoutAzureBackupPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noVirtualMachinesWithoutAzureBackupPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noVirtualMachinesWithoutAzureBackupPolicyDefinition.properties.displayName}', 120)
    description: take(noVirtualMachinesWithoutAzureBackupPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noVirtualMachinesWithoutAzureBackupPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
    }
  }
}

@description('Audit Linux virtual machines without Dependency Agent applied.')
resource noLinuxVirtualMachinesWithoutDependencyAgentPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noLinuxVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noLinuxVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition.properties.displayName}', 120)
    description: take(noLinuxVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noLinuxVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
    }
  }
}

@description('Audit Windows virtual machines without Dependency Agent applied.')
resource noWindowsVirtualMachinesWithoutDependencyAgentPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noWindowsVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noWindowsVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition.properties.displayName}', 120)
    description: take(noWindowsVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noWindowsVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition.id
    parameters: {
      effect: {
        value: 'AuditIfNotExists'
      }
    }
  }
}

@description('Audit Internet access to managed disks.')
resource noInternetAccessToManagedDisksPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', noManagedDisksWithPublicNetworkAccessPolicyDefinition.id, resourceGroup().id)
  location: location
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${noManagedDisksWithPublicNetworkAccessPolicyDefinition.properties.displayName}', 120)
    description: take(noManagedDisksWithPublicNetworkAccessPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: noManagedDisksWithPublicNetworkAccessPolicyDefinition.id
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

// Application landing zones are usually configured with DINE policies to configure Azure PaaS services
// to use private DNS zones in the hub. In the reference implementation for ALZ, this is done with a custom
// Policy Definition Set. For this reference implementation, we'll apply a few of the ones by hand that we
// use as part of the deployment.

@description('DINE - Configure private DNS zone for Azure Key Vault.')
resource configurePrivateDnsZoneForAzureKeyVaultPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', deployPrivateDnsForAzureKeyVaultPolicyDefinition.id, resourceGroup().id)
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${privateDnsManagementIdentity.id}': {}
    }
  }
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${deployPrivateDnsForAzureKeyVaultPolicyDefinition.properties.displayName}', 120)
    description: take(deployPrivateDnsForAzureKeyVaultPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: deployPrivateDnsForAzureKeyVaultPolicyDefinition.id
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      privateDnsZoneId: {
        value: azureKeyVaultPrivateDnsZone.id
      }
    }
  }
  dependsOn: [
    dineDnsPolicyAssignment
  ]
}

// TODO: validate if in scope
@description('DINE - Configure private DNS zone for managed disk access.')
resource configurePrivateDnsZoneForManagedDisksPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', deployPrivateDnsForManagedDiskAccessPolicyDefinition.id, resourceGroup().id)
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${privateDnsManagementIdentity.id}': {}
    }
  }
  properties: {
    displayName: take('${policyAssignmentNamePrefix} ${deployPrivateDnsForManagedDiskAccessPolicyDefinition.properties.displayName}', 120)
    description: take(deployPrivateDnsForManagedDiskAccessPolicyDefinition.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: deployPrivateDnsForManagedDiskAccessPolicyDefinition.id
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      privateDnsZoneId: {
        value: azureKeyVaultPrivateDnsZone.id
      }
    }
  }
  dependsOn: [
    dineDnsPolicyAssignment
  ]
}

@description('Ensure the managed identity for DINE policies in DNS can manage the zones.')
resource dineDnsPolicyAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, networkContributorRole.id, privateDnsManagementIdentity.id)
  properties: {
    principalId: privateDnsManagementIdentity.properties.principalId
    roleDefinitionId: networkContributorRole.id
    principalType: 'ServicePrincipal'
  }
}
