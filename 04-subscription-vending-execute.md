# Deploy a new application landing zone [Platform team]

As the platform team, you've [received a request from a new workload team](./03-subscription-vending-request.md) looking to stand up an application landing zone. Let's run this through a manual subscription vending process and hand the keys to the subscription back over to the application team.

## Subscription vending

The process below is manual in this deployment guide, it's likely your platform team has [automated](https://learn.microsoft.com/azure/architecture/landing-zones/subscription-vending) your [subscription vending process](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending).

## Expected results

### Resource group

The following resource group will be created and populated with core networking resources owned by the platform team.

| Name                 | Purpose                                   |
| :------------------- | :---------------------------------------- |
| rg-alz-bu04A42-spoke | This is a stand-in for in your application landing zone subscription, and specifically the virtual network in which your architecture will reside within. |

### Networking resources

The platform team provides the workload team one or more virtual networks to the specifiction provided by the workload team. In this case, it's a single virtual network. This network will be configured to use its regional hub, for both Internet egress and serving DNS.

Azure Firewall egress rules often need to be updated based on the gathered requirements. An example of those updates are deployed as part of this step.

### Identity resources

Typically your subscription vending process would yield identities that can then be used in your pipelines. This deployment guide will not be simulating this part.

## Steps

1. Create the networking spoke resource group.

   > :book: TODO-CK

   ```bash
   # [This takes less than one minute to run.]
   az group create -n rg-alz-bu04A42-spoke -l centralus

1. Create the spoke that will be home to the application team's compute and its adjacent resources.

   > :book: TODO-CK

   TODO-CK: File names
   TODO-CK: location is eastus but story I think says west coast -- fixup/bug?

   ```bash
   # [This takes about four minutes to run.]
   az deployment group create -g rg-alz-bu04A42-spoke -f networking/spoke-BU0001A0008.bicep -p location=eastus2 hubVnetResourceId="${RESOURCEID_VNET_HUB_IAAS_BASELINE}"
   ```

   TODO-CK: Capture in env variables
   TODO-CK: Add IpGroups for subnets (empty)
   TODO-CK: Groups: All VMs, Linux VMs, Windows VMs
            

   The spoke creation will emit the following:

     * `appGwPublicIpAddress` - The Public IP address of the Azure Application Gateway (WAF) that will receive traffic for your workload.
     * `spokeVnetResourceId` - The resource ID of the Virtual network where the VMs, App Gateway, and related resources will be deployed. E.g. `/subscriptions/[id]/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-spoke-BU0001A0008-00`
     * `vmssSubnetResourceIds` - The resource IDs of the Virtual network subnets for the VMs. E.g. `[ /subscriptions/[id]/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-spoke-BU0001A0008-00/subnet/snet-frontend, /subscriptions/[id]/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-spoke-BU0001A0008-00/subnet/snet-backend ]`

1. Update the shared, regional hub deployment to account for the requirements of the spoke.

   > :book: TODO-CK

   TODO-CK: Use IpGroups for subnets instead of subnet resource references
   TODO-CK: Bastion opening will need to be permissive.

   ```bash
   RESOURCEIDS_SUBNET_IAAS_BASELINE=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.vmssSubnetResourceIds.value -o json)
   echo RESOURCEIDS_SUBNET_IAAS_BASELINE: $RESOURCEIDS_SUBNET_IAAS_BASELINE

   # [This takes about ten minutes to run.]
   az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-regionA.bicep -p location=eastus2 vmssSubnetResourceIds="${RESOURCEIDS_SUBNET_IAAS_BASELINE}"
   ```

   The hub update  will emit the following:

      * `hubVnetId` - which you'll will query in future steps when creating connected regional spokes. E.g. `/subscriptions/[id]/resourceGroups/rg-enterprise-networking-hubs/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub`
      * `abName ` - which you'll will query in future steps when remotely connecting your VMs. E.g. `/subscriptions/[id]/resourceGroups/rg-enterprise-networking-hubs/providers/Microsoft.Network/bastionHosts/ab-eastus2`

   > TODO-CK
   >
   > :book: At this point the networking team has delivered a spoke in which BU 0001's app team can deploy the IaaS application (ID: A0008). The networking team provides the necessary information to the app team for them to reference in their infrastructure-as-code artifacts.
   >
   > Hubs and spokes are controlled by the networking team's GitHub Actions workflows. This automation is not included in this reference implementation as this body of work is focused on the IaaS baseline and not the networking team's CI/CD practices.

### Explore your resources

TODO-CK: Take the user through the "platform" and the application landing zone.

### Next step

This is the last step in which you'll be directly acting in the role of someone on the platform team. From this point forward, you now will be deploying your IaaS solution into your prepared application landing zone.

TODO-CK: Transition fully over to the workload team
