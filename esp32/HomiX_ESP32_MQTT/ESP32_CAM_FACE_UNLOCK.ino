#include <WiFi.h>
#include <HTTPClient.h>
#include "esp_camera.h"
#include "base64.h"

// =========================
// Network / API Configuration
// =========================
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char* API_HOST = "5.135.79.223"; // Remote backend host
const uint16_t API_PORT = 3000;          // Single port for API + AI (+ MQTT over WS)

const char* HOME_CODE = "DZ-ABCD-1234";
const char* DOOR_DEVICE_ID = "door_1";
const char* FACE_DEVICE_TOKEN = "dev-face-device-token"; // change in production

// IMPORTANT:
// If backend enforces HTTPS for face routes, set FACE_REQUIRE_HTTPS=false in backend env
// for local ESP32 HTTP tests, or move to HTTPS with certificates.

// Unlock relay (optional)
const int RELAY_PIN = 12;
const bool RELAY_ACTIVE_HIGH = true;
const unsigned long RELAY_UNLOCK_MS = 3000;

// Request reliability
const int FACE_UNLOCK_MAX_ATTEMPTS = 4;
const int HTTP_CONNECT_TIMEOUT_MS = 6000;
const int HTTP_READ_TIMEOUT_MS = 12000;
const unsigned long RETRY_DELAY_MS = 800;

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
#define VSYNC_GPIO_NUM 25
#define HREF_GPIO_NUM 23
#define PCLK_GPIO_NUM 22

bool initCamera() {
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
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_VGA;
  config.jpeg_quality = 10; // Better details for face model
  config.fb_count = 2;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    return false;
  }

  sensor_t* s = esp_camera_sensor_get();
  if (s) {
    s->set_brightness(s, 0);
    s->set_contrast(s, 1);
    s->set_saturation(s, 0);
    s->set_sharpness(s, 2);
    s->set_gain_ctrl(s, 1);
    s->set_exposure_ctrl(s, 1);
    s->set_awb_gain(s, 1);
  }

  return true;
}

String captureImageAsDataUrl() {
  // Warm-up: discard first 2 frames to stabilize exposure
  for (int i = 0; i < 2; i++) {
    camera_fb_t* warm = esp_camera_fb_get();
    if (warm) esp_camera_fb_return(warm);
    delay(40);
  }

  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    return "";
  }

  String encoded = base64::encode(fb->buf, fb->len);
  esp_camera_fb_return(fb);

  return String("data:image/jpeg;base64,") + encoded;
}

void triggerDoorRelay() {
  digitalWrite(RELAY_PIN, RELAY_ACTIVE_HIGH ? HIGH : LOW);
  delay(RELAY_UNLOCK_MS);
  digitalWrite(RELAY_PIN, RELAY_ACTIVE_HIGH ? LOW : HIGH);
}

bool shouldRetryByResponse(int code, const String& response) {
  if (code == 429 || code == 500 || code == 502 || code == 503 || code == 504) return true;

  // Retry for transient or quality-related failures.
  if (response.indexOf("low_quality") >= 0) return true;
  if (response.indexOf("face_verification_failed") >= 0) return true;
  if (response.indexOf("face_processing_timeout") >= 0) return true;
  if (response.indexOf("face_service_unavailable") >= 0) return true;

  // Usually retry once may pass when user adjusts pose/light.
  if (response.indexOf("anti_spoof_failed") >= 0) return true;

  // Do not retry auth/security failures automatically.
  if (response.indexOf("invalid_device_token") >= 0) return false;
  if (response.indexOf("https_required") >= 0) return false;

  return false;
}

bool sendUnlockRequest(const String& imageDataUrl, int& outCode, String& outResponse) {
  String endpoint = String("http://") + API_HOST + ":" + String(API_PORT) +
                    "/api/homes/" + HOME_CODE +
                    "/doors/" + DOOR_DEVICE_ID +
                    "/unlock-with-face";

  String body;
  body.reserve(imageDataUrl.length() + 32);
  body = String("{\"image\":\"") + imageDataUrl + "\"}";

  HTTPClient http;
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
      Serial.println("Face unlock authorized");
      triggerDoorRelay();
      return true;
    }

    if (!shouldRetryByResponse(code, response)) {
      Serial.println("Face unlock denied (non-retriable)");
      return false;
    }

    Serial.println("Retriable failure, trying again...");
    delay(RETRY_DELAY_MS);
  }

  Serial.println("Face unlock denied after retries");
  return false;
}

void setup() {
  Serial.begin(115200);

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_ACTIVE_HIGH ? LOW : HIGH);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("WiFi connected");

  if (!initCamera()) {
    Serial.println("Camera setup failed");
    return;
  }

  // Example: trigger one face unlock request once after boot.
  // In production call unlockDoorWithFace() from button/interrupt/command logic.
  unlockDoorWithFace();
}

void loop() {
  delay(1000);
}
