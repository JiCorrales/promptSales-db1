import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverEntry = path.resolve(__dirname, '../src/server.js');

async function run() {
  const transport = new StdioClientTransport({ command: 'node', args: [serverEntry] });
  const client = new Client({ name: 'precision-test', version: '0.1.0' });
  await client.connect(transport);

  const cases = [
    {
      description: 'bebida hidratante con electrolitos vegetales sin azucar',
      keywords: ['hidratante', 'electrolitos', 'vegetales']
    },
    {
      description: 'zapatos de running con amortiguacion suave y ligereza',
      keywords: ['running', 'amortiguacion', 'ligereza']
    }
  ];

  for (const c of cases) {
    const res = await client.callTool({
      name: 'getContent',
      arguments: { description: c.description, keywords: c.keywords }
    });
    const sc = res.structuredContent;
    const coverage = sc.validation.keywordCoverage;
    console.log(`[precision] ${c.description} -> coverage=${coverage.toFixed(2)}`);
    if (coverage < 0.4) {
      console.warn('precision warning: baja cobertura de keywords');
    }
  }

  await client.close();
  transport.close();
}

run().catch((e) => {
  console.error('precision-test failed:', e);
  process.exitCode = 1;
});
