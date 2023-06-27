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

/*** VARIABLES ***/

@description('Consistent prefix on all assignments to facilitate deleting assignments in the cleanup process.')
var policyAssignmentNamePrefix = '[IaaS baseline bu04a42] -'

/*** EXISTING RESOURCES ***/

@description('Built-in Monitoring Contributor Azure RBAC role.')
resource monitoringContributorRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
}

@description('Built-in Log Analytics Contributor Azure RBAC role.')
resource logAnalyticsContributorRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
}

@description('Built-in: Deploy Data Collection Rule for Linux virtual machines.')
resource configureLinuxMachinesWithDataCollectionRulePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  scope: tenant()
  name: '2ea82cdd-f2e8-4500-af75-67a2e084ca74'
}

@description('Built-in: Deploy Data Collection Rule for Windows virtual machines.')
resource configureWindowsMachinesWithDataCollectionRulePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  scope: tenant()
  name: 'eab1f514-22e3-42e3-9a1f-e1dc9199355c'
}

/*** RESOURCES ***/

@description('Common log sink across all resources in this architecture that are owned by the workload team.')
resource workloadLogAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
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

@description('Enable the change tracking features of Azure Monitor')
resource vmChangeTrackingTables 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'ChangeTracking(${workloadLogAnalytics.name})'
  location: location
  plan: {
    name: 'ChangeTracking(${workloadLogAnalytics.name})'
    publisher: 'Microsoft'
    promotionCode: ''
    product: 'OMSGallery/ChangeTracking'
  }
  properties: {
    workspaceResourceId: workloadLogAnalytics.id
  }
}

@description('Data collection rule for Windows virtual machines.')
resource windowsVmDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcrWindowsEventsAndMetrics'
  location: location
  kind: 'Windows'
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'VMInsightsPerfCounters'
          samplingFrequencyInSeconds: 60
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          counterSpecifiers: [
            '\\VmInsights\\DetailedMetrics'
          ]
        }
      ]
      extensions: [
        {
          name: 'CTDataSource-Windows'
          extensionName: 'ChangeTracking-Windows'
          streams: [
            'Microsoft-ConfigurationChange'
            'Microsoft-ConfigurationChangeV2'
            'Microsoft-ConfigurationData'
          ]
          extensionSettings: {
            enableFiles: true
            enableSoftware: true
            enableRegistry: true
            enableServices: true
            enableInventory: true
            registrySettings: {
              registryCollectionFrequency: 3000
              registryInfo: [
                {
                  name: 'Registry_1'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Group Policy\\Scripts\\Startup'
                  valueName: ''
                }
                {
                  name: 'Registry_2'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Group Policy\\Scripts\\Shutdown'
                  valueName: ''
                }
                {
                  name: 'Registry_3'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Run'
                  valueName: ''
                }
                {
                  name: 'Registry_4'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Active Setup\\Installed Components'
                  valueName: ''
                }
                {
                  name: 'Registry_5'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Classes\\Directory\\ShellEx\\ContextMenuHandlers'
                  valueName: ''
                }
                {
                  name: 'Registry_6'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Classes\\Directory\\Background\\ShellEx\\ContextMenuHandlers'
                  valueName: ''
                }
                {
                  name: 'Registry_7'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Classes\\Directory\\Shellex\\CopyHookHandlers'
                  valueName: ''
                }
                {
                  name: 'Registry_8'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ShellIconOverlayIdentifiers'
                  valueName: ''
                }
                {
                  name: 'Registry_9'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ShellIconOverlayIdentifiers'
                  valueName: ''
                }
                {
                  name: 'Registry_10'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Browser Helper Objects'
                  valueName: ''
                }
                {
                  name: 'Registry_11'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Browser Helper Objects'
                  valueName: ''
                }
                {
                  name: 'Registry_12'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Internet Explorer\\Extensions'
                  valueName: ''
                }
                {
                  name: 'Registry_13'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Microsoft\\Internet Explorer\\Extensions'
                  valueName: ''
                }
                {
                  name: 'Registry_14'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Drivers32'
                  valueName: ''
                }
                {
                  name: 'Registry_15'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Microsoft\\Windows NT\\CurrentVersion\\Drivers32'
                  valueName: ''
                }
                {
                  name: 'Registry_16'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\KnownDlls'
                  valueName: ''
                }
                {
                  name: 'Registry_17'
                  groupTag: 'Recommended'
                  enabled: false
                  recurse: true
                  description: ''
                  keyName: 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\\Notify'
                  valueName: ''
                }
              ]
            }
            fileSettings: {
              fileCollectionFrequency: 2700
            }
            softwareSettings: {
              softwareCollectionFrequency: 1800
            }
            inventorySettings: {
              inventoryCollectionFrequency: 36000
            }
            servicesSettings: {
              serviceCollectionFrequency: 1800
            }
          }
        }
        {
          streams: [
            'Microsoft-ServiceMap'
          ]
          extensionName: 'DependencyAgent'
          name: 'DependencyAgentDataSource'
          extensionSettings: {}
        }
      ]
      windowsEventLogs: [
        {
          name: 'eventLogsDataSource'
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'Application!*[System[(Level=1 or Level=2 or Level=3 or Level=4 or Level=0)]]'
            'Security!*[System[(band(Keywords,13510798882111488))]]'
            'System!*[System[(Level=1 or Level=2 or Level=3 or Level=4 or Level=0)]]'
          ]
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-ConfigurationChange'
          'Microsoft-ConfigurationChangeV2'
          'Microsoft-ConfigurationData'
        ]
        destinations: [
          workloadLogAnalytics.name
        ]
      }
      {
        streams: [
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          workloadLogAnalytics.name
        ]
      }
      {
        streams: [
          'Microsoft-Event'
        ]
        destinations: [
          workloadLogAnalytics.name
        ]
        transformKql: 'source'
        outputStream: 'Microsoft-Event'
      }
      {
        streams: [
          'Microsoft-ServiceMap'
        ]
        destinations: [
          workloadLogAnalytics.name
        ]
      }
    ]
    destinations: {
      azureMonitorMetrics: {
        name: 'azureMonitorMetrics-default'
      }
      logAnalytics: [
        {
          name: workloadLogAnalytics.name
          workspaceResourceId: workloadLogAnalytics.id
        }
      ]
    }
    description: 'Default data collection rule for Windows virtual machine.'
  }
}

