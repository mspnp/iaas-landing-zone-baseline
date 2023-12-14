# Deploy a new application landing zone [Platform team]

As the platform team, you've [received a new request from a workload team](./03-subscription-vending-request.md) looking to create an application landing zone for a new workload. Let's run this through a mock subscription vending process and hand the keys to the subscription back over to the application team.

## Subscription vending

The process below is manual in this deployment guide, it's likely your platform team has [automated](https://learn.microsoft.com/azure/architecture/landing-zones/subscription-vending) your [subscription vending process](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending). _For this deployment guide, you are not expected to use your existing subscription vending process._

## Expected results

### Resource group

The following resource group will be created and populated with core networking resources owned by the platform team, but delegated to you for your workload.

| Name                 | Purpose                                   |
| :------------------- | :---------------------------------------- |
| rg-alz-bu04a42-spoke | This is a stand-in for part of your application landing zone subscription. This specifically contains the virtual network in which your architecture will reside within. |

#### Resource group naming convention

Reminder that resource groups that are prefixed `rg-plz-` are proxies for resources owned and managed by the platform team in their own platform landing zone subscriptions. Likewise, resource groups that are prefixed `rg-alz-`, such as this one, are resource groups found in the application landing zone subscription(s) for your solution. Since this is all being deployed to a single subscription, these two prefixes will help distinguish between platform and application landing zone resources.

### Networking resources

The platform team provides the workload team one or more virtual networks to the specification provided by the workload team. In this case, it's a single virtual network. This network will be configured to use its regional hub, for both Internet egress and serving DNS.

Azure Firewall egress rules often need to be updated based on the gathered requirements. An example of those updates are deployed as part of this step.

- One virtual network (/21)
  - No subnets
  - DNS configured for regional hub
  - Peered to regional hub
- One UDR that is expected to be applied to subnets that will be egressing traffic, so that it will flow to the firewall.
- An IP Group that contains the Azure Bastion IP ranges for remote compute access.

### Identity and role-based access control (RBAC)

Typically your subscription vending process would yield identities that can then be used in your pipelines. This deployment guide will not be simulating this part. Also, it would be expected that you do not have full control over the network resources deployed. The network resources have a shared ownership/manipulation model between the platform team and you, the application team.

### Azure policy

Sample relevant Azure policies will be deployed to represent the types of policies you'd expect to see from your Online and Intermediate root management groups that govern application workloads. These policies would have existed PRIOR TO any individual application landing zone deployment, but since policies are going to be scoped to resource groups for isolation within your sandbox subscription, they are deployed at this point.  You may notice an empty "compute" resource group being deployed as well, that normally wouldn't have been part of this vending process, but is there just to get policy applied.

## Steps

1. Deploy and configure the application landing zone

   > :book: The platform team uses their IPAM system to allocate the required IP space, selects the appropriate management group to slot this application landing zone under, and invokes their subscription vending process to fullfil this subscription request, delegating RBAC permissions to the workload team as required.

   ```bash
   # [This takes about seven minutes to run.]
   az deployment sub create -l centralus -f platform-team/subscription-vending/deploy-alz-bu04a42.bicep -p location=${REGION_IAAS_BASELINE} hubVnetResourceId="${RESOURCEID_VNET_HUB_IAAS_BASELINE}"

   export RESOURCEID_VNET_SPOKE_IAAS_BASELINE=$(az deployment sub show -n deploy-alz-bu04a42 --query properties.outputs.spokeVirtualNetworkResourceId.value -o tsv)
   echo RESOURCEID_VNET_SPOKE_IAAS_BASELINE: $RESOURCEID_VNET_SPOKE_IAAS_BASELINE
   ```

   > :book: The application landing zone has been created, almost ready for the workload team to use for their scenario. The application team nows has a subscription dedicated to their scenario, with core networking components in place, connected to its regional hub, enrolled in cost management, and placed under organizational governance. Initial RBAC permissions have been assigned as well. As the application requirements evolve, their will undoubtedly be future requests from the application team to the platform team, such as Azure Firewall changes to support new egress flows. Likewise, the application team may submit troubleshooting requests for Connectivity resources. When the platform team has new Azure policy assignments or updates to roll out, there would be conversations to the impacted application team.

### Save your work-in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to iaas_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source iaas_baseline.env
```

### Next step

:arrow_forward: [Configure user access for application team](./05-entra-id.md)



:arrow_forward: Let's start by [getting your TLS certificates ready for workload deployment](./05-ca-certificates.md)
