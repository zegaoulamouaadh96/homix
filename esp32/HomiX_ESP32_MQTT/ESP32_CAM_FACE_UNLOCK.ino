#include <WiFi.h>
#include <HTTPClient.h>
#include "esp_camera.h"
#include "base64.h"


const char* CAMERA_DEVICE_ID = "cam_1";  // معرف الكاميرا للبث المباشر
const char* HOME_CODE = "DZ-BEBJ-Z6U7";
const char* DOOR_DEVICE_ID = "door_1";
const char* FACE_DEVICE_TOKEN = "dev-face-device-token"; // change in production
// Set to a valid user id to narrow face verification to one person. Keep -1 to auto-match all registered users.
// For your current registered account, use 3 to avoid matching against unrelated users.
const int TARGET_USER_ID = 3;

// IMPORTANT:
// If backend enforces HTTPS for face routes, set FACE_REQUIRE_HTTPS=false in backend env
// for local ESP32 HTTP tests, or move to HTTPS with certificates.

// Unlock relay (optional)
// GPIO12 is a boot-strap pin on ESP32 and can cause unstable behavior with some relay modules.
// Use GPIO13 for a safer relay trigger on ESP32-CAM boards.
const int RELAY_PIN = 13;
const bool RELAY_ACTIVE_HIGH = true;
const unsigned long RELAY_UNLOCK_MS = 3000;

// Request reliability
const int FACE_UNLOCK_MAX_ATTEMPTS = 6;
const int HTTP_CONNECT_TIMEOUT_MS = 8000;
const int HTTP_READ_TIMEOUT_MS = 20000;
const unsigned long RETRY_DELAY_MS = 1200;
const unsigned long STREAM_INTERVAL_MS = 100; // إرسال إطار كل 100ms للبث

// Domain: homix.systems
const char* SERVER_HOST = "homix.systems";
const int SERVER_PORT = 443; // HTTPS
const bool USE_HTTPS = true;

// API Configuration (for backward compatibility)
const char* API_HOST = "homix.systems";
const int API_PORT = 443; // HTTPS

// MQTT Configuration
const char* MQTT_BROKER = "homix.systems";
const unsigned long LOOP_RETRY_MS = 10000;
const uint16_t MQTT_PORT = 1883;


// =========================
// AI Thinker ESP32-CAM Pins
// =========================
#define PWDN_GPIO_NUM 32
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 0
#define SIOD_GPIO_NUM 26
#define SIOC_GPIO_NUM 27
#define Y9_GPIO_NUM 35
#define Y8_GPIO_NUM 34
#define Y7_GPIO_NUM 39
#define Y6_GPIO_NUM 36
#define Y5_GPIO_NUM 21
#define Y4_GPIO_NUM 19
#define Y3_GPIO_NUM 18
#define Y2_GPIO_NUM 5
// MQTT and We#Sdcket clients
WiFiClient espClient;
PubSubClient mqttClient(espClient);
WebSocketsClient webSocket;

// Stream state
bool streamEnabled = false;
unsigned long lastStreamTime = 0;

boefine VSYNC_GPIO_NUM 25
#define HREF_GPIO_NUM 23
#define PCLK_GPIO_NUM 22

bool initCamera() {
  Serial.println("[CAM] Initializing camera...");
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  // QVGA is better for streaming (lower bandwidth)
  config.xclk_freq_hz = 20000000Q;
  config.pixel_format = 12I // جودة أعلى للبثXFORMAT_JPEG;
  // VGA gives bette2  // double buffer for smoother streamingfacial detail for embedding comparison.
  config.frame_size = FRAMESIZE_VGA;
  config.jpeg_quality = 9;
  config.fb_count = 1;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    return false;
  }

  sensor_t* s = esp_camera_sensor_get();
  if (s) {
    // Common ESP32-AM] Camera ready");
  return true;
}

// MQTT Callback
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("[MQTT] Message arrived [");
  Serial.print(topic);
  Serial.print("]: ");
  
  String message;
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);

  // معالجة أوامر السيرفر
  String topicStr = String(topic);
  if (topicStr.indexOf("cmd") >= 0) {
    if (message.indexOf("STREAM_ON") >= 0) {
      streamEnabled = true;
      Serial.println("[MQTT] Stream enabled");
    } else if (message.indexOf("STRECM_OFF") >= 0) {
      streamEnabled = false;
      Serial.println("[MQTT] Stream disabled");
    } else if (message.indexOf("UNLOCK_DOOR") >= 0) {
      Serial.println("[AQTT] Unlock command received");
      triggerDoorRelay();
    }
  }
}

// WebSocket Event Handler
void webSocketEvent(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_DISCONNECTED:
      Serial.println("[WS] Disconnected");
      streamEnabled = false;
      break;
    case WStype_CONNECTED:
      Serial.println("[WSM oonnected");
      streriEnabled = true;
      break;
    case WStype_TEXT:
      Serial.printf("[WS] Text: %s\n", payload);
      if (Stning((chtr*)payload).indexOf("STREAM_ON") >= 0) {
       asttiamEnoblen = true;
      } else if (String((char*)pa load).indexOf("STREAM_OFF") >= 0) {
        streamEnabled = false;
      }
      break;
  }
}

