import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { promises as fs } from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { customAlphabet } from 'nanoid';

// Optional DB integration (initialized later if env is provided)
let mongoClient = null;
let mongoDb = null;
let mongoCollections = {
  contentRequests: null,
  campaignLogs: null
};
let pgPool = null;

const server = new McpServer({
  name: 'promptcontent-mcp',
  version: '0.1.0',
  metadata: {
    publisher: 'PromptContent',
    homepage: 'https://promptcontent.local'
  }
});

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_DIR = path.resolve(__dirname, '../data');
const CONTENT_HISTORY_PATH = path.join(DATA_DIR, 'content-history.json');
const CAMPAIGN_LOG_PATH = path.join(DATA_DIR, 'campaign-log.json');

const idGenerator = customAlphabet('abcdefghjkmnpqrstuvwxyz23456789', 10);

await ensureStorage();

// --------- Configuration via ENV -------------------------------------------
const CONFIG = {
  defaultChannels: parseListEnv('PC_DEFAULT_CHANNELS', ['instagram', 'tiktok']),
  hashtagCount: parseIntEnv('PC_HASHTAG_COUNT', 10),
  moodboardMax: parseIntEnv('PC_MOODBOARD_MAX', 5),
  keywordMax: parseIntEnv('PC_KEYWORD_MAX', 6),
  messageTemplates: parseJsonEnv('PC_MESSAGE_TEMPLATES', null),
  mongoUri: process.env.MONGODB_URI ?? null,
  mongoDbName: process.env.MONGODB_DB_NAME ?? null,
  mongoContentRequestsCollection: process.env.PC_CONTENT_REQUESTS_COLLECTION ?? 'ContentRequests',
  mongoCampaignLogsCollection: process.env.PC_CAMPAIGN_LOGS_COLLECTION ?? 'CampaignLogs',
  pgDsn: process.env.PGVECTOR_DSN ?? null,
  pgTable: process.env.PGVECTOR_TABLE ?? 'content_embeddings',
  pgDim: parseIntEnv('PGVECTOR_DIM', 128)
};

// Initialize optional MongoDB connection
await initMongoIfAvailable();
// Initialize optional pgvector connection
await initPgvectorIfAvailable();

// Estado de salud/ready para probes
let serverConnected = false;

const getContentSchema = {
  description: z.string().min(10, 'Describe la idea con al menos diez caracteres'),
  campaignGoal: z.string().min(5).optional(),
  tone: z.enum(['aspiracional', 'educativo', 'informativo', 'promocional', 'emocional']).optional(),
  keywords: z.array(z.string().min(2)).max(12).optional(),
  channels: z
    .array(z.enum(['instagram', 'tiktok', 'facebook', 'outdoor', 'email', 'landing']))
    .max(4)
    .optional(),
  dominantColors: z.array(z.string().min(3)).max(5).optional(),
  callToAction: z.string().optional(),
  aspectRatio: z.enum(['1:1', '4:5', '9:16', '16:9']).optional(),
  moodboardCount: z.number().int().min(1).max(5).optional()
};

const diarySchema = {
  campaignName: z.string().min(3),
  campaignDescription: z.string().min(12),
  objective: z.enum(['awareness', 'consideration', 'conversion', 'retention']).default('consideration'),
  keyOffer: z.string().optional(),
  launchWindow: z.string().optional(),
  tone: z.enum(['aspiracional', 'educativo', 'promo', 'humano']).default('humano'),
  callToAction: z.string().optional(),
  targetAudiences: z
    .array(
      z.object({
        name: z.string().min(3),
        profile: z.string().optional(),
        motivations: z.array(z.string().min(3)).max(5).optional(),
        pains: z.array(z.string().min(3)).max(5).optional(),
        preferredChannels: z.array(z.string().min(3)).max(4).optional()
      })
    )
    .min(1)
};

