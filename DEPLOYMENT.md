# 🚀 خطوات نشر Homix على VPS

## 📋 المتطلبات الأساسية

- VPS مع Ubuntu 20.04+ أو Debian 11+ (2GB RAM على الأقل)
- Domain name: `homix.systems`
- حساب GitHub
- Git مثبت على جهازك

---

## 📤 الخطوة 1: رفع المشروع على GitHub

### 1.1 إنشاء Repository جديد على GitHub

1. اذهب إلى https://github.com/new
2. اسم المشروع: `homix` أو `smart-home-security`
3. اجعله Private أو Public حسب رغبتك
4. لا تضيف README أو .gitignore
5. انقر "Create repository"

### 1.2 إعداد Git محلياً

```bash
# الانتقال لمجلد المشروع
cd d:\PFE

# تهيئة Git (إذا لم يكن مهيئاً)
git init

# إضافة ملفات
git add .

# Commit أولي
git commit -m "Initial commit - Homix Smart Home Security"

# إضافة remote
git remote add origin https://github.com/YOUR_USERNAME/homix.git

# رفع المشروع
git push -u origin main
```

### 1.3 إعداد .gitignore

تم تحديث `.gitignore` لاستبعاد الملفات غير المرغوبة:
- `node_modules/`
- `.env`
- `build/`
- `.dart_tool/`
- ملفات Logs
- ملفات IDE

---

## 🔒 الخطوة 2: إعداد VPS

### 2.1 الاتصال بـ VPS

```bash
ssh root@5.135.79.223
```

### 2.2 تحديث النظام

```bash
apt update && apt upgrade -y
```

### 2.3 تثبيت Docker و Docker Compose

```bash
# تثبيت Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# تثبيت Docker Compose
apt install docker-compose -y

# تفعيل Docker
systemctl enable docker
systemctl start docker

# إضافة المستخدم لمجموعة docker
usermod -aG docker $USER
```

### 2.4 تثبيت Git و Nginx

```bash
apt install -y git nginx certbot python3-certbot-nginx
```

---

## 📥 الخطوة 3: سحب المشروع على VPS

### 3.1 إنشاء مجلد المشروع

```bash
mkdir -p /opt/homix
cd /opt/homix
```

### 3.2 سحب المشروع من GitHub

```bash
# استخدم HTTPS (أو SSH إذا قمت بإعداد SSH keys)
git clone https://github.com/YOUR_USERNAME/homix.git .
```

---

## 🔐 الخطوة 4: إعداد SSL Certificate

### 4.1 تشغيل سكريبت SSL

```bash
cd /opt/homix
chmod +x deploy/scripts/setup-ssl.sh
sudo ./deploy/scripts/setup-ssl.sh
```

هذا السكريبت سيقوم بـ:
- تثبيت Certbot
- الحصول على شهادة SSL مجانية من Let's Encrypt
- إعداد Nginx
- نسخ الشهادات لـ MQTT over SSL

### 4.2 التحقق من SSL

```bash
# اختبار HTTPS
curl https://homix.systems

# فحص الشهادة
openssl x509 -enddate -noout -in /etc/letsencrypt/live/homix.systems/cert.pem
```

---

## ⚙️ الخطوة 5: إعداد متغيرات البيئة

### 5.1 إنشاء ملف .env

```bash
cd /opt/homix/deploy
cp .env.example .env
nano .env
```

### 5.2 تحديث القيم

```env
# Database
DB_PASSWORD=your_secure_password_here_2024

# JWT Secrets (استخدم كلمات قوية عشوائية)
JWT_SECRET=generate_strong_secret_32_chars_here
ADMIN_JWT_SECRET=generate_strong_admin_secret_32_chars_here

# Face Recognition
FACE_DEVICE_TOKEN=prod-face-device-token-2024
FACE_REQUIRE_HTTPS=true

# Email (اختياري - لإرسال كود المنزل)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_app_password
```

---

## 🐳 الخطوة 6: تشغيل الخدمات بـ Docker

### 6.1 تشغيل Docker Compose

```bash
cd /opt/homix/deploy/docker
docker-compose -f docker-compose.prod.yml up -d
```

### 6.2 التحقق من الخدمات

```bash
# عرض الحالة
docker-compose -f docker-compose.prod.yml ps

# عرض Logs
docker-compose -f docker-compose.prod.yml logs -f
```

---

## ✅ الخطوة 7: اختبار الاتصالات

### 7.1 تشغيل سكريبت الاختبار

```bash
cd /opt/homix
chmod +x deploy/scripts/test-connections.sh
./deploy/scripts/test-connections.sh
```

### 7.2 اختبار يدوي

```bash
# اختبار API
curl https://homix.systems/api/health

# اختبار MQTT
mosquitto_sub -h homix.systems -t home/DZ-BEBJ-Z6U7/#

# اختبار WebSocket
wscat -c wss://homix.systems/mqtt
```

