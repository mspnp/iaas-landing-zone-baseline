# Generate your client-facing and mTLS certificates

Now that you have an [application landing zone awaiting your workload](./04-subscription-vending-execute.md), follow the steps below to create the TLS certificate Azure Application Gateway will serve clients connecting to your web app, and the certificate to implement TLS communication among the VMs in the environment. If you already have access to appropriate certificates, or can procure them from your organization, consider doing so and skipping the certificate generation steps. The following will describe using self-signed certs for instruction purposes only.

## Steps

1. Generate a client-facing, self-signed TLS certificate.

   > :book: The application team needs to procure a CA certificate for the web site. As this is going to be a user-facing site, they purchase an EV cert from their CA. This will be served in front of the Azure Application Gateway. They will also procure another one, a standard cert, and the certificate to implement TLS communication among the VMs in the environment. The second one is not EV, as it will not be user facing.

   :warning: Do not use the certificate created by this script for your solutions. Self-signed certificates are used here for illustration purposes only. For your compute infrastructure, use your organization's requirements for procurement and lifetime management of TLS certificates, _even for development purposes_.

   Create the certificate that will be presented to web clients by Azure Application Gateway.

   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out appgw.crt -keyout appgw.key -subj "/CN=contoso.com/O=Contoso" -addext "subjectAltName = DNS:contoso.com" -addext "keyUsage = digitalSignature" -addext "extendedKeyUsage = serverAuth"
   openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:
   ```

1. Base64 encode the client-facing certificate.

   :bulb: No matter if you used a certificate from your organization or you generated one from above, you'll need the certificate (as `.pfx`) to be Base64 encoded for proper storage in Key Vault later.

   ```bash
   export APP_GATEWAY_LISTENER_CERTIFICATE_IAAS_BASELINE=$(cat appgw.pfx | base64 | tr -d '\n')
   echo APP_GATEWAY_LISTENER_CERTIFICATE_IAAS_BASELINE: $APP_GATEWAY_LISTENER_CERTIFICATE_IAAS_BASELINE
   ```

1. Generate the wildcard certificate for the internal service to service communication.

   > :book: Contoso will also procure another TLS certificate, a standard cert, to be used by the virtual machines for tier to tier communication. This one is not EV, as it will not be user facing. The app team decided to use a wildcard certificate `*.iaas-ingress.contoso.com` for both the frontend and backend endpoints.

   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out nginx-ingress-internal-iaas-ingress-tls.crt -keyout nginx-ingress-internal-iaas-ingress-tls.key -subj "/CN=*.iaas-ingress.contoso.com/O=Contoso IaaS Ingresses"
   ```

1. Base64 encode the internal service to service communication certificate.

   :bulb: Regardless of whether you used a certificate from your organization or generated one with the instructions provided in this document, you'll need the public certificate (as `.crt` or `.cer`) to be Base64 encoded for proper storage in Key Vault.

   ```bash
   export VMSS_WILDCARD_CERTIFICATE_BASE64_IAAS_BASELINE=$(cat nginx-ingress-internal-iaas-ingress-tls.crt | base64 | tr -d '\n')
   echo VMSS_WILDCARD_CERTIFICATE_BASE64_IAAS_BASELINE: $VMSS_WILDCARD_CERTIFICATE_BASE64_IAAS_BASELINE
   ```

1. Format the wildcard certificate for `*.iaas-ingress.contoso.com` to PKCS12.

   :warning: If you already have access to an [appropriate certificate](https://learn.microsoft.com/azure/key-vault/certificates/certificate-scenarios#formats-of-import-we-support), or can procure one from your organization, consider using it for this step. For more information, please take a look at the [import certificate tutorial using Azure Key Vault](https://learn.microsoft.com/azure/key-vault/certificates/tutorial-import-certificate#import-a-certificate-to-key-vault).

   :warning: Do not use the certificate created by this script for your solutions. Self-signed certificates are used here for  illustration purposes only. In your solutions, use your organization's requirements for procurement and lifetime management of TLS certificates, _even for development purposes_.

   ```bash
   openssl pkcs12 -export -out nginx-ingress-internal-iaas-ingress-tls.pfx -in nginx-ingress-internal-iaas-ingress-tls.crt -inkey nginx-ingress-internal-iaas-ingress-tls.key -passout pass:
   ```

1. Base64 encode the internal wildcard certificate private and public key.

   :bulb: No matter if you used a certificate from your organization or generated one from above, you'll need the certificate (as `.pfx`) to be Base64 encoded for proper storage in Key Vault.

   ```bash
   export VMSS_WILDCARD_CERT_PUBLIC_PRIVATE_KEYS_BASE64_IAAS_BASELINE=$(cat nginx-ingress-internal-iaas-ingress-tls.pfx | base64 | tr -d '\n')
   echo VMSS_WILDCARD_CERT_PUBLIC_PRIVATE_KEYS_BASE64_IAAS_BASELINE: $VMSS_WILDCARD_CERT_PUBLIC_PRIVATE_KEYS_BASE64_IAAS_BASELINE
   ```

### Save your work-in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to iaas_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source iaas_baseline.env
```

### Next step

:arrow_forward: [Deploy the compute infrastructure](./06-compute-infra.md)
