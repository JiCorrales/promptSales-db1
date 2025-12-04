// Seed PromptContent with ≥100 images and vectors via HTTP endpoints
// Usage: node scripts/data-generation/seed-promptcontent.mjs
// Env:
//  - SEED_BASE_URL (default: http://localhost:8080)
//  - API_KEY (optional; not required for these endpoints)
//  - SEED_TOTAL (default: 120)

const BASE_URL = process.env.SEED_BASE_URL ?? 'http://localhost:8080';
const API_KEY = process.env.API_KEY ?? null;
const TOTAL = Number.parseInt(process.env.SEED_TOTAL ?? '120', 10);

async function httpJson(method, path, payload) {
  const url = `${BASE_URL}${path}`;
  const headers = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
  if (API_KEY) headers['X-API-Key'] = API_KEY;
  const res = await fetch(url, {
    method,
    headers,
    body: payload ? JSON.stringify(payload) : undefined
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch (_) {
    data = text;
  }
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} ${res.statusText}: ${typeof data === 'string' ? data : JSON.stringify(data)}`);
  }
  return data;
}

function toHashtagToken(word) {
  return word
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '')
    .slice(0, 18);
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

function generateHashtags(description) {
  const tokens = description.split(/\s+/);
  const base = ['marketing', 'campana', 'contenido'];
  const tags = Array.from(new Set(tokens.map(toHashtagToken).filter(Boolean).concat(base)));
  return tags.slice(0, 10);
}

function buildImageMeta(idx) {
  const id = `seed-img-${idx + 1}`;
  const width = 800 + (idx % 4) * 40;
  const height = 800;
  const url = `https://picsum.photos/seed/promptcontent-${idx + 1}/${width}/${height}`;
  const title = `Imagen seed ${idx + 1}`;
  const description = generateDescription(idx);
  const hashtags = generateHashtags(description);
  const format = 'jpeg';
  const size_bytes = width * height * 3; // aproximación
  return { id, url, title, description, hashtags, format, size_bytes, width, height };
}

async function main() {
  console.log(`[seed] Base URL: ${BASE_URL}`);
  const ready = await httpJson('GET', '/readyz');
  console.log(`[seed] Ready state: ${ready.status}, mongo=${!!ready.mongoConnected}, pg=${!!ready.pgConnected}`);
  const canVectors = !!ready.pgConnected;

  let count = 0;
  for (let i = 0; i < TOTAL; i++) {
    const meta = buildImageMeta(i);
    try {
      await httpJson('POST', '/images', {
        id: meta.id,
        url: meta.url,
        title: meta.title,
        hashtags: meta.hashtags,
        format: meta.format,
        size_bytes: meta.size_bytes,
        width: meta.width,
        height: meta.height
      });
      if (canVectors) {
        await httpJson('POST', '/vectors', { id: meta.id, description: meta.description });
      }
      count++;
      if ((i + 1) % 20 === 0) {
        console.log(`[seed] Progreso: ${i + 1}/${TOTAL}`);
      }
    } catch (err) {
      console.warn(`[seed] fallo registro ${meta.id}:`, err.message);
    }
  }
  console.log(`[seed] Completado: ${count} imágenes${canVectors ? ' con vectores' : ''}`);
  if (!canVectors) {
    console.warn('[seed] Aviso: pgvector no disponible, vectores omitidos. Configura PGVECTOR_DSN para indexar embeddings.');
  }
}

main().catch((e) => {
  console.error('[seed] Error fatal:', e);
  process.exit(1);
});

