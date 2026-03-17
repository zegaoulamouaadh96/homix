export function chunkText(text, chunkSize = 900, overlap = 120) {
  const clean = (text || "").replace(/\r/g, "").trim();
  if (!clean) return [];
  const chunks = [];
  let i = 0;
  while (i < clean.length) {
    const end = Math.min(i + chunkSize, clean.length);
    const chunk = clean.slice(i, end);
    chunks.push(chunk);
    i = end - overlap;
    if (i < 0) i = 0;
    if (end === clean.length) break;
  }
  return chunks.map(c => c.trim()).filter(Boolean);
}
