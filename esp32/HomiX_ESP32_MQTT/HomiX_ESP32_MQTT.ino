#include <WiFi.h>
#include <PubSubClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ESP32Servo.h>

// =========================
// User Configuration
// =========================
const char* WIFI_SSID = "Ztn FIBER";
const char* WIFI_PASSWORD = "Majdi2004";

const char* MQTT_HOST = "5.135.79.223";
const uint16_t MQTT_PORT = 1883;
const char* MQTT_USERNAME = "";
const char* MQTT_PASSWORD = "";

// Must match the home code created/paired in backend.
const char* HOME_CODE = "DZ-BEBJ-Z6U7";

// Logical device IDs used by backend/app.
const char* DOOR_DEVICE_ID = "door_1";
const char* CAMERA_DEVICE_ID = "camera_1";
const char* SEISMIC_HUB_DEVICE_ID = "seismic_hub";

// Camera stream URL published to the mobile app.
// Use a reachable IP from the phone (same LAN or public IP/domain).
// Set CAMERA_STREAM_HOST to "AUTO_LOCAL_IP" only if this same ESP32 serves the stream endpoint.
const char* CAMERA_STREAM_HOST = "192.168.1.50";
const uint16_t CAMERA_STREAM_PORT = 81;
const char* CAMERA_STREAM_PATH = "/stream";
const bool CAMERA_STREAM_USE_HTTPS = false;

// Add authorized RFID UIDs in uppercase HEX with '-'.
const char* AUTHORIZED_UIDS[] = {
  "92-65-94-04"
};
const size_t AUTHORIZED_UID_COUNT = sizeof(AUTHORIZED_UIDS) / sizeof(AUTHORIZED_UIDS[0]);

// =========================
// Hardware Pins
// =========================
#define RFID_SS_PIN 5
#define RFID_RST_PIN 22
#define SERVO_PIN 13

#define GREEN_LED_PIN 26
#define RED_LED_PIN 4
#define BLUE_LED_PIN 27

// 4 seismic/vibration sensors.
// Expand this array if you wire more sensors.
struct SeismicSensor {
  const char* deviceId;
  uint8_t pin;
  bool activeHigh;
  bool armed;
  int lastRaw;
  bool active;
};

SeismicSensor sensors[] = {
  {"seismic_1", 32, true, true, LOW, false},
  {"seismic_2", 33, true, true, LOW, false},
  {"seismic_3", 25, true, true, LOW, false},
  {"seismic_4", 14, true, true, LOW, false}
};

const size_t SENSOR_COUNT = sizeof(sensors) / sizeof(sensors[0]);

// =========================
// Runtime State
// =========================
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
MFRC522 rfid(RFID_SS_PIN, RFID_RST_PIN);
Servo doorServo;

bool doorIsOpen = false;
bool doorLedState = false;
unsigned long doorOpenedAtMs = 0;
unsigned long doorAutoCloseMs = 3000;

bool redAlertActive = false;
unsigned long redAlertUntilMs = 0;

bool earthquakeLatched = false;
bool earthquakeFlashActive = false;
unsigned long earthquakeFlashUntilMs = 0;
unsigned long lastEarthquakeMs = 0;

unsigned long lastHeartbeatMs = 0;
unsigned long lastMqttReconnectAttemptMs = 0;
unsigned long lastWiFiAttemptMs = 0;

const unsigned long HEARTBEAT_MS = 10000;
const unsigned long WIFI_RETRY_MS = 8000;
const unsigned long MQTT_RETRY_MS = 5000;
const unsigned long RED_ALERT_MS = 2000;
const unsigned long EARTHQUAKE_COOLDOWN_MS = 12000;
const unsigned long EARTHQUAKE_FLASH_MS = 3000;
const int EARTHQUAKE_MIN_ACTIVE_SENSORS = 3;

const int SERVO_CLOSED_ANGLE = 0;
const int SERVO_OPEN_ANGLE = 90;

// =========================
// Helpers
// =========================
String boolJson(bool value) {
  return value ? "true" : "false";
}

