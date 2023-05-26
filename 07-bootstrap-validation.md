# Validate your compute infrastructure is bootstrapped

Now that [the compute infrastructure](./06-compute-infra.md) has been deployed, the next step to validate that your VMs are running.

## Steps

1. Check all your recently created VMs at the rg-bu0001a0008 resources group are in `running` power state

   ```bash
   az graph query -q "resources | where type =~ 'Microsoft.Compute/virtualMachines' and resourceGroup contains 'rg-bu0001a0008' | extend ['8-PowerState'] = properties.extended.instanceView.powerState.code, ['1-Zone'] = tostring(zones[0]), ['2-Name'] = name, ['4-OSType'] = tostring(properties.storageProfile.osDisk.osType), ['5-OSDiskSizeGB'] = properties.storageProfile.osDisk.diskSizeGB, ['7-DataDiskSizeDB'] = tostring(properties.storageProfile.dataDisks[0].diskSizeGB), ['6-DataDiskType'] = tostring(properties.storageProfile.dataDisks[0].managedDisk.storageAccountType), ['3-VMSize'] = tostring(properties.hardwareProfile.vmSize) | project ['8-PowerState'], ['1-Zone'], ['2-Name'], ['4-OSType'], ['5-OSDiskSizeGB'], ['7-DataDiskSizeGB'], ['6-DataDiskType'], ['3-VMSize'] | sort by ['1-Zone'] asc, ['4-OSType'] asc" -o table
   ````

   ```output
   1-Zone    2-Name                     3-VMSize         4-OSType    5-OSDiskSizeGB    6-DataDiskType    7-DataDiskSizeDB    8-PowerState
   --------  -------------------------  ---------------  ----------  ----------------  ----------------  ------------------  ------------------
   1         vmss-frontend-00_e49497b3  Standard_D4s_v3  Linux       30                                                      PowerState/running
   1         vmss-backend-00_c454e7bb   Standard_E2s_v3  Windows     30                Premium_LRS       4                   PowerState/running
   2         vmss-frontend-00_187eb769  Standard_D4s_v3  Linux       30                                                      PowerState/running
   2         vmss-backend-00_e4057ba4   Standard_E2s_v3  Windows     30                Premium_LRS       4                   PowerState/running
   3         vmss-frontend-00_9d738714  Standard_D4s_v3  Linux       30                                                      PowerState/running
   3         vmss-backend-00_6e781ed7   Standard_E2s_v3  Windows     30                Premium_LRS       4                   PowerState/running
   ```

   :bulb: From the `Zone` column you can easily understand how you VMs were spread at provisioning time in the Azure Availablity Zones. Additionally, you will notice that only backend machines are attached with managed data disks. This list also gives you the current power state of every machine in your VMSS instances.

1. Validate all your VMs have been able to sucessfully install all the desired VM extensions

   ```bash
   az graph query -q "Resources | where type == 'microsoft.compute/virtualmachines' and resourceGroup contains 'rg-bu0001a0008' | extend JoinID = toupper(id), ComputerName = tostring(properties.osProfile.computerName), VMName = name | join kind=leftouter( Resources | where type == 'microsoft.compute/virtualmachines/extensions' | extend VMId = toupper(substring(id, 0, indexof(id, '/extensions'))), ExtensionName = name ) on \$left.JoinID == \$right.VMId | summarize Extensions = make_list(ExtensionName) by VMName, ComputerName | order by tolower(ComputerName) asc" -o table --query "[].[Name: VMName, ComputerName, Extensions[]]"
   ```

   ```output
   Column1                    Column2         Column3
   -------------------------  --------------  ------------------------------------------------------------------------------------------------------------------------
   vmss-backend-00_e4057ba4   backend7RGXGC   ['KeyVaultForWindows', 'AzureMonitorWindowsAgent', 'CustomScript', 'DependencyAgentWindows', 'ApplicationHealthWindows']
   vmss-backend-00_c454e7bb   backendGK0DHH   ['DependencyAgentWindows', 'KeyVaultForWindows', 'CustomScript', 'ApplicationHealthWindows', 'AzureMonitorWindowsAgent']
   vmss-backend-00_6e781ed7   backendUNG2C7   ['CustomScript', 'ApplicationHealthWindows', 'DependencyAgentWindows', 'AzureMonitorWindowsAgent', 'KeyVaultForWindows']
   vmss-frontend-00_187eb769  frontend6SO8YX  ['KeyVaultForLinux', 'AzureMonitorLinuxAgent', 'CustomScript', 'HealthExtension', 'DependencyAgentLinux']
   vmss-frontend-00_e49497b3  frontend7LVWP9  ['DependencyAgentLinux', 'KeyVaultForLinux', 'CustomScript', 'AzureMonitorLinuxAgent', 'HealthExtension']
   vmss-frontend-00_9d738714  frontendRCDIWC  ['CutomScript', 'AzureMonitorLinuxAgent', 'KeyVaultForLinux', 'HealthExtension', 'DependencyAgentLinux']
   ```

   :bulb: From some of the extension names in `Column3` you can easily spot that the backend VMs are `Windows` machines and the frontend VMs are `Linux` machines. For more information about the VM extensions please take a look at https://learn.microsoft.com/azure/virtual-machines/extensions/overview

1. Query Application Heath Extension substatus and see whether your application is healthy

   ```bash
   az vm get-instance-view --resource-group rg-bu0001a0008 --name <VMNAME> --query "[name, instanceView.extensions[?name=='HealthExtension'].substatuses[].message]"
   ```

   :bulb: this reports you back on application health from inside the virtual machine instance probing on a local application endpoint that happens to be `./favicon.ico` over HTTPS. This health status is used by Azure to initiate repairs on unhealthy instances and to determine if an instance is eligible for upgrade operations. Additionally, this extension can be used in situations where an external probe such as the Azure Load Balancer health probes can't be used.


1. Get the regional hub Azure Bastion name.

   ```bash
   AB_NAME_HUB=$(az deployment group show -g rg-enterprise-networking-hubs -n hub-regionA --query properties.outputs.abName.value -o tsv)
   echo AB_NAME_HUB: $AB_NAME_HUB
   ```

1. Remote ssh using Bastion into a frontend VM

   ```bash
   az network bastion ssh -n $AB_NAME_HUB -g rg-enterprise-networking-hubs --username opsuser01 --ssh-key ~/.ssh/opsuser01.pem --auth-type ssh-key --target-resource-id $(az graph query -q "resources | where type =~ 'Microsoft.Compute/virtualMachines' | where resourceGroup contains 'rg-bu0001a0008' and name contains 'vmss-frontend'| project id" --query [0].id -o tsv)
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
   az network bastion rdp -n $AB_NAME_HUB -g rg-enterprise-networking-hubs --target-resource-id $(az graph query -q "resources | where type =~ 'Microsoft.Compute/virtualMachines' | where resourceGroup contains 'rg-bu0001a0008' and name contains 'vmss-backend'| project id" --query [0].id -o tsv)
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

:arrow_forward: [End to end infrastructure and workload validation](./11-validation.md)