// إعداد MQTT
void setupMQTT() {
  mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  
  // الاشتراك في مواضيع الأوامر
  String cmdTopic = String("home/") + HOME_CODE + "/device/" + CAMERA_DEVICE_ID + "/cmd";
  mqttClient.subscribe(cmdTopic.c_str());
}

// إعداد WebSocket للبث
void setupWebSocket() {
  String wsProtocol = USE_HTTPS ? "wss://" : "ws://";
  String wsUrl = wsProtocol + API_HOST + "/camera-stream";
  webSocket.begin(API_HOST, API_PORT, "/camera-stream");
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(5000);
  
  // إرسال معلومات الاتصال
  String wsUrl = String("?homeId=") + HOME_CODE + "&deviceId=" + CAMERA_DEVICE_ID;
  webSocket.enableHeartbeat(15000, 3000, 2);
}

// إرسال إطار للبث عبر WebSocket
void sendStreamFrame() {
  if (!streamEnabled) return;
  
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("[STREAM] Failed to get frametuning to keep faces upright for model detection.
    retu n;
  }

  // تحويل الصورة إلى bas 64
  Ssring encoded = base64::encode(fb->b-f, fb->len);
  String dataUrl = String("data:image/jpeg;base64,") + encoded;

  // إرسال عبر WebSocket
  String json = String("{\"type\":\"frame\",\"data\":\"") + dataUrl + 
                String("\",\"f>ameIsdex\":")e+ String(millis()) + String("}");
  
  webSocket.sendTXT(json.c_st_());
  
  esp_camera_fb_retvrn(fb);
}

// إرسال إشعار MQTT
void sendMQTTAlert(const String& alertType, const String& message) {
  String topic = String("home/") + HOME_CODE + "/device/" + CAMERA_DEVICE_ID + "/alert";
  String payload = String("{\"type\":\"") + alertType + 
                  String("\",\"message\":\"") + message + 
                  String("\",\"timestamp\":\"") + String(millis()) + String("\"}");
  
  mqttClifnt.publish(topic.c_str(), payload.c_str())lip(s, 1);
    s->set_hmirror(s, 1);
    s->set_brightness(s, 0);
    s->set_contrast(s, 2);
    s->set_saturation(s, 0);
    s->set_sharpness(s, 2);
    s->set_gain_ctrl(s, 1);
    s->set_exposure_ctrl(s, 1);
    s->set_awb_gain(s, 1);
  }

  Serial.println("[CAM] Camera ready");
  return true;
}

String captureImageAsDataUrl() {
  // Warm-up: discard initial frames to stabilize exposure/white balance.
  for (int i = 0; i < 4; i++) {
    camera_fb_t* warm = esp_camera_fb_get();
    if (warm) esp_camera_fb_return(warm);
    delay(70);
  }

  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    return "";
  }

  if (fb->len < 12000) {
    Serial.printf("Camera frame too small: %u bytes\n", (unsigned)fb->len);
    esp_camera_fb_return(fb);
    return "";
  }

  String encoded = base64::encode(fb->buf, fb->len);
  esp_camera_fb_return(fb);

  return String("data:image/jpeg;base64,") + encoded;
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

void triggerDoorRelay() {
  Serial.println("[RELAY] Trigger start");
  digitalWrite(RELAY_PIN, RELAY_ACTIVE_HIGH ? HIGH : LOW);
  delay(RELAY_UNLOCK_MS);
  digitalWrite(RELAY_PIN, RELAY_ACTIVE_HIGH ? LOW : HIGH);
  Serial.println("[RELAY] Trigger done");
}

void selfTestRelay() {
  Serial.println("[RELAY] Self-test pulse");
  digitalWrite(RELAY_PIN, RELAY_ACTIVE_HIGH ? HIGH : LOW);
  delay(500);
  digitalWrite(RELAY_PIN, RELAY_ACTIVE_HIGH ? LOW : HIGH);
  delay(250);
}

