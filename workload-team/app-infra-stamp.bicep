targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke virtual network resource ID that will host the VM\'s NIC')
@minLength(79)
param targetVnetResourceId string

@description('IaaS region. This needs to be the same region as the virtual network provided in these parameters.')
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
param location string

@description('The certificate data for Azure Application Gateway TLS termination. It is Base64 encoded.')
param appGatewayListenerCertificate string

@description('The Base64 encoded VMSS web server public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
param vmssWildcardTlsPublicCertificate string

@description('The Base64 encoded VMSS web server public and private certificates (formatterd as .pem or .pfx) to be stored in Azure Key Vault as secret and downloaded into the frontend and backend Vmss instances for the workloads ssl certificate configuration.')
param vmssWildcardTlsPublicAndKeyCertificates string

@description('The admin password for the Windows backend machines.')
@minLength(12)
@secure()
param adminPassword string

@description('A common uniquestring reference used for resources that benefit from having a unique component.')
@maxLength(13)
param subComputeRgUniqueString string

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

@description('Built-in: Azure Backup should be enabled for Virtual Machines.')
resource configureLinuxMachinesWithDataCollectionRulePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  scope: tenant()
  name: '2ea82cdd-f2e8-4500-af75-67a2e084ca74'
}

@description('Built-in: Azure Backup should be enabled for Virtual Machines.')
resource configureWindowsMachinesWithDataCollectionRulePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  scope: tenant()
  name: 'eab1f514-22e3-42e3-9a1f-e1dc9199355c'
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

@description('TEMP: TODO: Provide a solution.')
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

@description('Application security group for the backend compute.')
resource asgKeyVault 'Microsoft.Network/applicationSecurityGroups@2022-11-01' existing = {
  scope: spokeResourceGroup
  name: 'asg-keyvault'
}

@description('Consistent prefix on all assignments to facilitate deleting assignments in the cleanup process.')
var policyAssignmentNamePrefix = '[IaaS baseline bu04a42] -'

/*** RESOURCES ***/

/* TODO: private endpoint disk access 
resource x 'Microsoft.Compute/diskAccesses@2022-07-02' = {
  name: ''
  location: location
  properties: {
  }
}
*/
@description('Add Change Tracking to Linux virtual machines.')
resource configureLinuxMachinesWithDataCollectionRulePolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('workload', 'dca-ct-linux', configureLinuxMachinesWithDataCollectionRulePolicy.id, resourceGroup().id)
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: take('${policyAssignmentNamePrefix} Configure Linux virtual machines with change tracking', 120)
    description: take(configureLinuxMachinesWithDataCollectionRulePolicy.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: configureLinuxMachinesWithDataCollectionRulePolicy.id
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      dcrResourceId: {
        value: changeTrackingDataCollectionRule.id
      }
      resourceType: {
        value: changeTrackingDataCollectionRule.type
      }
    }
  }
}

@description('Add log and metrics DCR to Linux virtual machines.')
resource configureLinuxMachinesWithSyslogPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('workload', 'dca-syslog-linux', configureLinuxMachinesWithDataCollectionRulePolicy.id, resourceGroup().id)
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: take('${policyAssignmentNamePrefix} Configure Linux virtual machines with syslog data collection', 120)
    description: take(configureLinuxMachinesWithDataCollectionRulePolicy.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: configureLinuxMachinesWithDataCollectionRulePolicy.id
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      dcrResourceId: {
        value: linuxEventsAndMetricsDataCollectionRule.id
      }
      resourceType: {
        value: linuxEventsAndMetricsDataCollectionRule.type
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

@description('Ensure the managed identity for DCR DINE policies is has needed permissions.')
resource dineLinuxDcrSyslogPolicyLogAnalyticsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, logAnalyticsContributorRole.id, configureLinuxMachinesWithSyslogPolicyAssignment.id)
  properties: {
    principalId: configureLinuxMachinesWithSyslogPolicyAssignment.identity.principalId
    roleDefinitionId: logAnalyticsContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

@description('Ensure the managed identity for DCR DINE policies is has needed permissions.')
resource dineLinuxDcrSyslogPolicyMonitoringContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, monitoringContributorRole.id, configureLinuxMachinesWithSyslogPolicyAssignment.id)
  properties: {
    principalId: configureLinuxMachinesWithSyslogPolicyAssignment.identity.principalId
    roleDefinitionId: monitoringContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

@description('Deny deploying hybrid networking resources.')
resource configureWindowsMachinesWithDataCollectionRulePolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('workload', 'dca-ct-windows', configureWindowsMachinesWithDataCollectionRulePolicy.id, resourceGroup().id)
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: take('${policyAssignmentNamePrefix} Configure Windows virtual machines with change tracking', 120)
    description: take(configureWindowsMachinesWithDataCollectionRulePolicy.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: configureWindowsMachinesWithDataCollectionRulePolicy.id
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      dcrResourceId: {
        value: changeTrackingDataCollectionRule.id
      }
      resourceType: {
        value: changeTrackingDataCollectionRule.type
      }
    }
  }
}