server.registerTool(
  'getContent',
  {
    title: 'Generador de imágenes y hashtags',
    description:
      'Recibe una descripción de campaña y responde con ideas visuales sugeridas, prompts y hashtags listos para usar.',
    inputSchema: getContentSchema,
    outputSchema: {
      requestId: z.string(),
      ideas: z.array(
        z.object({
          id: z.string(),
          title: z.string(),
          prompt: z.string(),
          hashtags: z.array(z.string()),
          recommendedChannels: z.array(z.string()),
          ratio: z.string(),
          palette: z.array(z.string())
        })
      ),
      images: z.array(
        z.object({
          id: z.string(),
          title: z.string(),
          url: z.string(),
          hashtags: z.array(z.string())
        })
      ),
      masterHashtags: z.array(z.string()),
      validation: z.object({
        keywordCoverage: z.number(),
        channelAlignment: z.number(),
        embeddingSimilarity: z.number().optional()
      })
    }
  },
  async (params) => {
    const normalized = normalizeContentParams(params);
    const keywords = buildKeywordList(normalized);
    const hashtags = generateHashtags(normalized.description, keywords);
    const ideas = buildImageIdeas(normalized, keywords, hashtags);
    const requestId = `pc-${idGenerator()}`;
    await persistContentRequest(requestId, normalized, ideas, hashtags);
    // upsert embedding para indexación
    await upsertEmbedding(requestId, normalized.description);

    // Construir imágenes simuladas con placeholder y hashtags
    const images = ideas.map((idea, idx) => ({
      id: `img-${idx + 1}-${idGenerator()}`,
      title: idea.title,
      url: `https://picsum.photos/seed/${encodeURIComponent(idea.title)}/${normalized.aspectRatio.replace(':','x')}`,
      hashtags: idea.hashtags
    }));

    // Validación de relevancia
    const validation = await validateRelevance({ normalized, keywords, ideas });

    const structuredContent = {
      requestId,
      summary: `${ideas.length} escenas sugeridas para ${normalized.channels.join(', ')}`,
      ideas,
      images,
      masterHashtags: hashtags,
      validation
    };

    return {
      content: [
        {
          type: 'text',
          text: [
            `ID de solicitud: ${requestId}`,
            `Escenas sugeridas: ${ideas.length}`,
            `Hashtags clave: ${hashtags.slice(0, 5).join(', ')}`,
            `Cobertura de keywords: ${Math.round(validation.keywordCoverage * 100)}%`
          ].join('\n')
        }
      ],
      structuredContent
    };
  }
);

server.registerTool(
  'campaignDiary',
  {
    title: 'Bitácora de mensajes por audiencia',
    description:
      'Guarda la solicitud de campaña y construye una bitácora de tres mensajes por cada segmento objetivo.',
    inputSchema: diarySchema,
    outputSchema: {
      requestId: z.string(),
      campaignName: z.string(),
      diary: z.array(
        z.object({
          audience: z.string(),
          messages: z.array(
            z.object({
              stage: z.string(),
              copy: z.string(),
              suggestedChannels: z.array(z.string())
            })
          )
        })
      )
    }
  },
  async (params) => {
    const normalized = normalizeDiaryParams(params);
    const diary = normalized.targetAudiences.map((audience) =>
      buildAudienceDiary(audience, normalized)
    );
    const requestId = `log-${idGenerator()}`;
    await persistCampaignDiary(requestId, normalized, diary);
    // almacenar vector de descripción de campaña
    await upsertEmbedding(requestId, normalized.campaignDescription);

    // Generar horarios sugeridos y metadatos de seguimiento
    const scheduleSuggestions = buildSchedules(diary);
    const tracking = {
      trackingId: requestId,
      objective: normalized.objective,
      audiences: diary.map((d) => d.audience)
    };

    const structuredContent = {
      requestId,
      campaignName: normalized.campaignName,
      diary,
      scheduleSuggestions,
      tracking
    };

    return {
      content: [
        {
          type: 'text',
          text: `Bitácora generada para ${normalized.campaignName} con ${diary.length} audiencias. Primer envío sugerido: ${scheduleSuggestions[0]?.when ?? 'N/A'}.`
        }
      ],
      structuredContent
    };
  }
);

