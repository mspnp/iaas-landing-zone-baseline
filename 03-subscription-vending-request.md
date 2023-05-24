# Request your application landing zone [Workload team]

In the prior step, you [deployed a fairly basic network hub](./02-connectivity-subscription.md) to stand in for the typical resources found in a Connectivity subscription. Next we start turning our eyes to the workload's needs. You'll start by building a mock landing zone request

## Expected results

We're going to take the core workload requirements from the [IaaS baseline](https://github.com/mspnp/iaas-baseline) and capture them as if it was part of the ITSM tooling or portal experience that your landging zone subscripting vending process follows. There will be no resources deployed in this step.

## Steps

1. Communicate initial application requirements.

   > :book: Instead of opening an ITSM ticket or using your portal, we'll document key concepts to communicate which will be used in the next step. These values are all from the [IaaS baseline](https://github.com/mspnp/iaas-baseline) architecture.

   - Business unit: **BU03**
   - App identifier: **A42**
   - Environment: **Pre-production**
   - Internet Ingress: **Workload-managed, one public IP**
     - WAF and DDoS applied by workload team
   - Cross-premises ingress: **None**
   - Internet egress: **Yes**
     - Infra: Ubuntu updates and NTP
     - Infra: Windows updates and NTP
     - Infra: Azure monitor
     - Workload: nginx.org
     - Workload: github
   - Cross-premises egress: **None**
   - Number of virtual networks needed: **one**
     - Size: **/16** TODO-CK
     - Region: **eastus2**
   - Primary Azure resources:
     - Linux virtual machines
     - Windows virtual machines
     - Azure Application Gateway (with WAF)
   - Solution uses Private Link: **Yes**
     - TODO-CK
   - Mission-critical: **No**
   - Latency-senstive: **No**
   - High SNAT port usage on egress: **No**
   - Fully predictable public IP for egress: **No**
   - AAD Security group for virtual machine access: **TODO-CK**
   - ... plenty more such as both user and service principal auth needs, etc.

### Next step

Now you'll switch back to playing the role of a Platform team member, and will create your workload's landing zone subscription (represented as a resource group in this walkthrough).

:arrow_forward: [Deploy your mock application landing zone subscription](./04-subscription-vending-execute.md)