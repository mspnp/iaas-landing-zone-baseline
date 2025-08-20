targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke virtual network resource ID that will host the VM\'s NIC')
@minLength(79)
param targetVnetResourceId string

@description('IaaS region. This needs to be the same region as the virtual network provided in these parameters.')
param location string = resourceGroup().location

@description('The certificate data for Azure Application Gateway TLS termination. It is Base64 encoded.')
@secure()
param appGatewayListenerCertificate string

@description('The Base64 encoded VMSS web server public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
param vmssWildcardTlsPublicCertificate string

@description('The Base64 encoded VMSS web server public and private certificates (formatterd as .pem or .pfx) to be stored in Azure Key Vault as secret and downloaded into the frontend and backend Vmss instances for the workloads ssl certificate configuration.')
@secure()
param vmssWildcardTlsPublicAndKeyCertificates string

@description('The admin password for the Windows backend machines.')
@minLength(12)
@secure()
param adminPassword string

@description('A common uniquestring reference used for resources that benefit from having a unique component.')
@maxLength(13)
param subComputeRgUniqueString string

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

var agwName = 'agw-public-ingress'
var lbName = 'ilb-backend'

var defaultAdminUserName = uniqueString('vmss', subComputeRgUniqueString, resourceGroup().id)

/*** EXISTING SUBSCRIPTION RESOURCES ***/

@description('Built-in Azure RBAC role that is applied a Key Vault to grant with metadata, certificates, keys and secrets read privileges. Granted to App Gateway\'s managed identity.')
resource keyVaultReaderRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '21090545-7ca7-4776-b22c-e363652d74d2'
}

@description('Built-in Azure RBAC role that is applied to a Key Vault to grant with secrets content read privileges. Granted to both Key Vault and our workload\'s identity.')
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

@description('Built-in Azure RBAC role that is applied to the virtual machines to grant remote user access to them via SSH or RDP. Granted to the provided group object id.')
resource virtualMachineAdminLoginRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '1c0163c0-47e6-4577-8991-ea5c82e286e4'
}

@description('Existing resource group that holds our application landing zone\'s network.')
resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(targetVnetResourceId, '/')[4]
}

@description('Existing resource group that has our regional hub network. This is owned by the platform team, and usually is in another subscription.')
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: 'rg-plz-connectivity-regional-hubs-${location}'
}

/*** EXISTING RESOURCES ***/

@description('Existing log sink for the workload.')
resource workloadLogAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: 'log-${subComputeRgUniqueString}'
}

@description('The existing public IP address to be used by Application Gateway for public ingress.')
resource appGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' existing = {
  scope: spokeResourceGroup
  name: 'pip-bu04a42-00'
}

// Spoke virtual network
@description('Existing spoke virtual network, as deployed by the platform team into our landing zone and with subnets added by the workload team.')
resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  scope: spokeResourceGroup
  name: last(split(targetVnetResourceId, '/'))

  // Spoke virtual network's subnet for the nic vms
  resource snetFrontend 'subnets' existing = {
    name: 'snet-frontend'
  }

  // Spoke virtual network's subnet for the nic vms
  resource snetBackend 'subnets' existing = {
    name: 'snet-backend'
  }

  // Spoke virtual network's subnet for the nic ilb
  resource snetInternalLoadBalancer 'subnets' existing = {
    name: 'snet-ilbs'
  }

  // Spoke virtual network's subnet for all private endpoints
  resource snetPrivatelinkendpoints 'subnets' existing = {
    name: 'snet-privatelinkendpoints'
  }

  // Spoke virtual network's subnet for application gateway
  resource snetApplicationGateway 'subnets' existing = {
    name: 'snet-applicationgateway'
  }
}

@description('Application security group for the frontend compute.')
resource asgVmssFrontend 'Microsoft.Network/applicationSecurityGroups@2024-07-01' existing = {
  scope: spokeResourceGroup
  name: 'asg-frontend'
}

@description('Application security group for the backend compute.')
resource asgVmssBackend 'Microsoft.Network/applicationSecurityGroups@2024-07-01' existing = {
  scope: spokeResourceGroup
  name: 'asg-backend'
}

@description('Application security group for the backend compute.')
resource asgKeyVault 'Microsoft.Network/applicationSecurityGroups@2024-07-01' existing = {
  scope: spokeResourceGroup
  name: 'asg-keyvault'
}

