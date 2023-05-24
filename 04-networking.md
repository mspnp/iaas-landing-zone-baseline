# Deploy the hub-spoke network topology

The prerequisites for the [IaaS baseline](./) are now completed with [Azure AD group and user work](./03-aad.md) performed in the prior steps. Now we will start with our first Azure resource deployment, the network resources.

**TODO-CK: Figure out what we need to do here.  Taking out of user flow for now.**

## Subscription and resource group topology

This reference implementation is split across several resource groups in a single subscription. This is to replicate the fact that many organizations will split certain responsibilities into specialized subscriptions (e.g. regional hubs/vwan in a _Connectivity_ subscription and workloads in landing zone subscriptions). We expect you to explore this reference implementation within a single subscription, but when you implement this at your organization, you will need to take what you've learned here and apply it to your expected subscription and resource group topology (such as those [offered by the Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/decision-guides/subscriptions/).) This single subscription, multiple resource group model is for simplicity of demonstration purposes only.

## Expected results

### Resource groups

The following two resource groups will be created and populated with networking resources in the steps below.

| Name                            | Purpose                                   |
|---------------------------------|-------------------------------------------|
| rg-enterprise-networking-hubs   | Contains all of your organization's regional hubs. A regional hubs include an egress firewall and Log Analytics for network logging. |
| rg-enterprise-networking-spokes | Contains all of your organization's regional spokes and related networking resources. All spokes will peer with their regional hub and subnets will egress through the regional firewall in the hub. |

### Resources

* Regional Azure Firewall in hub virtual network
* Network spoke for the compute resources
* Network peering from the spoke to the hub
* Force tunnel UDR for compute subnets to the hub
* Network Security Groups for all subnets that support them

## Steps

1. Login into the Azure subscription that you'll be deploying into.

   > :book: The networking team logins into the Azure subscription that will contain the regional hub. At Contoso, all of their regional hubs are in the same, centrally-managed subscription.

   ```bash
   az login -t $TENANTID_AZSUBSCRIPTION_IAAS_BASELINE
   ```

1. Create the networking hubs resource group.

   > :book: The networking team has all their regional networking hubs in the following resource group. The group's default location does not matter, as it's not tied to the resource locations. (This resource group would have already existed.)

   ```bash
   # [This takes less than one minute to run.]
   az group create -n rg-enterprise-networking-hubs -l centralus
   ```

1. Create the networking spokes resource group.

   > :book: The networking team also keeps all of their spokes in a centrally-managed resource group. As with the hubs resource group, the location of this group does not matter and will not factor into where our network will live. (This resource group would have already existed or would have been part of an Azure landing zone that contains the compute resources.)

   ```bash
   # [This takes less than one minute to run.]
   az group create -n rg-enterprise-networking-spokes -l centralus
   ```

1. Create the regional network hub.

   > :book: When the networking team created the regional hub for eastus2, it didn't have any spokes yet defined, yet the networking team always lays out a base hub following a standard pattern (defined in `hub-default.bicep`). A hub always contains an Azure Firewall (with some org-wide policies), Azure Bastion, a gateway subnet for VPN connectivity, and Azure Monitor for network observability. They follow Microsoft's recommended sizing for the subnets.
   >
   > The networking team has decided that `10.200.[0-9].0` will be where all regional hubs are homed on their organization's network space. The `eastus2` hub (created below) will be `10.200.0.0/24`.

   ```bash
   # [This takes about six minutes to run.]
   az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-default.bicep -p location=eastus2
   ```

   The hub creation will emit the following:

      * `hubVnetId` - which you'll will query in future steps when creating connected regional spokes. E.g. `/subscriptions/[id]/resourceGroups/rg-enterprise-networking-hubs/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub`

1. Create the spoke that will be home to the compute and its adjacent resources.

   > :book: The networking team receives a request from an app team in business unit (BU) 0001 for a network spoke to house their new VM-based application (Internally know as Application ID: A0008). The network team talks with the app team to understand their requirements and aligns those needs with Microsoft's best practices for a general-purpose compute deployment. They capture those specific requirements and deploy the spoke, aligning to those specs, and connecting it to the matching regional hub.

   ```bash
   RESOURCEID_VNET_HUB=$(az deployment group show -g rg-enterprise-networking-hubs -n hub-default --query properties.outputs.hubVnetId.value -o tsv)
   echo RESOURCEID_VNET_HUB: $RESOURCEID_VNET_HUB

   # [This takes about four minutes to run.]
   az deployment group create -g rg-enterprise-networking-spokes -f networking/spoke-BU0001A0008.bicep -p location=eastus2 hubVnetResourceId="${RESOURCEID_VNET_HUB}"
   ```

   The spoke creation will emit the following:

     * `appGwPublicIpAddress` - The Public IP address of the Azure Application Gateway (WAF) that will receive traffic for your workload.
     * `spokeVnetResourceId` - The resource ID of the Virtual network where the VMs, App Gateway, and related resources will be deployed. E.g. `/subscriptions/[id]/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-spoke-BU0001A0008-00`
     * `vmssSubnetResourceIds` - The resource IDs of the Virtual network subnets for the VMs. E.g. `[ /subscriptions/[id]/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-spoke-BU0001A0008-00/subnet/snet-frontend, /subscriptions/[id]/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-spoke-BU0001A0008-00/subnet/snet-backend ]`

1. Update the shared, regional hub deployment to account for the requirements of the spoke.

   > :book: Now that their regional hub has its first spoke, the hub can no longer run off of the generic hub template. The networking team creates a named hub template (e.g. `hub-eastus2.bicep`) to forever represent this specific hub and the features this specific hub needs in order to support its spokes' requirements. As new spokes are attached and new requirements arise for the regional hub, they will be added to this template file.

   ```bash
   RESOURCEIDS_SUBNET_IAAS_BASELINE=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.vmssSubnetResourceIds.value -o json)
   echo RESOURCEIDS_SUBNET_IAAS_BASELINE: $RESOURCEIDS_SUBNET_IAAS_BASELINE

   # [This takes about ten minutes to run.]
   az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-regionA.bicep -p location=eastus2 vmssSubnetResourceIds="${RESOURCEIDS_SUBNET_IAAS_BASELINE}"
   ```

   The hub update  will emit the following:

      * `hubVnetId` - which you'll will query in future steps when creating connected regional spokes. E.g. `/subscriptions/[id]/resourceGroups/rg-enterprise-networking-hubs/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub`
      * `abName ` - which you'll will query in future steps when remotely connecting your VMs. E.g. `/subscriptions/[id]/resourceGroups/rg-enterprise-networking-hubs/providers/Microsoft.Network/bastionHosts/ab-eastus2`

   > :book: At this point the networking team has delivered a spoke in which BU 0001's app team can deploy the IaaS application (ID: A0008). The networking team provides the necessary information to the app team for them to reference in their infrastructure-as-code artifacts.
   >
   > Hubs and spokes are controlled by the networking team's GitHub Actions workflows. This automation is not included in this reference implementation as this body of work is focused on the IaaS baseline and not the networking team's CI/CD practices.

### Next step

:arrow_forward: [Prep for compute bootstrapping](./05-bootstrap-prep.md)
