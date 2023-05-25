# Request your application landing zone [Workload team]

In the prior step, you [deployed a fairly basic network hub](./02-connectivity-subscription.md) to stand in for the typical resources found in a Connectivity subscription. Next we start turning our eyes to the workload's needs. You'll start by building a mock landing zone request

## Expected results

We're going to take the core workload requirements from the [IaaS baseline](https://github.com/mspnp/iaas-baseline) and capture them as if it was part of the ITSM tooling or portal experience that your landging zone subscripting vending process follows.

**There will be no resources deployed in this step.**

## Steps

1. Gather initial application requirements and submit application landing zone request.

   > :book: Instead of opening an ITSM ticket or using your portal, we'll document key concepts to communicate to the platform team which will be used in the next step. These values are all from the [IaaS baseline](https://github.com/mspnp/iaas-baseline) architecture.

   - Biographical information
     - Business unit: **BU03**
     - App identifier: **A42**
     - Mission-critical: **No**
   - Ingress information
     - Internet ingress: **Workload-managed, one public IP**
       - WAF and DDoS applied by workload team
     - Cross-premises ingress: **None**
   - Engress information
     - Internet egress: **Yes**
     - Known initial firewall allowances
       - Infra: Ubuntu updates and NTP
       - Infra: Windows updates and NTP
       - Infra: Azure monitor
       - Workload: nginx.org
       - Workload: github
     - Cross-premises egress: **None**
     - Fully predictable public IP for egress: **No**
     - High SNAT port usage on egress: **No**
   - Number of virtual networks needed: **One**
     - Size: **/21**
     - Region: **eastus2**
   - Primary Azure resources:
     - Linux virtual machines
     - Windows virtual machines
     - Azure Application Gateway (with WAF)
   - Solution uses Private Link: **Yes**
     - Azure Storage
     - Azure Key Vault
   - … plenty more such as: environment, latency sensitivity, user and service principal auth needs, etc.

   **To be clear, there was NO ACTION for you to perform here.**

### Next step

Now you'll switch back to playing the role of a Platform team member, and will create your workload's landing zone subscription, which in this deployment guide is simply represented as a resource group.

:arrow_forward: [Deploy your mock application landing zone subscription](./04-subscription-vending-execute.md)