/*** RESOURCES ***/

@description('Sets up the provided group object id to have access to SSH or RDP into all virtual machines with the Entra ID login extension installed in this resource group.')
resource grantAdminRbacAccessToRemoteIntoVMs 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, adminSecurityPrincipalObjectId, virtualMachineAdminLoginRole.id)
  properties: {
    principalId: adminSecurityPrincipalObjectId
    roleDefinitionId: virtualMachineAdminLoginRole.id
    principalType: adminSecurityPrincipalType
    description: 'Allows all users in this group access to log into virtual machines that use the Entra ID login extension.'
  }
}

@description('Azure WAF policy to apply to our workload\'s inbound traffic.')
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-07-01' = {
  name: 'waf-ingress-policy'
  location: location
  properties: {
    policySettings: {
      fileUploadLimitInMb: 10
      state: 'Enabled'
      mode: 'Prevention'
      customBlockResponseBody: null
      customBlockResponseStatusCode: null
      fileUploadEnforcement: true
      logScrubbing: {
        state: 'Disabled'
        scrubbingRules: []
      }
      maxRequestBodySizeInKb: 128
      requestBodyCheck: true
      requestBodyEnforcement: true
      requestBodyInspectLimitInKB: 128
    }
    managedRules: {
      exclusions: []
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
        }
      ]
    }
  }
}

@description('User Managed Identity that App Gateway is assigned. Used for Azure Key Vault Access.')
resource miAppGatewayFrontend 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-appgateway'
  location: location
}

@description('The managed identity for all frontend virtual machines.')
resource miVmssFrontend 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-vm-frontend'
  location: location
}

@description('The managed identity for all backend virtual machines.')
resource miVmssBackend 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-vm-backend'
  location: location
}

