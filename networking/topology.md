# IaaS baseline network topology

> Note: This is part of the IaaS baseline reference implementation. For more information see the [readme file in the root](../README.md).

## Hub virtual network

`CIDR: 10.200.0.0/24`

This regional VNet hub (shared) is meant to hold the following subnets:

* [Azure Firewall subnet]
* [Gateway subnet]
* [Azure Bastion subnet], with reference NSG in place

> Note: For more information about this topology, you can read more at [Azure hub-spoke topology].

## Spoke virtual network

`CIDR: 10.240.0.0/16`

This VNet spoke is meant to hold the following subnets:

* [VMSS Frontend] and [VMSS Backend] subnet
* [Internal Load Balancer subnet]
* [Azure Application Gateway subnet]
* [Private Link Endpoint subnet]
* All with basic NSGs around each

## Subnet details

| Subnet                                      | Upgrade VM   | VMs/Instance | % Seasonal scale out | +VMs       | Max IPs per VM           | % Max Surge   | % Max Unavailable   | Tot. IPs per VM           | [Azure Subnet not assignable IPs factor] | [Private Endpoints] | Minimum Subnet size]  | Scaled Subnet size | [Subnet Mask bits] | CIDR            | Host         | Broadcast    |
|---------------------------------------------|-------------:|-------------:|---------------------:|-----------:|-------------------------:|--------------:|--------------------:|--------------------------:|-----------------------------------------:|--------------------:|----------------------:|-------------------:|-------------------:|-----------------|--------------|--------------|
| VMSS Frontend Subnet                        | -            | 3            | -                    | -          | -                        | 100           | 100                 | 0                         | 5                                        | 0                   | 7                     | 7                  | 24                 | 10.240.0.0/24   | 10.240.0.0   | 10.240.0.255 |
| VMSS Backend Subnet                         | -            | 3            | -                    | -          | -                        | 100           | 100                 | 5                         | 5                                        | 0                   | 7                     | 7                  | 24                 | 10.240.1.0/24   | 10.240.4.0   | 10.240.1.255 |
| Internal Load Balancer Subnet               | -            | -            | -                    | -          | 5                        | 100           | 100                 | 5                         | 5                                        | 0                   | 10                    | 10                 | 28                 | 10.240.4.0/28   | 10.240.4.0   | 10.240.4.15  |
| Private Link Endpoint Subnet                | -            | -            | -                    | -          | -                        | 100           | 100                 | 0                         | 5                                        | 1                   | 7                     | 7                  | 28                 | 10.240.4.32/28  | 10.240.4.32  | 10.240.4.47  |
| Azure Application Gateway Subnet            | -            | [251]        | -                    | -          | -                        | 100           | 100                 | 0                         | 5                                        | 0                   | 256                   | 256                | 24                 | 10.240.5.0/24   | 10.240.5.0   | 10.240.5.255 |
| Gateway Subnet (GatewaySubnet)              | -            | [27]         | -                    | -          | -                        | 100           | 100                 | 0                         | 5                                        | 0                   | 32                    | 32                 | 27                 | 10.200.0.64/27  | 10.200.0.64  | 10.200.0.95  |
| Azure Firewall Subnet (AzureFirewallSubnet) | -            | [59]         | -                    | -          | -                        | 100           | 100                 | 0                         | 5                                        | 0                   | 64                    | 64                 | 26                 | 10.200.0.0/26   | 10.200.0.0   | 10.200.0.63  |
| Azure Bastion Subnet (AzureBastionSubnet)   | -            | [50]         | -                    | -          | -                        | 100           | 100                 | 0                         | 5                                        | 0                   | 64                    | 64                 | 26                 | 10.200.0.128/26 | 10.200.0.128 | 10.200.0.191 |

## Additional considerations

* [Private Endpoints] subnet: Private Links are created for Azure Key Vault, so this Azure service can be accessed using Private Endpoints within the spoke virtual network. There are multiple [Private Link deployment options]; in this implementation they are deployed to a dedicated subnet within the spoke virtual network.

[27]: https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsub
[251]: https://learn.microsoft.com/azure/application-gateway/configuration-overview#size-of-the-subnet
[59]: https://learn.microsoft.com/azure/firewall/firewall-faq#does-the-firewall-subnet-size-need-to-change-as-the-service-scales
[50]: https://learn.microsoft.com/azure/bastion/configuration-settings#instance
[Azure Subnet not assignable IPs factor]: https://learn.microsoft.com/azure/virtual-network/virtual-network-ip-addresses-overview-arm#allocation-method-1
[Private Endpoints]: https://learn.microsoft.com/azure/private-link/private-endpoint-overview#private-endpoint-properties
[Subnet Mask bits]: https://learn.microsoft.com/azure/virtual-network/virtual-networks-faq#how-small-and-how-large-can-vnets-and-subnets-be
[Azure hub-spoke topology]: https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke
[Azure Firewall subnet]: https://learn.microsoft.com/azure/firewall/firewall-faq#does-the-firewall-subnet-size-need-to-change-as-the-service-scales
[Gateway subnet]: https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsub
[Azure Application Gateway subnet]: https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#virtual-network-and-dedicated-subnet
[Private Link Endpoint subnet]: https://learn.microsoft.com/azure/architecture/guide/networking/private-link-hub-spoke-network#networking
[Private Link deployment options]: https://learn.microsoft.com/azure/architecture/guide/networking/private-link-hub-spoke-network#decision-tree-for-private-link-deployment
[Azure Bastion subnet]: https://learn.microsoft.com/azure/bastion/configuration-settings#subnet
