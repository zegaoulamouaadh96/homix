# ESP32-CAM HomiX Smart Home Security

## التحديثات الجديدة

تم تحديث كود ESP32-CAM ليدعم:

### 1. البث المباشر للكاميرا
- **WebSocket**: بث الفيديو عبر WebSocket على المنفذ 3000
- **المسار**: `/camera-stream?homeId=HOME_CODE&deviceId=cam_1`
- **فاصل الإطارات**: 100ms (10 FPS تقريباً)
- **جودة الصورة**: QVGA (320x240) لتقليل استهلاك الباندويث

### 2. دعم MQTT
- **المواضيع**:
  - `home/{HOME_CODE}/device/{DEVICE_ID}/cmd` - استقبال الأوامر
  - `home/{HOME_CODE}/device/{DEVICE_ID}/alert` - إرسال التنبيهات
- **الأوامر المدعومة**:
  - `STREAM_ON` - تشغيل البث المباشر
  - `STREAM_OFF` - إيقاف البث المباشر
  - `UNLOCK_DOOR` - فتح الباب

### 3. إعدادات الكاميرا
- **الدقة**: QVGA (320x240) للبث المباشر
- **JPEG Quality**: 12
- **Double Buffer**: 2 إطارات لبث سلس

## التثبيت

### المتطلبات
1. تثبيت مكتبة PubSubClient عبر Library Manager
2. تثبيت مكتبة WebSockets عبر Library Manager
3. Arduino IDE 2.x أو PlatformIO

### الخطوات
1. افتح المشروع في Arduino IDE
2. حدد Board: AI Thinker ESP32-CAM
3. حدد COM Port المناسب
4. قم بتحديث الإعدادات:
   - WIFI_SSID
   - WIFI_PASSWORD
   - HOME_CODE
   - CAMERA_DEVICE_ID
5. ارفع الكود (Upload)

## الاستخدام

### البث المباشر
البث يعمل تلقائياً بعد التشغيل. للتطبيق:
1. افتح تطبيق Flutter
2. انتقل لشاشة الكاميرات
3. اضغط على زر البث المباشر
4. سيتم الاتصال بـ WebSocket وعرض البث

### فتح الباب بالوجه
- يعمل تلقائياً بشكل دوري (كل 10 ثوان)
- يمكن تعطيله من الكود (تعليق السطر في loop)
- يرسل الصورة للسيرفر للتحقق من الوجه

### MQTT
- يتصل تلقائياً بالسيرفر
- يستقبل الأوامر من التطبيق
- يرسل التنبيهات عند اكتشاف أحداث

## ملاحظات هامة

1. **استهلاك الذاكرة**: البث المباشر يستخدم ذاكرة كبيرة، قد تحتاج لتقليل الجودة إذا واجهت مشاكل
2. **استهلاك الباندويث**: البث يستخدم ~500KB/s، تأكد من اتصال WiFi قوي
3. **الطاقة**: البث المستمر يستهلك طاقة عالية، استخدم مصدر طاقة كافٍ (5V 2A على الأقل)
4. **التبريد**: ESP32-CAM قد يسخن مع البث المستمر، استخدم heat sink إذا لزم الأمر

## إعدادات متقدمة

### تقليل استهلاك الباندويث
```cpp
// في initCamera()
config.frame_size = FRAMESIZE_QQVGA; // 160x120
config.jpeg_quality = 20; // جودة أقل

// في المتغيرات العامة
const unsigned long STREAM_INTERVAL_MS = 200; // 5 FPS
```

### تحسين جودة الصورة
```cpp
config.frame_size = FRAMESIZE_VGA; // 640x480
config.jpeg_quality = 10; // جودة أعلى
const unsigned long STREAM_INTERVAL_MS = 50; // 20 FPS
```

### تعطيل البث التلقائي
```cpp
// في setup()
streamEnabled = false; // بدلاً من true
```