@description('The virtual machines for the frontend. Orchestrated by a Virtual Machine Scale Set with flexible orchestration.')
resource vmssFrontend 'Microsoft.Compute/virtualMachineScaleSets@2023-03-01' = {
  name: 'vmss-frontend-00'
  location: location
  zones: pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, 3)
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miVmssFrontend.id}': {}
    }
  }
  sku: {
    name: 'Standard_D4s_v3'
    tier: 'Standard'
    capacity: 3
  }
  properties: {
    singlePlacementGroup: false
    additionalCapabilities: {
      ultraSSDEnabled: false
    }
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    zoneBalance: false
    virtualMachineProfile: {
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
      osProfile: {
        computerNamePrefix: 'frontend'
        linuxConfiguration: {
          disablePasswordAuthentication: true
          provisionVMAgent: true
          patchSettings: {
            assessmentMode: 'ImageDefault'
            automaticByPlatformSettings: {
              bypassPlatformSafetyChecksOnUserSchedule: false
              rebootSetting: 'IfRequired'
            }
            patchMode: 'AutomaticByPlatform'
          }
          ssh: {
            publicKeys: [
              {
                path: '/home/${defaultAdminUserName}/.ssh/authorized_keys'
                keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcFvQl2lYPcK1tMB3Tx2R9n8a7w5MJCSef14x0ePRFr9XISWfCVCNKRLM3Al/JSlIoOVKoMsdw5farEgXkPDK5F+SKLss7whg2tohnQNQwQdXit1ZjgOXkis/uft98Cv8jDWPbhwYj+VH/Aif9rx8abfjbvwVWBGeA/OnvfVvXnr1EQfdLJgMTTh+hX/FCXCqsRkQcD91MbMCxpqk8nP6jmsxJBeLrgfOxjH8RHEdSp4fF76YsRFHCi7QOwTE/6U+DpssgQ8MTWRFRat97uTfcgzKe5MOfuZHZ++5WFBgaTr1vhmSbXteGiK7dQXOk2cLxSvKkzeaiju9Jy6hoSl5oMygUVd5fNPQ94QcqTkMxZ9tQ9vPWOHwbdLRD31Ses3IBtDV+S6ehraiXf/L/e0jRUYk8IL/J543gvhOZ0hj2sQqTj9XS2hZkstZtrB2ywrJzV5ByETUU/oF9OsysyFgnaQdyduVqEPHaqXqnJvBngqqas91plyT3tSLMez3iT0s= unused-generated-by-azure'
              }
            ]
          }
        }
        adminUsername: defaultAdminUserName
        customData: frontendCloudInitAsBase64
      }
      storageProfile: {
        osDisk: {
          osType: 'Linux'
          diffDiskSettings: {
            option: 'Local'
            placement: 'CacheDisk'
          }
          diskSizeGB: 30
          caching: 'ReadOnly'
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-focal'
          sku: '20_04-lts-gen2'
          version: 'latest'
        }
        dataDisks: [
          {
            caching: 'None'
            createOption: 'Empty'
            deleteOption: 'Delete'
            diskSizeGB: 4
            lun: 0
            managedDisk: {
              storageAccountType: 'Premium_ZRS'
            }
          }
        ]
      }
      networkProfile: {
        networkApiVersion: '2020-11-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-frontend'
            properties: {
              primary: true
              enableIPForwarding: false
              enableAcceleratedNetworking: false
              networkSecurityGroup: null
              deleteOption: 'Delete'
              ipConfigurations: [
                {
                  name: 'default'
                  properties: {
                    primary: true
                    privateIPAddressVersion: 'IPv4'
                    publicIPAddressConfiguration: null
                    subnet: {
                      id: spokeVirtualNetwork::snetFrontend.id
                    }
                    loadBalancerBackendAddressPools: []
                    applicationGatewayBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', workloadAppGateway.name, 'vmss-frontend')
                      }
                    ]
                    applicationSecurityGroups: [
                      {
                        id: asgVmssFrontend.id
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'AzureMonitorLinuxAgent'
            properties: {
              publisher: 'Microsoft.Azure.Monitor'
              type: 'AzureMonitorLinuxAgent'
              typeHandlerVersion: '1.26'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                authentication: {
                  managedIdentity: {
                    'identifier-name': 'mi_res_id'
                    'identifier-value': miVmssFrontend.id
                  }
                }
              }
            }
          }
          {
            name: 'ChangeTracking-Linux'
            properties: {
              provisionAfterExtensions: [
                'AzureMonitorLinuxAgent'
              ]
              publisher: 'Microsoft.Azure.ChangeTrackingAndInventory'
              type: 'ChangeTracking-Linux'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: false
            }
          }
          {
            name: 'DependencyAgentLinux'
            properties: {
              provisionAfterExtensions: [
                'AzureMonitorLinuxAgent'
              ]
              publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
              type: 'DependencyAgentLinux'
              typeHandlerVersion: '9.10'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                enableAMA: true
              }
            }
          }
          {
            name: 'NetworkWatcherAgentLinux'
            properties: {
              provisionAfterExtensions: [
                'DependencyAgentLinux'
              ]
              publisher: 'Microsoft.Azure.NetworkWatcher'
              type: 'NetworkWatcherAgentLinux'
              typeHandlerVersion: '1.4'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
            }
          }
          {
            name: 'AADSSHLogin'
            properties: {
              provisionAfterExtensions: [
                'NetworkWatcherAgentLinux'
                'CustomScript'
              ]
              publisher: 'Microsoft.Azure.ActiveDirectory'
              type: 'AADSSHLoginForLinux'
              typeHandlerVersion: '1.0'
              autoUpgradeMinorVersion: true
            }
          }
          {
            name: 'KeyVaultForLinux'
            properties: {
              publisher: 'Microsoft.Azure.KeyVault'
              type: 'KeyVaultForLinux'
              typeHandlerVersion: '2.2'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                secretsManagementSettings: {
                  certificateStoreLocation: '/var/lib/waagent/Microsoft.Azure.KeyVault.Store'
                  observedCertificates: [
                    workloadKeyVault::kvsWorkloadPublicAndPrivatePublicCerts.properties.secretUri
                  ]
                  requireInitialSync: true  // Ensures all certs have been downloaded before the extension is considered installed
                  pollingIntervalInS: '3600'
                }
                authenticationSettings: {
                  msiClientId: miVmssFrontend.properties.clientId
                }
              }
            }
          }
          {
            name: 'CustomScript'
            properties: {
              provisionAfterExtensions: [
                'KeyVaultForLinux'
              ]
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.1'
              autoUpgradeMinorVersion: true
              protectedSettings: {
                commandToExecute: 'sh configure-nginx-frontend.sh'
                // The following installs and configure Nginx for the frontend Linux machine, which is used as an application stand-in for this reference implementation.
                // Using the CustomScript extension can be useful for bootstrapping VMs in leu of a larger DSC solution, but is generally not recommended for application deployment.
                fileUris: [
                  'https://raw.githubusercontent.com/mspnp/iaas-landing-zone-baseline/main/workload-team/workload/configure-nginx-frontend.sh'
                ]
              }
            }
          }
          {
            name: 'HealthExtension'
            properties: {
              provisionAfterExtensions: [
                'CustomScript'
              ]
              publisher: 'Microsoft.ManagedServices'
              type: 'ApplicationHealthLinux'
              typeHandlerVersion: '1.0'  // In 2.x, you need to hit an endpoint that returns { "ApplicationHealthState": "Healthy" } or { "ApplicationHealthState": "Unhealthy" }
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                protocol: 'https'
                port: 443
                requestPath: '/favicon.ico'
                intervalInSeconds: 5
                numberOfProbes: 3
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    kvMiVmssFrontendSecretsUserRole_roleAssignment
    kvMiVmssFrontendKeyVaultReader_roleAssignment
    peKv
    contosoPrivateDnsZone::vmssBackend
    contosoPrivateDnsZone::vnetlnk
    grantAdminRbacAccessToRemoteIntoVMs
  ]
}

@description('The virtual machines for the backend. Orchestrated by a Virtual Machine Scale Set with flexible orchestration.')
resource vmssBackend 'Microsoft.Compute/virtualMachineScaleSets@2023-03-01' = {
  name: 'vmss-backend-00'
  location: location
  zones: pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, 3)
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miVmssBackend.id}': {}
    }
  }
  sku: {
    name: 'Standard_E2s_v3'
    tier: 'Standard'
    capacity: 3
  }
  properties: {
    singlePlacementGroup: false
    additionalCapabilities: {
      ultraSSDEnabled: false
    }
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    zoneBalance: false
    virtualMachineProfile: {
      securityProfile: {
        securityType: 'TrustedLaunch'
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
          /* TODO: Why not to our own storage account? */
        }
      }
      osProfile: {
        computerNamePrefix: 'backend'
        windowsConfiguration: {
          provisionVMAgent: true
          enableAutomaticUpdates: true
          patchSettings: {
            patchMode: 'AutomaticByPlatform'
            automaticByPlatformSettings: {
              bypassPlatformSafetyChecksOnUserSchedule: false
              rebootSetting: 'IfRequired'
            }
            assessmentMode: 'ImageDefault'
            enableHotpatching: false
          }
        }
        adminUsername: defaultAdminUserName
        adminPassword: adminPassword
        secrets: [] // Uses the Key Vault extension instead
        allowExtensionOperations: true
      }
      storageProfile: {
        osDisk: {
          osType: 'Windows'
          diffDiskSettings: {
            option: 'Local'
            placement: 'CacheDisk'
          }
          caching: 'ReadOnly'
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
          deleteOption: 'Delete'
          diskSizeGB: 30
        }
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: '2022-datacenter-azure-edition-smalldisk'
          version: 'latest'
        }
        dataDisks: [
          {
            caching: 'None'
            createOption: 'Empty'
            deleteOption: 'Delete'
            diskSizeGB: 4
            lun: 0
            managedDisk: {
              storageAccountType: 'Premium_ZRS'
            }
          }
        ]
      }
      networkProfile: {
        networkApiVersion: '2020-11-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-backend'
            properties: {
              deleteOption: 'Delete'
              primary: true
              enableIPForwarding: false
              enableAcceleratedNetworking: false
              networkSecurityGroup: null
              ipConfigurations: [
                {
                  name: 'default'
                  properties: {
                    primary: true
                    privateIPAddressVersion: 'IPv4'
                    publicIPAddressConfiguration: null
                    applicationGatewayBackendAddressPools: []
                    subnet: {
                      id: spokeVirtualNetwork::snetBackend.id
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancer.name, 'vmss-backend')
                      }
                    ]
                    applicationSecurityGroups: [
                      {
                        id: asgVmssBackend.id
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'AADLogin'
            properties: {
              provisionAfterExtensions: [
                'CustomScript'
              ]
              autoUpgradeMinorVersion: true
              publisher: 'Microsoft.Azure.ActiveDirectory'
              type: 'AADLoginForWindows'
              typeHandlerVersion: '2.0'
              settings: {
                mdmId: ''
              }
            }
          }
          {
            name: 'KeyVaultForWindows'
            properties: {
              publisher: 'Microsoft.Azure.KeyVault'
              type: 'KeyVaultForWindows'
              typeHandlerVersion: '3.1'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                secretsManagementSettings: {
                  observedCertificates: [
                    {
                      certificateStoreName: 'MY'
                      certificateStoreLocation: 'LocalMachine'
                      keyExportable: true
                      url: workloadKeyVault::kvsWorkloadPublicAndPrivatePublicCerts.properties.secretUri
                      accounts: [
                        'Network Service'
                        'Local Service'
                      ]
                    }
                  ]
                  linkOnRenewal: true
                  pollingIntervalInS: '3600'
                }
                authenticationSettings: {
                  msiEndpoint: 'http://169.254.169.254/metadata/identity/oauth2/token'
                  msiClientId: miVmssBackend.properties.clientId
                }
              }
            }
          }
          {
            name: 'CustomScript'
            properties: {
              provisionAfterExtensions: [
                'KeyVaultForWindows'
              ]
              publisher: 'Microsoft.Compute'
              type: 'CustomScriptExtension'
              typeHandlerVersion: '1.10'
              autoUpgradeMinorVersion: true
              protectedSettings: {
                commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File configure-nginx-backend.ps1'
                // The following installs and configure Nginx for the backend Windows machine, which is used as an application stand-in for this reference implementation.
                // Using the CustomScript extension can be useful for bootstrapping VMs in leu of a larger DSC solution, but is generally not recommended for application deployments.
                fileUris: [
                  'https://raw.githubusercontent.com/mspnp/iaas-landing-zone-baseline/main/workload-team/workload/configure-nginx-backend.ps1'
                ]
              }
            }
          }

          {
            name: 'AzureMonitorWindowsAgent'
            properties: {
              publisher: 'Microsoft.Azure.Monitor'
              type: 'AzureMonitorWindowsAgent'
              typeHandlerVersion: '1.14'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                authentication: {
                  managedIdentity: {
                    'identifier-name': 'mi_res_id'
                    'identifier-value': miVmssBackend.id
                  }
                }
              }
            }
          }
          {
            name: 'ChangeTracking-Windows'
            properties: {
              provisionAfterExtensions: [
                'AzureMonitorWindowsAgent'
              ]
              publisher: 'Microsoft.Azure.ChangeTrackingAndInventory'
              type: 'ChangeTracking-Windows'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: false
            }
          }
          {
            name: 'DependencyAgentWindows'
            properties: {
              provisionAfterExtensions: [
                'AzureMonitorWindowsAgent'
              ]
              publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
              type: 'DependencyAgentWindows'
              typeHandlerVersion: '9.10'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                enableAMA: true
              }
            }
          }

          {
            name: 'ApplicationHealthWindows'
            properties: {
              provisionAfterExtensions: [
                'CustomScript'
              ]
              publisher: 'Microsoft.ManagedServices'
              type: 'ApplicationHealthWindows'
              typeHandlerVersion: '1.0'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                protocol: 'https'
                port: 443
                requestPath: '/favicon.ico'
                intervalInSeconds: 5
                numberOfProbes: 3
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    kvMiVmssBackendSecretsUserRole_roleAssignment
    peKv
    contosoPrivateDnsZone::vmssBackend
    contosoPrivateDnsZone::vnetlnk
    grantAdminRbacAccessToRemoteIntoVMs
  ]
}

@description('Common Key Vault used for all resources in this architecture that are owned by the workload team. Starts with no secrets/keys.')
resource workloadKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-${subComputeRgUniqueString}'
  location: location
  properties: {
    accessPolicies: [] // Azure RBAC is used instead
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices' // Required for ARM deployments to set secrets
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    createMode: 'default'
  }

  resource kvsAppGwInternalVmssWebserverTls 'secrets' = {
    name: 'appgw-vmss-webserver-tls'
    properties: {
      value: vmssWildcardTlsPublicCertificate
    }
  }

  resource kvsGatewayPublicCert 'secrets' = {
    name: 'gateway-public-cert'
    properties: {
      value: appGatewayListenerCertificate
    }
  }

  resource kvsWorkloadPublicAndPrivatePublicCerts 'secrets' = {
    name: 'workload-public-private-cert'
    properties: {
      value: vmssWildcardTlsPublicAndKeyCertificates
      contentType: 'application/x-pkcs12'
    }
  }
}