const transport = new StdioServerTransport();

server
  .connect(transport)
  .then(() => {
    serverConnected = true;
  })
  .catch((error) => {
    console.error('Error al iniciar PromptContent MCP server:', error);
    process.exitCode = 1;
  });

// HTTP server para healthz/readyz (solo para Kubernetes probes)
const PORT = Number.parseInt(process.env.PORT ?? '8080', 10);
const healthServer = http.createServer((req, res) => {
  if (req.url === '/healthz') {
    const status = {
      status: 'ok',
      serverConnected,
      mongoConnected: !!mongoDb,
      pgConnected: !!pgPool
    };
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(status));
    return;
  }
  if (req.url === '/readyz') {
    const ready = serverConnected === true;
    const status = {
      status: ready ? 'ready' : 'not_ready',
      serverConnected,
      mongoConnected: !!mongoDb,
      pgConnected: !!pgPool
    };
    res.writeHead(ready ? 200 : 503, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(status));
    return;
  }
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not_found' }));
});

healthServer.listen(PORT, () => {
  console.log(`PromptContent MCP health server escuchando en :${PORT}`);
});

process.on('SIGINT', async () => {
  await server.close();
  transport.close();
  try {
    healthServer.close();
  } catch {}
  process.exit(0);
});

// -- Helpers -----------------------------------------------------------------

async function ensureStorage() {
  await fs.mkdir(DATA_DIR, { recursive: true });
  await ensureArrayFile(CONTENT_HISTORY_PATH);
  await ensureArrayFile(CAMPAIGN_LOG_PATH);
}

async function ensureArrayFile(filePath) {
  try {
    await fs.access(filePath);
  } catch {
    await fs.writeFile(filePath, '[]', 'utf-8');
  }
}

async function appendEntry(filePath, payload) {
  const current = await readArrayFile(filePath);
  current.push(payload);
  await fs.writeFile(filePath, JSON.stringify(current, null, 2));
}

async function readArrayFile(filePath) {
  try {
    const raw = await fs.readFile(filePath, 'utf-8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    if (error.code === 'ENOENT') {
      return [];
    }
    throw error;
  }
}

function normalizeContentParams(params) {
  return {
    description: params.description.trim(),
    campaignGoal: params.campaignGoal?.trim() ?? 'engagement',
    tone: params.tone ?? 'aspiracional',
    keywords: params.keywords?.map((kw) => kw.toLowerCase().trim()) ?? [],
    channels: params.channels?.length ? params.channels : CONFIG.defaultChannels,
    dominantColors: params.dominantColors ?? ['#F97316', '#1E293B', '#FDE047'],
    callToAction: params.callToAction ?? 'Descubre mas',
    aspectRatio: params.aspectRatio ?? '4:5',
    moodboardCount: clampNumber(params.moodboardCount ?? 3, 1, CONFIG.moodboardMax)
  };
}

function normalizeDiaryParams(params) {
  return {
    ...params,
    campaignName: params.campaignName.trim(),
    campaignDescription: params.campaignDescription.trim(),
    tone: params.tone ?? 'humano',
    callToAction: params.callToAction ?? 'Conoce mas',
    targetAudiences: params.targetAudiences.map((audience) => ({
      ...audience,
      name: audience.name.trim(),
      profile: audience.profile?.trim(),
      preferredChannels: audience.preferredChannels?.length
        ? audience.preferredChannels
        : ['instagram', 'email', 'landing']
    }))
  };
}

