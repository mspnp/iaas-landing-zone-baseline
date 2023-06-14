# Networking resources

> Note: This is part of the IaaS baseline reference implementation. For more information check out the [readme file in the root](../README.md).

This reference implementation uses a standard hub-spoke model, with a bring your own network; not using Virtual WAN secured hubs. It's expected that the hub be in a different Connectivity subscription than the workload being deployed, as aligned with a typical [Azure Landing Zone](https://aka.ms/alz) implementation. Attempts are made to simulate this in the deployment.

## Topology details

See the [IaaS baseline network topology](./topology.md) for specifics on how this hub-spoke model has its subnets defined and IP space allocation concerns accounted for.

## See also

* [Hub-spoke network topology in Azure](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
* [Network topology and connectivity in Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/network-topology-and-connectivity)