@description('Azure Diagnostics for Key Vault.')
resource kv_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: workloadKeyVault
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('Grant the Azure Application Gateway managed identity with key vault secrets role permissions; this allows pulling frontend and backend certificates.')
resource kvMiAppGatewayFrontendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: workloadKeyVault
  name: guid(resourceGroup().id, 'mi-appgateway', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.')
resource kvMiAppGatewayFrontendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: workloadKeyVault
  name: guid(resourceGroup().id, 'mi-appgateway', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Vmss Frontend managed identity with key vault secrets role permissions; this allows pulling frontend and backend certificates.')
resource kvMiVmssFrontendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: workloadKeyVault
  name: guid(resourceGroup().id, 'mi-vm-frontend', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miVmssFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Vmss Frontend managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.')
resource kvMiVmssFrontendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: workloadKeyVault
  name: guid(resourceGroup().id, 'mi-vm-frontend', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miVmssFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the backend compute managed identity with Key Vault secrets role permissions; this allows pulling frontend and backend certificates.')
resource kvMiVmssBackendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: workloadKeyVault
  name: guid(resourceGroup().id, 'mi-vm-backend', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miVmssBackend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the backend compute managed identity with Key Vault reader role permissions; this allows pulling frontend and backend certificates.')
resource kvMiVmssBackendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: workloadKeyVault
  name: guid(resourceGroup().id, 'mi-vm-backend', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miVmssBackend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Private Endpoint for Key Vault. All compute in the virtual network will use this endpoint.')
resource peKv 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: 'pe-${workloadKeyVault.name}'
  location: location
  properties: {
    subnet: {
      id: spokeVirtualNetwork::snetPrivatelinkendpoints.id
    }
    customNetworkInterfaceName: 'nic-pe-${workloadKeyVault.name}'
    applicationSecurityGroups: [
      {
        id: asgKeyVault.id
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'to_${spokeVirtualNetwork.name}'
        properties: {
          privateLinkServiceId: workloadKeyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }

  // The DNS zone group for this is deployed to the hub via the DINE policy that is applied
  // at via our imposed management groups (in this reference implementation, faked by being applied
  // directly on our resource group to limit impact to the rest of your sandbox subscription).
  // TODO: Evaluate impact on guidance.
}

// Application Gateway does not inhert the virtual network DNS settings for the parts of the service that
// are responsible for getting Key Vault certs connected at resource deployment time, but it does for other parts
// of the service. To that end, we have a local private DNS zone that is in place just to support Application Gateway.
// No other resources in this virtual network benefit from this.  If this is ever resolved both keyVaultSpokeDnsZone and
// peKeyVaultForAppGw can be removed.
@description('Deploy Key Vault private DNS zone so that Application Gateway can resolve at resource deployment time.')
resource keyVaultSpokeDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  properties: {}

  resource spokeLink 'virtualNetworkLinks' = {
    name: 'link-to-${spokeVirtualNetwork.name}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: spokeVirtualNetwork.id
      }
    }
  }
}

@description('Private Endpoint for Key Vault exclusively for the use of Application Gateway, which doesn\'t seem to pick up on DNS settings for Key Vault access.')
resource peKeyVaultForAppGw 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: 'pe-${workloadKeyVault.name}-appgw'
  location: location
  properties: {
    subnet: {
      id: spokeVirtualNetwork::snetPrivatelinkendpoints.id
    }
    customNetworkInterfaceName: 'nic-pe-${workloadKeyVault.name}-for-appgw'
    applicationSecurityGroups: [
      {
        id: asgKeyVault.id
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'to_${spokeVirtualNetwork.name}_for_appgw'
        properties: {
          privateLinkServiceId: workloadKeyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }

  resource pdnszg 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-akv-net'
          properties: {
            privateDnsZoneId: keyVaultSpokeDnsZone.id
          }
        }
      ]
    }
  }

  dependsOn: [
    peKv    // Deploying both endpoints at the same time can cause ConflictErrors
  ]
}

@description('A private DNS zone for iaas-ingress.contoso.com')
resource contosoPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'iaas-ingress.contoso.com'
  location: 'global'

  resource vmssBackend 'A' = {
    name: 'backend-00'
    properties: {
      ttl: 3600
      aRecords: [
        {
          ipv4Address: loadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress // 10.240.4.4 - Internal Load Balancer IP address
        }
      ]
    }
  }

  resource vnetlnk 'virtualNetworkLinks' = {
    name: 'to_${spokeVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: spokeVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

@description('The Azure Application Gateway that fronts our workload.')
resource workloadAppGateway 'Microsoft.Network/applicationGateways@2024-07-01' = {
  name: agwName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miAppGatewayFrontend.id}': {}
    }
  }
  zones: pickZones('Microsoft.Network', 'applicationGateways', location, 3)
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    sslPolicy: {
      policyType: 'Predefined'
      policyName: 'AppGwSslPolicy20220101S'
    }
    trustedRootCertificates: [
      {
        name: 'root-cert-wildcard-vmss-webserver'
        properties: {
          keyVaultSecretId: workloadKeyVault::kvsAppGwInternalVmssWebserverTls.properties.secretUri
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: 'ingress-into-${spokeVirtualNetwork::snetApplicationGateway.name}'
        properties: {
          subnet: {
            id: spokeVirtualNetwork::snetApplicationGateway.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'public-ip'
        properties: {
          publicIPAddress: {
            id: appGatewayPublicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'https'
        properties: {
          port: 443
        }
      }
    ]
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    firewallPolicy: {
      id: wafPolicy.id
    }
    enableHttp2: false
    rewriteRuleSets: []
    redirectConfigurations: []
    privateLinkConfigurations: []
    urlPathMaps: []
    listeners: []
    sslProfiles: []
    trustedClientCertificates: []
    loadDistributionPolicies: []
    sslCertificates: [
      {
        name: 'public-gateway-cert'
        properties: {
          keyVaultSecretId: workloadKeyVault::kvsGatewayPublicCert.properties.secretUri
        }
      }
    ]
    probes: [
      {
        name: 'vmss-frontend'
        properties: {
          protocol: 'Https'
          path: '/favicon.ico'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {}
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'vmss-frontend'
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'vmss-webserver'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: 'frontend-00.${contosoPrivateDnsZone.name}'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
          probeEnabled: true
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', agwName, 'vmss-frontend')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', agwName, 'root-cert-wildcard-vmss-webserver')
            }
          ]
        }
      }
    ]
    httpListeners: [
      {
        name: 'https-public-ip'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agwName, 'public-ip')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agwName, 'https')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', agwName, 'public-gateway-cert')
          }
          hostName: 'contoso.com'
          requireServerNameIndication: true
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'https-to-vmss-frontend'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', agwName, 'https-public-ip')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwName, 'vmss-frontend')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', agwName, 'vmss-webserver')
          }
        }
      }
    ]
  }
  dependsOn: [
    contosoPrivateDnsZone::vnetlnk
    contosoPrivateDnsZone::vmssBackend
    peKv
    peKeyVaultForAppGw::pdnszg
    keyVaultSpokeDnsZone::spokeLink
    kvMiAppGatewayFrontendKeyVaultReader_roleAssignment
    kvMiAppGatewayFrontendSecretsUserRole_roleAssignment
  ]
}

