// ===== HomiX AI Chat — Connected to Ollama RAG Server =====
const HOMIX_API = "http://localhost:3005/api/chat";
const SESSION_ID = "web_" + Math.random().toString(36).slice(2, 10);
let isSending = false;

// === Toggle Chat Widget ===
function toggleChat() {
  const widget = document.getElementById("chatWidget");
  const btn = document.getElementById("chatBtn");
  if (!widget) return;
  widget.classList.toggle("active");
  if (btn) btn.classList.toggle("open");
}

// === Display Message ===
function displayMessage(text, sender = "user") {
  const container = document.getElementById("chatMessages");
  if (!container) return;
  const div = document.createElement("div");
  div.className = `chat-message ${sender}`;
  // Convert markdown-like **bold** and line breaks
  let html = text
    .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
    .replace(/\n/g, "<br>");
  div.innerHTML = html;
  container.appendChild(div);
  container.scrollTop = container.scrollHeight;
  playSound(sender);
}

// === Typing Indicator ===
function showTyping() {
  const container = document.getElementById("chatMessages");
  if (!container) return null;
  const div = document.createElement("div");
  div.className = "chat-message bot typing";
  div.id = "typingIndicator";
  div.innerHTML = '<span class="dot"></span><span class="dot"></span><span class="dot"></span>';
  container.appendChild(div);
  container.scrollTop = container.scrollHeight;
  return div;
}

function removeTyping() {
  const el = document.getElementById("typingIndicator");
  if (el) el.remove();
}

// === Sound Effect ===
function playSound(type) {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.frequency.value = type === "user" ? 800 : 600;
    gain.gain.setValueAtTime(0.08, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.12);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.12);
  } catch (e) {}
}

// === Send Message to Ollama API ===
async function sendMessage() {
  const input = document.getElementById("chatInput");
  const sendBtn = document.getElementById("chatSendBtn");
  const message = input ? input.value.trim() : "";
  if (!message || isSending) return;

  isSending = true;
  if (sendBtn) sendBtn.disabled = true;
  displayMessage(message, "user");
  if (input) input.value = "";

  // Hide quick actions after first user message
  const qa = document.getElementById("chatQuickActions");
  if (qa) qa.style.display = "none";

  const typing = showTyping();

  try {
    const res = await fetch(HOMIX_API, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sessionId: SESSION_ID, message }),
      signal: AbortSignal.timeout(180000) // 3 min timeout
    });

    removeTyping();

    if (!res.ok) throw new Error("Server error");
    const data = await res.json();
    const reply = data.reply || "عذراً، حدث خطأ. حاول مرة أخرى.";
    displayMessage(reply, "bot");

  } catch (err) {
    removeTyping();
    console.error("Chat error:", err);

    // Fallback: local quick response
    const fallback = getLocalFallback(message);
    displayMessage(fallback, "bot");
  }

  isSending = false;
  if (sendBtn) sendBtn.disabled = false;
  if (input) input.focus();
}

// === Quick Message (from buttons) ===
function sendQuickMessage(msg) {
  const input = document.getElementById("chatInput");
  if (input) input.value = msg;
  sendMessage();
}

// === Local Fallback (when server is offline) ===
function getLocalFallback(msg) {
  const m = msg.toLowerCase();

  // Arabic
  if (/[\u0600-\u06FF]/.test(msg)) {
    if (/مزاي|ميز|خصائص|وظائف/.test(m))
      return "🏠 HomiX يوفر: تحكم ذكي بالأبواب والنوافذ، 4 كاميرات AI، حساسات (دخان/فيضان/زلازل/حركة/كسر زجاج)، أكواد OTP للضيوف، نظام احتواء، ووضع طوارئ. كل شيء بالذكاء الاصطناعي! 🚀";
    if (/تركيب|تثبيت|install/.test(m))
      return "🔧 التركيب: 1) تركيب الحساسات والأقفال والكاميرات 2) توصيل ESP32 بـ Wi-Fi 3) تشغيل MQTT والسيرفر 4) تثبيت التطبيق 5) تفعيل البيومترية 6) اختبار كل شيء. هل تريد تفاصيل أكثر؟";
    if (/demo|ديمو|عرض/.test(m))
      return "🎬 لطلب Demo: أرسل لنا اسمك + مدينتك + واتساب أو بريد + نوع المنزل + عدد الأبواب والكاميرات المطلوبة.";
    if (/باق|سعر|ثمن|pack|prix/.test(m))
      return "📦 الباقات:\n🥉 أساسية: 2 أبواب + 2 كاميرات + حساسات أساسية\n🥈 متقدمة: 3 أبواب + 4 كاميرات + كل الحساسات + احتواء\n🥇 VIP: مخصصة حسب طلبك\nتواصل معنا للأسعار!";
    if (/دعم|مشكل|مساعد|خطأ|error/.test(m))
      return "🛠️ صف المشكلة بالتفصيل: أين تظهر؟ (تطبيق/كاميرا/حساس/باب) وما رسالة الخطأ؟ سأساعدك خطوة بخطوة.";
    if (/مرحب|سلام|أهلا|هلا/.test(m))
      return "مرحبًا! 👋 أنا HomiX AI. كيف يمكنني مساعدتك اليوم؟";
    return "⚡ السيرفر الذكي غير متصل حالياً. جرب لاحقاً أو اسأل عن: المزايا، التركيب، Demo، الباقات، أو الدعم الفني.";
  }

  // French
  if (/bonjour|salut|prix|installation|caméra|capteur|porte|démo/i.test(m)) {
    if (/fonctionnalit|caractéristiq/i.test(m))
      return "🏠 HomiX offre: portes/fenêtres intelligentes, 4 caméras IA, capteurs, codes OTP invités, mode confinement, et urgence. Le tout piloté par IA!";
    if (/demo|démo/i.test(m))
      return "🎬 Pour une démo: nom + ville + WhatsApp/email + type logement + portes/caméras souhaités.";
    return "Bonjour! 👋 Je suis HomiX AI. Comment puis-je vous aider?";
  }

  // English fallback
  if (/feature|benefit/i.test(m))
    return "🏠 HomiX: smart doors/windows, 4 AI cameras, sensors (smoke/flood/earthquake/motion/glass break), guest OTP codes, containment mode, emergency mode. All AI-powered!";
  if (/demo/i.test(m))
    return "🎬 For a demo: send your name + city + WhatsApp/email + home type + doors/cameras needed.";
  if (/hello|hi |hey/i.test(m))
    return "Hello! 👋 I'm HomiX AI. How can I help you today?";

  return "⚡ AI server is currently offline. Try again later or ask about: features, installation, demo, packages, or support.";
}

// === Clear Chat History ===
function clearChatHistory() {
  const container = document.getElementById("chatMessages");
  if (container) {
    container.innerHTML = "";
    displayMessage("مرحبًا! 👋 أنا <strong>HomiX AI</strong> — مساعدك الذكي.\nيمكنني مساعدتك في كل ما يخص نظام أمن المنزل الذكي.\n\n💡 جرب أحد الأزرار أو اكتب سؤالك!", "bot");
  }
  const qa = document.getElementById("chatQuickActions");
  if (qa) qa.style.display = "flex";
}