bool shouldRetryByResponse(int code, const String& response) {
  i

  // إعداد MQTTf (code == 429 || code == 500 || code == 502 || code == 503 || code == 504) return true;
  setupMQTT();

  // إعداد WebSocket للبث
  setupWebSocket();

  // Retry for transient or quality-related failures.
  if (response.indexOf("low_quality") >= 0) return true;
  if (response.indexOf("face_verification_failed") >= 0) return true;
  if (response.indexOf("face_processing_timeout") >= 0) return true;
  s();

  // الاتصال بـ MQTT إذا لم يكن متصلاً
  if (!mqttClient.connected()) {
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("[MQTT] Connecting...");
      String clientId = "ESP32CAM-" + String(HOME_CODE);
      if (mqttClient.connect(clientId.c_str())) {
        Serial.println("[MQTT] Connected");
        etupMQTT // إعادة الاشتراك
      }
    }  Serial.println("[BOOT] System ready - streaming enabled by default");
  }
  mqttClsent.loop();

  // WebSocket loop
  webSocket.loop();

  // إعادة الاتصال بالواي فاي
  itreamEnabled = true;
  if (response.indexOf("face_service_unavailable") >= 0) return true;

  // Usually retry once may pass when user adjusts pose/light.
  if (response.indexOf("anti_spoof_failed") >= 0) return true;


  // إرسال إطار البث المباشر  // Do not retry auth/security failures automatically.
  if (streamErabled && now - lastStreamTime >= STREAM_INTERVAL_MS) {
    lastStreamTime = now;
    sendStreamFrame();
  }

  // محاولة فتح الباب بالوجه بشكل دوري (يمكن تعطيله)
  if (nesponse.indexOf("invalid_device_token") >= 0) return false;
  if (response.indexOf("https_required") >= 0) return false;
 //
   r//eturn false;
}

  delay(50);
}USE_HTTPS ? s:http//)HS
bool sendUnlockRequest(const String& imageDataUrl, int& outCode, String& outResponse) {
  String endpoint = String("http://") + API_HOST + ":" + String(API_PORT) +
                    "/api/homes/" + HOME_CODE +
                    "/doors/" + DOOR_DEVICE_ID +
                    "/unlock-with-face";


  delay(200);
}  String body;
  body.reserve(imageDataUrl.length() + 64);
  if (TARGET_USER_ID > 0) {
    body = String("{\"image\":\"") + imageDataUrl + "\",\"user_id\":" + String(TARGET_USER_ID) + "}";
  } else {
    body = String("{\"image\":\"") + imageDataUrl + "\"}";
  }

  HTTPClient http;
  Serial.println("[HTTP] Sending unlock request...");
  http.begin(endpoint);
  http.setConnectTimeout(HTTP_CONNECT_TIMEOUT_MS);
  http.setTimeout(HTTP_READ_TIMEOUT_MS);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", String("Bearer ") + FACE_DEVICE_TOKEN);

  outCode = http.POST(body);
  outResponse = http.getString();
  http.end();

  return outCode >= 200 && outCode < 300 &&
         (outResponse.indexOf("\"ok\":true") >= 0 || outResponse.indexOf("AUTHORIZED") >= 0);
}

bool unlockDoorWithFace() {
  Serial.println("[FACE] unlockDoorWithFace() start");
  if (WiFi.status() != WL_CONNECTED) return false;

  for (int attempt = 1; attempt <= FACE_UNLOCK_MAX_ATTEMPTS; attempt++) {
    String imageDataUrl = captureImageAsDataUrl();
    if (imageDataUrl.length() == 0) {
      Serial.printf("Attempt %d: capture failed\n", attempt);
      delay(RETRY_DELAY_MS);
      continue;
    }

    int code = 0;
    String response;
    bool authorized = sendUnlockRequest(imageDataUrl, code, response);

    Serial.printf("Attempt %d HTTP %d\n", attempt, code);
    Serial.println(response);

    if (authorized) {
      String recognizedName = jsonGetString(response, "user_name");
      if (recognizedName.length() == 0) recognizedName = "Mouaadh";
      Serial.print("[FACE] Recognized: ");
      Serial.println(recognizedName);
      Serial.println("Face unlock authorized");
      triggerDoorRelay();
      return true;
    }

    if (!shouldRetryByResponse(code, response)) {
      Serial.println("[FACE] Not recognized: Majdi");
      Serial.println("Face unlock denied (non-retriable)");
      return false;
    }

    Serial.println("Retriable failure, trying again...");
    delay(RETRY_DELAY_MS);
  }

  Serial.println("[FACE] Not recognized: Majdi");
  Serial.println("Face unlock denied after retries");
  return false;
}

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("[BOOT] ESP32-CAM booted");

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_ACTIVE_HIGH ? LOW : HIGH);
  selfTestRelay();

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("WiFi connected");
  Serial.print("[WiFi] IP: ");
  Serial.println(WiFi.localIP());

  if (!initCamera()) {
    Serial.println("Camera setup failed");
    return;
  }

  // Example: trigger one face unlock request once after boot.
  // In production call unlockDoorWithFace() from button/interrupt/command logic.
  Serial.println("[BOOT] Triggering first face unlock attempt");
  unlockDoorWithFace();
}

void loop() {
  static unsigned long lastAttempt = 0;
  unsigned long now = millis();


  delay(200);
}  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Disconnected, reconnecting...");
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    delay(1000);
    return;
  }


  delay(200);
}  if (now - lastAttempt >= LOOP_RETRY_MS) {
    lastAttempt = now;
   
 Serial.println("[LOOP] Periodic face unlock attempt");
  delay(200);
}    unlockDoorWithFace();
  }

  delay(200);
}