@description('Azure Diagnostics for Application Gateway.')
resource workloadAppGateway_Diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: workloadAppGateway
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('Internal load balancer that sits between the front end and back end compute.')
resource loadBalancer 'Microsoft.Network/loadBalancers@2024-07-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'backend'
        zones: pickZones('Microsoft.Network', 'publicIPAddresses', location, 3)
        properties: {
          subnet: {
            id: spokeVirtualNetwork::snetInternalLoadBalancer.id
          }
          privateIPAddress: '10.240.4.4'
          privateIPAllocationMethod: 'Static'
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'vmss-backend'
      }
    ]
    loadBalancingRules: [
      {
        name: 'https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', lbName, 'backend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'vmss-backend')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'vmss-backend-probe')
          }
          protocol: 'Tcp'
          frontendPort: 443
          backendPort: 443
          idleTimeoutInMinutes: 15
          enableFloatingIP: false
          enableTcpReset: false
          disableOutboundSnat: false
          loadDistribution: 'Default'
        }
      }
    ]
    probes: [
      {
        name: 'vmss-backend-probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
          probeThreshold: 1
        }
      }
    ]
  }
}

@description('Azure Diagnostics for Internal Load Balancer.')
resource workloadLoadBalancer_Diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: loadBalancer
  name: 'default'
  properties: {
    workspaceId: workloadLogAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

/*** OUTPUTS ***/

output keyVaultName string = workloadKeyVault.name

output frontendVmssResourceId string = vmssFrontend.id

output backendVmssResourceId string = vmssBackend.id
