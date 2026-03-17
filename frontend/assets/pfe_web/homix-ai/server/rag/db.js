import initSqlJs from "sql.js";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DB_PATH = path.join(__dirname, "rag.sqlite");

let SQL = null;

async function getSqlJs() {
  if (!SQL) {
    SQL = await initSqlJs();
  }
  return SQL;
}

export async function openDb() {
  const SqlJs = await getSqlJs();
  let db;
  if (fs.existsSync(DB_PATH)) {
    const buffer = fs.readFileSync(DB_PATH);
    db = new SqlJs.Database(buffer);
  } else {
    db = new SqlJs.Database();
  }
  db.run(
    `CREATE TABLE IF NOT EXISTS docs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source TEXT,
      chunk_index INTEGER,
      content TEXT
    )`
  );
  db.run(
    `CREATE TABLE IF NOT EXISTS embeddings (
      doc_id INTEGER,
      vector TEXT,
      FOREIGN KEY(doc_id) REFERENCES docs(id)
    )`
  );
  return db;
}

export function saveDb(db) {
  const data = db.export();
  const buffer = Buffer.from(data);
  fs.writeFileSync(DB_PATH, buffer);
}

export async function resetDb(db) {
  db.run("DELETE FROM embeddings");
  db.run("DELETE FROM docs");
}
