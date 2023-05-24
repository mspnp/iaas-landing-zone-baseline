# Deploy long-lived services [Workload team]

Now that you have a [mock application landing zone deployed](./04-subscription-vending-execute.md), the next step in the [IaaS baseline reference implementation](./) is to deploy some resources whose lifecycle isn't tied to the....

**TODO-CK I think I'm going to take this out of the flow as well.**

## Expected results

* The spoke resource group.
* Log Analytics is deployed. This workspace will be used by your compute resources.

## Steps

1. Create the spoke resource group that is handed to a specific app team (the workload owners).

   > :book: The app team working on behalf of business unit 0001 (BU001) is looking to create compute resources to deploy the app they are creating (Application ID: 0008) into it. They have worked with the organization's networking team and have been provisioned a spoke network in which to lay their compute resources and network-aware external resources into (such as Application Gateway). They took that information and added it to their [`shared-svcs-stamp.bicep`](./shared-svcs-stamp.bicep), [`vmss-stamp.bicep`](./vmss-stamp.bicep), and [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) files.
   >
   > They create this resource group to be the parent group for the application.

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0008 --location eastus2
   ```

1. Get the spoke virtual network resource ID.

   > :book: The app team will be deploying to a spoke virtual network, that was already provisioned by the network team.

   ```bash
   export RESOURCEID_VNET_SPOKE_IAAS_BASELINE=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.spokeVnetResourceId .value -o tsv)
   echo RESOURCEID_VNET_SPOKE_IAAS_BASELINE: $RESOURCEID_VNET_SPOKE_IAAS_BASELINE
   ```

1. Deploy the shared resources per spoke. All resources from this stamp are meant to be singletons shared among all spoke-BU0001A008 resources, and its supporting managed services.

   ```bash
   # [This takes about four minutes.]
   az deployment group create -g rg-bu0001a0008 -f shared-svcs-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_SPOKE_IAAS_BASELINE} location=eastus2
   ```

### Save your work in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to iaas_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source iaas_baseline.env
```

### Next step

:arrow_forward: [Deploy the compute infrastructure](./06-compute-infra.md)