function buildKeywordList(params) {
  const descKeywords = params.description
    .split(/\W+/)
    .map((word) => word.toLowerCase())
    .filter((word) => word.length > 4);
  const combined = [...descKeywords.slice(0, CONFIG.keywordMax), ...params.keywords];
  return Array.from(new Set(combined));
}

function generateHashtags(description, keywords) {
  const tokens = [...keywords, ...description.split(/\s+/)];
  const pick = tokens
    .map((token) => toHashtagToken(token))
    .filter(Boolean);
  const defaults = ['marketing', 'campana', 'contenido'];
  const merged = Array.from(new Set([...pick, ...defaults]));
  return merged.slice(0, CONFIG.hashtagCount).map((token) => `#${token}`);
}

function toHashtagToken(word) {
  return word
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '')
    .slice(0, 18);
}

function buildImageIdeas(params, keywords, hashtags) {
  const angles = [
    {
      title: 'Hero lifestyle',
      description: 'Momento aspiracional con protagonistas disfrutando del beneficio'
    },
    {
      title: 'Detalle del producto',
      description: 'Close-up que resalta textura o funcionalidad'
    },
    {
      title: 'Escena testimonial',
      description: 'Situacion cotidiana con cita corta de cliente'
    },
    {
      title: 'Mood de experiencia',
      description: 'Ambiente inmersivo que comunica sensaciones de la marca'
    }
  ];

  return Array.from({ length: params.moodboardCount }).map((_, index) => {
    const angle = angles[index % angles.length];
    const prompt = [
      params.description,
      `Enfasis: ${angle.description}`,
      `Tono ${params.tone}`,
      `Paleta ${params.dominantColors.join(', ')}`,
      `Keywords: ${keywords.slice(0, 5).join(', ')}`
    ].join(' | ');

    return {
      id: `idea-${index + 1}-${idGenerator()}`,
      title: `${angle.title} ${index + 1}`,
      prompt,
      hashtags: hashtags.slice(index, index + 4),
      recommendedChannels: params.channels,
      ratio: params.aspectRatio,
      palette: params.dominantColors
    };
  });
}

async function validateRelevance({ normalized, keywords, ideas }) {
  const keywordHits = ideas.reduce((acc, idea) => {
    const hits = keywords.filter((kw) => idea.prompt.toLowerCase().includes(kw)).length;
    return acc + hits;
  }, 0);
  const keywordCoverage = ideas.length
    ? keywordHits / (ideas.length * Math.max(1, keywords.length))
    : 0;
  const channelAlignment = ideas.length
    ? ideas.filter((i) => i.recommendedChannels.some((c) => normalized.channels.includes(c))).length /
      ideas.length
    : 0;
  let embeddingSimilarity = undefined;
  try {
    embeddingSimilarity = await computeEmbeddingSimilarity(normalized.description);
  } catch {
    // opcional: si no hay pgvector
  }
  return { keywordCoverage, channelAlignment, embeddingSimilarity };
}

