# Validate your compute infrastructure is operational [Workload team]

Now that [the compute infrastructure](./06-compute-infra.md) has been deployed, the next step to validate that your virtual machines are running.

A web server is enabled on both tiers of this deployment so that you can test end to end connectivity. It was installed & configured with a custom script extension on the virtual machines you just deployed. This is NOT how applications should be deployed, it's simply deployed like this so you have a connectivity experience to work with out of the box.

## Steps

1. Check all your recently created virtual machines in rg-alz-bu04a42-compute are in `running` power state

   ```bash
   az graph query -q "where type =~ 'Microsoft.Compute/virtualMachines' and resourceGroup contains 'rg-alz-bu04a42-compute' | project ['Zone'] = tostring(zones[0]), ['Name'] = name, ['Size'] = tostring(properties.hardwareProfile.vmSize), ['OS'] = tostring(properties.storageProfile.osDisk.osType), ['OS Disk (GB)'] = properties.storageProfile.osDisk.diskSizeGB, ['Data Disk Type'] = tostring(properties.storageProfile.dataDisks[0].managedDisk.storageAccountType), ['Data Disk (GB)'] = tostring(properties.storageProfile.dataDisks[0].diskSizeGB), ['State'] = properties.extended.instanceView.powerState.code | sort by ['Zone'] asc, ['OS'] asc" --query 'data[]' -o table
   ````

   ```output
   Zone    Name                       Size             OS       OS Disk (GB)    Data Disk Type    Data Disk (GB)    State
   ------  -------------------------  ---------------  -------  --------------  ----------------  ----------------  ------------------
   1       vmss-frontend-00_b9ea8bd7  Standard_D4s_v3  Linux    30                                                  PowerState/running
   1       vmss-backend-00_6a916c6e   Standard_E2s_v3  Windows  30              Premium_LRS       4                 PowerState/running
   2       vmss-frontend-00_8c869f9c  Standard_D4s_v3  Linux    30                                                  PowerState/running
   2       vmss-backend-00_201d3445   Standard_E2s_v3  Windows  30              Premium_LRS       4                 PowerState/running
   3       vmss-frontend-00_c059ce7d  Standard_D4s_v3  Linux    30                                                  PowerState/running
   3       vmss-backend-00_e7d46ff2   Standard_E2s_v3  Windows  30              Premium_LRS       4                 PowerState/running
   ```

   :bulb: From the `Zone` column you can understand how your virtual machines were spread at provisioning time across Azure Availability Zones. Additionally, you will notice that only backend machines are attached with managed data disks. This list also gives you the current power state of every machine.

1. Validate all your virtual machines have been able to successfully install all their VM extensions

   ```bash
   az graph query -q "resources | where type == 'microsoft.compute/virtualmachines' and resourceGroup contains 'rg-alz-bu04a42-compute' | extend JoinID = toupper(id), ComputerName = tostring(properties.osProfile.computerName), VMName = name | join kind=leftouter( resources | where type == 'microsoft.compute/virtualmachines/extensions' | extend VMId = toupper(substring(id, 0, indexof(id, '/extensions'))), ExtensionName = name ) on \$left.JoinID == \$right.VMId | summarize Extensions = make_list(ExtensionName) by VMName, ComputerName | order by tolower(ComputerName) asc" --query 'data[].[VMName, ComputerName, Extensions]' -o table
   ```

   ```output
   Column1                    Column2         Column3
   -------------------------  --------------  ----------------------------------------------------------------------------------------------------------------------------------------------------
   vmss-backend-00_e7d46ff2   backend6PFG26   ['KeyVaultForWindows', 'ApplicationHealthWindows', 'DependencyAgentWindows', 'AzureMonitorWindowsAgent', 'CustomScript']
   vmss-backend-00_201d3445   backend8WS11H   ['CustomScript', 'ApplicationHealthWindows', 'DependencyAgentWindows', 'AzureMonitorWindowsAgent', 'KeyVaultForWindows']
   vmss-backend-00_6a916c6e   backendTKH8BY   ['CustomScript', 'ApplicationHealthWindows', 'DependencyAgentWindows', 'KeyVaultForWindows', 'AzureMonitorWindowsAgent']
   vmss-frontend-00_c059ce7d  frontendHNRV5V  ['AADSSHLogin', 'CustomScript', 'HealthExtension', 'NetworkWatcherAgentLinux', 'KeyVaultForLinux', 'AzureMonitorLinuxAgent', 'DependencyAgentLinux']
   vmss-frontend-00_b9ea8bd7  frontendJG1PNT  ['KeyVaultForLinux', 'NetworkWatcherAgentLinux', 'CustomScript', 'AADSSHLogin', 'DependencyAgentLinux', 'AzureMonitorLinuxAgent', 'HealthExtension']
   vmss-frontend-00_8c869f9c  frontendW1FSRO  ['KeyVaultForLinux', 'DependencyAgentLinux', 'AADSSHLogin', 'NetworkWatcherAgentLinux', 'HealthExtension', 'CustomScript', 'AzureMonitorLinuxAgent']
   ```

   :bulb: From some of the extension names in `Column3` you can easily spot that the backend VMs are `Windows` machines and the frontend VMs are `Linux` machines. For more information about the VM extensions please take a look at <https://learn.microsoft.com/azure/virtual-machines/extensions/overview>.

1. Query Application Heath Extension substatus and see whether the web server is healthy

   ```bash
   az vm get-instance-view --resource-group rg-alz-bu04a42-compute --name <VM NAME> --query "[name, instanceView.extensions[?name=='HealthExtension'||name=='ApplicationHealthWindows'].substatuses[].message]"
   ```

   :bulb: this reports you back on application health from inside the virtual machine instance probing on a local application endpoint that happens to be `./favicon.ico` over HTTPS. This health status is used by Azure to initiate repairs on unhealthy instances and to determine if an instance is eligible for upgrade operations. Additionally, this extension can be used in situations where an external probe such as the Azure Load Balancer health probes can't be used.

1. Get the regional hub Azure Bastion name.

   ```bash
   AB_NAME_HUB=$(az deployment group show -g rg-plz-connectivity-regional-hubs -n hub-default --query properties.outputs.regionalBastionHostName.value -o tsv)
   echo AB_NAME_HUB: $AB_NAME_HUB
   ```

1. Remote SSH using Bastion into a frontend VM

   ```bash
   az network bastion ssh -n $AB_NAME_HUB -g rg-plz-connectivity-regional-hubs --target-resource-id $(az graph query -q "resources | where type =~ 'Microsoft.Compute/virtualMachines' | where resourceGroup contains 'rg-bu0001a0008' and name contains 'vmss-frontend'| project id" --query [0].id -o tsv)
   ```

1. Validate your workload (a Nginx instance) is running in the frontend

   ```bash
   curl https://frontend-00.iaas-ingress.contoso.com/ --resolve frontend-00.iaas-ingress.contoso.com:443:127.0.0.1 -k
   ```

1. Exit the ssh session from the frontend VM

   ```bash
   exit
   ```

1. Remote to a Windows backend VM using Bastion

   ```bash
   az network bastion rdp -n $AB_NAME_HUB -g rg-plz-connectivity-regional-hubs --target-resource-id $(az graph query -q "resources | where type =~ 'Microsoft.Compute/virtualMachines' | where resourceGroup contains 'rg-bu0001a0008' and name contains 'vmss-backend'| project id" --query [0].id -o tsv)
   ```

   :warning: the bastion rdp command will work from Windows machines. Other platforms might need to remote your VM Windows machines from [Azure portal using Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview)

1. Validate your backend workload (another Nginx instance) is running in the backend

   ```bash
   curl http://127.0.0.1
   ```

1. Exit the RDP session from the backend VM

   ```bash
   exit
   ```

### Next step

:arrow_forward: [End to end infrastructure validation](./11-validation.md)