String buildCameraStreamUrl() {
  String host = String(CAMERA_STREAM_HOST);
  host.trim();
  if (host.length() == 0 || host == "AUTO_LOCAL_IP") {
    host = WiFi.localIP().toString();
  }

  String path = String(CAMERA_STREAM_PATH);
  if (!path.startsWith("/")) path = "/" + path;

  const char* scheme = CAMERA_STREAM_USE_HTTPS ? "https://" : "http://";
  return String(scheme) + host + ":" + String(CAMERA_STREAM_PORT) + path;
}

String buildTopic(const char* deviceId, const char* kind) {
  return String("home/") + HOME_CODE + "/device/" + deviceId + "/" + kind;
}

void publishRaw(const String& topic, const String& payload, bool retained = false) {
  if (!mqttClient.connected()) return;
  mqttClient.publish(topic.c_str(), payload.c_str(), retained);
}

void publishEvent(const char* deviceId, const String& type, const String& message) {
  String payload =
      String("{\"type\":\"") + type +
      "\",\"message\":\"" + message +
      "\",\"source\":\"esp32\",\"ts\":" + String(millis()) + "}";
  publishRaw(buildTopic(deviceId, "event"), payload);
}

void publishAck(const char* deviceId, const String& cmd, bool ok, const String& note) {
  String payload =
      String("{\"cmd\":\"") + cmd +
      "\",\"ok\":" + boolJson(ok) +
      ",\"note\":\"" + note +
      "\",\"source\":\"esp32\",\"ts\":" + String(millis()) + "}";
  publishRaw(buildTopic(deviceId, "ack"), payload);
}

void publishDoorTelemetry(const String& source) {
  String payload =
      String("{\"online\":true,\"type\":\"door\",\"open\":") + boolJson(doorIsOpen) +
      ",\"locked\":" + boolJson(!doorIsOpen) +
      ",\"source\":\"" + source +
      "\",\"ts\":" + String(millis()) + "}";
  publishRaw(buildTopic(DOOR_DEVICE_ID, "telemetry"), payload);
}

void publishCameraTelemetry() {
  String streamUrl = buildCameraStreamUrl();
  String payload =
      String("{\"online\":true,\"type\":\"camera\",\"stream_url\":\"") + streamUrl + "\",\"ts\":" +
      String(millis()) + "}";
  publishRaw(buildTopic(CAMERA_DEVICE_ID, "telemetry"), payload);
}

void publishSensorTelemetry(size_t index, const String& source) {
  if (index >= SENSOR_COUNT) return;
  bool triggered = sensors[index].active && sensors[index].armed;
  String payload =
      String("{\"online\":true,\"type\":\"seismic\",\"active\":") + boolJson(sensors[index].active) +
      ",\"triggered\":" + boolJson(triggered) +
      ",\"motion\":" + boolJson(triggered) +
      ",\"armed\":" + boolJson(sensors[index].armed) +
      ",\"sensor_index\":" + String(index + 1) +
      ",\"source\":\"" + source +
      "\",\"ts\":" + String(millis()) + "}";
  publishRaw(buildTopic(sensors[index].deviceId, "telemetry"), payload);
}

void publishSeismicHubTelemetry(int activeSensors, bool quake) {
  String payload =
      String("{\"online\":true,\"type\":\"seismic\",\"active_sensors\":") + String(activeSensors) +
      ",\"earthquake\":" + boolJson(quake) +
      ",\"ts\":" + String(millis()) + "}";
  publishRaw(buildTopic(SEISMIC_HUB_DEVICE_ID, "telemetry"), payload);
}

void refreshLeds() {
  bool green = doorLedState || sensors[0].active || earthquakeFlashActive;
  bool blue = sensors[1].active || sensors[3].active || earthquakeFlashActive;
  bool red = sensors[2].active || redAlertActive || earthquakeFlashActive;

  digitalWrite(GREEN_LED_PIN, green ? HIGH : LOW);
  digitalWrite(BLUE_LED_PIN, blue ? HIGH : LOW);
  digitalWrite(RED_LED_PIN, red ? HIGH : LOW);
}

String uidToString(const MFRC522::Uid& uid) {
  String out;
  for (byte i = 0; i < uid.size; i++) {
    if (i > 0) out += "-";
    if (uid.uidByte[i] < 0x10) out += "0";
    out += String(uid.uidByte[i], HEX);
  }
  out.toUpperCase();
  return out;
}

