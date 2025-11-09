import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverEntry = path.resolve(__dirname, '../src/server.js');

async function run() {
  const transport = new StdioClientTransport({
    command: 'node',
    args: [serverEntry]
  });

  const client = new Client({
    name: 'promptcontent-smoke',
    version: '0.1.0'
  });

  await client.connect(transport);

  const getContentResult = await client.callTool({
    name: 'getContent',
    arguments: {
      description: 'Nueva bebida hidratante natural con electrolitos vegetales',
      campaignGoal: 'Generar expectativa en digital',
      tone: 'aspiracional',
      keywords: ['hidratacion', 'energia limpia'],
      channels: ['instagram', 'tiktok'],
      dominantColors: ['#00B0FF', '#F5F5F5'],
      callToAction: 'Descubre la experiencia'
    }
  });

  console.log('=== getContent ===');
  console.dir(getContentResult.structuredContent, { depth: null });

  const diaryResult = await client.callTool({
    name: 'campaignDiary',
    arguments: {
      campaignName: 'Lanzamiento Agua Nova',
      campaignDescription: 'Campana que posiciona una bebida premium enfocada en bienestar y energia limpia.',
      objective: 'awareness',
      tone: 'humano',
      keyOffer: 'Suscripcion con envios semanales',
      targetAudiences: [
        {
          name: 'Atletas urbanos',
          motivations: ['mantenerse activos sin azucares'],
          pains: ['bebidas demasiado artificiales'],
          preferredChannels: ['tiktok', 'instagram']
        },
        {
          name: 'Profesionales wellness',
          motivations: ['productividad sostenible'],
          pains: ['fatiga por exceso de cafe'],
          preferredChannels: ['email', 'linkedin']
        }
      ]
    }
  });

  console.log('=== campaignDiary ===');
  console.dir(diaryResult.structuredContent, { depth: null });

  await client.close();
  transport.close();
}

run().catch((error) => {
  console.error('Smoke test failed:', error);
  process.exitCode = 1;
});
