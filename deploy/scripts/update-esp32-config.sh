#!/bin/bash

# ESP32 Configuration Update Script
# Updates ESP32 code to use homix.systems with SSL

ESP32_DIR="../../esp32/HomiX_ESP32_MQTT"

echo "=== ESP32 Configuration Update Script ==="
echo "Updating ESP32 code to use homix.systems with SSL"
echo ""

# Update ESP32_CAM_FACE_UNLOCK.ino
if [ -f "$ESP32_DIR/ESP32_CAM_FACE_UNLOCK.ino" ]; then
    echo "Updating ESP32_CAM_FACE_UNLOCK.ino..."
    sed -i 's|5\.135\.79\.223|homix.systems|g' "$ESP32_DIR/ESP32_CAM_FACE_UNLOCK.ino"
    sed -i 's|USE_HTTPS = false|USE_HTTPS = true|g' "$ESP32_DIR/ESP32_CAM_FACE_UNLOCK.ino"
    sed -i 's|SERVER_PORT = 3000|SERVER_PORT = 443|g' "$ESP32_DIR/ESP32_CAM_FACE_UNLOCK.ino"
    sed -i 's|API_PORT = 3000|API_PORT = 443|g' "$ESP32_DIR/ESP32_CAM_FACE_UNLOCK.ino"
    sed -i 's|http://|https://|g' "$ESP32_DIR/ESP32_CAM_FACE_UNLOCK.ino"
    echo "✓ ESP32_CAM_FACE_UNLOCK.ino updated"
else
    echo "✗ ESP32_CAM_FACE_UNLOCK.ino not found"
fi

# Update ESP32_CAM_STREAM_MQTT.ino
if [ -f "$ESP32_DIR/ESP32_CAM_STREAM_MQTT.ino" ]; then
    echo "Updating ESP32_CAM_STREAM_MQTT.ino..."
    sed -i 's|5\.135\.79\.223|homix.systems|g' "$ESP32_DIR/ESP32_CAM_STREAM_MQTT.ino"
    echo "✓ ESP32_CAM_STREAM_MQTT.ino updated"
else
    echo "✗ ESP32_CAM_STREAM_MQTT.ino not found"
fi

# Update HomiX_ESP32_MQTT.ino
if [ -f "$ESP32_DIR/HomiX_ESP32_MQTT.ino" ]; then
    echo "Updating HomiX_ESP32_MQTT.ino..."
    sed -i 's|5\.135\.79\.223|homix.systems|g' "$ESP32_DIR/HomiX_ESP32_MQTT.ino"
    echo "✓ HomiX_ESP32_MQTT.ino updated"
else
    echo "✗ HomiX_ESP32_MQTT.ino not found"
fi

echo ""
echo "=== Update Complete ==="
echo ""
echo "Next steps:"
echo "1. Upload updated code to ESP32 devices"
echo "2. Test MQTT connection: mosquitto_sub -h homix.systems -t home/DZ-BEBJ-Z6U7/#"
echo "3. Test API connection from ESP32"
echo ""
echo "For MQTT over SSL (MQTTS) on ESP32:"
echo "- ESP32 supports TLS/SSL"
echo "- Add WiFiClientSecure instead of WiFiClient"
echo "- Load SSL certificate (or use fingerprint verification)"
