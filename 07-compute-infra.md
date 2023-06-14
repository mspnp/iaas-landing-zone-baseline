# Deploy the compute infrastructure [Workload team]

Now that you have [procured your TLS certificates for your solution](./06-ca-certificates.md), the next step in the [IaaS baseline reference implementation](./README.md) is deploying the frontend and backend compute resources and the Azure managed services they depend on. These are the resources for your application's architecture.

## Expected results

### Resource group

The following resource group will be created and populated with the IaaS baseline reference implementation resources.

| Name                   | Purpose                                   |
| :--------------------- | :---------------------------------------- |
| rg-alz-bu04a42-compute | This contains your application landing zone resources related to your infrastructure. It contains load balancing, compute, and related resources. |

### Application Gateway placement

Azure Application Gateway, for this reference implementation, is placed in the same virtual network as the virtual machines (isolated by subnets and related NSGs). This facilitates direct network line-of-sight from Application Gateway to the private VM IP addresses and still allows for strong network boundary control. More importantly, this aligns the application team owning the point of ingress into the workload. Some organizations may instead use a perimeter network in which Application Gateway is managed centrally, often resided in an entirely separated virtual network, such as in the Connectivity subscription. That topology is also fine, but you'll need to ensure there is secure and limited routing between that perimeter network and your private IP addresses for your virtual machines. Also, there will be additional coordination necessary between the application team and the platform team owning the Application Gateway as the application evolves.

## Steps

1. Deploy the compute infrastructure ARM template.

   ```bash
   # [This takes about 18 minutes.]
   az deployment sub create -l eastus2 -n application-infra -f workload-team/main.bicep -p targetVnetResourceId=${RESOURCEID_VNET_SPOKE_IAAS_BASELINE} location=eastus2 appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE_IAAS_BASELINE} vmssWildcardTlsPublicCertificate=${VMSS_WILDCARD_CERTIFICATE_BASE64_IAAS_BASELINE} vmssWildcardTlsPublicAndKeyCertificates=${VMSS_WILDCARD_CERT_PUBLIC_PRIVATE_KEYS_BASE64_IAAS_BASELINE}

   export RESOURCEID_VMSS_FRONTEND_IAAS_BASELINE = $(az deployment sub show -n application --query properties.outputs.frontendVmssResourceId.value -o tsv)
   export RESOURCEID_VMSS_BACKEND_IAAS_BASELINE = $(az deployment sub show -n application --query properties.outputs.backendVmssResourceId.value -o tsv)
   echo "RESOURCEID_VMSS_FRONTEND_IAAS_BASELINE: $RESOURCEID_VMSS_FRONTEND_IAAS_BASELINE"
   echo "RESOURCEID_VMSS_BACKEND_IAAS_BASELINE: $RESOURCEID_VMSS_BACKEND_IAAS_BASELINE"
   ```

1. Assign system managed identities to all virtual machines.

   The virtual machines each need a system managed identity assigned to [support Azure Active Directory authentication](https://learn.microsoft.com/azure/active-directory/devices/howto-vm-sign-in-azure-ad-linux#virtual-machine). This is not possible to assign within the Bicep, unless implemented similarly through deploymentScripts which would be an option. Generally speaking, you should strive to minimize mixing declarative deployments (Bicep) and imperative control (az cli, DINE policies, portal) in your workload.

   ```bash
   az vm identity assign --identities [system] --ids $(az vm list --vmss ${RESOURCEID_VMSS_FRONTEND_IAAS_BASELINE} --query '[[].id]' -o tsv)  $(az vm list --vmss ${RESOURCEID_VMSS_BACKEND_IAAS_BASELINE} --query '[[].id]' -o tsv)
   ```

### Next step

:arrow_forward: [Validate your compute infrastructure is deployed](./08-bootstrap-validation.md)
