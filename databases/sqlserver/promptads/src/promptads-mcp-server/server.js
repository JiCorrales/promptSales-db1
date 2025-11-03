const express = require("express");
const app = express();

// Variables de entorno que Kubernetes inyecta
const {
  SQLSERVER_HOST,
  SQLSERVER_PORT,
  SQLSERVER_DB,
  SQLSERVER_USER,
  MCP_SHARED_SECRET,
  MCP_SERVICE_ID,
  SERVICE_ENV,
  NEG_SENTIMENT_THRESHOLD,
  ENGAGEMENT_DROP_THRESHOLD,
} = process.env;

// Health check (usada por readinessProbe y livenessProbe)
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    service: MCP_SERVICE_ID || "promptads-mcp",
    env: SERVICE_ENV || "dev-local",
    dbHost: SQLSERVER_HOST || "(not set)",
  });
});

// Endpoint MCP placeholder
// Aquí más adelante vamos a implementar las tools MCP reales:
// - getCampaignPerformance
// - listNegativeSentimentAlerts
// - pauseCampaignAd
app.post("/mcp", express.json(), (req, res) => {
  // Autorización básica por secreto compartido
  const providedSecret = req.headers["x-mcp-secret"];

  if (!providedSecret || providedSecret !== MCP_SHARED_SECRET) {
    return res.status(403).json({
      error: "Forbidden: invalid MCP secret",
    });
  }

  // Por ahora respondemos dummy. Más adelante este bloque
  // hará queries reales a SQL Server con el usuario limitado.
  res.json({
    ok: true,
    message: "MCP server PromptAds activo",
    db: {
      host: SQLSERVER_HOST,
      port: SQLSERVER_PORT,
      name: SQLSERVER_DB,
      user: SQLSERVER_USER,
    },
    policy: {
      negThreshold: NEG_SENTIMENT_THRESHOLD,
      engagementDrop: ENGAGEMENT_DROP_THRESHOLD,
    },
  });
});

// Puerto 8080 porque el Deployment espera containerPort: 8080
const PORT = 8080;
app.listen(PORT, () => {
  console.log(`[promptads-mcp-server] Listening on port ${PORT}`);
});
