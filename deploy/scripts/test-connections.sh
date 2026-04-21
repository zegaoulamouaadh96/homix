#!/bin/bash

# Connection Test Script for homix.systems
# Tests HTTPS, API, MQTT, and WebSocket connections

set -e

DOMAIN="homix.systems"
API_URL="https://$DOMAIN/api"
MQTT_HOST="$DOMAIN"
MQTT_PORT=1883
MQTTS_PORT=8883
WS_PORT=9001

echo "=== Homix Connection Test Script ==="
echo "Domain: $DOMAIN"
echo "Timestamp: $(date)"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
    fi
}

# Test 1: DNS Resolution
echo "Test 1: DNS Resolution"
if nslookup $DOMAIN > /dev/null 2>&1; then
    IP=$(nslookup $DOMAIN | grep -A 1 "Name:" | tail -n 1 | awk '{print $2}')
    print_result 0 "DNS resolved to $IP"
else
    print_result 1 "DNS resolution failed"
fi
echo ""

# Test 2: HTTPS Connection
echo "Test 2: HTTPS Connection"
if curl -sSf -o /dev/null "https://$DOMAIN" --max-time 10; then
    print_result 0 "HTTPS connection successful"
else
    print_result 1 "HTTPS connection failed"
fi
echo ""

# Test 3: SSL Certificate
echo "Test 3: SSL Certificate"
if echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -checkend 0 > /dev/null 2>&1; then
    EXPIRY=$(echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
    print_result 0 "SSL certificate valid (expires: $EXPIRY)"
else
    print_result 1 "SSL certificate invalid or expired"
fi
echo ""

# Test 4: API Health Check
echo "Test 4: API Health Check"
if curl -sSf -o /dev/null "$API_URL/health" --max-time 10; then
    print_result 0 "API health check passed"
else
    print_result 1 "API health check failed (endpoint might not exist yet)"
fi
echo ""

# Test 5: API Login
echo "Test 5: API Login Endpoint"
if curl -sSf -X POST "$API_URL/admin/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"test","password":"test"}' \
    --max-time 10 -o /dev/null 2>&1; then
    print_result 0 "API login endpoint accessible"
else
    print_result 1 "API login endpoint failed"
fi
echo ""

# Test 6: MQTT TCP Connection
echo "Test 6: MQTT TCP Connection (Port 1883)"
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$MQTT_HOST/$MQTT_PORT" 2>/dev/null; then
    print_result 0 "MQTT TCP connection successful"
else
    print_result 1 "MQTT TCP connection failed"
fi
echo ""

# Test 7: MQTT over SSL (MQTTS)
echo "Test 7: MQTT over SSL (Port 8883)"
if echo | openssl s_client -connect $DOMAIN:8883 -servername $DOMAIN 2>/dev/null | grep -q "Verify return code"; then
    print_result 0 "MQTTS connection successful"
else
    print_result 1 "MQTTS connection failed"
fi
echo ""

# Test 8: WebSocket Connection
echo "Test 8: WebSocket Connection"
if curl -sSf -i -N \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "https://$DOMAIN/mqtt" \
    --max-time 5 -o /dev/null 2>&1 | grep -q "101 Switching Protocols"; then
    print_result 0 "WebSocket connection successful"
else
    print_result 1 "WebSocket connection failed"
fi
echo ""

# Test 9: Camera Stream WebSocket
echo "Test 9: Camera Stream WebSocket"
if curl -sSf -i -N \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "https://$DOMAIN/camera-stream" \
    --max-time 5 -o /dev/null 2>&1 | grep -q "101 Switching Protocols"; then
    print_result 0 "Camera stream WebSocket accessible"
else
    print_result 1 "Camera stream WebSocket failed"
fi
echo ""

# Test 10: HTTP Headers (Security)
echo "Test 10: HTTP Security Headers"
HEADERS=$(curl -sI "https://$DOMAIN" --max-time 10)
if echo "$HEADERS" | grep -qi "strict-transport-security"; then
    print_result 0 "HSTS header present"
else
    print_result 1 "HSTS header missing"
fi
if echo "$HEADERS" | grep -qi "x-frame-options"; then
    print_result 0 "X-Frame-Options header present"
else
    print_result 1 "X-Frame-Options header missing"
fi
echo ""

echo "=== Test Summary Complete ==="
echo ""
echo "To fix failed tests:"
echo "1. DNS: Configure domain DNS records to point to VPS IP"
echo "2. HTTPS: Run setup-ssl.sh to obtain SSL certificate"
echo "3. API: Ensure backend service is running on port 3000"
echo "4. MQTT: Ensure Mosquitto is running and ports are open"
echo "5. WebSocket: Ensure Nginx WebSocket proxy is configured"
echo ""
echo "To open firewall ports:"
echo "  sudo ufw allow 80/tcp"
echo "  sudo ufw allow 443/tcp"
echo "  sudo ufw allow 1883/tcp"
echo "  sudo ufw allow 8883/tcp"
echo "  sudo ufw allow 9001/tcp"
