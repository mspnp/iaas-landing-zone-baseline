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

@description('The admin passwork for the Windows backend machines.')
@secure()
param adminPassword string

@description('A common uniquestring reference used for resources that benefit from having a unique component.')
@maxLength(13)
param subComputeRgUniqueString string

/*** VARIABLES ***/

var agwName = 'agw-${subComputeRgUniqueString}'
var lbName = 'ilb-${subComputeRgUniqueString}'

var defaultAdminUserName = uniqueString('vmss', subComputeRgUniqueString, resourceGroup().id)

/*** EXISTING SUBSCRIPTION RESOURCES ***/

@description('Built-in Azure RBAC role that is applied a Key Vault to grant with metadata, certificates, keys and secrets read privileges. Granted to App Gateway\'s managed identity.')
resource keyVaultReaderRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '21090545-7ca7-4776-b22c-e363652d74d2'
  scope: subscription()
}

@description('Built-in Azure RBAC role that is applied to a Key Vault to grant with secrets content read privileges. Granted to both Key Vault and our workload\'s identity.')
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
  scope: subscription()
}

@description('Existing resource group that holds our application landing zone\'s network.')
resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(targetVnetResourceId, '/')[4]
}

@description('Existing resource group that has our regional hub network. This is owned by the platform team, and usually is in another subscription.')
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: 'rg-plz-connectivity-regional-hubs'
}

/*** EXISTING RESOURCES ***/

@description('Existing log sink for the workload.')
resource workloadLogAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: 'log-${subComputeRgUniqueString}'
}

@description('Private DNS zone for Key Vault in the Hub. This is owned by the platform team.')
resource keyVaultDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: hubResourceGroup
  name: 'privatelink.vaultcore.azure.net'
}

@description('TEMP: TODO-CK: Provide a solution.')
resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  scope: hubResourceGroup
  name: 'vnet-${location}-hub'
}

@description('The existing public IP address to be used by Application Gateway for public ingress.')
resource appGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2022-11-01' existing = {
  scope: spokeResourceGroup
  name: 'pip-bu04a42-00'
}

// Spoke virtual network
@description('Existing spoke virtual network, as deployed by the platform team into our landing zone and with subnets added by the workload team.')
resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
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
resource asgVmssFrontend 'Microsoft.Network/applicationSecurityGroups@2022-11-01' existing = {
  scope: spokeResourceGroup
  name: 'asg-frontend'
}

@description('Application security group for the backend compute.')
resource asgVmssBackend 'Microsoft.Network/applicationSecurityGroups@2022-11-01' existing = {
  scope: spokeResourceGroup
  name: 'asg-backend'
}

/*** RESOURCES ***/

@description('Azure WAF policy to apply to our workload\'s inbound traffic.')
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-11-01' = {
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
  name: 'mi-vm-frontent'
  location: location
}

