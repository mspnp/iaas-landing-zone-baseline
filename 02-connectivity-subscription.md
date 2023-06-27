# Deploy mock connectivity subscription [Platform team]

Now that you have your target [Azure subscription and other prerequisites](./01-prerequisites.md) verified, it's time to start deploying some foundational resources. In this step you'll deploy a stand-in for the core networking components of a traditional platform landing zone Connectivity subscription.

## Subscription and resource group topology

This reference implementation is split across several resource groups in a single subscription. This is to act as a proxy for the distributed resource and subscription organization found in typical Azure landing zone implementations. You are expected to explore this reference implementation within a single subscription, but when you implement this at your organization, you will need to take what you've learned here and apply it to your actual landing zone platform subscriptions and resource group topology.

## Expected results

### Resource group

The following resource group will be created and populated with networking resources in the steps below.

| Name                              | Purpose                                   |
| :-------------------------------- | :---------------------------------------- |
| rg-plz-connectivity-regional-hubs | Contains all of your organization's regional hubs. A regional hubs include an egress firewall and Log Analytics for network logging. This is a stand-in for resources typically found in your Connectivity subscription. |

#### Resource group naming convention

Please notice resource groups that are prefixed `rg-plz-` are proxies for resources owned and managed by the platform team in their own platform landing zone subscriptions. Likewise, resource groups that are prefixed `rg-alz-` are resource groups found in the application landing zone subscription(s) for your solution. Since this is all being deployed to a single subscription, these two prefixes will help distinguish between platform and application landing zone resources.

### Networking resources

The hub will be a virtual network based hub, containing common shared resources like Azure Bastion, Azure Firewall for egress, and Private DNS zones for common services.

## Steps

1. Login into Azure and select the subscription that you'll be deploying into.

   > :book: The networking team logins into the Azure subscription that will contain the regional hub. At Contoso, all of their regional hubs are in the same, centrally-managed Connectivity subscription.

   ```bash
   az login
   az account show
   ```

1. Select a region with availability zones for this deployment guide's resources.

   ```bash
   export REGION_IAAS_BASELINE=eastus2
   ```

1. Create the networking hubs resource group.

   > :book: The networking team has all their regional networking hubs in the following resource group in their Connectivity subscription. (This resource group would have already existed as part of your platform team's Connectivity subscription. Also, the region indicated below is not related to the deployment region of the resources set in the prior step.)

   ```bash
   # [This takes less than one minute to run.]
   az group create -n rg-plz-connectivity-regional-hubs -l centralus
   ```

1. Create the regional network hub.

   > :book: In this scenario, the platform team has a regional hub that contains an Azure Firewall (with some existing org-wide policies), Azure Bastion, a gateway subnet for cross-premises connectivity, and Azure Monitor for hub network observability. They follow Microsoft's recommended sizing for the subnets. (These resources would have already existed as part of your platform team's Connectivity subscription.)
   >
   > The networking team has registered `10.200.[0-9].0` in their IP address management (IPAM) system for all regional hubs. The regional hub created below will be `10.200.0.0/24`.

   ```bash
   # [This takes about ten minutes to run.]
   az deployment group create -g rg-plz-connectivity-regional-hubs -f platform-team/hub-default.bicep -p location=${REGION_IAAS_BASELINE}

   export RESOURCEID_VNET_HUB_IAAS_BASELINE=$(az deployment group show -g rg-plz-connectivity-regional-hubs -n hub-default --query properties.outputs.hubVnetId.value -o tsv)
   echo RESOURCEID_VNET_HUB_IAAS_BASELINE: $RESOURCEID_VNET_HUB_IAAS_BASELINE
   ```

### Save your work-in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to iaas_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source iaas_baseline.env
```

### Next step

At this point, you have a basic connectivity subscription proxy, with basic connectivity subscription resources. Your architecture _has not yet influenced this deployment_, that'll happen with the fulfillment of your upcoming subscription vending request.

:arrow_forward: [Submit your application landing zone request](./03-subscription-vending-request.md)
