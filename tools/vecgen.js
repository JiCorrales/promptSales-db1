// Simple utility to generate a pgvector literal from text using the same algorithm as server.js
function hashString(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function textToEmbedding(text, dim = 128) {
  const vec = new Array(dim).fill(0);
  const tokens = String(text).toLowerCase().split(/\W+/).filter(Boolean);
  for (const t of tokens) {
    const h = hashString(t) % dim;
    vec[h] += 1;
  }
  const norm = Math.sqrt(vec.reduce((s, v) => s + v * v, 0)) || 1;
  return vec.map((v) => v / norm);
}

const input = process.argv.slice(2).join(' ');
const vec = textToEmbedding(input, Number(process.env.PGVECTOR_DIM) || 128);
const literal = '[' + vec.join(',') + ']';
console.log(literal);
