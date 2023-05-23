targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke VNet Resource ID that will host the VM\'s NIC')
@minLength(79)
param targetVnetResourceId string

@description('IaaS region. This needs to be the same region as the vnet provided in these parameters.')
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
param location string = 'eastus2'

@description('The certificate data for app gateway TLS termination. It is base64 encoded')
param appGatewayListenerCertificate string

@description('The Base64 encoded Vmss Webserver public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
param vmssWildcardTlsPublicCertificate string

@description('The Base64 encoded Vmss Webserver public and private certificates (formatterd as .pem or .pfx) to be stored in Azure Key Vault as secret and downloaded into the frontend and backend Vmss instances for the workloads ssl certificate configuration.')
param vmssWildcardTlsPublicAndKeyCertificates string

@description('Domain name to use for App Gateway and Vmss Webserver.')
param domainName string = 'contoso.com'

@description('A cloud init file (starting with #cloud-config) as a base 64 encoded string used to perform image customization on the jump box VMs. Used for user-management in this context.')
@minLength(100)
param frontendCloudInitAsBase64 string

@description('A cloud init file (starting with #cloud-config) as a base 64 encoded string used to perform image customization on the jump box VMs. Used for user-management in this context.')
@minLength(100)
param backendCloudInitAsBase64 string

@description('The admin passwork for the Windows backend machines.')
@secure()
param adminPassword string

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('vmss', subscription().subscriptionId, resourceGroup().id)
var vmssName = 'vmss-${subRgUniqueString}'
var agwName = 'agw-${vmssName}'
var lbName = 'ilb-${vmssName}'

var ingressDomainName = 'iaas-ingress.${domainName}'
var vmssBackendSubdomain = 'bu0001a0008-00-backend'
var vmssFrontendSubdomain = 'bu0001a0008-00-frontend'
var vmssFrontendDomainName = '${vmssFrontendSubdomain}.${ingressDomainName}'

var defaultAdminUserName = uniqueString(vmssName, resourceGroup().id)

/*** EXISTING SUBSCRIPTION RESOURCES ***/

// Built-in Azure RBAC role that is applied a Key Vault to grant with metadata, certificates, keys and secrets read privileges.  Granted to App Gateway's managed identity.
resource keyVaultReaderRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '21090545-7ca7-4776-b22c-e363652d74d2'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a Key Vault to grant with secrets content read privileges. Granted to both Key Vault and our workload's identity.
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a Log Anlytics Workspace to grant with contrib access privileges. Granted to both frontend and backend user managed identities.
resource logAnalyticsContributorUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
  scope: subscription()
}

/*** EXISTING RESOURCES ***/

// Spoke resource group
resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: '${split(targetVnetResourceId,'/')[4]}'
}

// Spoke virtual network
resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  scope: targetResourceGroup
  name: '${last(split(targetVnetResourceId,'/'))}'

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

// Log Analytics Workspace
resource la 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  scope: resourceGroup()
  name: 'la-${vmssName}'
}

// Default ASG on the vmss frontend. Feel free to constrict further.
resource asgVmssFrontend 'Microsoft.Network/applicationSecurityGroups@2022-07-01' existing = {
  scope: targetResourceGroup
  name: 'asg-frontend'
}

// Default ASG on the vmss backend. Feel free to constrict further.
resource asgVmssBackend 'Microsoft.Network/applicationSecurityGroups@2022-07-01' existing = {
  scope: targetResourceGroup
  name: 'asg-backend'
}

/*** RESOURCES ***/

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-05-01' = {
  name: 'waf-${vmssName}'
  location: location
  properties: {
    policySettings: {
      fileUploadLimitInMb: 10
      state: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
            ruleSetType: 'OWASP'
            ruleSetVersion: '3.2'
            ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '0.1'
          ruleGroupOverrides: []
        }
      ]
    }
  }
}

// User Managed Identity that App Gateway is assigned. Used for Azure Key Vault Access.
resource miAppGatewayFrontend 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-appgateway'
  location: location
}

@description('The managed identity for frontend instances')
resource miVmssFrontend 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-vm-frontent'
  location: location
}

@description('The managed identity for backend instances')
resource miVmssBackend 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-vm-backent'
  location: location
}

