const express = require('express');
const sql = require('mssql');

const app = express();
app.use(express.json());

// ====== Config desde variables de entorno (inyectadas por Secrets/ConfigMap) ======
const {
  SQLSERVER_HOST,
  SQLSERVER_PORT,
  SQLSERVER_DB,
  SQLSERVER_USER,
  SQLSERVER_PASSWORD,
  MCP_SHARED_SECRET,
  MCP_SERVICE_ID = 'promptads-mcp-v1',
  SERVICE_ENV = 'local'
} = process.env;

// ====== Pool MSSQL (reutilizable) ======
let sqlPoolPromise;

async function getSqlPool() {
  if (!sqlPoolPromise) {
    const config = {
      server: SQLSERVER_HOST,       // mssql.mssql.svc.cluster.local
      port: Number(SQLSERVER_PORT || 1433),
      user: SQLSERVER_USER,
      password: SQLSERVER_PASSWORD,
      database: SQLSERVER_DB,
      options: {
        encrypt: true,               // Recomendado por driver en SQL 2016+
        trustServerCertificate: true // En k8s/lab suele no haber CA pública
      },
      pool: {
        max: 10,
        min: 1,
        idleTimeoutMillis: 30000
      },
      requestTimeout: 30000,
      connectionTimeout: 15000
    };
    sqlPoolPromise = sql.connect(config);
  }
  return sqlPoolPromise;
}

// ====== Health ======
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: MCP_SERVICE_ID,
    env: SERVICE_ENV,
    dbHost: SQLSERVER_HOST
  });
});

// ====== Ping DB ======
app.get('/db/ping', async (req, res) => {
  try {
    const pool = await getSqlPool();
    const r = await pool.request().query('SELECT 1 AS ok');
    res.json({ ok: true, result: r.recordset });
  } catch (err) {
    console.error('DB ping error:', err);
    res.status(500).json({ ok: false, error: String(err) });
  }
});

// ====== Ejemplo stats (ajusta a tus tablas reales) ======
app.get('/db/stats', async (req, res) => {
  try {
    const pool = await getSqlPool();
    // Ajusta nombres de tablas/columnas a los de PromptAds
    const q = `
      SELECT
        (SELECT COUNT(*) FROM Campaigns)  AS campaigns,
        (SELECT COUNT(*) FROM Ads)        AS ads
    `;
    const r = await pool.request().query(q);
    res.json({ ok: true, stats: r.recordset[0] });
  } catch (err) {
    console.error('DB stats error:', err);
    res.status(500).json({ ok: false, error: String(err) });
  }
});

// ====== Endpoint MCP "real" (autenticado con shared secret) ======
app.post('/mcp', (req, res) => {
  const secret = req.header('x-mcp-secret');
  if (!secret || secret !== MCP_SHARED_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  // Aquí irán tus tools MCP (getContent, etc.)
  res.json({ ok: true, msg: 'MCP endpoint ready' });
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`MCP listening on ${PORT}`));
