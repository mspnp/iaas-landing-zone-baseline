# Case study – Contoso

Contoso, a fictitious technology company, is investing in modernizing its legendary infrastructure for the well-known Contoso weather forecasting app. The app relies on a highly demanded low latency business web API that is served by backend servers located on their three on-premises servers in a single data center, which poses a risk to their service level agreement (SLA) as power, cooling, and networking issues could affect all their servers. However, as their business grows, they realize that they need better resiliency to handle the increasing demand for their API. To reduce the risk of data loss and ensure a more robust infrastructure, they decide to take advantage of the cloud infrastructure as a service offering by creating virtual machines in the cloud across three different zones (1, 2, and 3). The Contoso IT department with the help of Azure is successfully migrating their backend servers to the cloud, and their API continues to provide fast and reliable weather forecasts to both internal and external clients in the west coast, North America.

External clients access the web app hosted on frontend servers, which in turn relies on a web API hosted in backend servers. The application experiences high seasonality in traffic. Contoso wants to leverage the elasticity of cloud infrastructure to scale in or out their frontend virtual machines based on fluctuations in traffic while keeping the backend virtual machines at a reserved capacity. This ensures that the backend servers are always ready to handle any workload without compromising on performance. With Azure's help, Contoso can easily adjust their resources as needed to meet their clients' demands and provide a seamless user experience. Here's the brief hybrid on-premises and cloud profile:

- Have two workloads running and operating on premises.
- Use Entra ID for identity management.
- They are investing in getting knowledgeable about containers but as a first step they plan to land in the cloud using Infrastructure as a Service (virtual machine) resources.
- Aware of Virtual Machine Scale Sets and their capabilities for orchestration.

Overall, Contoso's migration to Azure is improving their resiliency, flexibility, and scalability. The Azure's infrastructure as a service offering has allowed Contoso to focus on their core business and provide better services to their clients. With the ongoing growth of their business, Contoso is confident that their cloud-based infrastructure will be able to meet their evolving needs and provide a reliable and efficient platform for their weather forecasting app.

Based on the company's profile and business requirements, we've created a [reference architecture](https://aka.ms/architecture/iaas-baseline) that serves as an Infrastructure as a Service baseline. The architecture is accompanied with the implementation found in this repo. We recommend that you start with this implementation and add components based on your needs.

## Organization structure

Contoso has adopted [Azure Landing Zones](https://aka.ms/alz) and makes a distinction between its platform team and its workload/application teams. The platform team attempts to delegate as much permission to the workload teams as practical, but still retaining visibility and governance through their platform and application landing zone implementation. The platform team uses [subscription vending](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending) to allocate individual subscriptions to workload teams.

## Business requirements

See [Business requirements](https://github.com/mspnp/iaas-baseline/tree/main/contoso#business-requirements) in the IaaS Baseline reference implementation, as they are the same.