bool isAuthorizedUid(const String& uid) {
  for (size_t i = 0; i < AUTHORIZED_UID_COUNT; i++) {
    if (uid.equalsIgnoreCase(AUTHORIZED_UIDS[i])) return true;
  }
  return false;
}

String extractDeviceIdFromTopic(const String& topic) {
  int start = topic.indexOf("/device/");
  if (start < 0) return "";
  start += 8;
  int end = topic.indexOf("/cmd", start);
  if (end < 0) return "";
  return topic.substring(start, end);
}

String jsonGetString(const String& json, const String& key) {
  String token = "\"" + key + "\"";
  int keyPos = json.indexOf(token);
  if (keyPos < 0) return "";

  int colonPos = json.indexOf(':', keyPos + token.length());
  if (colonPos < 0) return "";

  int firstQuote = json.indexOf('"', colonPos + 1);
  if (firstQuote < 0) return "";

  int secondQuote = json.indexOf('"', firstQuote + 1);
  if (secondQuote < 0) return "";

  return json.substring(firstQuote + 1, secondQuote);
}

long jsonGetLong(const String& json, const String& key, long fallback) {
  String token = "\"" + key + "\"";
  int keyPos = json.indexOf(token);
  if (keyPos < 0) return fallback;

  int colonPos = json.indexOf(':', keyPos + token.length());
  if (colonPos < 0) return fallback;

  int i = colonPos + 1;
  while (i < (int)json.length() && (json[i] == ' ' || json[i] == '"')) i++;

  int j = i;
  while (j < (int)json.length() && (json[j] == '-' || (json[j] >= '0' && json[j] <= '9'))) j++;
  if (j <= i) return fallback;

  return json.substring(i, j).toInt();
}

void openDoor(const String& source) {
  doorServo.write(SERVO_OPEN_ANGLE);
  doorIsOpen = true;
  doorLedState = true;
  doorOpenedAtMs = millis();

  publishDoorTelemetry(source);
  publishEvent(DOOR_DEVICE_ID, "door_opened", source);
  refreshLeds();
}

void closeDoor(const String& source) {
  doorServo.write(SERVO_CLOSED_ANGLE);
  doorIsOpen = false;
  doorLedState = false;

  publishDoorTelemetry(source);
  publishEvent(DOOR_DEVICE_ID, "door_closed", source);
  refreshLeds();
}

void triggerInvalidAccessAlert() {
  redAlertActive = true;
  redAlertUntilMs = millis() + RED_ALERT_MS;
  refreshLeds();
}

void handleDoorCommand(const String& cmd, const String& payloadJson) {
  if (cmd == "UNLOCK_DOOR" || cmd == "OPEN_DOOR") {
    openDoor(String("mqtt_") + cmd);
    publishAck(DOOR_DEVICE_ID, cmd, true, "door_opened");
    return;
  }

  if (cmd == "LOCK_DOOR" || cmd == "CLOSE_DOOR") {
    closeDoor(String("mqtt_") + cmd);
    publishAck(DOOR_DEVICE_ID, cmd, true, "door_closed");
    return;
  }

  if (cmd == "SET_DOOR_TIMEOUT") {
    long timeoutMs = jsonGetLong(payloadJson, "value", (long)doorAutoCloseMs);
    if (timeoutMs < 500) timeoutMs = 500;
    if (timeoutMs > 60000) timeoutMs = 60000;
    doorAutoCloseMs = (unsigned long)timeoutMs;
    publishAck(DOOR_DEVICE_ID, cmd, true, String("timeout_ms=") + String(doorAutoCloseMs));
    return;
  }

  publishAck(DOOR_DEVICE_ID, cmd, false, "unsupported_command");
}

void handleSensorCommand(size_t sensorIndex, const String& cmd) {
  if (sensorIndex >= SENSOR_COUNT) return;

  if (cmd == "ARM_SENSOR") {
    sensors[sensorIndex].armed = true;
    publishSensorTelemetry(sensorIndex, "armed");
    publishAck(sensors[sensorIndex].deviceId, cmd, true, "armed");
    return;
  }

  if (cmd == "DISARM_SENSOR") {
    sensors[sensorIndex].armed = false;
    publishSensorTelemetry(sensorIndex, "disarmed");
    publishAck(sensors[sensorIndex].deviceId, cmd, true, "disarmed");
    return;
  }

  publishAck(sensors[sensorIndex].deviceId, cmd, false, "unsupported_command");
}

