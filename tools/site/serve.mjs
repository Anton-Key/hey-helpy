// Локальный просмотр собранного сайта (как GitHub Pages: папка → index.html, нет файла → 404.html, gzip).
//   node tools/site/build.mjs --out build/site && node tools/site/serve.mjs build/site 8090
import { createServer } from 'node:http';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, extname, normalize } from 'node:path';
import { gzipSync } from 'node:zlib';

const dir = process.argv[2] || 'build/site';
const port = Number(process.argv[3] || 8090);
const TYPES = { '.html': 'text/html; charset=utf-8', '.txt': 'text/plain; charset=utf-8', '.xml': 'application/xml',
  '.css': 'text/css', '.js': 'text/javascript', '.webp': 'image/webp', '.png': 'image/png', '.woff2': 'font/woff2',
  '.mp4': 'video/mp4', '.webmanifest': 'application/manifest+json', '.json': 'application/json' };

createServer((req, res) => {
  let p = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^(\.\.[/\\])+/, '');
  let f = join(dir, p);
  if (existsSync(f) && statSync(f).isDirectory()) f = join(f, 'index.html');
  let status = 200;
  if (!existsSync(f)) { f = join(dir, '404.html'); status = 404; }
  let body = readFileSync(f);
  const type = TYPES[extname(f)] || 'application/octet-stream';
  const headers = { 'content-type': type, 'cache-control': 'max-age=600' };
  if (/text|xml|json|manifest/.test(type) && /gzip/.test(req.headers['accept-encoding'] || '')) {
    body = gzipSync(body); headers['content-encoding'] = 'gzip';
  }
  res.writeHead(status, headers).end(req.method === 'HEAD' ? undefined : body);
}).listen(port, () => console.log(`http://localhost:${port}/`));
