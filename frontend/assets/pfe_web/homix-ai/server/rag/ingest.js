import fs from "fs";
import path from "path";
import { openDb, resetDb, saveDb } from "./db.js";
import { chunkText } from "./chunker.js";

const OLLAMA_URL = "http://localhost:11434";
const EMBED_MODEL = "nomic-embed-text";

async function embed(text) {
  const res = await fetch(`${OLLAMA_URL}/api/embeddings`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model: EMBED_MODEL, prompt: text })
  });
  if (!res.ok) throw new Error("Embedding failed");
  const data = await res.json();
  return data.embedding;
}

function vecToString(v) {
  return JSON.stringify(v);
}

async function main() {
  const knowledgeDir = path.join(process.cwd(), "knowledge");
  const files = fs.readdirSync(knowledgeDir).filter(f => f.endsWith(".md"));

  const db = await openDb();
  await resetDb(db);

  for (const file of files) {
    const full = path.join(knowledgeDir, file);
    const text = fs.readFileSync(full, "utf8");
    const chunks = chunkText(text);

    for (let idx = 0; idx < chunks.length; idx++) {
      const content = chunks[idx];

      db.run(
        "INSERT INTO docs(source, chunk_index, content) VALUES(?,?,?)",
        [file, idx, content]
      );

      // Get the last inserted ID
      const result = db.exec("SELECT last_insert_rowid() as id");
      const docId = result[0].values[0][0];

      const v = await embed(content);

      db.run(
        "INSERT INTO embeddings(doc_id, vector) VALUES(?,?)",
        [docId, vecToString(v)]
      );

      console.log(`Indexed: ${file} [${idx+1}/${chunks.length}]`);
    }
  }

  saveDb(db);
  db.close();
  console.log("✅ RAG index built successfully.");
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