@description('Add log and metrics DCR to Windows virtual machines.')
resource configureWindowsMachinesWithEventAndMetricsDataCollectionRulePolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: guid('workload', 'dca-logs-windows', configureWindowsMachinesWithDataCollectionRulePolicy.id, resourceGroup().id)
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: take('${policyAssignmentNamePrefix} Configure Windows virtual machines with event log and metrics data collection rule.', 120)
    description: take(configureWindowsMachinesWithDataCollectionRulePolicy.properties.description, 500)
    enforcementMode: 'Default'
    policyDefinitionId: configureWindowsMachinesWithDataCollectionRulePolicy.id
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      dcrResourceId: {
        value: windowsEventsAndMetricsDataCollectionRule.id
      }
      resourceType: {
        value: windowsEventsAndMetricsDataCollectionRule.type
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

@description('Ensure the managed identity for DCR Log DINE policies is has needed permissions.')
resource dineWindowsLogDcrPolicyLogAnalyticsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, logAnalyticsContributorRole.id, configureWindowsMachinesWithEventAndMetricsDataCollectionRulePolicyAssignment.id)
  properties: {
    principalId: configureWindowsMachinesWithEventAndMetricsDataCollectionRulePolicyAssignment.identity.principalId
    roleDefinitionId: logAnalyticsContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

@description('Ensure the managed identity for DCR Log DINE policies is has needed permissions.')
resource dineWindowsDcrLogPolicyMonitoringContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, monitoringContributorRole.id, configureWindowsMachinesWithEventAndMetricsDataCollectionRulePolicyAssignment.id)
  properties: {
    principalId: configureWindowsMachinesWithEventAndMetricsDataCollectionRulePolicyAssignment.identity.principalId
    roleDefinitionId: monitoringContributorRole.id
    principalType: 'ServicePrincipal'
  }
}

@description('Data collection rule for Windows virtual machines.')
resource windowsEventsAndMetricsDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcrWindowsEventsAndMetrics'
  location: location
  kind: 'Windows'
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounterDataSource'
          samplingFrequencyInSeconds: 60
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          counterSpecifiers: [
            '\\Processor Information(_Total)\\% Processor Time'
            '\\Processor Information(_Total)\\% Privileged Time'
            '\\Processor Information(_Total)\\% User Time'
            '\\Processor Information(_Total)\\Processor Frequency'
            '\\System\\Processes'
            '\\Process(_Total)\\Thread Count'
            '\\Process(_Total)\\Handle Count'
            '\\System\\System Up Time'
            '\\System\\Context Switches/sec'
            '\\System\\Processor Queue Length'
            '\\Memory\\% Committed Bytes In Use'
            '\\Memory\\Available Bytes'
            '\\Memory\\Committed Bytes'
            '\\Memory\\Cache Bytes'
            '\\Memory\\Pool Paged Bytes'
            '\\Memory\\Pool Nonpaged Bytes'
            '\\Memory\\Pages/sec'
            '\\Memory\\Page Faults/sec'
            '\\Process(_Total)\\Working Set'
            '\\Process(_Total)\\Working Set - Private'
            '\\LogicalDisk(_Total)\\% Disk Time'
            '\\LogicalDisk(_Total)\\% Disk Read Time'
            '\\LogicalDisk(_Total)\\% Disk Write Time'
            '\\LogicalDisk(_Total)\\% Idle Time'
            '\\LogicalDisk(_Total)\\Disk Bytes/sec'
            '\\LogicalDisk(_Total)\\Disk Read Bytes/sec'
            '\\LogicalDisk(_Total)\\Disk Write Bytes/sec'
            '\\LogicalDisk(_Total)\\Disk Transfers/sec'
            '\\LogicalDisk(_Total)\\Disk Reads/sec'
            '\\LogicalDisk(_Total)\\Disk Writes/sec'
            '\\LogicalDisk(_Total)\\Avg. Disk sec/Transfer'
            '\\LogicalDisk(_Total)\\Avg. Disk sec/Read'
            '\\LogicalDisk(_Total)\\Avg. Disk sec/Write'
            '\\LogicalDisk(_Total)\\Avg. Disk Queue Length'
            '\\LogicalDisk(_Total)\\Avg. Disk Read Queue Length'
            '\\LogicalDisk(_Total)\\Avg. Disk Write Queue Length'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\LogicalDisk(_Total)\\Free Megabytes'
            '\\Network Interface(*)\\Bytes Total/sec'
            '\\Network Interface(*)\\Bytes Sent/sec'
            '\\Network Interface(*)\\Bytes Received/sec'
            '\\Network Interface(*)\\Packets/sec'
            '\\Network Interface(*)\\Packets Sent/sec'
            '\\Network Interface(*)\\Packets Received/sec'
            '\\Network Interface(*)\\Packets Outbound Errors'
            '\\Network Interface(*)\\Packets Received Errors'
          ]
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
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          'azureMonitorMetrics-default'
        ]
        transformKql: 'source'
        outputStream: 'Microsoft-InsightsMetrics'
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
    description: 'Default data collection rule for Windows VMs.'
  }
}