void handleHubCommand(const String& cmd) {
  if (cmd == "RESET_ALARM") {
    earthquakeLatched = false;
    earthquakeFlashActive = false;
    publishSeismicHubTelemetry(0, false);
    publishAck(SEISMIC_HUB_DEVICE_ID, cmd, true, "alarm_reset");
    refreshLeds();
    return;
  }

  if (cmd == "TRIGGER_ALARM") {
    earthquakeLatched = true;
    earthquakeFlashActive = true;
    earthquakeFlashUntilMs = millis() + EARTHQUAKE_FLASH_MS;
    publishEvent(SEISMIC_HUB_DEVICE_ID, "manual_alarm", "triggered_from_app");
    publishSeismicHubTelemetry(EARTHQUAKE_MIN_ACTIVE_SENSORS, true);
    publishAck(SEISMIC_HUB_DEVICE_ID, cmd, true, "alarm_triggered");
    refreshLeds();
    return;
  }

  publishAck(SEISMIC_HUB_DEVICE_ID, cmd, false, "unsupported_command");
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String topicStr(topic);
  String payloadStr;
  payloadStr.reserve(length + 1);
  for (unsigned int i = 0; i < length; i++) payloadStr += (char)payload[i];

  String cmd = jsonGetString(payloadStr, "cmd");
  if (cmd.length() == 0) return;

  String deviceId = extractDeviceIdFromTopic(topicStr);
  if (deviceId.length() == 0) return;

  if (deviceId == DOOR_DEVICE_ID) {
    handleDoorCommand(cmd, payloadStr);
    return;
  }

  if (deviceId == SEISMIC_HUB_DEVICE_ID) {
    handleHubCommand(cmd);
    return;
  }

  for (size_t i = 0; i < SENSOR_COUNT; i++) {
    if (deviceId == sensors[i].deviceId) {
      handleSensorCommand(i, cmd);
      return;
    }
  }

  publishAck(deviceId.c_str(), cmd, false, "unknown_device");
}

void ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  unsigned long now = millis();
  if (now - lastWiFiAttemptMs < WIFI_RETRY_MS) return;

  lastWiFiAttemptMs = now;
  Serial.println("[WiFi] Connecting...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

void subscribeCmdTopics() {
  String topic = String("home/") + HOME_CODE + "/device/+/cmd";
  mqttClient.subscribe(topic.c_str());
}

void publishDiscoveryTelemetry() {
  publishDoorTelemetry("boot");
  publishCameraTelemetry();
  for (size_t i = 0; i < SENSOR_COUNT; i++) {
    publishSensorTelemetry(i, "boot");
  }
  publishSeismicHubTelemetry(0, false);
}

void ensureMqtt() {
  if (mqttClient.connected() || WiFi.status() != WL_CONNECTED) return;

  unsigned long now = millis();
  if (now - lastMqttReconnectAttemptMs < MQTT_RETRY_MS) return;

  lastMqttReconnectAttemptMs = now;

  String clientId = String("homix-esp32-") + String((uint32_t)(ESP.getEfuseMac() & 0xFFFFFFFF), HEX);
  bool ok;
  if (String(MQTT_USERNAME).length() > 0) {
    ok = mqttClient.connect(clientId.c_str(), MQTT_USERNAME, MQTT_PASSWORD);
  } else {
    ok = mqttClient.connect(clientId.c_str());
  }

  if (ok) {
    Serial.println("[MQTT] Connected");
    subscribeCmdTopics();
    publishEvent(DOOR_DEVICE_ID, "device_online", "esp32_connected");
    publishDiscoveryTelemetry();
  } else {
    Serial.print("[MQTT] Connect failed, rc=");
    Serial.println(mqttClient.state());
  }
}

void handleRfid() {
  if (!rfid.PICC_IsNewCardPresent()) return;
  if (!rfid.PICC_ReadCardSerial()) return;

  String uid = uidToString(rfid.uid);
  Serial.print("RFID UID: ");
  Serial.println(uid);

  if (isAuthorizedUid(uid)) {
    publishEvent(DOOR_DEVICE_ID, "rfid_granted", uid);
    openDoor("rfid_granted");
  } else {
    publishEvent(DOOR_DEVICE_ID, "rfid_denied", uid);
    triggerInvalidAccessAlert();
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

void handleSensors() {
  int activeCount = 0;

  for (size_t i = 0; i < SENSOR_COUNT; i++) {
    int raw = digitalRead(sensors[i].pin);
    bool active = sensors[i].activeHigh ? (raw == HIGH) : (raw == LOW);

    if (active) activeCount++;

    if (raw != sensors[i].lastRaw) {
      sensors[i].lastRaw = raw;
      sensors[i].active = active;
      refreshLeds();
      publishSensorTelemetry(i, "edge");

      if (active && sensors[i].armed) {
        publishEvent(sensors[i].deviceId, "seismic", String("sensor_") + String(i + 1) + "_triggered");
      } else if (!active && sensors[i].armed) {
        publishEvent(sensors[i].deviceId, "seismic_cleared", String("sensor_") + String(i + 1));
      }
    }
  }

  unsigned long now = millis();
  if (activeCount >= EARTHQUAKE_MIN_ACTIVE_SENSORS) {
    if (!earthquakeLatched && (now - lastEarthquakeMs > EARTHQUAKE_COOLDOWN_MS)) {
      earthquakeLatched = true;
      lastEarthquakeMs = now;
      earthquakeFlashActive = true;
      earthquakeFlashUntilMs = now + EARTHQUAKE_FLASH_MS;
      publishEvent(SEISMIC_HUB_DEVICE_ID, "seismic", String("earthquake_alert_active_sensors=") + String(activeCount));
      publishSeismicHubTelemetry(activeCount, true);
      refreshLeds();
    }
  } else {
    if (earthquakeLatched) {
      earthquakeLatched = false;
      publishEvent(SEISMIC_HUB_DEVICE_ID, "earthquake_cleared", "sensors_back_to_normal");
      publishSeismicHubTelemetry(activeCount, false);
    }
  }
}

void handleTimers() {
  unsigned long now = millis();

  if (doorIsOpen && (now - doorOpenedAtMs >= doorAutoCloseMs)) {
    closeDoor("auto_close");
  }

  if (redAlertActive && now >= redAlertUntilMs) {
    redAlertActive = false;
    refreshLeds();
  }

  if (earthquakeFlashActive && now >= earthquakeFlashUntilMs) {
    earthquakeFlashActive = false;
    refreshLeds();
  }
}

void handleHeartbeat() {
  unsigned long now = millis();
  if (now - lastHeartbeatMs < HEARTBEAT_MS) return;

  lastHeartbeatMs = now;

  publishDoorTelemetry("heartbeat");
  publishCameraTelemetry();
  int activeCount = 0;
  for (size_t i = 0; i < SENSOR_COUNT; i++) {
    if (sensors[i].active) activeCount++;
    publishSensorTelemetry(i, "heartbeat");
  }
  publishSeismicHubTelemetry(activeCount, earthquakeLatched);
}

void setup() {
  Serial.begin(115200);

  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(BLUE_LED_PIN, OUTPUT);

  digitalWrite(GREEN_LED_PIN, LOW);
  digitalWrite(RED_LED_PIN, LOW);
  digitalWrite(BLUE_LED_PIN, LOW);

  for (size_t i = 0; i < SENSOR_COUNT; i++) {
    pinMode(sensors[i].pin, INPUT_PULLDOWN);
    sensors[i].lastRaw = digitalRead(sensors[i].pin);
    sensors[i].active = sensors[i].activeHigh ? (sensors[i].lastRaw == HIGH) : (sensors[i].lastRaw == LOW);
  }

  SPI.begin(18, 19, 23, RFID_SS_PIN);
  rfid.PCD_Init();

  doorServo.attach(SERVO_PIN, 500, 2400);
  doorServo.write(SERVO_CLOSED_ANGLE);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  lastWiFiAttemptMs = millis();

  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setBufferSize(1024);

  Serial.println("HomiX ESP32 ready");
}

void loop() {
  ensureWiFi();
  ensureMqtt();

  if (mqttClient.connected()) {
    mqttClient.loop();
  }

  handleRfid();
  handleSensors();
  handleTimers();

  if (mqttClient.connected()) {
    handleHeartbeat();
  }
}