@description('The compute for frontend instances; these machines are assigned to the frontend app team to deploy their workloads')
resource vmssFrontend 'Microsoft.Compute/virtualMachineScaleSets@2022-11-01' = {
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
          ssh: {
            publicKeys: [
              {
                path: '/home/${defaultAdminUserName}/.ssh/authorized_keys'
                keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcFvQl2lYPcK1tMB3Tx2R9n8a7w5MJCSef14x0ePRFr9XISWfCVCNKRLM3Al/JSlIoOVKoMsdw5farEgXkPDK5F+SKLss7whg2tohnQNQwQdXit1ZjgOXkis/uft98Cv8jDWPbhwYj+VH/Aif9rx8abfjbvwVWBGeA/OnvfVvXnr1EQfdLJgMTTh+hX/FCXCqsRkQcD91MbMCxpqk8nP6jmsxJBeLrgfOxjH8RHEdSp4fF76YsRFHCi7QOwTE/6U+DpssgQ8MTWRFRat97uTfcgzKe5MOfuZHZ++5WFBgaTr1vhmSbXteGiK7dQXOk2cLxSvKkzeaiju9Jy6hoSl5oMygUVd5fNPQ94QcqTkMxZ9tQ9vPWOHwbdLRD31Ses3IBtDV+S6ehraiXf/L/e0jRUYk8IL/J543gvhOZ0hj2sQqTj9XS2hZkstZtrB2ywrJzV5ByETUU/oF9OsysyFgnaQdyduVqEPHaqXqnJvBngqqas91plyT3tSLMez3iT0s= unused-generated-by-azure'
              }
            ]
          }
        }
        customData: frontendCloudInitAsBase64
        adminUsername: defaultAdminUserName
      }
      storageProfile: {
        osDisk: {
          diffDiskSettings: {
            option: 'Local'
            placement: 'ResourceDisk'
          }
          caching: 'ReadOnly'
          createOption: 'FromImage'
        }
        imageReference: {
          publisher: 'Canonical'
          offer: 'UbuntuServer'
          sku: '18.04-LTS'
          version: 'latest'
        }
      }
      networkProfile: {
        networkApiVersion: '2020-11-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-vnet-spoke-BU0001A0008-00-frontend'
            properties: {
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
                    subnet: {
                      id: targetVirtualNetwork::snetFrontend.id
                    }
                    applicationGatewayBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwName, 'webappBackendPool')
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
            name: 'KeyVaultForLinux'
            properties: {
              publisher: 'Microsoft.Azure.KeyVault'
              type: 'KeyVaultForLinux'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                secretsManagementSettings: {
                  certificateStoreLocation: '/var/lib/waagent/Microsoft.Azure.KeyVault.Store'
                  observedCertificates: [
                    kv::kvsWorkloadPublicAndPrivatePublicCerts.properties.secretUri
                  ]
                  pollingIntervalInS: '3600'
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
                // The following installs and configure Nginx for the frontend Linux machine, which is used as an application stand-in for this reference implementation. Using the CustomScript extension can be useful for bootstrapping VMs in leu of a larger DSC solution, but is generally not recommended for application deployment in production environments.
                fileUris: [
                  'https://raw.githubusercontent.com/mspnp/iaas-baseline/main/configure-nginx-frontend.sh'
                ]
              }
            }
          }
          {
            name: 'AzureMonitorLinuxAgent'
            properties: {
              publisher: 'Microsoft.Azure.Monitor'
              type: 'AzureMonitorLinuxAgent'
              typeHandlerVersion: '1.25'
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
    agw
    omsVmssInsights
    kvMiVmssFrontendSecretsUserRole_roleAssignment
    kvMiVmssFrontendKeyVaultReader_roleAssignment
  ]


}