---

## 🔥 الخطوة 8: إعداد Firewall

```bash
# تفعيل UFW
ufw enable

# السماح بالمنافذ
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 1883/tcp  # MQTT TCP
ufw allow 8883/tcp  # MQTT over SSL
ufw allow 9001/tcp  # MQTT over WebSocket

# عرض الحالة
ufw status
```

---

## 🔄 الخطوة 9: إعداد Auto-restart

### 9.1 إنشاء Systemd Service للـ Backend

```bash
nano /etc/systemd/system/homix-backend.service
```

أضف التالي:

```ini
[Unit]
Description=Homix Backend API
After=network.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/homix/deploy/docker
ExecStart=/usr/bin/docker-compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.prod.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

تفعيل الخدمة:

```bash
systemctl enable homix-backend
systemctl start homix-backend
```

### 9.2 إعداد SSL Auto-renewal

تم إعداد cron job تلقائياً بواسطة سكريبت setup-ssl.sh.

للتحقق:

```bash
crontab -l
```

---

## 📱 الخطوة 10: تحديث ESP32

### 10.1 تشغيل سكريبت التحديث

```bash
cd /opt/homix
chmod +x deploy/scripts/update-esp32-config.sh
./deploy/scripts/update-esp32-config.sh
```

### 10.2 رفع الكود إلى ESP32

استخدم Arduino IDE أو PlatformIO لرفع الكود المحدث على ESP32.

---

## 🎯 التحقق النهائي

### 10.1 اختبار شامل

```bash
# 1. Domain Name
ping homix.systems

# 2. HTTPS
curl -I https://homix.systems

# 3. API
curl https://homix.systems/api/health

# 4. MQTT
mosquitto_pub -h homix.systems -t test -m "hello"

# 5. WebSocket
wscat -c wss://homix.systems/mqtt
```

### 10.2 فحص Logs

```bash
# Nginx
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Docker
docker-compose -f docker-compose.prod.yml logs -f backend
docker-compose -f docker-compose.prod.yml logs -f mqtt
```

---

## 🔄 التحديثات المستقبلية

### تحديث المشروع من GitHub

```bash
# على VPS
cd /opt/homix
git pull origin main

# إعادة بناء Docker
cd deploy/docker
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d
```

### تحديث SSL Certificate

```bash
# تجديد يدوي
certbot renew
systemctl reload nginx

# أو انتظر التجديد التلقائي (يتم كل 90 يوم)
```

---

## 🆘 استكشاف الأخطاء

### المشكلة: SSL Certificate فشل

```bash
# تحقق من DNS
nslookup homix.systems

# يجب أن يشير Domain إلى IP الخاص بـ VPS
```

### المشكلة: Backend لا يعمل

```bash
# عرض Logs
docker-compose -f docker-compose.prod.yml logs backend

# إعادة التشغيل
docker-compose -f docker-compose.prod.yml restart backend
```

### المشكلة: MQTT لا يعمل

```bash
# عرض Logs
docker-compose -f docker-compose.prod.yml logs mqtt

# إعادة التشغيل
docker-compose -f docker-compose.prod.yml restart mqtt
```

### المشكلة: Ports مغلقة

```bash
# تحقق من Firewall
ufw status

# فتح المنافذ
ufw allow 1883/tcp
ufw allow 8883/tcp
```

---

## 📊 المراقبة

### عرض استهلاك الموارد

```bash
# Docker
docker stats

# System
htop
```

### عرض الـ Logs

```bash
# جميع الخدمات
docker-compose -f docker-compose.prod.yml logs -f

# خدمة محددة
docker-compose -f docker-compose.prod.yml logs -f backend
```

---

## ✅ قائمة التحقق النهائية

- [ ] Domain name homix.systems يشير إلى VPS IP
- [ ] SSL Certificate مثبت وصالح
- [ ] Nginx يعمل ويعيد التوجيه
- [ ] Backend API يعمل على port 3000
- [ ] MQTT Broker يعمل على port 1883
- [ ] MQTT over SSL يعمل على port 8883
- [ ] PostgreSQL يعمل
- [ ] Redis يعمل
- [ ] AI Service يعمل
- [ ] Firewall مُعد بشكل صحيح
- [ ] ESP32 مُحدث لاستخدام homix.systems
- [ ] اختبار الاتصالات ناجح

---

## 🎉 تهانينا!

تم نشر Homix بنجاح على VPS مع SSL آمن!

- **API**: https://homix.systems/api
- **Dashboard**: https://homix.systems
- **MQTT**: homix.systems:1883 (TCP) / :8883 (SSL)
- **WebSocket**: wss://homix.systems/mqtt
