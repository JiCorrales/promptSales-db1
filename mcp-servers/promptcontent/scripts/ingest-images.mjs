import { Pool } from 'pg';

function parseIntEnv(name, fallback) {
  const raw = process.env[name];
  const n = Number.parseInt(raw ?? `${fallback}`, 10);
  return Number.isFinite(n) ? n : fallback;
}

const CONFIG = {
  pgDsn: process.env.PGVECTOR_DSN,
  pgTable: process.env.PGVECTOR_TABLE ?? 'content_embeddings',
  pgDim: parseIntEnv('PGVECTOR_DIM', 128)
};

if (!CONFIG.pgDsn) {
  console.error('PGVECTOR_DSN no configurado. Exporta PGVECTOR_DSN en tu entorno.');
  process.exit(1);
}

function hashString(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function textToEmbedding(text, dim = CONFIG.pgDim) {
  const vec = new Array(dim).fill(0);
  const tokens = text.toLowerCase().split(/\W+/).filter(Boolean);
  for (const t of tokens) {
    const h = hashString(t) % dim;
    vec[h] += 1;
  }
  const norm = Math.sqrt(vec.reduce((s, v) => s + v * v, 0)) || 1;
  return vec.map((v) => v / norm);
}

function generateDescription(idx) {
  const themes = [
    'atardecer en la playa con tonos cálidos',
    'ciudad nocturna con neón y lluvia',
    'montaña nevada con cielo despejado',
    'café artesanal con textura y vapor',
    'deporte urbano con energía y movimiento',
    'naturaleza minimalista con luz suave'
  ];
  const t = themes[idx % themes.length];
  return `Escena ${idx + 1}: ${t}. Inspirada en campañas aspiracionales y lifestyle.`;
}

function toHashtagToken(word) {
  return word
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '')
    .slice(0, 18);
}

function generateHashtags(description) {
  const tokens = description.split(/\s+/);
  const base = ['marketing', 'campana', 'contenido'];
  const tags = Array.from(new Set(tokens.map(toHashtagToken).filter(Boolean).concat(base)));
  return tags.slice(0, 8);
}

function buildImageMeta(idx) {
  const id = `img-${idx + 1}`;
  const width = 800 + (idx % 5) * 40;
  const height = 600 + (idx % 5) * 30;
  const url = `https://picsum.photos/id/${(idx % 100) + 1}/${width}/${height}`;
  const title = `Imagen ${idx + 1}`;
  const description = generateDescription(idx);
  const hashtags = generateHashtags(description);
  const format = 'jpeg';
  const sizeBytes = width * height * 3; // aproximación
  return { id, url, title, description, hashtags, format, sizeBytes, width, height };
}

async function ensureSchema(pool) {
  await pool.query('CREATE EXTENSION IF NOT EXISTS vector');
  await pool.query(
    `CREATE TABLE IF NOT EXISTS ${CONFIG.pgTable} (
      id TEXT PRIMARY KEY,
      description TEXT NOT NULL,
      embedding VECTOR(${CONFIG.pgDim})
    )`
  );
  await pool.query(
    `CREATE TABLE IF NOT EXISTS images_meta (
      id TEXT PRIMARY KEY,
      url TEXT NOT NULL,
      title TEXT,
      hashtags TEXT[],
      format TEXT,
      size_bytes INTEGER,
      width INTEGER,
      height INTEGER
    )`
  );
}

async function upsertEmbedding(pool, id, description) {
  const vec = textToEmbedding(description);
  const placeholders = vec.join(',');
  await pool.query(
    `INSERT INTO ${CONFIG.pgTable} (id, description, embedding)
     VALUES ($1, $2, ('['||$3||']')::vector)
     ON CONFLICT (id) DO UPDATE SET description = EXCLUDED.description, embedding = EXCLUDED.embedding`,
    [id, description, placeholders]
  );
}

async function upsertImageMeta(pool, meta) {
  await pool.query(
    `INSERT INTO images_meta (id, url, title, hashtags, format, size_bytes, width, height)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (id) DO UPDATE SET url = EXCLUDED.url, title = EXCLUDED.title, hashtags = EXCLUDED.hashtags, format = EXCLUDED.format, size_bytes = EXCLUDED.size_bytes, width = EXCLUDED.width, height = EXCLUDED.height`,
    [meta.id, meta.url, meta.title, meta.hashtags, meta.format, meta.sizeBytes, meta.width, meta.height]
  );
}

async function main() {
  const pool = new Pool({ connectionString: CONFIG.pgDsn });
  try {
    await ensureSchema(pool);
    const total = 100;
    for (let i = 0; i < total; i++) {
      const meta = buildImageMeta(i);
      await upsertImageMeta(pool, meta);
      await upsertEmbedding(pool, meta.id, meta.description);
      if ((i + 1) % 10 === 0) {
        console.log(`Progreso: ${i + 1}/${total}`);
      }
    }
    console.log(`Ingesta completada: ${total} imágenes`);
  } catch (err) {
    console.error('Fallo en ingesta:', err?.message ?? err);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

main();
