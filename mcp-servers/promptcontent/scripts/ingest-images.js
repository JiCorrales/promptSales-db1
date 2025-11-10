import { spotifySearchAlbums } from '../src/externalApi.js';
import { Pool } from 'pg';

// Ingest at least 100 images using Spotify album covers.
// Requires PGVECTOR_DSN and optionally PGVECTOR_DIM env.

async function ensureTables(pool, dim) {
  await pool.query('CREATE EXTENSION IF NOT EXISTS vector');
  await pool.query(
    `CREATE TABLE IF NOT EXISTS content_embeddings (
      id TEXT PRIMARY KEY,
      description TEXT NOT NULL,
      embedding VECTOR(${dim})
    )`
  );
  await pool.query(
    `CREATE TABLE IF NOT EXISTS images_meta (
      id TEXT PRIMARY KEY,
      url TEXT NOT NULL,
      title TEXT,
      hashtags TEXT[]
    )`
  );
}

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
  const tokens = text.toLowerCase().split(/\W+/).filter(Boolean);
  for (const t of tokens) {
    const h = hashString(t) % dim;
    vec[h] += 1;
  }
  const norm = Math.sqrt(vec.reduce((s, v) => s + v * v, 0)) || 1;
  return vec.map((v) => v / norm);
}

function buildDescription(item) {
  const artistList = (item.artists ?? []).join(', ');
  return `Portada del álbum "${item.title}" de ${artistList}. Imagen cuadrada, estilo editorial, colores vibrantes.`;
}

function buildHashtags(item) {
  const tokens = [item.title, ...(item.artists ?? [])].map((t) => t.toLowerCase());
  const base = ['album', 'cover', 'music', 'art'];
  const tags = [...tokens, ...base]
    .map((w) => w.replace(/[^a-z0-9]+/g, ''))
    .filter(Boolean)
    .slice(0, 8)
    .map((w) => `#${w}`);
  return Array.from(new Set(tags));
}

async function upsert(pool, id, description, url, title, hashtags, vec) {
  const placeholders = vec.join(',');
  const vectorLiteral = `[${placeholders}]`;
  await pool.query(
    `INSERT INTO content_embeddings (id, description, embedding)
     VALUES ($1, $2, $3::vector)
     ON CONFLICT (id) DO UPDATE SET description = EXCLUDED.description, embedding = EXCLUDED.embedding`,
    [id, description, vectorLiteral]
  );
  await pool.query(
    `INSERT INTO images_meta (id, url, title, hashtags)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (id) DO UPDATE SET url = EXCLUDED.url, title = EXCLUDED.title, hashtags = EXCLUDED.hashtags`,
    [id, url, title, hashtags]
  );
}

async function main() {
  const dsn = process.env.PGVECTOR_DSN;
  const dim = Number.parseInt(process.env.PGVECTOR_DIM ?? '128', 10);
  if (!dsn) {
    console.error('PGVECTOR_DSN no configurado');
    process.exit(1);
  }
  const pool = new Pool({ connectionString: dsn });
  await ensureTables(pool, dim);

  const queries = ['pop', 'rock', 'electronic', 'latin', 'jazz'];
  let collected = 0;
  for (const q of queries) {
    for (let offset = 0; offset < 200 && collected < 120; offset += 50) {
      try {
        const albums = await spotifySearchAlbums(q, 50, offset);
        for (const al of albums) {
          const description = buildDescription(al);
          const hashtags = buildHashtags(al);
          const vec = textToEmbedding(description, dim);
          await upsert(pool, al.id, description, al.url, al.title, hashtags, vec);
          collected++;
          if (collected >= 120) break;
        }
      } catch (err) {
        console.warn('Fallo consulta Spotify:', err?.message ?? err);
      }
      if (collected >= 120) break;
    }
    if (collected >= 120) break;
  }
  await pool.end();
  console.log(`Ingesta completada: ${collected} imágenes`);
}

main().catch((e) => {
  console.error('Error en la ingesta:', e);
  process.exit(1);
});
