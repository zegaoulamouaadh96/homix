# 🏠 Smart Home Security - نظام الأمان المنزلي الذكي

## 📋 نظرة عامة

تطبيق Flutter متكامل لإدارة أمان المنزل الذكي مع واجهة مستخدم مظلمة أنيقة وتأثيرات حركية متطورة.

**🌐 Domain**: https://homix.systems  
**🔒 SSL**: Enabled with Let's Encrypt  
**📡 MQTT**: Secure MQTT over SSL (MQTTS)

## ✨ المميزات الرئيسية

- 🔐 **نظام مصادقة متعدد**: كود المنزل + بصمة + التعرف على الوجه
- 📹 **بث مباشر للكاميرات**: RTSP → HLS/WebRTC
- 🚪 **التحكم بالأبواب والشبابيك**: أقفال ذكية مع تأكيد PIN
- 📡 **مستشعرات متنوعة**: حركة، دخان، اهتزاز، كسر زجاج، فيضان
- 🎫 **رموز ضيوف مؤقتة**: One-time codes مع انتهاء صلاحية
- 🔔 **إشعارات فورية**: Firebase Push Notifications
- 👥 **إدارة الأعضاء**: أدوار متعددة (Owner, Admin, Resident, Guest)
- 🎨 **تصميم أسود كامل**: Material 3 مع تأثيرات Neon
- 🔒 **HTTPS آمن**: SSL Certificate من Let's Encrypt
- 📡 **MQTT over SSL**: اتصال آمن للأجهزة

## 🛠️ التقنيات المستخدمة

### Frontend (Flutter)
- **Flutter 3.24+** - إطار العمل الأساسي
- **flutter_screenutil** - تصميم متجاوب
- **flutter_animate** - تأثيرات حركية
- **go_router** - التنقل بين الشاشات
- **flutter_bloc** - إدارة الحالة
- **firebase_auth** - المصادقة
- **local_auth** - البصمة والوجه
- **video_player** - تشغيل الفيديو
- **flutter_vlc_player** - بث RTSP

### Backend (Node.js)
- **Express.js** - إطار API
- **PostgreSQL** - قاعدة البيانات
- **MQTT Broker** - مراسلة الأجهزة
- **Mosquitto** - MQTT broker
- **JWT** - المصادقة
- **Bcrypt** - تشفير كلمات المرور

### ESP32
- **ESP32-CAM** - كاميرا ذكية
- **ESP32** - متحكم للأجهزة
- **MQTT Client** - اتصال MQTT
- **WebSocket** - بث الفيديو

## 🚀 النشر على VPS

للاطلاع على دليل النشر الكامل على VPS، راجع [DEPLOYMENT.md](DEPLOYMENT.md)

### المتطلبات

- VPS مع Ubuntu 20.04+ (2GB RAM على الأقل)
- Domain name: `homix.systems`
- Docker و Docker Compose

### خطوات سريعة

1. **رفع المشروع على GitHub**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/YOUR_USERNAME/homix.git
   git push -u origin main
   ```

2. **نشر على VPS**
   ```bash
   # SSH للـ VPS
   ssh root@5.135.79.223
   
   # سحب المشروع
   git clone https://github.com/YOUR_USERNAME/homix.git /opt/homix
   cd /opt/homix
   
   # إعداد SSL
   ./deploy/scripts/setup-ssl.sh
   
   # تشغيل الخدمات
   cd deploy/docker
   docker-compose -f docker-compose.prod.yml up -d
   
   # اختبار الاتصالات
   ../scripts/test-connections.sh
   ```

### المنافذ المفتوحة

- 80/tcp - HTTP (Redirect to HTTPS)
- 443/tcp - HTTPS
- 1883/tcp - MQTT TCP
- 8883/tcp - MQTT over SSL (MQTTS)
- 9001/tcp - MQTT over WebSocket Secure

## 📁 هيكل المشروع

```
PFE/
├── frontend/                    # تطبيق Flutter
│   ├── lib/
│   │   ├── main.dart           # نقطة الدخول
│   │   ├── core/               # الأساسيات
│   │   │   ├── router/         # التنقل
│   │   │   └── theme/          # الألوان والثيمات
│   │   └── features/           # الميزات
│   │       ├── splash/         # شاشة البداية
│   │       ├── auth/           # المصادقة
│   │       ├── home/           # الشاشة الرئيسية
│   │       ├── cameras/        # الكاميرات
│   │       ├── control/        # التحكم بالمنزل
│   │       ├── sensors/        # المستشعرات
│   │       └── access/         # رموز الضيوف
│   └── pubspec.yaml            # حزم Flutter
│
├── backend/                     # خادم Python
│   ├── app/
│   │   ├── main.py             # FastAPI app
│   │   ├── config.py           # الإعدادات
│   │   ├── database.py         # MongoDB
│   │   └── models/             # نماذج البيانات
│   │       ├── home.py         # بيانات المنزل
│   │       ├── user.py         # المستخدمين
│   │       ├── device.py       # الأجهزة
│   │       └── access_code.py  # رموز الوصول
│   └── requirements.txt        # حزم Python
│
├── DEMO.html                    # عرض تفاعلي للتطبيق
└── README.md                    # هذا الملف
```

## 🚀 خطوات التشغيل

### 1. متطلبات التشغيل

#### Windows
```powershell
# تحقق من وجود Git
git --version

