import { openDb } from "./db.js";

function cosine(a, b) {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (Math.sqrt(na) * Math.sqrt(nb) + 1e-9);
}

export async function retrieveTopK(queryEmbedding, k = 5) {
  const db = await openDb();

  const result = db.exec(
    `SELECT docs.id as doc_id, docs.source, docs.chunk_index, docs.content, embeddings.vector
    FROM docs
    JOIN embeddings ON docs.id = embeddings.doc_id`
  );

  db.close();

  if (!result.length || !result[0].values.length) return [];

  const columns = result[0].columns;
  const rows = result[0].values.map(row => {
    const obj = {};
    columns.forEach((col, i) => obj[col] = row[i]);
    return obj;
  });

  const scored = rows.map(r => {
    const vec = JSON.parse(r.vector);
    return {
      source: r.source,
      chunk_index: r.chunk_index,
      content: r.content,
      score: cosine(queryEmbedding, vec)
    };
  }).sort((x, y) => y.score - x.score);

  return scored.slice(0, k);
}
