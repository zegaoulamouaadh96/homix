#!/bin/bash

# SSL Certificate Setup Script for homix.systems (CentOS/RHEL/Fedora)
# This script installs Certbot and obtains SSL certificate from Let's Encrypt

set -e

echo "=== Homix SSL Setup Script (CentOS/RHEL/Fedora) ==="
echo "Domain: homix.systems"
echo ""

# Detect OS
if [ -f /etc/redhat-release ]; then
    OS="centos"
elif [ -f /etc/fedora-release ]; then
    OS="fedora"
else
    echo "Unsupported OS"
    exit 1
fi

echo "Detected OS: $OS"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
if [ "$OS" = "centos" ]; then
    yum install -y epel-release
    yum install -y certbot nginx python3-certbot-nginx
else
    dnf install -y certbot nginx python3-certbot-nginx
fi

# Create directory for ACME challenge
mkdir -p /var/www/certbot
chown -R nginx:nginx /var/www/certbot

# Create Nginx config directory
mkdir -p /etc/nginx/conf.d

# Copy Nginx config
echo "Copying Nginx configuration..."
if [ -f "/opt/homix/deploy/nginx/homix.conf" ]; then
    cp /opt/homix/deploy/nginx/homix.conf /etc/nginx/conf.d/homix.conf
else
    echo "Warning: Nginx config not found at /opt/homix/deploy/nginx/homix.conf"
    echo "Please copy the Nginx config manually"
fi

# Remove default site
rm -f /etc/nginx/conf.d/default.conf

# Test Nginx config
echo "Testing Nginx configuration..."
nginx -t

# Start and enable Nginx
echo "Starting Nginx..."
systemctl start nginx
systemctl enable nginx

# Obtain SSL certificate
echo "Obtaining SSL certificate from Let's Encrypt..."
certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email admin@homix.systems \
    --agree-tos \
    --no-eff-email \
    -d homix.systems \
    -d www.homix.systems

# Set up auto-renewal
echo "Setting up SSL auto-renewal..."
echo "0 0,12 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'" | crontab -

# Copy certificates for Mosquitto
echo "Copying certificates for Mosquitto..."
mkdir -p /etc/mosquitto/certs
cp /etc/letsencrypt/live/homix.systems/fullchain.pem /etc/mosquitto/certs/homix.systems.crt
cp /etc/letsencrypt/live/homix.systems/privkey.pem /etc/mosquitto/certs/homix.systems.key
cp /etc/letsencrypt/live/homix.systems/chain.pem /etc/mosquitto/certs/chain.pem
chown -R mosquitto:mosquitto /etc/mosquitto/certs
chmod 644 /etc/mosquitto/certs/*.crt
chmod 600 /etc/mosquitto/certs/*.key

# Reload Nginx with SSL
echo "Reloading Nginx with SSL configuration..."
systemctl reload nginx

echo ""
echo "=== SSL Setup Complete ==="
echo "SSL Certificate installed for homix.systems"
echo "Auto-renewal configured"
echo "Certificates copied for Mosquitto MQTT over SSL"
echo ""
echo "Next steps:"
echo "1. Restart Mosquitto: systemctl restart mosquitto"
echo "2. Restart Backend: systemctl restart homix-backend"
echo "3. Test HTTPS: curl https://homix.systems"
echo "4. Test MQTT over SSL: openssl s_client -connect homix.systems:8883"