@description('The compute for backend instances; these machines are assigned to the api app team so they can deploy their workloads.')
resource vmssBackend 'Microsoft.Compute/virtualMachineScaleSets@2022-11-01' = {
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
              rebootSetting: 'IfRequired'
            }
            assessmentMode: 'ImageDefault'
            enableHotpatching: true
          }
        }
        customData: backendCloudInitAsBase64
        adminUsername: defaultAdminUserName
        adminPassword: adminPassword
        secrets: []
        allowExtensionOperations: true
      }
      storageProfile: {
        osDisk: {
          osType: 'Windows'
          diffDiskSettings: {
            option: 'Local'
            placement: 'ResourceDisk'
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
          sku: '2022-datacenter-azure-edition-core-smalldisk'
          version: 'latest'
          exactVersion: '20348.1668.230404'
        }
        dataDisks: [
          {
            caching: 'None'
            createOption: 'Empty'
            deleteOption: 'Delete'
            diskSizeGB: 4
            lun: 0
            managedDisk: {
              storageAccountType: 'Premium_LRS'
            }
          }

        ]
      }
      networkProfile: {
        networkApiVersion: '2020-11-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-vnet-spoke-BU0001A0008-00-backend'
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
                    subnet: {
                      id: targetVirtualNetwork::snetBackend.id
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'apiBackendPool')
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
            name: 'KeyVaultForWindows'
            properties: {
              publisher: 'Microsoft.Azure.KeyVault'
              type: 'KeyVaultForWindows'
              typeHandlerVersion: '3.0'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              settings: {
                secretsManagementSettings: {
                  observedCertificates: [
                    {
                      certificateStoreName: 'MY'
                      certificateStoreLocation: 'LocalMachine'
                      keyExportable: true
                      url: kv::kvsWorkloadPublicAndPrivatePublicCerts.properties.secretUri
                      accounts: [
                        'Network Service'
                        'Local Service'
                      ]
                    }
                  ]
                  linkOnRenewal: true
                  pollingIntervalInS: '3600'
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
                // The following installs and configure Nginx for the backend Windows machine, which is used as an application stand-in for this reference implementation. Using the CustomScript extension can be useful for bootstrapping VMs in leu of a larger DSC solution, but is generally not recommended for application deployment in production environments.
                fileUris: [
                  'https://raw.githubusercontent.com/mspnp/iaas-baseline/main/configure-nginx-backend.ps1'
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

          /*
          {
            name: 'WindowsOpenSSH'
            properties: {
              autoUpgradeMinorVersion: true
              publisher: 'Microsoft.Azure.OpenSSH'
              type: 'WindowsOpenSSH'
              typeHandlerVersion: '3.0'
              settings: {}
            }
          }
          */
        ]
      }
    }
  }
  dependsOn: [
    omsVmssInsights
    loadBalancer
    kvMiVmssBackendSecretsUserRole_roleAssignment
  ]
}

resource omsVmssInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'VMInsights(${la.name})'
  location: location
  properties: {
    workspaceResourceId: la.id
  }
  plan: {
    name: 'VMInsights(${la.name})'
    product: 'OMSGallery/VMInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'kv-${vmssName}'
  location: location
  properties: {
    accessPolicies: [] // Azure RBAC is used instead
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices' // Required for AppGW communication
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
  dependsOn: [
    miAppGatewayFrontend
  ]

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

resource kv_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: kv
  name: 'default'
  properties: {
    workspaceId: la.id
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

// Grant the Azure Application Gateway managed identity with key vault secrets role permissions; this allows pulling frontend and backend certificates.
resource kvMiAppGatewayFrontendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-appgateway', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.
resource kvMiAppGatewayFrontendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-appgateway', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Vmss Frontend managed identity with key vault secrets role permissions; this allows pulling frontend and backend certificates.
resource kvMiVmssFrontendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-vm-frontent', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miVmssFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Vmss Frontend managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.
resource kvMiVmssFrontendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-vm-frontent', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miVmssFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Vmss Frontend managed identity with Log Analytics Contributor role permissions; this allows pushing data with the Azure Monitor Agent to Log Analytics.
resource laMiVmssFrontendContributorUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-vm-frontent', logAnalyticsContributorUserRole.id)
  properties: {
    roleDefinitionId: logAnalyticsContributorUserRole.id
    principalId: miVmssFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Vmss Backend managed identity with key vault secrets role permissions; this allows pulling frontend and backend certificates.
resource kvMiVmssBackendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-vm-backent', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miVmssBackend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Vmss Backend managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.
resource kvMiVmssBackendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-vm-backent', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miVmssBackend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Vmss Backend managed identity with Log Analytics Contributor role permissions; this allows pushing data with the Azure Monitor Agent to Log Analytics.
resource laMiVmssBackendContributorUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-vm-backent', logAnalyticsContributorUserRole.id)
  properties: {
    roleDefinitionId: logAnalyticsContributorUserRole.id
    principalId: miVmssBackend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Enabling Azure Key Vault Private Link support.
resource pdzKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'

  // Enabling Azure Key Vault Private Link on vmss vnet.
  resource vnetlnk 'virtualNetworkLinks' = {
    name: 'to_${targetVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: targetVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource peKv 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-${kv.name}'
  location: location
  properties: {
    subnet: {
      id: targetVirtualNetwork::snetPrivatelinkendpoints.id
    }
    privateLinkServiceConnections: [
      {
        name: 'to_${targetVirtualNetwork.name}'
        properties: {
          privateLinkServiceId: kv.id
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
            privateDnsZoneId: pdzKv.id
          }
        }
      ]
    }
  }
}

resource pdzVmss 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: ingressDomainName
  location: 'global'

  resource vmssBackendDomainName_bu0001a0008_00 'A' = {
    name: vmssBackendSubdomain
    properties: {
      ttl: 3600
      aRecords: [
        {
          ipv4Address: '10.240.4.4' // Internal Load Balancer IP address
        }
      ]
    }
  }

  resource vnetlnk 'virtualNetworkLinks' = {
    name: 'to_${targetVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: targetVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource agw 'Microsoft.Network/applicationGateways@2021-05-01' = {
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
      policyType: 'Custom'
      cipherSuites: [
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
      ]
      minProtocolVersion: 'TLSv1_2'
    }
    trustedRootCertificates: [
      {
        name: 'root-cert-wildcard-vmss-webserver'
        properties: {
          keyVaultSecretId: kv::kvsAppGwInternalVmssWebserverTls.properties.secretUri
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: 'agw-ip-configuration'
        properties: {
          subnet: {
            id: targetVirtualNetwork::snetApplicationGateway.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'agw-frontend-ip-configuration'
        properties: {
          publicIPAddress: {
            id: resourceId(subscription().subscriptionId, targetResourceGroup.name, 'Microsoft.Network/publicIpAddresses', 'pip-BU0001A0008-00')
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port-443'
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
    sslCertificates: [
      {
        name: '${agwName}-ssl-certificate'
        properties: {
          keyVaultSecretId: kv::kvsGatewayPublicCert.properties.secretUri
        }
      }
    ]
    probes: [
      {
        name: 'probe-${vmssFrontendDomainName}'
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
        name: 'webappBackendPool'
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'vmss-webserver-backendpool-httpsettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: vmssFrontendDomainName
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', agwName, 'probe-${vmssFrontendDomainName}')
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
        name: 'listener-https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agwName, 'agw-frontend-ip-configuration')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agwName, 'port-443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', agwName, '${agwName}-ssl-certificate')
          }
          hostName: domainName
          hostNames: []
          requireServerNameIndication: true
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'agw-routing-rules'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', agwName, 'listener-https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwName, 'webappBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', agwName, 'vmss-webserver-backendpool-httpsettings')
          }
        }
      }
    ]
  }
  dependsOn: [
    peKv
    kvMiAppGatewayFrontendKeyVaultReader_roleAssignment
    kvMiAppGatewayFrontendSecretsUserRole_roleAssignment
  ]
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        properties: {
          subnet: {
            id: targetVirtualNetwork::snetInternalLoadBalancer.id
          }
          privateIPAddress: '10.240.4.4'
          privateIPAllocationMethod: 'Static'
        }
        name: 'ilbBackend'
        zones: [
          '1'
          '2'
          '3'
        ]
      }
    ]
    backendAddressPools: [
      {
        name: 'apiBackendPool'
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', lbName, 'ilbBackend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'apiBackendPool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'ilbprobe')
          }
          protocol: 'Tcp'
          frontendPort: 443
          backendPort: 443
          idleTimeoutInMinutes: 15
        }
        name: 'ilbrule'
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: 'ilbprobe'
      }
    ]
  }
  dependsOn: []
}

/*** OUTPUTS ***/
output keyVaultName string = kv.name
