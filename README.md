# Azure Infrastructure as a Service baseline

This reference implementation demonstrates a _recommended starting (baseline) infrastructure as a service architecture_ using [Virtual Machine Scale Sets](#). This implementation and document is meant to guide an interdisciplinary team or multiple distinct teams like networking, security and development through the process of getting this general purpose baseline infrastructure deployed and understanding its components.

We walk through the deployment here in a rather _verbose_ method to help you understand each component of this compute that relies on the very foundation of Virtual Machines. This guidance is meant to teach about each layer and providing you with the knowledge necessary to apply it to your workload.

## Azure Architecture Center guidance

This project has a companion set of articles that describe challenges, design patterns, and best practices for using Virtual Machine Scale Sets. You can find this article on the Azure Architecture Center at [Azure Infrastructure as a Service baseline](https://aka.ms/architecture/iaas-baseline). If you haven't reviewed it, we suggest you read it to learn about the considerations applied in the implementation. Ultimately, this is the direct implementation of that specific architectural guidance.

## Architecture

**This architecture is infrastructure focused**, more so than on workload. It concentrates on the VMSS itself, including concerns with identity, bootstrapping configuration, secret management, and network topologies.

The implementation presented here is the _minimum recommended baseline. This implementation integrates with Azure services that will deliver observability, provide a network topology that will support multi-regional growth, and keep the traffic secure. This architecture should be considered your starting point for pre-production and production stages.

The material here is relatively dense. We strongly encourage you to dedicate time to walk through these instructions, with a mind to learning. We do NOT provide any "one click" deployment here. However, once you've understood the components involved and identified the shared responsibilities between your team and your great organization, it is encouraged that you build suitable, auditable deployment processes around your final infrastructure.

Throughout the reference implementation, you will see reference to _Contoso_. Contoso is a fictional fast-growing startup that provides online web services to its clientele on the west coast of North America. The company has on-premise data centers and all their line of business applications are now about to be orchestrated by secure, enterprise-ready Infrastructure as a Service using Virtual Machine Scale Sets. You can read more about [their requirements and their IT team composition](./contoso/README.md). This narrative provides grounding for some implementation details, naming conventions, etc. You should adapt as you see fit.

Finally, this implementation uses [Nginx](https://nginx.org) as an example workload in the the frontend and backend VMs. This workload is purposefully uninteresting, as it is here exclusively to help you experience the baseline infrastructure.

### Core architecture components

#### Azure platform

- VMSS
  - [Availability Zones](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-use-availability-zones)
  - [Flex orchestration mode](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes)
  - Monitoring: [VM Insights](https://learn.microsoft.com/azure/azure-monitor/vm/vminsights-overview)
  - Security: [Automatic Guest Patching](https://learn.microsoft.com/azure/virtual-machines/automatic-vm-guest-patching)
  - Extensions
    1. [Azure Monitor Agent](https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-manage?toc=%2Fazure%2Fvirtual-machines%2Ftoc.json&tabs=azure-portal)
    1. _Preview_ [Application Health](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-health-extension)
    1. Azure KeyVaut [Linux](https://learn.microsoft.com/azure/virtual-machines/extensions/key-vault-linux) and [Windows](https://learn.microsoft.com/azure/virtual-machines/extensions/key-vault-windows?tabs=version3)
    1. Custom Script for [Linux](https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-linux) and [Windows](https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-windows)
    1. [Automatic Extension Upgrades](https://learn.microsoft.com/azure/virtual-machines/automatic-extension-upgrade)
  - [Autoscale](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-autoscale-overview)
  - [Ephemeral OS disks](https://learn.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks)
  - Managed Identities
- Azure Virtual Networks (hub-spoke)
  - Azure Firewall managed egress
- Azure Application Gateway (WAF)
- Internal Load Balancers

#### In-VM OSS components

- [NGINX](http://nginx.org/)

![Network diagram depicting a hub-spoke network with two peered VNets and main Azure resources used in the architecture.](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks/images/secure-baseline-architecture.svg)

## Deploy the reference implementation

A deployment of VM-hosted workloads typically experiences a separation of duties and lifecycle management in the area of prerequisites, the host network, the compute infrastructure, and finally the workload itself. This reference implementation is similar. Also, be aware our primary purpose is to illustrate the topology and decisions of a baseline infrastructure as a service. We feel a "step-by-step" flow will help you learn the pieces of the solution and give you insight into the relationship between them. Ultimately, lifecycle/SDLC management of your compute and its dependencies will depend on your situation (team roles, organizational standards, etc), and will be implemented as appropriate for your needs.

**Please start this learning journey in the _Preparing for the VMs_ section.** If you follow this through to the end, you'll have our recommended baseline infrastructure as a service installed, with an end-to-end sample workload running for you to reference in your own Azure subscription.

### 1. :rocket: Preparing for the VMs

There are considerations that must be addressed before you start deploying your compute. Do I have enough permissions in my subscription and AD tenant to do a deployment of this size? How much of this will be handled by my team directly vs having another team be responsible?

- [ ] Begin by ensuring you [install and meet the prerequisites](./01-prerequisites.md)
- [ ] [Procure client-facing and VM TLS certificates](./02-ca-certificates.md)
- [ ] [Plan your Azure Active Directory integration](./03-aad.md)

### 2. Build target network

Microsoft recommends VMs be deploy into a carefully planned network; sized appropriately for your needs and with proper network observability. Organizations typically favor a traditional hub-spoke model, which is reflected in this implementation. While this is a standard hub-spoke model, there are fundamental sizing and portioning considerations included that should be understood.

- [ ] [Build the hub-spoke network](./04-networking.md)

### 3. Deploying the VMs and Workload

This is the heart of the guidance in this reference implementation; paired with prior network topology guidance. Here you will deploy the Azure resources for your compute and the adjacent services such as Azure Application Gateway WAF, Azure Monitor, and Azure Key Vault. This is also where you will validate the VMs are bootstrapped.

- [ ] [Prep for VMs bootstrapping](./05-bootstrap-prep.md)
- [ ] [Deploy the VMs, workload, and supporting services](./06-compute-infra.md)
- [ ] [Validate compute infrastructure bootsrapping](./07-bootstrap-validation.md)

We perform the prior steps manually here for you to understand the involved components, but we advocate for an automated DevOps process. Therefore, incorporate the prior steps into your CI/CD pipeline, as you would any infrastructure as code (IaC).

### 5. :checkered_flag: Validation

Now that the compute and the sample workload is deployed; it's time to look at how the VMs are functioning.

- [ ] [Perform end-to-end deployment validation](./11-validation.md)

## :broom: Clean up resources

Most of the Azure resources deployed in the prior steps will incur ongoing charges unless removed.

- [ ] [Cleanup all resources](./12-cleanup.md)

## Related reference implementations

The Infrastructure as a Service baseline was used as the foundation for the following additional reference implementations:

- [IaaS LZ](#)

## Advanced topics

This reference implementation intentionally does not cover more advanced scenarios. For example topics like the following are not addressed:

- Compute lifecycle management with regard to SDLC and GitOps
- Workload SDLC integration
- Multiple (related or unrelated) workloads owned by the same team
- Multiple workloads owned by disparate teams (VMs as a shared platform in your organization)
- [Autoscaling](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-autoscale-overview)

Keep watching this space, as we build out reference implementation guidance on topics such as these. Further guidance delivered will use this baseline infrastructure as a service implementation as their starting point. If you would like to contribute or suggest a pattern built on this baseline, [please get in touch](./CONTRIBUTING.md).

## Related documentation

- [Virtual Machine Scale Sets Documentation](https://learn.microsoft.com/azure/virtual-machine-scale-sets/)
- [Microsoft Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)

## Contributions

Please see our [contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Microsoft Patterns & Practices, [Azure Architecture Center](https://aka.ms/architecture).
