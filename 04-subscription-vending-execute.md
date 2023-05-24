# Deploy a new application landing zone [Platform team]

As the platform team, you've [received a request from a new workload team](./03-subscription-vending-request.md) looking to stand up an application landing zone. Let's run this through a manual subscription vending process and hand the keys to the subscription back over to the application team.

## Subscription vending

The process below is manual in this deployment guide, it's likely your platform team has [automated](https://learn.microsoft.com/azure/architecture/landing-zones/subscription-vending) your [subscription vending process](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending).

## Expected results

### Resource group

The following resource group will be created and populated with core networking resources owned by the platform team.

| Name                 | Purpose                                   |
| :------------------- | :---------------------------------------- |
| rg-alz-bu04a42-spoke | This is a stand-in for in your application landing zone subscription, and specifically the virtual network in which your architecture will reside within. |

### Networking resources

The platform team provides the workload team one or more virtual networks to the specifiction provided by the workload team. In this case, it's a single virtual network. This network will be configured to use its regional hub, for both Internet egress and serving DNS.

Azure Firewall egress rules often need to be updated based on the gathered requirements. An example of those updates are deployed as part of this step.

### Identity resources

Typically your subscription vending process would yield identities that can then be used in your pipelines. This deployment guide will not be simulating this part.

## Steps

1. Deploy the application landing zone

   > :book: TODO-CK

   ```bash
   # [This takes about two minutes to run.]
   az deployment sub create -l eastus2 -f platform-landing-zone/subscription-vending/deploy-alz-bu04a42.bicep -p location=eastus2 hubVnetResourceId="${RESOURCEID_VNET_HUB_IAAS_BASELINE}"
   ```


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
