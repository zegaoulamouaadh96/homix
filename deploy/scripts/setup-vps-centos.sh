#!/bin/bash

# Complete VPS Setup Script for homix.systems (CentOS/RHEL/Fedora)
# This script sets up the entire Homix system on VPS

set -e

echo "=== Homix VPS Setup Script (CentOS/RHEL/Fedora) ==="
echo "Domain: homix.systems"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

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
echo ""

# Step 1: Update system
echo "Step 1: Updating system..."
if [ "$OS" = "centos" ]; then
    yum update -y
else
    dnf update -y
fi

# Step 2: Install Docker
echo "Step 2: Installing Docker..."
if [ "$OS" = "centos" ]; then
    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io
else
    dnf -y install dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io
fi

systemctl start docker
systemctl enable docker

# Step 3: Install Docker Compose
echo "Step 3: Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Step 4: Install Git and Nginx
echo "Step 4: Installing Git and Nginx..."
if [ "$OS" = "centos" ]; then
    yum install -y git nginx certbot python3-certbot-nginx
else
    dnf install -y git nginx certbot python3-certbot-nginx
fi

# Step 5: Clone repository (if not exists)
echo "Step 5: Setting up project directory..."
mkdir -p /opt/homix
if [ ! -d "/opt/homix/deploy" ]; then
    echo "Please clone the repository first:"
    echo "cd /opt/homix"
    echo "git clone https://github.com/zegaoulamouaadh96/homix.git ."
    exit 1
fi

# Step 6: Setup SSL
echo "Step 6: Setting up SSL Certificate..."
if [ -f "/opt/homix/deploy/scripts/setup-ssl-centos.sh" ]; then
    chmod +x /opt/homix/deploy/scripts/setup-ssl-centos.sh
    /opt/homix/deploy/scripts/setup-ssl-centos.sh
else
    echo "SSL setup script not found, skipping SSL setup"
fi

# Step 7: Setup environment variables
echo "Step 7: Setting up environment variables..."
if [ ! -f "/opt/homix/deploy/.env" ]; then
    cp /opt/homix/deploy/.env.example /opt/homix/deploy/.env
    echo "Please edit /opt/homix/deploy/.env with your values"
    echo "nano /opt/homix/deploy/.env"
fi

# Step 8: Setup Firewall
echo "Step 8: Configuring Firewall..."
if command -v firewall-cmd &> /dev/null; then
    systemctl start firewalld
    systemctl enable firewalld
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-port=1883/tcp
    firewall-cmd --permanent --add-port=8883/tcp
    firewall-cmd --permanent --add-port=9001/tcp
    firewall-cmd --reload
else
    echo "firewalld not found, skipping firewall setup"
fi

# Step 9: Start services
echo "Step 9: Starting Docker services..."
cd /opt/homix/deploy/docker
docker-compose -f docker-compose.prod.yml up -d

echo ""
echo "=== VPS Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit environment variables: nano /opt/homix/deploy/.env"
echo "2. Restart services: cd /opt/homix/deploy/docker && docker-compose -f docker-compose.prod.yml restart"
echo "3. Test connections: cd /opt/homix && ./deploy/scripts/test-connections.sh"
echo ""
echo "Services:"
echo "- API: https://homix.systems/api"
echo "- MQTT: homix.systems:1883 (TCP) / :8883 (SSL)"
echo "- WebSocket: wss://homix.systems/mqtt"