@description('Data collection rule for Windows virtual machines.')
resource linuxEventsAndMetricsDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcrLinuxSyslogAndMetrics'
  location: location
  kind: 'Linux'
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounterDataSource'
          samplingFrequencyInSeconds: 60
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          counterSpecifiers: [
            'Processor(*)\\% Processor Time'
            'Processor(*)\\% Idle Time'
            'Processor(*)\\% User Time'
            'Processor(*)\\% Nice Time'
            'Processor(*)\\% Privileged Time'
            'Processor(*)\\% IO Wait Time'
            'Processor(*)\\% Interrupt Time'
            'Processor(*)\\% DPC Time'
            'Memory(*)\\Available MBytes Memory'
            'Memory(*)\\% Available Memory'
            'Memory(*)\\Used Memory MBytes'
            'Memory(*)\\% Used Memory'
            'Memory(*)\\Pages/sec'
            'Memory(*)\\Page Reads/sec'
            'Memory(*)\\Page Writes/sec'
            'Memory(*)\\Available MBytes Swap'
            'Memory(*)\\% Available Swap Space'
            'Memory(*)\\Used MBytes Swap Space'
            'Memory(*)\\% Used Swap Space'
            'Logical Disk(*)\\% Free Inodes'
            'Logical Disk(*)\\% Used Inodes'
            'Logical Disk(*)\\Free Megabytes'
            'Logical Disk(*)\\% Free Space'
            'Logical Disk(*)\\% Used Space'
            'Logical Disk(*)\\Logical Disk Bytes/sec'
            'Logical Disk(*)\\Disk Read Bytes/sec'
            'Logical Disk(*)\\Disk Write Bytes/sec'
            'Logical Disk(*)\\Disk Transfers/sec'
            'Logical Disk(*)\\Disk Reads/sec'
            'Logical Disk(*)\\Disk Writes/sec'
            'Network(*)\\Total Bytes Transmitted'
            'Network(*)\\Total Bytes Received'
            'Network(*)\\Total Bytes'
            'Network(*)\\Total Packets Transmitted'
            'Network(*)\\Total Packets Received'
            'Network(*)\\Total Rx Errors'
            'Network(*)\\Total Tx Errors'
            'Network(*)\\Total Collisions'
          ]
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
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          'azureMonitorMetrics-default'
        ]
        transformKql: 'source'
        outputStream: 'Microsoft-InsightsMetrics'
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
    description: 'Default data collection rule for Windows VMs.'
  }
}

