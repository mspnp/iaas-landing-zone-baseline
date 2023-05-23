# Case study – Contoso

Contoso, a fictitious technology company, is investing in modernizing its legendary infrastructure for the well-known Contoso weather forecasting app. The app relies on a highly demanded low latency business web API that is served by backend servers located on their three on-premises servers in a single datacenter, which poses a risk to their service level agreement (SLA) as power, cooling, and networking issues could affect all their servers. However, as their business grows, they realize that they need better resiliency to handle the increasing demand for their API. To reduce the risk of data loss and ensure a more robust infrastructure, they decide to take advantage of the cloud infrastructure as a service offering by creating virtual machines in the cloud across three different zones (1, 2, and 3). The Contoso IT department with the help of Azure is successfully migrating their backend servers to the cloud, and their API continues to provide fast and reliable weather forecasts to both internal and external clients in the west coast, North America.

External clients access the web app hosted on frontend servers, which in turn relies on a web API hosted in backend servers. The application experiences high seasonality in traffic. Contoso wants to leverage the elasticity of cloud infrastructure to scale in or out their frontend virtual machines based on fluctuations in traffic while keeping the backend virtual machines at a reserved capacity. This ensures that the backend servers are always ready to handle any workload without compromising on performance. With Azure's help, Contoso can easily adjust their resources as needed to meet their clients' demands and provide a seamless user experience. Here's the brief hybrid on-premises and cloud profile:


- Have two workloads running and operating on premises.
- Use Azure Active Directory for identity management.
- They are investing in getting knowledgeable about containers but as a first step they plan to land in the cloud using Infrastructure as a Service resources.
- Aware of Virtual Machine Scale Sets and their new capabilities for orchestration.

Overall, Contoso's migration to Azure is improving their resiliency, flexibility, and scalability. The Azure's infrastructure as a service offering has allowed Contoso to focus on their core business and provide better services to their clients. With the ongoing growth of their business, Contoso is confident that their cloud-based infrastructure will be able to meet their evolving needs and provide a reliable and efficient platform for their weather forecasting app.

Based on the company's profile and business requirements, we've created a [reference architecture](https://aka.ms/architecture/iaas-baseline) that serves as an Infrastructure as a Service baseline. The architecture is accompanied with the implementation found in this repo. We recommend that you start with this implementation and add components based on your needs.

## Organization structure

Contoso has a single IT Team with these sub teams.

![Contoso teams](contoso-teams.svg)

### Architecture team

Work with the line of business from idea through deployment into production. They understand all aspects of the Azure components: function, integration, controls, and monitoring capabilities. The team evaluates those aspects for functional, security, and compliance requirements. They coordinate and have representation from other teams. Their workflow aligns with Contoso's SDL process.

### Development team

Responsible for developing Contoso’s web services. They rely on the guidance from the architecture team about implementing cloud design patterns. They own and run the integration and deployment pipeline for the web services.

### Security team

Review Azure services and workloads from the lens of security. Incorporate Azure service best practices in configurations. They review choices for authentication, authorization, network connectivity, encryption, and key management and, or rotation. Also, they have monitoring requirements for any proposed service.

### Identity team

Responsible for identity and access management for the Azure environment. They work with the Security and Architecture teams for use of Azure Active Directory, role-based access controls, and segmentation. Also, monitoring service principles for service access and application level access.

### Networking team

Make sure that different architectural components can talk to each other in a secure manner. They manage the hub and spoke network topologies and IP space allocation.

### Operations team

Responsible for the infrastructure deployment and day-to-day operations of the Azure environment.

## Business requirements

Here are the requirements based on an initial [Well-Architected Framework review](https://learn.microsoft.com/assessments/?id=azure-architecture-review).

### Reliability

- Global presence: The customer base is focused on the West Coast of North America.
- Business continuity: The workloads need to be highly available at a minimum cost. They have a Recovery Time Objective (RTO) of 4 hours.
- On-premises connectivity: They don’t need to connect to on-premises data centers or legacy applications.

### Performance efficiency

The web service’s host should have these capabilities.

- Auto scaling: Automatically scale to handle the demands of expected traffic patterns. The web service is unlikely to experience a high-volume scale event. The scaling methods shouldn't drive up the cost.
- Right sizing: Select hardware size and features that are suited for the web service and are cost effective.
- Growth: Ability to expand the workload or add adjacent workloads as the product matures and gains market adoption.
- Monitoring: Emit telemetry metrics to get insights into the performance and scaling operations. Integration with Azure Monitor is preferred.
- Workload-based scaling: Allow granular scaling per workload and independent scaling between different partitions in the workload.

### Security

- Identity management: Contoso is an existing Microsoft 365 user. They rely heavily on Azure Active Directory as their control plane for identity.
- Certificate: They must expose all web services through SSL and aim for end-to-end encryption, as much as possible.
- Network: They have existing workloads running in Azure Virtual Networks. They would like to minimize direct exposure to Azure resources to the public internet. Their existing architecture runs with regional hub and spoke topologies. This way, the network can be expanded in the future and also provide workload isolation. All web applications require a web application firewall (WAF) service to help govern HTTP traffic flows.
- Secrets management: They would like to use a secure store for sensitive information.

### Operational excellence

- Logging, monitoring, metrics, alerting: They use Azure Monitor for their existing workloads. They would like to use it for AKS, if possible.
- Automated deployments: They understand the importance of automation. They build automated processes for all infrastructure so that environments and workloads
can easily be recreated consistently and at any time.

### Cost optimization

- Cost center: There’s only one line-of-business. So, all costs are billed to a single cost center.
- Budget and alerts: They have certain planned budgets. They want to be alerted when certain thresholds like 50%, 75%, and 90% of the plan has been reached.

## Design and technology choices

- Deploy the VMSS frontend and backend instances into an existing Azure Virtual Network spoke. Use the existing Azure Firewall in the regional hub for securing outgoing traffic from the Virtual Machines.
- Traffic from public facing website is required to be encrypted. This encryption is implemented with Azure Application Gateway with integrated web application firewall (WAF).
- The frontend and backend VMSS frontend are configured with flexible orchestration mode, allowing the operations team to incorporate a variety of Virtual Machines SKUs, and to receive security patching and extensions upgrades. The frontend VMs are configured with Ephemeral OS and burstable VM SKUs for web servers.
- Use NGINX as the web server.
- The web app workload is stateless. No data will be persisted inside the Virtual Machines.
- The web Api workload is stateful. Data will be persisted inside the Virtual Machines managed data disks.

- Azure Network Policy will be enabled for use, even though there's a single workload in one line-of-business.
- Azure Control Plane requests are sent with `az-cli` using bicep templates.
- Azure Monitor VM Insights will be used for logging, metrics, monitoring, and alerting to use the existing knowledge of Log Analytics.
- Azure Key Vault will be used to store all secret information including SSL certificates. Key Vault data will be integrated with VM extensions.
- Three Virtual Machines using different skus for demostration purposes are added to the VMSS Flex to serve api traffic.
- All compute resources are distributed evenly in all Azure Availability Zones (1, 2 and 3) and Fault Domains for better SLA.

