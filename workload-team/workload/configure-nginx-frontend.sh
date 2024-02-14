#!/bin/bash

# Initialize Managed Data Disk
DISK_NAME=$(lsblk -I 8 -d -o NAME,SIZE | grep 4G | grep -Po 'sd\S*')
sudo parted /dev/${DISK_NAME} --script mklabel gpt mkpart xfspart xfs 0% 100%
PARTITION_LOCATION=/dev/${DISK_NAME}1
sudo mkfs.xfs ${PARTITION_LOCATION}
sudo partprobe ${PARTITION_LOCATION}
sudo mkdir /datadrive
sudo mount ${PARTITION_LOCATION} /datadrive
SD_UUID=$(blkid | grep -Po "$PARTITION_LOCATION: UUID=\"\K.*?(?=\")")
echo "${SD_UUID}   /datadrive   xfs   defaults,nofail   1   2" | sudo tee -a /etc/fstab

# Copy SSL certs from Key Vault
# TODO: Why isn't this in the default location, why overridden in extension?
export SYMLINK_CERTNAME=$(sudo ls /var/lib/waagent/Microsoft.Azure.KeyVault.Store/ | grep -i -E ".workload-public-private-cert" | head -1)
sudo openssl x509 -in /var/lib/waagent/Microsoft.Azure.KeyVault.Store/${SYMLINK_CERTNAME} -out /etc/ssl/certs/nginx-ingress-internal-iaas-ingress-tls.crt
sudo openssl rsa -in /var/lib/waagent/Microsoft.Azure.KeyVault.Store/${SYMLINK_CERTNAME} -out /etc/ssl/private/nginx-ingress-internal-iaas-ingress-tls.key

# Update apt cache.
sudo apt-get update

# Install Nginx.
sudo apt-get install -y nginx

# Create a Nginx log folder
sudo mkdir -p /datadrive/log/nginx

# Configure Nginx with root page, SSL, health probe endpoint, and reverse proxy
cat > /etc/nginx/sites-enabled/forward << EOF
server {
    listen 443 ssl;
    server_name frontend-00.iaas-ingress.contoso.com;
    ssl_certificate /etc/ssl/certs/nginx-ingress-internal-iaas-ingress-tls.crt;
    ssl_certificate_key /etc/ssl/private/nginx-ingress-internal-iaas-ingress-tls.key;
    ssl_protocols TLSv1.2;

    location / {
        access_log /datadrive/log/nginx/frontend.log combined buffer=10K flush=1m;
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
