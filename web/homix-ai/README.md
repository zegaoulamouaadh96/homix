# HomiX AI - نظام شات ذكاء اصطناعي محلي مع RAG

## 📋 المتطلبات
- **Node.js** ✅ (مثبت)
- **Ollama** ❌ (يجب تثبيته)

## 🚀 خطوات التشغيل

### 1) تثبيت Ollama (مرة واحدة)
حمّل من: https://ollama.com/download

بعد التثبيت، افتح Terminal جديد واسحب النماذج:
```bash
ollama pull qwen2.5:3b
ollama pull nomic-embed-text
```

اختبار سريع:
```bash
ollama run qwen2.5:3b
```
اكتب أي سؤال للتأكد، ثم اضغط Ctrl+D للخروج.

### 2) بناء قاعدة المعرفة (RAG)
```bash
cd homix-ai/server
npm run ingest
```
سيقرأ ملفات `knowledge/` ويبني الـ embeddings في `rag/rag.sqlite`.

### 3) تشغيل السيرفر
```bash
cd homix-ai/server
npm run dev
```
السيرفر سيعمل على: http://localhost:3005

### 4) تشغيل الواجهة
```bash
cd homix-ai/web
npx http-server -p 8080
```
افتح: http://localhost:8080

## 📁 هيكلة المشروع
```
homix-ai/
  server/
    package.json          # تبعيات Node.js
    server.js             # السيرفر الرئيسي (Express + Chat API)
    leads.jsonl           # بيانات العملاء (يتم إنشاؤه تلقائيًا)
    rag/
      db.js               # إدارة قاعدة البيانات SQLite
      ingest.js           # بناء قاعدة المعرفة
      retrieve.js         # استرجاع المقاطع ذات الصلة (Cosine Similarity)
      chunker.js          # تقسيم النصوص لمقاطع
      prompts.js          # System Prompt للمساعد
      safety.js           # فلاتر الأمان
    knowledge/            # ← ملفات "التدريب"
      features.md
      installation.md
      faq.md
      sales.md
  web/
    index.html
    styles.css
    chat-widget.js
```

## ✏️ إضافة معرفة جديدة ("تدريب")
1. أنشئ ملف `.md` جديد في `server/knowledge/`
2. أعد بناء القاعدة:
```bash
cd homix-ai/server
npm run ingest
```
3. أعد تشغيل السيرفر.

## 🔧 أمثلة ملفات معرفة إضافية
- `troubleshooting.md` — حل مشاكل MQTT/ESP32/الكاميرات
- `security_policy.md` — سياسة الأمان ورفض الاختراق
- `demo.md` — سيناريو عرض Demo
- `pricing.md` — الباقات والأسعار
