# Infrastructure-as-a-service baseline for Azure landing zones

This reference implementation demonstrates a _recommended starting (baseline) infrastructure as a service (IaaS) architecture_ with special considerations for Azure landing zone integration. This implementation is a direct continuation of the [IaaS baseline reference implementation](https://github.com/mspnp/iaas-baseline), which did not have any specialized Azure landing zone context.

## Azure landing zone workload focus

This repository and its deployment guide primarily addresses the **workload team** looking to build our their solution expected to be homed within a workload Azure landing zone. The **platform team** will be referenced throughout where their role in this solution is required. However, their role will be abstracted out through proxy deployments and hypotheticals.

This solution is written as if it will be deployed into a single sandbox or a standalone subscription. Functions normally provided by your **platform team** will be included in this deployment, but purely a stand-in for your individualized Azure landing zone implementation.

We walk through the deployment here in a rather _verbose_ method to help you understand each component of this architecture so that you can understand what parts would map back to your responsibility as a **workload team** vs the responsbility of the **platform team**.

## Azure Architecture Center guidance

This project has a companion reference architecture article that describe the architecture, design patterns, and other guidance for this implementation. You can find this article on the Azure Architecture Center at [Infrastructure as a Service baseline for Azure landing zones](https://aka.ms/architecture/iaas-lz-baseline). If you haven't reviewed it, we suggest you read it to learn about the considerations applied in the implementation. Ultimately, this is the direct implementation of that specific architectural guidance.

## Architecture

**This architecture is infrastructure focused**, more so than on workload. It concentrates on the VMSS itself, including concerns with identity, bootstrapping configuration, secret management, and network topologies, all with the explicit context that it's expected to be deployed within a workload Azure landing zone.

The implementation presented here is the _minimum recommended baseline_. This implementation integrates with Azure services provided by the platform team and owned by you, the workload team, that will deliver observability and provide a network topology to help keep the traffic secure. This architecture should be considered your starting point for pre-production and production stages.

The material here is relatively dense. We strongly encourage you to dedicate time to walk through this deployment guide, with a mind to _learning_. We do NOT provide any "one click" deployment here. However, once you've understood the components involved and identified the shared responsibilities between your workload team and your platform team, it is encouraged that you build suitable, auditable deployment processes around your final infrastructure.

Throughout the reference implementation, you will see reference to _Contoso_. Contoso is a fictional fast-growing startup that has adopted the Azure landing zones conceptual architecture to govern their organization's Azure deployment. Contoso provides online web services to its clientele on the west coast of North America. The company has on-premise data centers and some of their business applications are now about to be run from infrastructure as a service on Azure using Virtual Machine Scale Sets. You can read more about [their requirements and their IT team composition](./contoso/README.md). This narrative provides grounding for some implementation details, naming conventions, etc. You should adapt as you see fit.

### The workload

This implementation uses [Nginx](https://nginx.org) as an example workload in the the frontend and backend virtual machines. This workload is purposefully _uninteresting_, as it is here exclusively to help you experience the baseline infrastructure running within the context of a landing zone.

### Core architecture components

- Virtual machines executing within Virtual Machine Scale Sets
  - [Availability Zones](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-use-availability-zones)
  - [Flex orchestration mode](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes)
  - Monitoring: [VM Insights](https://learn.microsoft.com/azure/azure-monitor/vm/vminsights-overview)
  - Security: [Automatic Guest Patching](https://learn.microsoft.com/azure/virtual-machines/automatic-vm-guest-patching)
  - Virtual machine extensions:
    - [Azure Monitor Agent](https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-manage?toc=%2Fazure%2Fvirtual-machines%2Ftoc.json&tabs=azure-portal)
    - _Preview_ [Application Health](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-health-extension)
    - Azure Key Vault [Linux](https://learn.microsoft.com/azure/virtual-machines/extensions/key-vault-linux) and [Windows](https://learn.microsoft.com/azure/virtual-machines/extensions/key-vault-windows?tabs=version3)
    - Custom Script for [Linux](https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-linux) and [Windows](https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-windows)
    - [Automatic Extension Upgrades](https://learn.microsoft.com/azure/virtual-machines/automatic-extension-upgrade)
  - [Autoscale](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-autoscale-overview)
  - [Ephemeral OS disks](https://learn.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks)
  - Managed Identities
- Azure Virtual Networks (hub-spoke)
  - Azure Firewall managed egress
- Azure Application Gateway (WAF)
- Internal Load Balancers

![Network diagram depicting a hub-spoke network with two peered virtual networks and main Azure resources used in the architecture.](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks/images/secure-baseline-architecture.svg)

## Which Azure landing zone implementation?

Azure landing zone implementations are varied, by design. Your implementation likely will share some similarities with the conceptual architecture used here, but likely may deviate in significant ways. These ways could be as fundimental as a different NVA instead of Azure Firewall running from a Secured Vitual Hub in a Azure Virtual WAN to subtle things like an Azure Policy applied to your target management group that disallows a feature showcased in this implementation.

We acknowledge that you will need to map your organization's Azure landing zone realities onto this architecture. This architecture strives to follow an implementation similar to one described in [Deploy Enterprise-Scale with hub and spoke architecture](https://github.com/Azure/Enterprise-Scale/blob/main/docs/reference/adventureworks/README.md), and as such the deployment guide will reference key concepts like the "Connectivity subscription," "Subscription vending," or "Online" management group; to name a few.

**You do NOT need to fully understand your own Azure landing zone platform implementation in order to use this deployment guide.** You will be deploying into a single subscription, you will not be expected to connect to ANY existing networks or platform resources.

### Application landing zone

The workload that we are deploying in this guide aligns with the Cloud Adoption Framework definition of an _application landing zone_, and specifically the subcategoy of _workload_. We'll be refering to the workload's landing zone as the "application landing zone" in this deployment guide.

See [Platform vs. application landing zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/#platform-vs-application-landing-zones) as a reminder of the distinction.

## Deploy the reference implementation

Azure landing zone deployments or any workload always experiences a separation of duties and lifecycle management in the area of prerequisites, the host network, the compute infrastructure, and finally the workload itself. This reference implementation acknowledges this. To make that clearer, a "step-by-step" flow will help you learn the pieces of the solution and give you insight into the relationship between them. Ultimately, lifecycle/SDLC management of your compute and its dependencies will depend on your situation (team roles, organizational standards, etc), and will be implemented as appropriate for your needs.

**Please start this learning journey in the _Preparing for the VMs_ section.** If you follow this through to the end, you'll have our recommended baseline infrastructure as a service installed, with an end-to-end sample workload running for you to reference in your own Azure subscription, mirroring a typical Azure landing zone implementation.

### 1. :rocket: Build a platform landing zone proxy

You are not the platform team, and you are not deploying this into an existing Azure landing zone platform topology, as such we need to set up a proxy version of key typical components to reflect a more realistic resource organization. Also, we just need you to ensure you have the tools and access necessary to accomplish all of the tasks in this deployment guide.

- [ ] Begin by ensuring you [install and meet the prerequisites](./01-prerequisites.md)
- [ ] [Deploy mock connectitity subscription](./02-connectivity-subscription.md)

### 2. Request a application landing zone

All landing zone deployments eventually need the actual subscription(s) the workload resources will be deployed to. Most organizations have a subscription vending process to create these application landing zone subscriptions. Let's walk through the request and fulfillment

- [ ] [Submit your application landing zone request](./03-subscription-vending-request.md)
- [ ] [Deploy a mock application landing zone subscription](./04-subscription-vending-execute.md)

### 3. Deploy the workload infrastructure

This is the heart of the guidance in this reference implementation; paired with prior network topology guidance. Here you will deploy the Azure resources for your compute and the adjacent services such as Azure Application Gateway WAF, Azure Monitor, and Azure Key Vault.

**TODO-CK: Reflow as the narative builds out.**

- [ ] [Procure client-facing and VM TLS certificates](./02-ca-certificates.md)
- [ ] [Plan your Azure Active Directory integration](./03-aad.md)
- [ ] [Build the hub-spoke network](./04-networking.md)
- [ ] [Prep for VMs bootstrapping](./05-bootstrap-prep.md)
- [ ] [Deploy the VMs, workload, and supporting services](./06-compute-infra.md)

We perform the prior steps manually here for you to understand the involved components, but we advocate for an automated DevOps process. Therefore, incorporate the prior steps into your CI/CD pipeline, as you would any infrastructure as code (IaC).

### 5. :checkered_flag: Validation

Now that the compute and the sample workload is deployed; it's time to look at how it's all working.

- [ ] [Validate compute infrastructure bootsrapping](./07-bootstrap-validation.md)
- [ ] [Perform end-to-end deployment validation](./11-validation.md)

## :broom: Clean up resources

Most of the Azure resources deployed in the prior steps will incur ongoing charges unless removed.

- [ ] [Cleanup all resources](./12-cleanup.md)

## Related documentation

- [Virtual Machine Scale Sets Documentation](https://learn.microsoft.com/azure/virtual-machine-scale-sets/)
- [Microsoft Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)

## Contributions

Please see our [contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Microsoft Patterns & Practices, [Azure Architecture Center](https://aka.ms/architecture).
