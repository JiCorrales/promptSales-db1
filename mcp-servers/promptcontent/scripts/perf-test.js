import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverEntry = path.resolve(__dirname, '../src/server.js');

function now() { return performance.now ? performance.now() : Date.now(); }

async function run() {
  const transport = new StdioClientTransport({ command: 'node', args: [serverEntry] });
  const client = new Client({ name: 'perf-test', version: '0.1.0' });
  await client.connect(transport);

  const N = 10;
  let sum = 0;
  for (let i = 0; i < N; i++) {
    const t0 = now();
    await client.callTool({
      name: 'getContent',
      arguments: { description: `prueba rendimiento ${i} con imagenes y hashtags` }
    });
    const t1 = now();
    const dt = t1 - t0;
    sum += dt;
    console.log(`[perf] iter ${i}: ${dt.toFixed(1)}ms`);
  }
  console.log(`[perf] avg: ${(sum / N).toFixed(1)}ms`);

  await client.close();
  transport.close();
}

run().catch((e) => {
  console.error('perf-test failed:', e);
  process.exitCode = 1;
});
