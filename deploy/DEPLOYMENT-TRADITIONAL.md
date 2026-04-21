# 🚀 النشر التقليدي بدون Docker

## لماذا Docker vs الطريقة التقليدية؟

### Docker (الطريقة الحديثة)
**المميزات:**
- ✅ بيئة معزولة ومتطابقة على جميع الأجهزة
- ✅ سهولة النشر والترقية
- ✅ إدارة تلقائية للتبعيات
- ✅ إعادة التشغيل التلقائي عند الفشل
- ✅ سهولة النسخ الاحتياطي

**العيوب:**
- ❌ يتطلب تعلم Docker
- ❌ استهلاك موارد إضافية

### الطريقة التقليدية (npm start)
**المميزات:**
- ✅ بسيطة وسهلة الفهم
- ✅ استهلاك موارد أقل
- ✅ تحكم مباشر بالعمليات

**العيوب:**
- ❌ قد تختلف البيئة بين الأجهزة
- ❌ إدارة يدوية للتبعيات
- ❌ صعوبة النسخ الاحتياطي
- ❌ لا إعادة تشغيل تلقائي

---

## خطوات النشر التقليدي على CentOS/RHEL

### 1. تثبيت Node.js و npm

```bash
# تثبيت Node.js 20
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# التحقق
node --version
npm --version
```

### 2. تثبيت PostgreSQL

```bash
yum install -y postgresql postgresql-server postgresql-contrib

# تهيئة قاعدة البيانات
postgresql-setup initdb
systemctl start postgresql
systemctl enable postgresql

# إنشاء مستخدم وقاعدة البيانات
sudo -u postgres psql
```

في PostgreSQL:
```sql
CREATE DATABASE homix;
CREATE USER homix WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE homix TO homix;
\q
```

### 3. تثبيت Mosquitto (MQTT Broker)

```bash
yum install -y mosquitto mosquitto-clients

# إعداد Mosquitto
nano /etc/mosquitto/mosquitto.conf
```

أضف:
```
listener 1883
allow_anonymous true
persistence true
persistence_location /var/lib/mosquitto/
log_dest file /var/log/mosquitto/mosquitto.log
```

تشغيل:
```bash
systemctl start mosquitto
systemctl enable mosquitto
```

### 4. إعداد Backend

```bash
cd /opt/homix/backend/server

# تثبيت التبعيات
npm install

# إنشاء ملف البيئة
cp .env.example .env
nano .env
```

تحديث `.env`:
```env
NODE_ENV=production
PORT=3000
DATABASE_URL=postgres://homix:your_password@localhost:5432/homix
MQTT_URL=mqtt://localhost:1883
MQTT_ENABLE_WS=true
MQTT_ENABLE_TCP=true
MQTT_PORT=1883
JWT_SECRET=your_strong_secret_here
ADMIN_JWT_SECRET=your_strong_admin_secret_here
FACE_REQUIRE_HTTPS=true
FACE_DEVICE_TOKEN=prod-face-device-token-2024
```

### 5. تهيئة قاعدة البيانات

```bash
cd /opt/homix/backend/server
npm run init-db
```

### 6. تشغيل Backend بـ PM2

```bash
# تثبيت PM2 لإدارة العمليات
npm install -g pm2

# تشغيل Backend
pm2 start index.js --name homix-backend

# حفظ القائمة
pm2 save

# إعداد التشغيل التلقائي عند الإقلاع
pm2 startup
# نفذ الأمر الذي يظهره لك
```

### 7. إعداد Python AI Service (اختياري)

```bash
# تثبيت Python 3
yum install -y python3 python3-pip

cd /opt/homix/backend/ai

# إنشاء بيئة افتراضية
python3 -m venv venv
source venv/bin/activate

# تثبيت التبعيات
pip install -r requirements.txt

# تشغيل بـ PM2
pm2 start "python3 app.py" --name homix-ai
pm2 save
```

### 8. إعداد Nginx Reverse Proxy

```bash
yum install -y nginx

# نسخ إعدادات Nginx
cp /opt/homix/deploy/nginx/homix.conf /etc/nginx/conf.d/homix.conf

# تعديل proxy_pass لي指向 localhost:3000 بدلاً من docker
nano /etc/nginx/conf.d/homix.conf
```

تأكد من:
```
proxy_pass http://127.0.0.1:3000;
```

تشغيل Nginx:
```bash
nginx -t
systemctl start nginx
systemctl enable nginx
```

### 9. إعداد SSL Certificate

```bash
# تثبيت Certbot
yum install -y certbot python3-certbot-nginx

# الحصول على الشهادة
certbot --nginx -d homix.systems -d www.homix.systems

# نسخ الشهادات لـ Mosquitto
mkdir -p /etc/mosquitto/certs
cp /etc/letsencrypt/live/homix.systems/fullchain.pem /etc/mosquitto/certs/homix.systems.crt
cp /etc/letsencrypt/live/homix.systems/privkey.pem /etc/mosquitto/certs/homix.systems.key
chown -R mosquitto:mosquitto /etc/mosquitto/certs
```

### 10. إعداد Firewall

```bash
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=1883/tcp
firewall-cmd --permanent --add-port=8883/tcp
firewall-cmd --permanent --add-port=9001/tcp
firewall-cmd --reload
```

### 11. إعداد Auto-restart بـ PM2

```bash
# إنشاء ملف ecosystem.config.js
cat > /opt/homix/backend/server/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'homix-backend',
    script: './index.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
}
EOF

# إعادة التشغيل
pm2 restart ecosystem.config.js
pm2 save
```

### 12. إعداد SSL Auto-renewal

```bash
echo "0 0,12 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'" | crontab -
```

---

## إدارة العمليات

### عرض حالة الخدمات

```bash
# Backend
pm2 status

# PostgreSQL
systemctl status postgresql

# Mosquitto
systemctl status mosquitto

# Nginx
systemctl status nginx
```

### إعادة التشغيل

```bash
# Backend
pm2 restart homix-backend

# PostgreSQL
systemctl restart postgresql

# Mosquitto
systemctl restart mosquitto

# Nginx
systemctl reload nginx
```

### عرض Logs

```bash
# Backend
pm2 logs homix-backend

# PostgreSQL
tail -f /var/lib/pgsql/data/log/postgresql-*.log

# Mosquitto
tail -f /var/log/mosquitto/mosquitto.log

# Nginx
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

---

## التحقق من العمل

```bash
# اختبار API
curl http://localhost:3000/api/health

# اختبار HTTPS
curl https://homix.systems

# اختبار MQTT
mosquitto_sub -h localhost -t test
```

---

## مقارنة الأداء

| الميزة | Docker | التقليدي |
|--------|--------|----------|
| استهلاك RAM | ~500MB إضافية | أقل |
| سهولة الإعداد | متوسطة | أسهل |
| إدارة التبعيات | تلقائية | يدوية |
| إعادة التشغيل | تلقائية | يدوية (PM2) |
| النسخ الاحتياطي | سهل (volumes) | متوسط |
| قابلية التوسع | سهل | أصعب |

---

## التوصية

- **للتطوير والاختبار**: استخدم الطريقة التقليدية (npm start)
- **للإنتاج**: استخدم Docker لسهولة الإدارة والصيانة
- **لـ VPS محدود الموارد**: استخدم الطريقة التقليدية

يمكنك استخدام الطريقة التقليدية الآن إذا أردت، أو يمكنني مساعدتك في إعدادها.
