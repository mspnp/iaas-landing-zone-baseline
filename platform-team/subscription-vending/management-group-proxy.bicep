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
    not all of the policies that your workload would be subject to under an "Online" (or "Corp") management
    group. For example, none of the custom Azure Landing Zone policies are deployed, and only a few select
    built-in ones are.
*/

param location string

/*** EXISITING SUBSCRIPTION RESOURCES ***/

@description('Built-in: No App Gateway without WAF.')
resource appGwShouldHaveWafEnabledPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  scope: subscription()
  name: '564feb30-bf6a-4854-b4bb-0d2d2d1e6c66'
}

@description('Built-in: Not allowed resources.')
resource notAllowedResourceTypesPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  scope: subscription()
  name: '6c112d4e-5bc7-47ae-a041-ea2d9dccd749'
}

@description('Built-in: Deny IP forwarding on NICs.')
resource denyIPForwardingPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '88c0b9da-ce96-4b03-9635-f29a937e2900'
}

@description('Built-in: Secure transfer to storage accounts should be enabled.')
resource secureStorageCommunicationPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '404c3081-a854-4457-ae30-26a93ef643f9'
}

@description('Built-in: NICs should not have public IPs.')
resource noPublicIpsOnNicsPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '83a86a26-fd1f-447c-b59d-e51f44264114'
}

@description('Built-in: No unmanaged virtual machine disks.')
resource noUnmanagedVirtualMachineDisksPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '06a78e20-9358-41c9-923c-fb736d382a4d'
}

@description('Built-in: Linux virtual machine scale sets should have Azure Monitor Agent installed')
resource noLinuxVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '32ade945-311e-4249-b8a4-a549924234d7'
}

@description('Built-in: Windows virtual machine scale sets should have Azure Monitor Agent installed')
resource noWindowsVirtualMachinesWithoutAzureMonitorAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '3672e6f7-a74d-4763-b138-fcf332042f8f'
}

@description('Built-in: Legacy Log Analytics extension should not be installed on Linux virtual machine scale sets.')
resource noLinuxVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '383c45fa-8b64-4d1c-aa9f-e69d2d879aa4'
}

@description('Built-in: Legacy Log Analytics extension should not be installed on Windows virtual machine scale sets.')
resource noWindowsVirtualMachinesWitLegacyLogAnayticsExtensionPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: 'ba6881f9-ab93-498b-8bad-bb91b1d755bf'
}

@description('Built-in: Azure Security agent should be installed on your Linux virtual machine scale sets.')
resource noLinuxVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '62b52eae-c795-44e3-94e8-1b3d264766fb'
}

@description('Built-in: Azure Security agent should be installed on your Windows virtual machine scale sets.')
resource noWindowsVirtualMachinesWithoutAzureSecurityAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: 'e16f967a-aa57-4f5e-89cd-8d1434d0a29a'
}

@description('Built-in: ChangeTracking extension should be installed on your Linux virtual machine scale sets.')
resource noLinuxVirtualMachinesWithoutChangeTrackingPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: 'e71c1e29-9c76-4532-8c4b-cb0573b0014c'
}

@description('Built-in: ChangeTracking extension should be installed on your Windows virtual machine scale sets.')
resource noWindowsVirtualMachinesWithoutChangeTrackingPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '4bb303db-d051-4099-95d2-e3e1428a4d00'
}

@description('Built-in: System updates on virtual machine scale sets should be installed.')
resource noVirtualMachinesWithoutSystemUpdatesPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: 'c3f317a7-a95c-4547-b7e7-11017ebdf2fe'
}

@description('Built-in: Vulnerabilities in security configuration on your virtual machine scale sets should be remediated.')
resource noVirtualMachinesWithVulnerabilitiesPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '3c735d8a-a4ba-4a3a-b7cf-db7754cf57f4'
}

@description('Built-in: Azure Backup should be enabled for Virtual Machines.')
resource noVirtualMachinesWithoutAzureBackupPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '013e242c-8828-4970-87b3-ab247555486d'
}

@description('Built-in: Network traffic data collection agent should be installed on Linux virtual machines.')
resource noLinuxVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '04c4380f-3fae-46e8-96c9-30193528f602'
}

@description('Built-in: Network traffic data collection agent should be installed on Windows virtual machines.')
resource noWindowsVirtualMachinesWithoutNetworkTrafficDataCollectionAgentPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '2f2ee1de-44aa-4762-b6bd-0893fc3f306d'
}

// Or TODO-CK: Managed disk access should be via private link: https://aka.ms/disksprivatelinksdoc
@description('Built-in: Managed disks should disable public network access.')
resource noManagedDisksWithPublicNetworkAccessPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing  = {
  scope: subscription()
  name: '8405fdab-1faf-48aa-b702-999c9c172094'
}

/*** POLICY ASSIGNMENTS ***/

@description('Consistent prefix on all assignments to facilitate deleting assignments in the cleanup process.')
var policyAssignmentNamePrefix = '[IaaS baseline Online] -'

@description('Deny deploying hybrid networking resources.')
resource noHybridNetworkingResourcesPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', notAllowedResourceTypesPolicyDefinition.id, resourceGroup().id)
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
    nonComplianceMessages: [
      {
        message: 'vWAN/ER/VPN gateway resources must not be deployed in the application landing zone.'
      }
    ]
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
    nonComplianceMessages: [
      {
        message: 'Web Application Firewall (WAF) must be enabled for Application Gateway.'
      }
    ]
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
    nonComplianceMessages: [
      {
        message: 'Network interfaces must disable IP forwarding.'
      }
    ]
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
    nonComplianceMessages: [
      {
        message: 'Secure transfer to storage accounts must be enabled.'
      }
    ]
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
    nonComplianceMessages: [
      {
        message: 'Network interfaces must not have a public IP associated.'
      }
    ]
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
    nonComplianceMessages: [
      {
        message: 'Virtual machines and virtual machine scales sets must use a managed disk.'
      }
    ]
  }
}

@description('Audit deploying public IP resources.')
resource auditPublicIpsPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('online management group', notAllowedResourceTypesPolicyDefinition.id, resourceGroup().id)
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
      listOfResourceTypesNotAllowed: {
        value: [
          'microsoft.network/publicipaddresses'
        ]
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
      listOfResourceTypesNotAllowed: {
        value: [
          'microsoft.network/publicipaddresses'
        ]
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

@description('Deny Internet access to managed disks.')
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
    overrides: [
      {
        kind: 'policyEffect'
        value: 'Deny'
      }
    ]
  }
}
