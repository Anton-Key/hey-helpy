// Время до первого экрана веб-версии (шаг 27, блок 8).
//
//   node tools/e2e/first_load.mjs build/web_perf [прогонов=3]
//
// Раздаёт папку сборки локальным сервером, открывает её в Playwright с
// холодным кэшем и сетью «медленный 4G» (1,6 Мбит/с вниз, 0,75 вверх,
// задержка 150 мс — как в Lighthouse) и замеряет время до первого кадра
// Flutter (событие `flutter-first-frame`) и сколько байт скачано до него.
// Экран без сервера Supabase — экран входа: это и есть первый экран.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { chromium } from '../screens/node_modules/playwright/index.mjs';

const dir = path.resolve(process.argv[2] ?? 'build/web_perf');
const runs = Number(process.argv[3] ?? 3);
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.css': 'text/css', '.svg': 'image/svg+xml',
};

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(dir, p);
  if (!f.startsWith(dir) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) {
    res.writeHead(404); res.end(); return;
  }
  // Сжатие gzip — как у GitHub Pages.
  const type = types[path.extname(f)] ?? 'application/octet-stream';
  const zip = /javascript|json|wasm|html|css|svg|font/.test(type);
  res.writeHead(200, { 'content-type': type, ...(zip ? { 'content-encoding': 'gzip' } : {}) });
  const body = fs.createReadStream(f);
  (zip ? body.pipe(zlib.createGzip()) : body).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const url = `http://127.0.0.1:${server.address().port}/`;

const browser = await chromium.launch();
const results = [];
for (let i = 0; i < runs; i++) {
  const ctx = await browser.newContext({ viewport: { width: 412, height: 915 } });
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false, latency: 150,
    downloadThroughput: (1.6 * 1024 * 1024) / 8,
    uploadThroughput: (750 * 1024) / 8,
  });
  let bytes = 0;
  const files = {};
  const perFile = {};
  cdp.on('Network.loadingFinished', (e) => {
    bytes += e.encodedDataLength;
    perFile[e.requestId] = e.encodedDataLength;
  });
  cdp.on('Network.responseReceived', (e) => { files[e.requestId] = e.response.url; });
  await page.addInitScript(() => {
    window.addEventListener('flutter-first-frame', () => {
      window.__firstFrame = performance.now();
    });
  });
  const t0 = Date.now();
  await page.goto(url);
  await page.waitForFunction(() => window.__firstFrame, null, { timeout: 180000 });
  const ms = await page.evaluate(() => window.__firstFrame);
  results.push({ ms: Math.round(ms), kb: Math.round(bytes / 1024), wall: Date.now() - t0 });
  if (i === 0) {
    console.log('до первого кадра (КБ, сжатыми):');
    const rows = Object.entries(perFile)
      .map(([id, n]) => [Math.round(n / 1024), (files[id] ?? id).replace(url, '')])
      .sort((a, b) => b[0] - a[0]);
    for (const [kb, name] of rows.slice(0, 12)) console.log(`  ${kb}\t${name}`);
  }
  await ctx.close();
}
await browser.close();
server.close();
for (const r of results) console.log(`первый кадр ${(r.ms / 1000).toFixed(1)} с · скачано ${r.kb} КБ`);
const med = results.map((r) => r.ms).sort((a, b) => a - b)[Math.floor(results.length / 2)];
console.log(`медиана: ${(med / 1000).toFixed(1)} с`);
