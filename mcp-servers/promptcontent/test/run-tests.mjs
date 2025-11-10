import assert from 'node:assert/strict';

// Evitar que el servidor HTTP escuche durante pruebas
process.env.PROMPTCONTENT_NO_LISTEN = '1';
const mod = await import('../src/server.js');

console.log('Running PromptContent basic tests...');

// Test OpenAPI spec shape
const spec = await mod.buildOpenApiSpec();
assert.equal(spec.openapi, '3.0.0');
assert.ok(spec.paths['/mcp/getContent']);
assert.ok(spec.paths['/mcp/campaignDiary']);
assert.ok(spec.paths['/vectors']);
assert.ok(spec.paths['/images']);
assert.ok(spec.paths['/external/spotify/import']);
console.log('✓ OpenAPI spec includes MCP endpoints');

// Test semantic search call (degraded mode allowed)
const res = await mod.searchImagesByDescription({ description: 'atardecer en la playa', page: 1, pageSize: 2, hashtags: [] });
assert.ok(res && typeof res === 'object');
assert.ok(Array.isArray(res.items));
assert.ok(typeof res.total === 'number');
console.log('✓ Semantic search function returns a valid shape');

console.log('All tests passed');