// ---------- pgvector --------------------------------------------------------
async function initPgvectorIfAvailable() {
  if (!CONFIG.pgDsn) return;
  try {
    const { Pool } = await import('pg');
    pgPool = new Pool({ connectionString: CONFIG.pgDsn });
    await pgPool.query('CREATE EXTENSION IF NOT EXISTS vector');
    await pgPool.query(
      `CREATE TABLE IF NOT EXISTS ${CONFIG.pgTable} (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        embedding VECTOR(${CONFIG.pgDim})
      )`
    );
    console.log('PromptContent MCP: pgvector listo');
  } catch (err) {
    console.warn('PromptContent MCP: no se pudo inicializar pgvector:', err?.message ?? err);
    pgPool = null;
  }
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

function hashString(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

async function upsertEmbedding(id, description) {
  if (!pgPool) return;
  const vec = textToEmbedding(description);
  const placeholders = vec.join(',');
  try {
    await pgPool.query(
      `INSERT INTO ${CONFIG.pgTable} (id, description, embedding)
       VALUES ($1, $2, '['||$3||']')
       ON CONFLICT (id) DO UPDATE SET description = EXCLUDED.description, embedding = EXCLUDED.embedding`,
      [id, description, placeholders]
    );
  } catch (err) {
    console.warn('pgvector upsert fallo:', err?.message ?? err);
  }
}

async function computeEmbeddingSimilarity(description) {
  if (!pgPool) return undefined;
  const vec = textToEmbedding(description);
  const placeholders = vec.join(',');
  try {
    const q = await pgPool.query(
      `SELECT 1 - (embedding <=> '['||$1||']') AS cosine
       FROM ${CONFIG.pgTable}
       ORDER BY embedding <=> '['||$1||']'
       LIMIT 1`,
      [placeholders]
    );
    const row = q.rows[0];
    return row ? Number(row.cosine) : undefined;
  } catch (err) {
    console.warn('pgvector similarity fallo:', err?.message ?? err);
    return undefined;
  }
}

function buildAudienceDiary(audience, context) {
  const defaultStages = [
    {
      stage: 'Descubrimiento',
      template: (aud, ctx) =>
        `Hola ${aud.name}, sabemos que ${describePain(aud)}. ${ctx.campaignDescription}.`
    },
    {
      stage: 'Consideracion',
      template: (aud, ctx) =>
        `Imagina ${aud.name} logrando ${describeMotivation(aud)} con ${ctx.keyOffer ?? 'nuestra propuesta principal'}.`
    },
    {
      stage: 'Conversion',
      template: (aud, ctx) =>
        `${ctx.callToAction}: visita ${aud.preferredChannels?.[0] ?? 'nuestro sitio'} y asegura el beneficio.`
    }
  ];

  // Allow overriding templates via env JSON
  const stages = Array.isArray(CONFIG.messageTemplates)
    ? CONFIG.messageTemplates.map((tpl, idx) => ({
        stage: tpl.stage ?? defaultStages[idx]?.stage ?? `Etapa ${idx + 1}`,
        template: (aud, ctx) =>
          (tpl.pattern ?? defaultStages[idx]?.template(aud, ctx))
            .replaceAll('{{audience}}', aud.name)
            .replaceAll('{{pain}}', describePain(aud))
            .replaceAll('{{motivation}}', describeMotivation(aud))
            .replaceAll('{{cta}}', ctx.callToAction ?? 'Conoce mas')
            .replaceAll('{{channel}}', aud.preferredChannels?.[0] ?? 'nuestro sitio')
            .replaceAll('{{campaignDescription}}', ctx.campaignDescription)
      }))
    : defaultStages;

  return {
    audience: audience.name,
    messages: stages.map((stage) => ({
      stage: stage.stage,
      copy: stage.template(audience, context),
      suggestedChannels: audience.preferredChannels ?? ['instagram']
    }))
  };
}

function buildSchedules(diary) {
  const base = new Date();
  const slots = [9, 13, 18]; // horas típicas: mañana, mediodía, tarde
  return diary.flatMap((entry, idx) => {
    return slots.map((hour, sIdx) => {
      const when = new Date(base.getTime() + (idx * 24 + sIdx * 6) * 60 * 60 * 1000);
      when.setHours(hour, 0, 0, 0);
      return {
        audience: entry.audience,
        stage: ['Descubrimiento', 'Consideracion', 'Conversion'][sIdx] ?? 'Mensaje',
        when: when.toISOString(),
        channels: entry.messages[sIdx]?.suggestedChannels ?? ['instagram']
      };
    });
  });
}

function describePain(audience) {
  if (!audience.pains?.length) {
    return 'buscas soluciones mas humanas';
  }
  return audience.pains[0];
}

function describeMotivation(audience) {
  if (!audience.motivations?.length) {
    return 'un estilo de vida equilibrado';
  }
  return audience.motivations[0];
}

// -- ENV helpers and DB integration -----------------------------------------
function parseListEnv(name, fallback = []) {
  const raw = process.env[name];
  if (!raw) return fallback;
  return raw.split(',').map((s) => s.trim()).filter(Boolean);
}

function parseIntEnv(name, fallback) {
  const raw = process.env[name];
  const n = Number.parseInt(raw ?? `${fallback}`, 10);
  return Number.isFinite(n) ? n : fallback;
}

function clampNumber(n, min, max) {
  return Math.max(min, Math.min(max, n));
}

function parseJsonEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) return fallback;
  try {
    return JSON.parse(raw);
  } catch {
    console.warn(`Advertencia: ${name} no es JSON valido`);
    return fallback;
  }
}