@description('The managed identity for all backend virtual machines.')
resource miVmssBackend 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-vm-backent'
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
            name: 'nic-frontend'
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
                    workloadKeyVault::kvsWorkloadPublicAndPrivatePublicCerts.properties.secretUri
                  ]
                  pollingIntervalInS: '3600'
                }
                /* TODO-CK: Where is the managed identity selection? */
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
                // TODO-CK: This won't work on 'internal', so temp moved to base64
                // commandToExecute: 'sh configure-nginx-frontend.sh'
                // The following installs and configure Nginx for the frontend Linux machine, which is used as an application stand-in for this reference implementation. Using the CustomScript extension can be useful for bootstrapping VMs in leu of a larger DSC solution, but is generally not recommended for application deployment in production environments.
                //fileUris: [
                //  'https://raw.githubusercontent.com/mspnp/iaas-landing-zone-baseline/content-pass/workload-team/workload/configure-nginx-frontend.sh'
                //]
                script: 'H4sIAAAAAAACA7VU22rcMBB991dMk8AmEFtJmz60SQohbCHkUsimhVKKkeWxLaKVjDR7cdP8e0f25tIQ6I36QcLSzJmjM0dafyEKbUUhQ5Mk63Ds2g4mwYBCTwEq76Zwit0nOTOU4LJ1nmDy+fzs5OI0Px5fXl0cnY8PNzbDrHRgAoi59MLoQiykrNGSONfKu+Aqyo6+zTxmd1jZhJxHAd+h9thCqiEdw1q2cP7aOFmm7awwWqWt13NJmEY2axzcoCwh3d1K+oKuRRuY6/L1zhuGsH9cfuPm6VluIXUzAoGkBEOLXgZha22XXIC5hsAzobfSpFrKcL9KJmTK08/MfJD/idhKmd+mdo1d7O/HtuQskC2BkqrBbODL/2mNBLN+Owae2EDSGLiI+E+i9Gov7aAvPxjHVrrmowwZsNDUgHeOoOUTbwNz3o7tM7zgXYGAtmwd890GaUvwOEcfMO4tu0RJgnfDWfsCImjCkKKVhcFSVM4vpC/h4ADGH94nAT0nw00C/BkdCC3s7b2KJff7tSEgt3KK0dGskS3TnZ3ssUiZ4nXuCM/TVVYweWy/rrSKmv29J57Fy7kj/9TOB1QWjZxyfP+uzibz3WHM7uaX+8mgjOOy2rEZV1LFr9c7b2UI0BC14a3gp0Bd/0IgsX8PEGZFXmnDPGH05U7cryMYbWw2LlDUfGv0XHjurEJwVTVs3j4heQiiknPNRTMeHjHGaUtdXuvqAVQqxQRz4+rHeLdJNAdb8xLZrvxuDcYkfqj4hQFqECwuQK2M25cdfB469tBUEd/fVWrfliz6SCtMfgAd7CO5NAUAAA=='
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
    kvMiVmssFrontendSecretsUserRole_roleAssignment
    kvMiVmssFrontendKeyVaultReader_roleAssignment
    peKv::pdnszg
    contosoPrivateDnsZone::vmssBackend
    contosoPrivateDnsZone::vnetlnk
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
                // TODO-CK: This won't work on 'internal', so temp moved to blob
                fileUris: [
                  'https://pnpgithubfuncst.blob.core.windows.net/temp/configure-nginx-backend.ps1'
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
        ]
      }
    }
  }
  dependsOn: [
    kvMiVmssBackendSecretsUserRole_roleAssignment
    peKv::pdnszg
    contosoPrivateDnsZone::vmssBackend
    contosoPrivateDnsZone::vnetlnk
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
    publicNetworkAccess: 'Enabled' //  TODO-CK: this doesn't seem to be working as 'Disabled', but this resource should be configured as disabled.
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
  name: guid(resourceGroup().id, 'mi-vm-frontent', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miVmssFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Vmss Frontend managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.')
resource kvMiVmssFrontendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: workloadKeyVault
  name: guid(resourceGroup().id, 'mi-vm-frontent', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miVmssFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the backend compute managed identity with Key Vault secrets role permissions; this allows pulling frontend and backend certificates.')
resource kvMiVmssBackendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: workloadKeyVault
  name: guid(resourceGroup().id, 'mi-vm-backent', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miVmssBackend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the backend compute managed identity with Key Vault reader role permissions; this allows pulling frontend and backend certificates.')
resource kvMiVmssBackendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: workloadKeyVault
  name: guid(resourceGroup().id, 'mi-vm-backent', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miVmssBackend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource peKv 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: 'pe-${workloadKeyVault.name}'
  location: location
  properties: {
    subnet: {
      id: spokeVirtualNetwork::snetPrivatelinkendpoints.id
    }
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

  // THIS IS BEING DONE FOR SIMPLICTY IN DEPLOYMENT, NOT AS GUIDANCE.
  // Normally a workload team wouldn't have this permission, and a DINE policy
  // would have taken care of this step.
  resource pdnszg 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-akv-net'
          properties: {
            privateDnsZoneId: keyVaultDnsZone.id
          }
        }
      ]
    }
  }
}

@description('A private DNS zone for iaas-ingress.contoso.com')
resource contosoPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'iaas-ingress.${domainName}'
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

  // TODO-CK: This is going to need to be solved. As this is configured below, it will not work in this topology.
  // THIS IS BEING DONE FOR SIMPLICTY IN DEPLOYMENT, NOT AS GUIDANCE.
  // Normally a workload team wouldn't have this permission, and a DINE policy
  // would have taken care of this step.
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

  resource linkToHub 'virtualNetworkLinks' = {
    name: 'to_${hubVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: hubVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

@description('The Azure Application Gateway that fronts our workload.')
resource workloadAppGateway 'Microsoft.Network/applicationGateways@2022-11-01' = {
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
          hostName: domainName
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
    peKv
    kvMiAppGatewayFrontendKeyVaultReader_roleAssignment
    kvMiAppGatewayFrontendSecretsUserRole_roleAssignment
  ]
}

@description('Internal load balancer that sits between the front end and back end compute.')
resource loadBalancer 'Microsoft.Network/loadBalancers@2022-11-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'backend'
        properties: {
          subnet: {
            id: spokeVirtualNetwork::snetInternalLoadBalancer.id
          }
          privateIPAddress: '10.240.4.4'
          privateIPAllocationMethod: 'Static'
          privateIPAddressVersion: 'IPv4'
        }
        zones: [
          '1'
          '2'
          '3'
        ]
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
    
/*** OUTPUTS ***/

output keyVaultName string = workloadKeyVault.name
