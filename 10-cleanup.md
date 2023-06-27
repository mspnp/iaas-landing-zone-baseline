# Clean up

After you are done exploring your deployed [IaaS baseline](./09-validation.md), you'll want to delete the created Azure resources to prevent undesired costs from accruing. Follow these steps to delete all resources created as part of this reference implementation.

## Steps

1. Obtain the Azure KeyVault resource name

   ```bash
   KEYVAULT_NAME=$(az deployment group show -g rg-alz-bu04a42-compute -n deploy-workload-infrastructure --query properties.outputs.keyVaultName.value -o tsv)
   echo KEYVAULT_NAME: $KEYVAULT_NAME
   ```

1. Delete the resource groups as a way to delete all contained Azure resources.

   > To delete all Azure resources associated with this reference implementation, you'll need to delete the three resource groups created.

   :warning: Ensure you are using the correct subscription, and validate that the only resources that exist in these groups are ones you're okay deleting.

   ```bash
   az group delete -n rg-alz-bu04a42-compute -f Microsoft.Compute/virtualMachineScaleSets
   az group delete -n rg-alz-bu04a42-spoke
   az group delete -n rg-plz-connectivity-regional-hubs
   ```

1. Purge Azure Key Vault

   > Because this reference implementation enables soft delete on Key Vault, execute a purge so your next deployment of this implementation doesn't run into a naming conflict.

   ```bash
   az keyvault purge -n $KEYVAULT_NAME
   ```

1. If any temporary changes were made to Azure AD or Azure RBAC permissions consider removing those as well.

## Automation

Before you can automate a process, it's important to experience the process in a bit more raw form as was presented here. That experience allows you to understand the various steps, inner- & cross-team dependencies, and failure points along the way. However, the steps provided in this walkthrough are not specifically designed with automation in mind. It does present a perspective on some common seperation of duties often encountered in organizations, but that might not align with your organization.

Now that you understand the components involved and have identified the shared responsibilities between your team and your greater organization, you are encouraged to build repeatable deployment processes around your final infrastructure and compute bootstrapping. Please refer to the [DevOps architecture designs](https://learn.microsoft.com/azure/architecture/guide/devops/devops-start-here) to learn how GitHub Actions combined with Infrastructure as Code can be used to facilitate this automation.

### Next step

:arrow_forward: [Review additional information in the main README](./README.md#broom-clean-up-resources)