# تحقق من وجود Python 3.9+
python --version

# تحقق من وجود Node.js (اختياري للـ web)
node --version
```

### 2. تثبيت Flutter SDK

#### الطريقة الأولى: تنزيل يدوي
1. اذهب إلى: https://docs.flutter.dev/get-started/install/windows
2. حمل Flutter SDK (zip file)
3. استخرج إلى `C:\flutter` (أو أي مسار آخر)
4. أضف `C:\flutter\bin` إلى PATH:
   ```powershell
   # افتح PowerShell كمسؤول وشغل:
   [Environment]::SetEnvironmentVariable(
       "Path",
       [Environment]::GetEnvironmentVariable("Path", "Machine") + ";C:\flutter\bin",
       "Machine"
   )
   ```
5. أعد تشغيل PowerShell/VS Code

#### الطريقة الثانية: باستخدام Chocolatey
```powershell
# تثبيت Chocolatey أولاً (إذا لم يكن مثبتاً)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# تثبيت Flutter
choco install flutter -y
```

### 3. التحقق من Flutter

```powershell
# أعد تشغيل Terminal ثم شغل:
flutter doctor
```

يجب أن ترى:
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.24.5, ...)
[✓] Windows Version (Installed version of Windows is version 10 or higher)
[!] Android toolchain - develop for Android devices (optional)
[!] Chrome - develop for the web (optional)
[✓] Visual Studio Code (version X.X)
[✓] Connected device (1 available)
[✓] Network resources
```

### 4. تشغيل Frontend

```powershell
# انتقل لمجلد Frontend
cd c:\Users\ADMIN\Desktop\PFE\frontend

# تثبيت الحزم
flutter pub get

# شغل على Chrome (الأسرع للتطوير)
flutter run -d chrome

# أو شغل على Windows Desktop
flutter run -d windows

# أو شغل على Android Emulator (إذا كان مثبتاً)
flutter run -d emulator-5554
```

### 5. تشغيل Backend (اختياري - للوظائف الكاملة)

