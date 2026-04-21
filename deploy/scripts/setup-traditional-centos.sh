#!/bin/bash

# Traditional Deployment Setup Script for homix.systems (CentOS/RHEL/Fedora)
# This script sets up the system without Docker

set -e

echo "=== Homix Traditional Deployment Setup (CentOS/RHEL/Fedora) ==="
echo "Domain: homix.systems"
echo "Method: Traditional (no Docker)"
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

# Step 2: Install Node.js 20
echo "Step 2: Installing Node.js 20..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
if [ "$OS" = "centos" ]; then
    yum install -y nodejs
else
    dnf install -y nodejs
fi
node --version
npm --version

# Step 3: Install PostgreSQL
echo "Step 3: Installing PostgreSQL..."
if [ "$OS" = "centos" ]; then
    yum install -y postgresql postgresql-server postgresql-contrib
else
    dnf install -y postgresql postgresql-server postgresql-contrib
fi

# Initialize PostgreSQL
postgresql-setup initdb
systemctl start postgresql
systemctl enable postgresql

# Create database and user
echo "Creating PostgreSQL database and user..."
sudo -u postgres psql << EOF
CREATE DATABASE homix;
CREATE USER homix WITH PASSWORD 'homix_secure_password_2024';
GRANT ALL PRIVILEGES ON DATABASE homix TO homix;
ALTER USER homix WITH PASSWORD 'homix_secure_password_2024';
\q
EOF

# Step 4: Install Mosquitto
echo "Step 4: Installing Mosquitto MQTT Broker..."
if [ "$OS" = "centos" ]; then
    yum install -y mosquitto mosquitto-clients
else
    dnf install -y mosquitto mosquitto-clients
fi

# Configure Mosquitto
cat > /etc/mosquitto/mosquitto.conf << EOF
listener 1883
allow_anonymous true
persistence true
persistence_location /var/lib/mosquitto/
log_dest file /var/log/mosquitto/mosquitto.log
EOF

systemctl start mosquitto
systemctl enable mosquitto

# Step 5: Install PM2 for process management
echo "Step 5: Installing PM2..."
npm install -g pm2

# Step 6: Setup Backend
echo "Step 6: Setting up Backend..."
cd /opt/homix/backend/server

# Install dependencies
npm install

# Create .env file
if [ ! -f .env ]; then
    cat > .env << EOF
NODE_ENV=production
PORT=3000
DATABASE_URL=postgres://homix:homix_secure_password_2024@localhost:5432/homix
MQTT_URL=mqtt://localhost:1883
MQTT_ENABLE_WS=true
MQTT_ENABLE_TCP=true
MQTT_PORT=1883
JWT_SECRET=change_this_strong_secret_32_chars_minimum
ADMIN_JWT_SECRET=change_this_strong_admin_secret_32_chars_minimum
FACE_REQUIRE_HTTPS=true
FACE_DEVICE_TOKEN=prod-face-device-token-2024
EOF
fi

# Initialize database
echo "Initializing database..."
npm run init-db || echo "Database init script not found, skipping..."

# Step 7: Start Backend with PM2
echo "Step 7: Starting Backend with PM2..."
pm2 start index.js --name homix-backend
pm2 save
pm2 startup

# Step 8: Install and setup Nginx
echo "Step 8: Setting up Nginx..."
if [ "$OS" = "centos" ]; then
    yum install -y nginx certbot python3-certbot-nginx
else
    dnf install -y nginx certbot python3-certbot-nginx
fi

# Copy Nginx config
if [ -f "/opt/homix/deploy/nginx/homix.conf" ]; then
    cp /opt/homix/deploy/nginx/homix.conf /etc/nginx/conf.d/homix.conf
    # Update proxy_pass to point to localhost instead of docker
    sed -i 's|http://127.0.0.1:3000|http://127.0.0.1:3000|g' /etc/nginx/conf.d/homix.conf
fi

# Remove default site
rm -f /etc/nginx/conf.d/default.conf

# Test Nginx
nginx -t
systemctl start nginx
systemctl enable nginx

# Step 9: Setup SSL
echo "Step 9: Setting up SSL Certificate..."
mkdir -p /var/www/certbot
certbot --nginx -d homix.systems -d www.homix.systems --non-interactive --agree-tos --email admin@homix.systems

# Copy certificates for Mosquitto
mkdir -p /etc/mosquitto/certs
cp /etc/letsencrypt/live/homix.systems/fullchain.pem /etc/mosquitto/certs/homix.systems.crt
cp /etc/letsencrypt/live/homix.systems/privkey.pem /etc/mosquitto/certs/homix.systems.key
chown -R mosquitto:mosquitto /etc/mosquitto/certs

# Step 10: Setup Firewall
echo "Step 10: Configuring Firewall..."
if command -v firewall-cmd &> /dev/null; then
    systemctl start firewalld
    systemctl enable firewalld
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-port=1883/tcp
    firewall-cmd --permanent --add-port=8883/tcp
    firewall-cmd --permanent --add-port=9001/tcp
    firewall-cmd --reload
fi

# Step 11: Setup SSL auto-renewal
echo "Step 11: Setting up SSL auto-renewal..."
echo "0 0,12 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'" | crontab -

echo ""
echo "=== Traditional Deployment Setup Complete ==="
echo ""
echo "Services running:"
echo "- PostgreSQL: systemctl status postgresql"
echo "- Mosquitto: systemctl status mosquitto"
echo "- Backend: pm2 status"
echo "- Nginx: systemctl status nginx"
echo ""
echo "Next steps:"
echo "1. Edit environment variables: nano /opt/homix/backend/server/.env"
echo "2. Restart Backend: pm2 restart homix-backend"
echo "3. Test connections: curl https://homix.systems"
echo ""
echo "Logs:"
echo "- Backend: pm2 logs homix-backend"
echo "- PostgreSQL: tail -f /var/lib/pgsql/data/log/postgresql-*.log"
echo "- Mosquitto: tail -f /var/log/mosquitto/mosquitto.log"
echo "- Nginx: tail -f /var/log/nginx/error.log"
