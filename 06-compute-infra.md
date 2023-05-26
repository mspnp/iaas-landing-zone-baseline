# Deploy the compute infrastructure [Workload team]

Now that you have a [mock application landing zone deployed](./04-subscription-vending-execute.md), the next step in the [IaaS baseline reference implementation](./) is deploying the frontend and backend compute resources and the Azure managed services they depend on.

## Expected results

**TODO-CK: fill in**

## Steps

1. Deploy the compute infrastructure stamp ARM template.

   ```bash
   # [This takes about 18 minutes.]
   az deployment sub create -l eastus2 -f workload-team/main.bicep -p targetVnetResourceId=${RESOURCEID_VNET_SPOKE_IAAS_BASELINE} location=eastus2 appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE_IAAS_BASELINE} vmssWildcardTlsPublicCertificate=${VMSS_WILDCARD_CERTIFICATE_BASE64_IAAS_BASELINE} vmssWildcardTlsPublicAndKeyCertificates=${VMSS_WILDCARD_CERT_PUBLIC_PRIVATE_KEYS_BASE64_IAAS_BASELINE} domainName=${DOMAIN_NAME_IAAS_BASELINE}
   ```

   > Alteratively, you could have updated the [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) file and deployed as above, using `-p "@azuredeploy.parameters.prod.json"` instead of providing the individual key-value pairs.

## Application Gateway placement

**TODO-CK: Might want this section somewhere else, someplace closer to the landing zone network choices**

Azure Application Gateway, for this reference implementation, is placed in the same virtual network as the VMs (isolated by subnets and related NSGs). This facilitates direct network line-of-sight from Application Gateway to the private VM ip addresses and still allows for strong network boundary control. More importantly, this aligns operation team owning the point of ingress. Some organizations may instead leverage a perimeter network in which Application Gateway is managed centrally which resides in an entirely separated virtual network. That topology is also fine, but you'll need to ensure there is secure and limited routing between that perimeter network and your internal private load balancer for your VMs. Also, there will be additional coordination necessary between the VMs/workload operators and the team owning the Application Gateway.

### Next step

:arrow_forward: [Validate your compute infrastructure is bootstrapped](./07-bootstrap-validation.md)
