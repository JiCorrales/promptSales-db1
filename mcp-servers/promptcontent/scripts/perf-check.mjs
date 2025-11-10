const mod = await import('../src/server.js');

const queries = [
  'sol, playa y verano',
  'fiesta nocturna urbana',
  'bosque nevado con animales',
  'arte abstracto colores vibrantes',
];

console.log('PromptContent perf check: semantic search timings');
for (const q of queries) {
  const start = performance.now();
  const res = await mod.searchImagesByDescription({ description: q, page: 1, pageSize: 5, hashtags: [] });
  const ms = Math.round(performance.now() - start);
  console.log(`Query '${q}' -> ${ms}ms, items=${res.items?.length ?? 0}`);
}
