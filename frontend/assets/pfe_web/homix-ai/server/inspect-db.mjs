import { openDb } from "./rag/db.js";

const db = await openDb();

const tablesResult = db.exec("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;");
const tableNames = tablesResult[0]?.values?.map((v) => v[0]) || [];

console.log("Tables:", tableNames.length ? tableNames.join(", ") : "(none)");

for (const name of tableNames) {
  const countRes = db.exec(`SELECT COUNT(*) FROM ${name}`);
  const count = countRes[0]?.values?.[0]?.[0] ?? 0;
  console.log(`${name}: ${count} rows`);
}