@description('Add data collection rules to Windows virtual machines.')
resource configureWindowsMachinesWithDataCollectionRulePolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('workload', 'dca-windows', configureWindowsMachinesWithDataCollectionRulePolicy.id, resourceGroup().id)
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: take('${policyAssignmentNamePrefix} Configure Windows virtual machines with data collection rules', 120)
    description: take(configureWindowsMachinesWithDataCollectionRulePolicy.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: configureWindowsMachinesWithDataCollectionRulePolicy.id
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      dcrResourceId: {
        value: windowsVmDataCollectionRule.id
      }
      resourceType: {
        value: windowsVmDataCollectionRule.type
      }
    }
  }
}

@description('Ensure the managed identity for DCR DINE policies is has needed permissions.')
resource dineWindowsDcrPolicyLogAnalyticsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, logAnalyticsContributorRole.id, configureWindowsMachinesWithDataCollectionRulePolicyAssignment.id)
  properties: {
    principalId: configureWindowsMachinesWithDataCollectionRulePolicyAssignment.identity.principalId
    roleDefinitionId: logAnalyticsContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

@description('Ensure the managed identity for DCR DINE policies is has needed permissions.')
resource dineWindowsDcrPolicyMonitoringContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, monitoringContributorRole.id, configureWindowsMachinesWithDataCollectionRulePolicyAssignment.id)
  properties: {
    principalId: configureWindowsMachinesWithDataCollectionRulePolicyAssignment.identity.principalId
    roleDefinitionId: monitoringContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

@description('Data collection rule for Linux virtual machines.')
resource linuxVmDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcrLinuxSyslogAndMetrics'
  location: location
  kind: 'Linux'
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'VMInsightsPerfCounters'
          samplingFrequencyInSeconds: 60
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          counterSpecifiers: [
            '\\VmInsights\\DetailedMetrics'
          ]
        }
      ]
      extensions: [
        {
          name: 'CTDataSource-Linux'
          extensionName: 'ChangeTracking-Linux'
          streams: [
            'Microsoft-ConfigurationChange'
            'Microsoft-ConfigurationChangeV2'
            'Microsoft-ConfigurationData'
          ]
          extensionSettings: {
            enableFiles: true
            enableSoftware: true
            enableRegistry: false
            enableServices: true
            enableInventory: true
            fileSettings: {
              fileCollectionFrequency: 900
              fileInfo: [
                {
                  name: 'ChangeTrackingLinuxPath_default'
                  enabled: true
                  destinationPath: '/etc/.*.conf'
                  useSudo: true
                  recurse: true
                  maxContentsReturnable: 5000000
                  pathType: 'File'
                  type: 'File'
                  links: 'Follow'
                  maxOutputSize: 500000
                  groupTag: 'Recommended'
                }
              ]
            }
            softwareSettings: {
              softwareCollectionFrequency: 300
            }
            inventorySettings: {
              inventoryCollectionFrequency: 36000
            }
            servicesSettings: {
              serviceCollectionFrequency: 300
            }
          }
        }
        {
          name: 'DependencyAgentDataSource'
          extensionName: 'DependencyAgent'
          streams: [
            'Microsoft-ServiceMap'
          ]
          extensionSettings: {}
        }
      ]
      syslog: [
        {
          name: 'eventLogsDataSource-info'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
          ]
          logLevels: [
            'Info'
            'Notice'
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
        {
          name: 'eventLogsDataSource-notice'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'cron'
            'daemon'
            'mark'
            'kern'
            'local0'
            'local1'
            'local2'
            'local3'
            'local4'
            'local5'
            'local6'
            'local7'
            'lpr'
            'mail'
            'news'
            'syslog'
            'user'
            'uucp'
          ]
          logLevels: [
            'Notice'
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-ConfigurationChange'
          'Microsoft-ConfigurationChangeV2'
          'Microsoft-ConfigurationData'
        ]
        destinations: [
          workloadLogAnalytics.name
        ]
      }
      {
        streams: [
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          workloadLogAnalytics.name
        ]
      }
      {
        streams: [
          'Microsoft-ServiceMap'
        ]
        destinations: [
          workloadLogAnalytics.name
        ]
      }
      {
        streams: [
          'Microsoft-Syslog'
        ]
        destinations: [
          workloadLogAnalytics.name
        ]
        transformKql: 'source'
        outputStream: 'Microsoft-Syslog'
      }
    ]
    destinations: {
      logAnalytics: [
        {
          name: workloadLogAnalytics.name
          workspaceResourceId: workloadLogAnalytics.id
        }
      ]
    }
    description: 'Default data collection rule for Linux virtual machines.'
  }
}

