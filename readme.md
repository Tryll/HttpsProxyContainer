# HttpsProxyContainer

`HttpsProxyContainer` is a Docker-based solution for proxying public web traffic to any private backend, using Nginx and Let's Encrypt's Certbot for HTTPS support. This setup is particularly effective for reducing costs when hosting static websites, such as using an Azure Storage account with web enabled, compared to using Azure Front Door.

## Features

- **HTTPS Support**: Secure your backend services with HTTPS using Let's Encrypt.
- **Automatic SSL Renewal**: Certbot ensures your SSL certificates are automatically renewed.
- **Custom Domain**: Easily use your custom domain name to access private backends.
- **HTTP Support**: HTTP requests are also proxied to your backend, with automatic redirection to HTTPS.
- **Cost-Effective**: Reduce costs by using simple proxy containers instead of more expensive solutions like Azure Front Door.

## Prerequisites

- A custom domain name pointing to the server's public IP address.
- Backend URL for the service you want to proxy.
- Optionally, an email address for SSL certificate notifications.

## Quick Start

### Azure Container Apps

1. **Create a Container App**

   Use the Azure portal or Azure CLI to create a new container app. Refer to the [Azure Container Apps documentation](https://docs.microsoft.com/en-us/azure/container-apps/) for detailed instructions.

2. **Deploy the Container**

   Deploy the `HttpsProxyContainer` image from Docker Hub to your Azure Container App with the necessary environment variables. You can use the following example configuration:

   ```sh
   az containerapp create \
     --name my-https-proxy \
     --resource-group my-resource-group \
     --image tryll/https-proxy-container:latest \
     --environment my-environment \
     --ingress external \
     --target-port 80 \
     --target-port 443 \
     --env-vars DOMAIN_NAME=yourdomain.com BACKEND_URL=https://yourbackendurl.com ADMIN_EMAIL=admin@yourdomain.com
