# Request your application landing zone [Workload team]

In the prior step, you [deployed a basic network hub](./02-connectivity-subscription.md) to stand-in for the typical resources found in your platform team's Connectivity subscription. Next, you'll turn your eyes to the workload's needs. You'll start by building a mock landing zone request.

## Expected results

We're going to take the core workload requirements from the IaaS baseline architecture and capture them as if it was part of the IT service management (ITSM) tooling or portal experience that your application landing zone subscripting vending process follows.

**There will be no resources deployed in this step.**

## Steps

1. Gather initial application requirements and submit application landing zone request.

   > :book: Instead of opening an ITSM ticket or using your internal request portal, listed below are key factors you'd likely be communicating to the platform team which will be used in the next step. These values are all from the [IaaS baseline](https://github.com/mspnp/iaas-baseline) architecture's technical requirements.

   - Biographical information
     - Business unit: **03**
     - App identifier: **42**
     - Mission-critical: **No**
   - Ingress information
     - Internet ingress: **Workload-managed, one public IP**
       - WAF and DDoS applied by workload team
     - Cross-premises ingress: **None**
   - Egress information
     - Internet egress: **Yes**
     - Known initial firewall allowances
       - Infra: Ubuntu updates and NTP
       - Infra: Windows updates and NTP
       - Infra: Azure monitor
       - Workload: nginx.org
       - Workload: GitHub endpoints
     - Cross-premises egress: **None**
     - Fully predictable public IP for egress: **No**
     - High SNAT port usage on egress: **No**
   - Number of virtual networks needed: **One**
     - Size: **/21**
     - Region: **$REGION_IAAS_BASELINE**, what a coincidence :)
   - Primary Azure resources:
     - Linux virtual machines
     - Windows virtual machines
     - Azure Application Gateway (with WAF)
   - Azure Bastion Access: **Yes**, platform provided
     - Existing compute admin Entra ID security group: **None**, please create.
   - Solution uses Private Link: **Yes**
     - Azure Key Vault
   - … plenty more such as: environment, latency sensitivity, user and service principal auth needs, etc.

   **To be clear, there was NO ACTION for you to perform here.**

### Next step

Now you'll switch back to playing the role of a Platform team member and create your mock application landing zone subscription based on these requirements. The "subscription" in this deployment guide will simply be represented as resource groups.

:arrow_forward: [Deploy your mock application landing zone subscription](./04-subscription-vending-execute.md)
