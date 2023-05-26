#!/bin/bash

# Copy Ssl certs from KeyVault
export SYMLINK_CERTNAME=$(sudo ls /var/lib/waagent/Microsoft.Azure.KeyVault.Store/ | grep -i -E ".workload-public-private-cert" | head -1)
sudo openssl x509 -in /var/lib/waagent/Microsoft.Azure.KeyVault.Store/${SYMLINK_CERTNAME} -out /etc/ssl/certs/nginx-ingress-internal-iaas-ingress-tls.crt
sudo openssl rsa -in /var/lib/waagent/Microsoft.Azure.KeyVault.Store/${SYMLINK_CERTNAME} -out /etc/ssl/private/nginx-ingress-internal-iaas-ingress-tls.key

# Update apt cache.
sudo apt-get update

# Install Nginx.
sudo apt-get install -y nginx

# Configure Nginx with root page, ssl, healt probe endpoint, and reverse proxy
cat > /etc/nginx/sites-enabled/forward << EOF
server {
    listen 443 ssl;
    server_name frontend-00.iaas-ingress.contoso.com;
    ssl_certificate /etc/ssl/certs/nginx-ingress-internal-iaas-ingress-tls.crt;
    ssl_certificate_key /etc/ssl/private/nginx-ingress-internal-iaas-ingress-tls.key;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

    location / {
        proxy_pass https://backend-00.iaas-ingress.contoso.com/;
        sub_filter '[frontend]' '$(hostname)';
        sub_filter_once off;
    }

    location = /favicon.ico {
        empty_gif;
        access_log off;
    }
}
EOF

# Restart Nginx to load the new configuration
sudo systemctl restart nginx.service
