import express from "express";
import cors from "cors";
import fs from "fs";
import path from "path";
import { SYSTEM_PROMPT } from "./rag/prompts.js";
import { isHarmful, containsSensitive } from "./rag/safety.js";
import { retrieveTopK } from "./rag/retrieve.js";

const app = express();
app.use(cors());
app.use(express.json({ limit: "2mb" }));

const OLLAMA_URL = "http://localhost:11434";
const CHAT_MODEL = "qwen2.5:3b"; // أذكى وأفضل للعربية
const EMBED_MODEL = "nomic-embed-text";

const sessions = new Map(); // RAM history

async function embed(text) {
  try {
    const res = await fetch(`${OLLAMA_URL}/api/embeddings`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model: EMBED_MODEL, prompt: text }),
      signal: AbortSignal.timeout(30000) // 30 ثانية timeout
    });
    if (!res.ok) throw new Error("Embedding failed");
    const data = await res.json();
    return data.embedding;
  } catch (e) {
    console.error("Embed error:", e.message);
    return null;
  }
}

async function ollamaChat(messages) {
  try {
    const res = await fetch(`${OLLAMA_URL}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: CHAT_MODEL,
        messages,
        stream: false,
        options: { temperature: 0.6, num_predict: 350 }
      }),
      signal: AbortSignal.timeout(300000) // 5 دقائق timeout
    });
    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Chat failed: ${err}`);
    }
    return await res.json();
  } catch (e) {
    console.error("Chat error:", e.message);
    throw e;
  }
}

function extractLead(text) {
  const phone = text.match(/(\+?\d[\d\s-]{7,})/);
  const email = text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
  return {
    phone: phone ? phone[1].trim() : null,
    email: email ? email[0].trim() : null
  };
}

function nowISO() {
  return new Date().toISOString();
}

// حفظ Leads محليًا في ملف JSONL
function saveLead(lead) {
  const line = JSON.stringify({ ...lead, ts: nowISO() }) + "\n";
  fs.appendFileSync(path.join(process.cwd(), "leads.jsonl"), line, "utf8");
}

// API: chat
app.post("/api/chat", async (req, res) => {
  try {
    const { sessionId = "default", message } = req.body || {};
    if (!message) return res.status(400).json({ error: "missing_message" });

    // Safety
    if (isHarmful(message)) {
      return res.json({
        reply: "⚠️ عذرًا، لا أستطيع المساعدة في الاختراق أو الإضرار بالآخرين. يمكنني مساعدتك في الحماية أو حل المشكلة بشكل آمن."
      });
    }
    if (containsSensitive(message)) {
      return res.json({
        reply: "🔒 لا تشارك كلمات مرور/OTP/توكن/كود المنزل هنا. صف المشكلة بدون بيانات حساسة وسأساعدك."
      });
    }

    // Leads
    const lead = extractLead(message);
    if (lead.phone || lead.email) {
      saveLead({ sessionId, ...lead, message });
    }

    // RAG
    const qEmb = await embed(message);
    const top = await retrieveTopK(qEmb, 3);

    const context = top
      .map((c, i) => `[#${i+1} | ${c.source} | chunk ${c.chunk_index}] (score=${c.score.toFixed(3)})\n${c.content}`)
      .join("\n\n---\n\n");

    const history = sessions.get(sessionId) || [];
    const messages = [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "system", content: `مقتطفات قاعدة المعرفة (RAG):\n\n${context}` },
      ...history.slice(-6),
      { role: "user", content: message }
    ];

    const out = await ollamaChat(messages);
    const reply = out?.message?.content || "…";

    history.push({ role: "user", content: message });
    history.push({ role: "assistant", content: reply });
    sessions.set(sessionId, history);

    res.json({ reply });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

// API: rebuild RAG index
app.post("/api/rebuild", async (req, res) => {
  const { key } = req.body || {};
  if (key !== "LOCAL_ADMIN_KEY") return res.status(403).json({ error: "forbidden" });
  res.json({ ok: true, message: "Run: npm run ingest (server/)" });
});

app.listen(3005, () => {
  console.log("✅ HomiX AI Server running: http://localhost:3005");
});
