# Use the official Debian image as the base image
FROM debian:latest

# Install Nginx, Certbot, Azure CLI, and other dependencies
RUN apt-get update && \
    apt-get install -y nginx certbot python3-certbot-nginx curl jq lsb-release gnupg && \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg && \
    AZ_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" > /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && \
    apt-get install -y azure-cli

# Copy the script to initialize certbot and start Nginx
COPY start.sh /start.sh
RUN chmod +x /start.sh


# Copy the default nginx.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Start Nginx and Certbot
CMD ["/start.sh"]