```powershell
# في terminal جديد
cd c:\Users\ADMIN\Desktop\PFE\backend

# إنشاء بيئة افتراضية
python -m venv venv

# تفعيل البيئة
.\venv\Scripts\Activate.ps1

# تثبيت الحزم
pip install -r requirements.txt

# تشغيل الخادم
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Backend API سيكون متاحاً على: http://localhost:8000

## 🎯 فتح المشروع في VS Code

### الطريقة السريعة:
1. افتح VS Code
2. اضغط `Ctrl+K Ctrl+O`
3. اختر مجلد: `c:\Users\ADMIN\Desktop\PFE`
4. اضغط `F5` للتشغيل المباشر

### من Command Palette:
1. اضغط `Ctrl+Shift+P`
2. اكتب: `Flutter: Select Device`
3. اختر `Chrome` أو `Windows (desktop)`
4. افتح الملف: `frontend/lib/main.dart`
5. اضغط `F5` أو اذهب إلى `Run → Start Debugging`

## 🌐 عرض Demo التفاعلي

إذا لم تستطع تشغيل Flutter مباشرة، يمكنك مشاهدة demo HTML:

```powershell
# افتح الملف في المتصفح
Start-Process "c:\Users\ADMIN\Desktop\PFE\DEMO.html"
```

أو افتحه يدوياً من Windows Explorer: `c:\Users\ADMIN\Desktop\PFE\DEMO.html`

## 📱 الشاشات المتاحة

### 1. ✨ Splash Screen
- **الملف**: `lib/features/splash/screens/splash_screen.dart`
- **المميزات**: شعار متحرك، خط مسح أمني، انتقال تلقائي

### 2. 🏠 Home Code Entry
- **الملف**: `lib/features/auth/screens/home_code_screen.dart`
- **الصيغة**: `DZ-XXXX-XXXX` (مثال: DZ-8F3A-91K2)

### 3. 🔐 Login + Register
- **الملفات**: `login_screen.dart`, `register_screen.dart`
- **المميزات**: بصمة، وجه، PIN

### 4. 📹 Cameras
- **الملف**: `lib/features/cameras/screens/cameras_screen.dart`
- **المميزات**: Grid view، بث مباشر، اختيار جودة

### 5. 🚪 Home Control
- **الملف**: `lib/features/control/screens/home_control_screen.dart`
- **المميزات**: أبواب، شبابيك، أقفال ذكية

### 6. 📡 Sensors
- **الملف**: `lib/features/sensors/screens/sensors_screen.dart`
- **المميزات**: مستشعرات، إنذارات، timeline

### 7. 🎫 Guest Access
- **الملف**: `lib/features/access/screens/guest_access_screen.dart`
- **المميزات**: رموز مؤقتة، عد تنازلي، سجل

## 🔧 إعدادات إضافية

### تفعيل Web Support
```powershell
flutter config --enable-web
```

### تفعيل Windows Desktop
```powershell
flutter config --enable-windows-desktop
```

### تثبيت Android Studio (للـ Android)
1. حمّل من: https://developer.android.com/studio
2. ثبّت Android SDK
3. أنشئ AVD (Android Virtual Device)
4. شغل: `flutter run -d emulator-5554`

## 🎨 ألوان التطبيق

```dart
Primary Black:     #000000
Charcoal:          #1A1A1A
Dark Grey:         #2A2A2A
Neon Blue:         #00D4FF
Neon Purple:       #7000FF
Secure Green:      #00FF84
Warning:           #FFA500
Error:             #FF4444
```

## 📝 ملاحظات هامة

### إذا واجهت مشاكل:

1. **Flutter command not found**:
   - تأكد من إضافة Flutter للـ PATH
   - أعد تشغيل Terminal/VS Code

2. **Android licenses**:
   ```powershell
   flutter doctor --android-licenses
   ```

3. **pub get fails**:
   ```powershell
   flutter clean
   flutter pub get
   ```

4. **Hot reload لا يعمل**:
   - اضغط `r` في Terminal
   - أو `R` لـ Hot Restart

## 🔄 الخطوات التالية المقترحة

- [ ] إضافة Bloc/Cubit للـ state management
- [ ] ربط Frontend مع Backend APIs
- [ ] تطبيق WebRTC للبث الحقيقي
- [ ] إضافة شاشة الإعدادات
- [ ] إضافة شاشة إدارة الأعضاء
- [ ] تطبيق Firebase Push Notifications
- [ ] إضافة Unit Tests
- [ ] إضافة Widget Tests

## 📞 الدعم

إذا واجهتك أي مشكلة:
1. راجع [Flutter Documentation](https://docs.flutter.dev)
2. تحقق من [Flutter issues on GitHub](https://github.com/flutter/flutter/issues)
3. تأكد من تثبيت جميع المتطلبات باستخدام `flutter doctor`

## 📄 الترخيص

هذا المشروع مطور كـ PFE (مشروع نهاية الدراسة).

---

**تم الإنشاء بواسطة**: GitHub Copilot  
**التاريخ**: 9 فبراير 2026  
**الإصدار**: 1.0.0
