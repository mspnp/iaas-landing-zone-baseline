# Validate your compute infrastructure is operational and accessible [Workload team]

Now that [the compute infrastructure](./07-compute-infra.md) has been deployed, the next step to validate that your virtual machines are running and remote access can be established.

A web server is enabled on both tiers of this deployment so that you can test end-to-end connectivity. It was installed & configured with a custom script extension on the virtual machines you just deployed. This is NOT how applications should be deployed, it's simply deployed like this so you have a connectivity experience to work with out of the box.

## Steps

1. Check all your recently created virtual machines in rg-alz-bu04a42-compute are in `running` power state.

   ```bash
   az graph query -q "where type =~ 'Microsoft.Compute/virtualMachines' and resourceGroup contains 'rg-alz-bu04a42-compute' | project ['Zone'] = tostring(zones[0]), ['Name'] = name, ['Size'] = tostring(properties.hardwareProfile.vmSize), ['OS'] = tostring(properties.storageProfile.osDisk.osType), ['OS Disk (GB)'] = properties.storageProfile.osDisk.diskSizeGB, ['Data Disk Type'] = tostring(properties.storageProfile.dataDisks[0].managedDisk.storageAccountType), ['Data Disk (GB)'] = tostring(properties.storageProfile.dataDisks[0].diskSizeGB), ['State'] = properties.extended.instanceView.powerState.code | sort by ['Zone'] asc, ['OS'] asc" --query 'data[]' -o table
   ````

   > The command above requires the **resource-graph** CLI extension and prompt you to install it if not already installed.

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

1. Validate all your virtual machines have been able to successfully install all their extensions.

   ```bash
   az graph query -q "resources | where type == 'microsoft.compute/virtualmachines' and resourceGroup contains 'rg-alz-bu04a42-compute' | extend JoinID = toupper(id), ComputerName = tostring(properties.osProfile.computerName), VMName = name | join kind=leftouter( resources | where type == 'microsoft.compute/virtualmachines/extensions' | extend VMId = toupper(substring(id, 0, indexof(id, '/extensions'))), ExtensionName = name ) on \$left.JoinID == \$right.VMId | order by ExtensionName asc | summarize Extensions = make_list(ExtensionName) by VMName, ComputerName | order by tolower(ComputerName) asc" --query 'data[].[VMName, ComputerName, Extensions]' -o table
   ```

   ```output
   Column1                    Column2         Column3
   -------------------------  --------------  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   vmss-backend-00_e7d46ff2   backend6PFG26   ['AADLogin', 'ApplicationHealthWindows', 'AzureMonitorWindowsAgent', 'ChangeTracking-Windows', 'CustomScript', 'DependencyAgentWindows', 'KeyVaultForWindows']
   vmss-backend-00_201d3445   backend8WS11H   ['AADLogin', 'ApplicationHealthWindows', 'AzureMonitorWindowsAgent', 'ChangeTracking-Windows', 'CustomScript', 'DependencyAgentWindows', 'KeyVaultForWindows']
   vmss-backend-00_6a916c6e   backendTKH8BY   ['AADLogin', 'ApplicationHealthWindows', 'AzureMonitorWindowsAgent', 'ChangeTracking-Windows', 'CustomScript', 'DependencyAgentWindows', 'KeyVaultForWindows']
   vmss-frontend-00_c059ce7d  frontendHNRV5V  ['AADSSHLogin', 'AzureMonitorLinuxAgent', 'ChangeTracking-Linux', 'CustomScript', 'DependencyAgentLinux', 'HealthExtension', 'KeyVaultForLinux', 'NetworkWatcherAgentLinux']
   vmss-frontend-00_b9ea8bd7  frontendJG1PNT  ['AADSSHLogin', 'AzureMonitorLinuxAgent', 'ChangeTracking-Linux', 'CustomScript', 'DependencyAgentLinux', 'HealthExtension', 'KeyVaultForLinux', 'NetworkWatcherAgentLinux']
   vmss-frontend-00_8c869f9c  frontendW1FSRO  ['AADSSHLogin', 'AzureMonitorLinuxAgent', 'ChangeTracking-Linux', 'CustomScript', 'DependencyAgentLinux', 'HealthExtension', 'KeyVaultForLinux', 'NetworkWatcherAgentLinux']
   ```

   :bulb: From some of the extension names in `Column3` you can easily spot that the backend VMs are `Windows` machines and the frontend VMs are `Linux` machines. For more information about the virtual machine extensions please take a look at <https://learn.microsoft.com/azure/virtual-machines/extensions/overview>.

1. Query Application Heath Extension substatus and see whether the virtual machines are reporting as healthy.

   ```bash
   az vm get-instance-view --ids $RESOURCEIDS_ALL_VIRTUAL_MACHINES_IAAS_BASELINE --query "[*].[name, instanceView.extensions[?name=='HealthExtension'||name=='ApplicationHealthWindows'].substatuses[].message]"
   ```

   :bulb: This reports you back on application health from inside the virtual machine instances, probing on a local application endpoint that happens to be `./favicon.ico` over HTTPS. This health status is used by Azure to initiate repairs on unhealthy instances and to determine if an instance is eligible for upgrade operations. Additionally, this extension can be used in situations where an external probe such as the Azure Load Balancer health probes can't be used.

1. Get the regional hub Azure Bastion name.

   ```bash
   AB_NAME_HUB=$(az deployment group show -g rg-plz-connectivity-regional-hubs -n hub-default --query properties.outputs.regionalBastionHostName.value -o tsv)
   echo AB_NAME_HUB: $AB_NAME_HUB
   ```

1. Remote SSH to a Linux virtual machine using Azure Bastion and Entra ID auth. _(optional)_

   ```bash
   az extension add -n ssh --upgrade
   az extension add -n bastion --upgrade

   TEMPDIR_SSH_CONFIG=$(mktemp -d -t entrasshcertXXXXXXXX)
   chmod 700 $TEMPDIR_SSH_CONFIG
   az ssh cert -f ${TEMPDIR_SSH_CONFIG}/id_rsa-aadcert.pub
   chmod 400 $TEMPDIR_SSH_CONFIG/id_rsa
   
   az network bastion tunnel -n $AB_NAME_HUB -g rg-plz-connectivity-regional-hubs --port 4222 --resource-port 22 --target-resource-id $(az vm list --vmss $RESOURCEID_VMSS_FRONTEND_IAAS_BASELINE --query '[0].id' -o tsv) &
   sleep 10
   az ssh vm --ip localhost -i ${TEMPDIR_SSH_CONFIG}/id_rsa -p ${TEMPDIR_SSH_CONFIG}/id_rsa.pub --port 4222
   ```

   > Ideally you'd just run `az network bastion ssh -n $AB_NAME_HUB -g rg-plz-connectivity-regional-hubs --target-resource-id <VM_RESOURCE_ID> --auth-type AAD` but due to a [known bug](https://github.com/Azure/azure-cli-extensions/issues/6408) you must connect using the above Azure Bastion tunnel method.

   1. Validate your frontend workload (an Nginx instance) is running on the virtual machine.

      ```bash
      curl https://frontend-00.iaas-ingress.contoso.com/ --resolve frontend-00.iaas-ingress.contoso.com:443:127.0.0.1 -k
      ```

   1. Exit the SSH session from the frontend VM, and close the bastion tunnel.

      ```bash
      exit
      fg
      <ctrl+c>
      rm -Rf $TEMPDIR_SSH_CONFIG
      ```

1. Remote RPD to a Windows virtual machine using Azure Bastion and Entra ID auth. _(optional)_

   ```bash
   az network bastion rdp -n $AB_NAME_HUB -g rg-plz-connectivity-regional-hubs --target-resource-id $(az vm list --vmss $RESOURCEID_VMSS_BACKEND_IAAS_BASELINE --query '[0].id' -o tsv)
   ```

   :warning: The bastion RDP command will only work from another Windows machine.

   1. Validate your backend workload (an Nginx instance) is running on the virtual machine.

      ```powershell
      (Invoke-WebRequest http://localhost).RawContent
      ```

   1. Exit the backend RDP session from the backend virtual machine.

### Next step

:arrow_forward: [End to end infrastructure validation](./09-validation.md)