async function initMongoIfAvailable() {
  if (!CONFIG.mongoUri || !CONFIG.mongoDbName) {
    return;
  }
  try {
    const { MongoClient } = await import('mongodb');
    mongoClient = new MongoClient(CONFIG.mongoUri, { serverSelectionTimeoutMS: 2000 });
    await mongoClient.connect();
    mongoDb = mongoClient.db(CONFIG.mongoDbName);
    mongoCollections.contentRequests = mongoDb.collection(CONFIG.mongoContentRequestsCollection);
    mongoCollections.campaignLogs = mongoDb.collection(CONFIG.mongoCampaignLogsCollection);
    console.log('PromptContent MCP: conectado a MongoDB');
  } catch (err) {
    console.warn('PromptContent MCP: no se pudo conectar a MongoDB, se usara almacenamiento local. Motivo:', err?.message ?? err);
  }
}

async function persistContentRequest(requestId, normalized, ideas, hashtags) {
  if (!mongoCollections.contentRequests) {
    // Fallback: append to local file
    await appendEntry(CONTENT_HISTORY_PATH, {
      id: requestId,
      createdAt: new Date().toISOString(),
      request: normalized,
      response: { hashtags, ideaCount: ideas.length }
    });
    return;
  }
  const doc = {
    requestId,
    requestedByUserId: 'system',
    platform: 'promptcontent',
    intent: 'content_ideas',
    campaignRef: normalized.campaignGoal ?? null,
    targets: normalized.channels,
    items: [
      {
        type: 'image',
        quantity: normalized.moodboardCount,
        spec: {
          aspectRatio: normalized.aspectRatio,
          palette: normalized.dominantColors,
          keywords: buildKeywordList(normalized)
        }
      }
    ],
    brief: normalized.description,
    originalPayload: normalized,
    status: 'completed',
    createdAt: new Date(),
    updatedAt: null
  };
  try {
    await mongoCollections.contentRequests.insertOne(doc);
  } catch (err) {
    console.warn('No se pudo insertar ContentRequests:', err?.message ?? err);
  }
}

async function persistCampaignDiary(requestId, normalized, diary) {
  if (!mongoCollections.campaignLogs) {
    // Fallback: append to local file
    await appendEntry(CAMPAIGN_LOG_PATH, {
      id: requestId,
      createdAt: new Date().toISOString(),
      campaignName: normalized.campaignName,
      objective: normalized.objective,
      entries: diary
    });
    return;
  }
  const now = new Date();
  try {
    const ops = diary.map((entry) => ({
      logId: `${requestId}-${entry.audience}`,
      campaignRef: normalized.campaignName,
      audience: entry.audience,
      messages: entry.messages.map((m) => ({ ts: now, text: m.copy, role: 'assistant' })),
      messageCount: entry.messages.length,
      lastMessageTs: now,
      metaJson: JSON.stringify({ suggestedChannels: entry.suggestedChannels ?? [] }),
      createdAt: now
    }));
    await mongoCollections.campaignLogs.insertMany(ops);
  } catch (err) {
    console.warn('No se pudo insertar CampaignLogs:', err?.message ?? err);
  }
}
