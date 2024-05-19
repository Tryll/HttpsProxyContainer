#!/bin/bash

# Check if environment variables are set
if [ -z "$DOMAIN_NAME" ] || [ -z "$BACKEND_URL" ]; then
  echo "DOMAIN_NAME and BACKEND_URL must be set"
  exit 1
fi

# Default ADMIN_EMAIL to admin@DOMAIN_NAME if not provided
if [ -z "$ADMIN_EMAIL" ]; then
  ADMIN_EMAIL="admin@$DOMAIN_NAME"
fi

# Create necessary directories
mkdir -p /var/www/certbot
mkdir -p /var/log/nginx
mkdir -p /etc/nginx/conf.d


# Log in to Azure using the managed identity
az login --identity

# Get the current public IP address of the container instance
RETRY_COUNT=0
MAX_RETRIES=5
SLEEP_INTERVAL=60

while [ -z "$(trim "$PUBLIC_IP")" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  PUBLIC_IP=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_GROUP --query "ipAddress.ip" --output tsv)
  PUBLIC_IP=$(trim "$PUBLIC_IP")
  if [ -z "$PUBLIC_IP" ]; then
    echo "Failed to get Public IP, retrying in $SLEEP_INTERVAL seconds..."
    sleep $SLEEP_INTERVAL
    RETRY_COUNT=$((RETRY_COUNT + 1))
  fi
done



# Get the current A record IP address
CURRENT_IP=$(az network dns record-set a show \
  --resource-group $DNSZONE_RGNAME \
  --zone-name $DOMAIN_NAME \
  --name '@' \
  --query 'ARecords[0].ipv4Address' \
  --output tsv)

echo Current A Record for @.$DOMAIN_NAME is $CURRENT_IP and the public IP is $PUBLIC_IP

# Update the A record if the IP address has changed
if [ "$PUBLIC_IP" != "$CURRENT_IP" ]; then
  echo "Updating DNS record from $CURRENT_IP to $PUBLIC_IP"
  az network dns record-set a update \
    --resource-group $DNSZONE_RGNAME \
    --zone-name $DOMAIN_NAME \
    --name '@' \
    --set "ARecords[0].ipv4Address=$PUBLIC_IP"

  # Wait for DNS propagation
  echo "Waiting for DNS propagation..."
  sleep 300
else
  echo "DNS record is up-to-date. No update required."
fi





# Generate initial Nginx configuration to listen on port 80 only
cat <<EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name $DOMAIN_NAME;
    location / {
        root /var/www/certbot;
        autoindex on;
    }
}
EOF

# Start Nginx to allow Certbot to perform the challenge
nginx

# Obtain SSL certificate
certbot certonly --webroot -w /var/www/certbot -d $DOMAIN_NAME --non-interactive --agree-tos --email $ADMIN_EMAIL


# Generate full Nginx configuration including SSL
cat <<EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass $BACKEND_URL;
        proxy_http_version 1.1;
    }
}
server {
    listen 443 ssl;
    server_name $DOMAIN_NAME;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    location / {
        proxy_pass $BACKEND_URL;
        proxy_http_version 1.1;
    }
}
EOF


# Reload Nginx with the new certificate
nginx -s reload

# Keep the container running
tail -f /var/log/nginx/access.log