@description('Change tracking data collection rule')
resource changeTrackingDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcrVirtualMachineChangeTracking'
  location: location
  properties: {
    description: 'Data collection rule for change tracking.'
    destinations: {
      logAnalytics: [
        {
          name: workloadLogAnalytics.name
          workspaceResourceId: workloadLogAnalytics.id
        }
      ]
    }
    dataSources: {
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
      ]
    }
    dataFlows: [
      {
        destinations: [
          workloadLogAnalytics.name
        ]
        streams: [
          'Microsoft-ConfigurationChange'
          'Microsoft-ConfigurationChangeV2'
          'Microsoft-ConfigurationData'
        ]
      }
    ]
  }
}

@description('Sets up the provided group object id to have access to SSH or RDP into all virtual machines with the AAD login extension installed in this resource group.')
resource grantAdminRbacAccessToRemoteIntoVMs 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, adminAadSecurityPrincipalObjectId, virtualMachineAdminLoginRole.id)
  properties: {
    principalId: adminAadSecurityPrincipalObjectId
    roleDefinitionId: virtualMachineAdminLoginRole.id
    principalType: adminAddSecurityPrincipalType
    description: 'Allows all users in this group access to log into virtual machines that use the AAD login extension.'
  }
}

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
            assessmentMode: 'AutomaticByPlatform'
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
      }
      storageProfile: {
        osDisk: {
          diffDiskSettings: {
            option: 'Local'
            placement: 'CacheDisk'
          }
          diskSizeGB: 30
          caching: 'ReadOnly'
          createOption: 'FromImage'
        }
        imageReference: {
          publisher: 'Canonical'
          offer: 'UbuntuServer'
          sku: '18.04-LTS' /* TODO: Move this to a supported version, 18.04 is no longer in support */
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
            name: 'AzureSecurityLinuxAgent'
            properties: {
              provisionAfterExtensions: [
                'AzureMonitorLinuxAgent'
              ]
              publisher: 'Microsoft.Azure.Security.Monitoring'
              type: 'AzureSecurityLinuxAgent'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
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
              provisionAfterExtensions: [
                'AADSSHLogin'
              ]
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
                // TODO: This won't work on 'internal', so temp moved to base64
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
    contosoPrivateDnsZone::linkToHub
    grantAdminRbacAccessToRemoteIntoVMs
    dineLinuxDcrPolicyLogAnalyticsRoleAssignment
    dineLinuxDcrPolicyMonitoringContributorRoleAssignment
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
            assessmentMode: 'AutomaticByPlatform'
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
            name: 'AADLogin'
            properties: {
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
                // TODO: This won't work on 'internal', so temp moved to blob
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
            name: 'AzureSecurityWindowsAgent'
            properties: {
              provisionAfterExtensions: [
                'AzureMonitorWindowsAgent'
              ]
              publisher: 'Microsoft.Azure.Security.Monitoring'
              type: 'AzureSecurityWindowsAgent'
              typeHandlerVersion: '1.0'
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
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
    peKv
    contosoPrivateDnsZone::vmssBackend
    contosoPrivateDnsZone::vnetlnk
    contosoPrivateDnsZone::linkToHub
    grantAdminRbacAccessToRemoteIntoVMs
    dineWindowsDcrPolicyLogAnalyticsRoleAssignment
    dineWindowsDcrPolicyMonitoringContributorRoleAssignment
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
resource peKv 'Microsoft.Network/privateEndpoints@2022-11-01' = {
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

  // THIS IS BEING DONE FOR SIMPLICTY IN DEPLOYMENT, NOT AS GUIDANCE.
  // Normally a workload team wouldn't have this permission, and a DINE policy
  // would have taken care of this step. 
  /* resource pdnszg 'privateDnsZoneGroups' = {
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
  } */
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
resource peKeyVaultForAppGw 'Microsoft.Network/privateEndpoints@2022-11-01' = {
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

  // TODO: This is going to need to be solved. As this is configured below, it will not work in this topology.
  // THIS IS BEING DONE FOR SIMPLICTY IN DEPLOYMENT, NOT AS GUIDANCE.
  // Normally a workload team wouldn't have this permission, and a DINE policy
  // would have taken care of this step.
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
    contosoPrivateDnsZone::linkToHub
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

/*** OUTPUTS ***/

output keyVaultName string = workloadKeyVault.name

output frontendVmssResourceId string = vmssFrontend.id

output backendVmssResourceId string = vmssBackend.id
