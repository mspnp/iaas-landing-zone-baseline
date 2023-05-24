# Deploy the compute infrastructure

Now that your [spoke shared resources are deployed and ready to support your IaaS deployment](./06-bootstrap-prep.md), the next step in the [IaaS baseline reference implementation](./) is deploying the frontend and backend compute resources and the Azure managed services they depend on.

## Steps

1. Generate new VM authentication ssh keys by following the instructions from [Create and manage SSH keys for authentication to a Linux VM in Azure](https://learn.microsoft.com/azure/virtual-machines/linux/create-ssh-keys-detailed). Alternatively, quickly execute the following command:

   ```bash
   ssh-keygen -m PEM -t rsa -b 4096 -C "opsuser01@iaas" -f ~/.ssh/opsuser01.pem -q -N ""
   ```

1. Ensure you have **read-only** access to the private key.

   ```bash
   chmod 400 ~/.ssh/opsuser01.pem
   ```

1. Get the public ssh cert

   ```bash
   SSH_PUBLIC=$(cat ~/.ssh/opsuser01.pem.pub)
   ```

1. Modify the `frontendCloudInit.yml` to change the public key

   ```bash
   sed -i "s:YOUR_SSH-RSA_HERE:${SSH_PUBLIC}:" ./frontendCloudInit.yml
   ```

1. Modify the `backendCloudInit.yml` to change the public key

   ```bash
   sed -i "s:YOUR_SSH-RSA_HERE:${SSH_PUBLIC}:" ./backendCloudInit.yml
   ```

1. Convert your front end cloud-init (users) file to Base64.

   ```bash
   FRONTEND_CLOUDINIT_BASE64=$(base64 frontendCloudInit.yml | tr -d '\n')
   ```

1. Convert your api cloud-init (users) file to Base64.

   ```bash
   BACKEND_CLOUDINIT_BASE64=$(base64 backendCloudInit.yml | tr -d '\n')
   ```

1. Deploy the compute infrastructure stamp ARM template.
  :exclamation: By default, this deployment will allow you establish ssh and rdp connections usgin Bastion to your machines. In the case of the backend machines you are granted with admin access.

   ```bash
   # [This takes about 18 minutes.]
   az deployment group create -g rg-bu0001a0008 -f vmss-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_SPOKE_IAAS_BASELINE} location=eastus2 frontendCloudInitAsBase64="${FRONTEND_CLOUDINIT_BASE64}" backendCloudInitAsBase64="${BACKEND_CLOUDINIT_BASE64}" appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE_IAAS_BASELINE} vmssWildcardTlsPublicCertificate=${VMSS_WILDCARD_CERTIFICATE_BASE64_IAAS_BASELINE} vmssWildcardTlsPublicAndKeyCertificates=${VMSS_WILDCARD_CERT_PUBLIC_PRIVATE_KEYS_BASE64_IAAS_BASELINE} domainName=${DOMAIN_NAME_IAAS_BASELINE}
   ```

   > Alteratively, you could have updated the [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) file and deployed as above, using `-p "@azuredeploy.parameters.prod.json"` instead of providing the individual key-value pairs.

## Application Gateway placement

Azure Application Gateway, for this reference implementation, is placed in the same virtual network as the VMs (isolated by subnets and related NSGs). This facilitates direct network line-of-sight from Application Gateway to the private VM ip addresses and still allows for strong network boundary control. More importantly, this aligns operation team owning the point of ingress. Some organizations may instead leverage a perimeter network in which Application Gateway is managed centrally which resides in an entirely separated virtual network. That topology is also fine, but you'll need to ensure there is secure and limited routing between that perimeter network and your internal private load balancer for your VMs. Also, there will be additional coordination necessary between the VMs/workload operators and the team owning the Application Gateway.

### Next step

:arrow_forward: [Validate your compute infrastructure is bootstrapped](./07-bootstrap-validation.md)