@description('Add data collection rules to Linux virtual machines.')
resource configureLinuxMachinesWithDataCollectionRulePolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('workload', 'dca-linux', configureLinuxMachinesWithDataCollectionRulePolicy.id, resourceGroup().id)
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: take('${policyAssignmentNamePrefix} Configure Linux virtual machines with data collection rules', 120)
    description: take(configureLinuxMachinesWithDataCollectionRulePolicy.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: configureLinuxMachinesWithDataCollectionRulePolicy.id
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      dcrResourceId: {
        value: linuxVmDataCollectionRule.id
      }
      resourceType: {
        value: linuxVmDataCollectionRule.type
      }
    }
  }
}

@description('Ensure the managed identity for DCR DINE policies is has needed permissions.')
resource dineLinuxDcrPolicyLogAnalyticsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, logAnalyticsContributorRole.id, configureLinuxMachinesWithDataCollectionRulePolicyAssignment.id)
  properties: {
    principalId: configureLinuxMachinesWithDataCollectionRulePolicyAssignment.identity.principalId
    roleDefinitionId: logAnalyticsContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

@description('Ensure the managed identity for DCR DINE policies is has needed permissions.')
resource dineLinuxDcrPolicyMonitoringContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, monitoringContributorRole.id, configureLinuxMachinesWithDataCollectionRulePolicyAssignment.id)
  properties: {
    principalId: configureLinuxMachinesWithDataCollectionRulePolicyAssignment.identity.principalId
    roleDefinitionId: monitoringContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

/*** OUTPUTS ***/

output logAnalyticsWorkspaceResourceId string = workloadLogAnalytics.id
