import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverEntry = path.resolve(__dirname, '../src/server.js');

async function run() {
  const concurrency = 20;
  const transport = new StdioClientTransport({ command: 'node', args: [serverEntry] });
  const client = new Client({ name: 'load-test', version: '0.1.0' });
  await client.connect(transport);

  const tasks = Array.from({ length: concurrency }).map((_, i) =>
    client.callTool({
      name: 'campaignDiary',
      arguments: {
        campaignName: `Carga ${i}`,
        campaignDescription: 'Test de estabilidad bajo carga generando bitacoras y horarios.',
        objective: 'awareness',
        targetAudiences: [
          { name: 'Segmento A', preferredChannels: ['instagram'] },
          { name: 'Segmento B', preferredChannels: ['email'] }
        ]
      }
    })
  );

  const results = await Promise.all(tasks);
  console.log(`[load] completadas ${results.length} solicitudes`);

  await client.close();
  transport.close();
}

run().catch((e) => {
  console.error('load-test failed:', e);
  process.exitCode = 1;
});
