# Homix Deployment Guide

This guide explains how to deploy Homix on VPS with SSL certificate and secure connections.

## Prerequisites

- VPS with Ubuntu 20.04+ or Debian 11+
- Domain name: `homix.systems`
- At least 2GB RAM, 2 CPU cores
- Root or sudo access

## Quick Start

### 1. Clone Repository

```bash
cd /opt
git clone <your-repo-url> homix
cd homix
```

### 2. Install Dependencies

```bash
./deploy/scripts/setup-ssl.sh
```

This will:
- Install Nginx and Certbot
- Obtain SSL certificate from Let's Encrypt
- Configure Nginx reverse proxy
- Set up SSL auto-renewal
- Copy certificates for MQTT over SSL

### 3. Configure Environment Variables

```bash
cp deploy/.env.example deploy/.env
nano deploy/.env
```

Edit the following variables:
```env
DB_PASSWORD=your_secure_password
JWT_SECRET=your_jwt_secret
ADMIN_JWT_SECRET=your_admin_jwt_secret
FACE_DEVICE_TOKEN=your_face_device_token
```

### 4. Start Services with Docker

```bash
cd deploy/docker
docker-compose -f docker-compose.prod.yml up -d
```

### 5. Test Connections

```bash
./deploy/scripts/test-connections.sh
```

## Manual Deployment (Without Docker)

### 1. Install Dependencies

```bash
apt update
apt install -y nodejs npm postgresql mosquitto nginx certbot
```

### 2. Setup Database

```bash
sudo -u postgres psql
CREATE DATABASE homix;
CREATE USER homix WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE homix TO homix;
\q
```

### 3. Setup Backend

```bash
cd backend/server
npm install
npm run init-db
npm start
```

### 4. Setup Nginx

```bash
cp deploy/nginx/homix.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/homix.conf /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

### 5. Setup Mosquitto

```bash
cp deploy/nginx/mqtt-ssl.conf /etc/mosquitto/mosquitto.conf
systemctl restart mosquitto
```

## SSL Certificate Setup

### Automatic Setup (Recommended)

```bash
./deploy/scripts/setup-ssl.sh
```

### Manual Setup

```bash
# Obtain certificate
certbot certonly --webroot -w /var/www/certbot -d homix.systems

# Test auto-renewal
certbot renew --dry-run
```

## Firewall Configuration

```bash
# Allow necessary ports
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 1883/tcp
ufw allow 8883/tcp
ufw allow 9001/tcp
ufw enable
```

## Service Management

### Backend

```bash
# Start
systemctl start homix-backend

# Stop
systemctl stop homix-backend

# Restart
systemctl restart homix-backend

# Status
systemctl status homix-backend
```

### Mosquitto (MQTT)

```bash
# Start
systemctl start mosquitto

# Stop
systemctl stop mosquitto

# Restart
systemctl restart mosquitto

# Status
systemctl status mosquitto
```

### Nginx

```bash
# Reload configuration
systemctl reload nginx

# Restart
systemctl restart nginx

# Status
systemctl status nginx
```

## Testing Connections

### Test HTTPS

```bash
curl https://homix.systems
```

### Test API

```bash
curl https://homix.systems/api/health
```

### Test MQTT (TCP)

```bash
mosquitto_sub -h homix.systems -t home/DZ-BEBJ-Z6U7/#
```

### Test MQTT over SSL

```bash
mosquitto_sub -h homix.systems -p 8883 --capath /etc/ssl/certs -t home/DZ-BEBJ-Z6U7/#
```

### Test WebSocket

```bash
wscat -c wss://homix.systems/mqtt
```

## ESP32 Configuration

Update ESP32 code to use new domain:

```bash
./deploy/scripts/update-esp32-config.sh
```

Then upload the updated code to your ESP32 devices.

## Monitoring

### View Nginx Logs

```bash
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### View Backend Logs

```bash
journalctl -u homix-backend -f
```

### View MQTT Logs

```bash
tail -f /mosquitto/log/mosquitto.log
```

## Troubleshooting

### SSL Certificate Issues

```bash
# Check certificate expiry
openssl x509 -enddate -noout -in /etc/letsencrypt/live/homix.systems/cert.pem

# Renew certificate manually
certbot renew
systemctl reload nginx
```

### Backend Not Starting

```bash
# Check logs
journalctl -u homix-backend -n 50

# Check database connection
psql -U homix -d homix -c "SELECT 1"
```

### MQTT Connection Issues

```bash
# Test MQTT broker
mosquitto_pub -h localhost -t test -m "hello"

# Check Mosquitto logs
tail -f /mosquitto/log/mosquitto.log
```

## Security Best Practices

1. **Change default passwords** in `.env` file
2. **Use strong JWT secrets** (at least 32 characters)
3. **Enable firewall** and only open necessary ports
4. **Keep system updated**: `apt update && apt upgrade`
5. **Monitor logs** regularly for suspicious activity
6. **Use fail2ban** to prevent brute force attacks
7. **Enable automatic security updates**

## Backup Strategy

### Database Backup

```bash
# Backup
pg_dump -U homix homix > backup_$(date +%Y%m%d).sql

# Restore
psql -U homix homix < backup_20240101.sql
```

### Automated Backup

Add to crontab:
```bash
0 2 * * * pg_dump -U homix homix > /backups/homix_$(date +\%Y\%m\%d).sql
```

## Support

For issues:
- Check logs: `journalctl -u homix-backend -f`
- Test connections: `./deploy/scripts/test-connections.sh`
- Check SSL: `curl -Iv https://homix.systems`
