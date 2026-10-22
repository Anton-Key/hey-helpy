// Шаг 31, блок 2: насколько разумную рамку оборудования даёт ИИ (поле box
// photo-identify). Нарисованные сцены с ИЗВЕСТНЫМ местом оборудования (рисуем
// сами — знаем рамку) + две демо-картинки assets/demo_photos/ → запрос в
// рабочую функцию photo-identify с box: true от имени демо-менеджера →
// таблица: вид, рамка, IoU с настоящей, попал ли центр рамки в оборудование.
//
// Нужно: функция выложена с шагом 31 (Deploy functions), env.json
// (SUPABASE_URL, SUPABASE_ANON_KEY) и .env.demo (DEMO_MANAGER_EMAIL /
// PASSWORD) — оба локальные, в git не идут. Данные не меняет (функция журнал
// не пишет). Реальных фото здесь нет — только рисунки.
//
// Запуск: cd tools/ar && PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node box_probe.mjs
// --dry — только нарисовать сцены в out/ (без сети), посмотреть глазами.
// Итог: tools/ar/out/box_report.md (папка out/ в git не идёт).
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const HERE = import.meta.dirname;
const ROOT = resolve(HERE, '../..');
const OUT = join(HERE, 'out');
const W = 1280, H = 960;

const env = JSON.parse(readFileSync(join(ROOT, 'env.json'), 'utf8'));
const demo = Object.fromEntries(readFileSync(join(ROOT, '.env.demo'), 'utf8')
  .split(/\r?\n/).filter((l) => l.includes('=')).map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim()]));

const wall = (extra) => `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
  <rect width="${W}" height="${H}" fill="#e6e1d8"/><path d="M0 0 H${W} V60 H0 Z" fill="#f3f0ea"/>${extra}</svg>`;

// Рамка truth — в пикселях 1280×960 (null — оборудования нет).
const SCENES = [
  { name: 'ac_left_small', truth: [80, 300, 420, 130], svg: wall(`
    <rect x="80" y="300" width="420" height="130" rx="20" fill="#fafaf8" stroke="#c8c8c4" stroke-width="3"/>
    <path d="M90 410 Q290 440 490 410" stroke="#9f9f9a" stroke-width="4" fill="none"/>
    <rect x="420" y="330" width="56" height="26" rx="6" fill="#1f2a2e"/>`) },
  { name: 'panel', truth: [700, 220, 360, 560], svg: wall(`
    <rect x="700" y="220" width="360" height="560" rx="8" fill="#b9bec2" stroke="#7d8488" stroke-width="4"/>
    <rect x="730" y="260" width="300" height="440" rx="4" fill="#cfd4d7" stroke="#8a9196" stroke-width="2"/>
    <path d="M880 300 l-30 60 h24 l-20 60 l50 -80 h-26 l20 -40 z" fill="#f2c200" stroke="#333" stroke-width="3"/>
    <circle cx="1030" cy="500" r="10" fill="#555"/>`) },
  { name: 'smoke_detector', truth: [560, 20, 160, 70], svg: `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
    <rect width="${W}" height="${H}" fill="#f1efe9"/><path d="M0 520 L${W} 640 V${H} H0 Z" fill="#d9d3c7"/>
    <ellipse cx="640" cy="55" rx="80" ry="35" fill="#ffffff" stroke="#c9c6bf" stroke-width="3"/>
    <circle cx="660" cy="55" r="5" fill="#e5484d"/></svg>` },
  { name: 'extinguisher', truth: [180, 360, 140, 440], svg: wall(`
    <rect x="200" y="420" width="100" height="380" rx="40" fill="#d0302b" stroke="#8f1d19" stroke-width="3"/>
    <rect x="225" y="380" width="50" height="45" fill="#333"/><path d="M260 385 q60 -20 60 40" stroke="#222" stroke-width="10" fill="none"/>
    <rect x="215" y="520" width="70" height="90" fill="#fff"/>`) },
  { name: 'exit_light', truth: [520, 120, 240, 90], svg: wall(`
    <rect x="520" y="120" width="240" height="90" rx="10" fill="#1aa64b" stroke="#0e6b30" stroke-width="3"/>
    <text x="640" y="180" font-family="Arial" font-size="44" font-weight="700" fill="#fff" text-anchor="middle">EXIT</text>`) },
  { name: 'no_equipment', truth: null, svg: wall(`
    <rect x="420" y="250" width="440" height="320" fill="#ffffff" stroke="#b8b2a6" stroke-width="6"/>
    <path d="M440 540 L560 400 L640 480 L720 380 L840 540 Z" fill="#9cc7a4"/><circle cx="780" cy="320" r="28" fill="#f5c542"/>`) },
];

async function login() {
  const r = await fetch(`${env.SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: env.SUPABASE_ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: demo.DEMO_MANAGER_EMAIL, password: demo.DEMO_MANAGER_PASSWORD }),
  });
  if (!r.ok) throw new Error(`вход: HTTP ${r.status}`);
  return (await r.json()).access_token;
}

function iou(a, b) {
  const x1 = Math.max(a[0], b[0]), y1 = Math.max(a[1], b[1]);
  const x2 = Math.min(a[0] + a[2], b[0] + b[2]), y2 = Math.min(a[1] + a[3], b[1] + b[3]);
  const inter = Math.max(0, x2 - x1) * Math.max(0, y2 - y1);
  return inter / (a[2] * a[3] + b[2] * b[3] - inter);
}

mkdirSync(OUT, { recursive: true });
const { chromium } = await import(new URL('../screens/node_modules/playwright/index.mjs', import.meta.url));
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H } });
const images = [];
for (const s of SCENES) {
  await page.setContent(`<body style="margin:0">${s.svg}</body>`);
  images.push({ name: s.name, truth: s.truth, jpeg: await page.screenshot({ type: 'jpeg', quality: 80 }) });
}
await browser.close();
// Демо-картинки: корпус кондиционера нарисован в tools/demo_photos/generate.mjs.
for (const n of ['ac_indoor', 'ac_after']) {
  images.push({ name: n, truth: [200, 250, 880, 300], jpeg: readFileSync(join(ROOT, 'assets/demo_photos', `${n}.jpg`)) });
}

if (process.argv.includes('--dry')) {
  for (const img of images) writeFileSync(join(OUT, `${img.name}.jpg`), img.jpeg);
  console.log(`Сцены: ${images.map((i) => i.name).join(', ')} → ${OUT}`);
  process.exit(0);
}

const jwt = await login();
const rows = ['| Сцена | Вид | Рамка (доли) | IoU | Центр в оборудовании | мс |', '|---|---|---|---|---|---|'];
let good = 0, centre = 0, withBox = 0, total = 0;
for (const img of images) {
  const r = await fetch(`${env.SUPABASE_URL}/functions/v1/photo-identify`, {
    method: 'POST',
    headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ image: img.jpeg.toString('base64'), locale: 'ru', box: true }),
  });
  const j = await r.json().catch(() => ({}));
  total++;
  if (!r.ok) {
    rows.push(`| ${img.name} | HTTP ${r.status} ${j.error ?? ''} | — | — | — | — |`);
    continue;
  }
  const b = j.box;
  let cell = b === undefined ? 'поля нет (функция без шага 31?)' : b === null ? 'null' : `${b.x}, ${b.y}, ${b.w}, ${b.h}`;
  let io = '—', inside = '—';
  if (b) {
    withBox++;
    const px = [b.x * W, b.y * H, b.w * W, b.h * H];
    if (img.truth) {
      const v = iou(px, img.truth);
      io = v.toFixed(2);
      if (v >= 0.5) good++;
      const cx = px[0] + px[2] / 2, cy = px[1] + px[3] / 2;
      const t = img.truth;
      const hit = cx >= t[0] && cx <= t[0] + t[2] && cy >= t[1] && cy <= t[1] + t[3];
      inside = hit ? 'да' : 'нет';
      if (hit) centre++;
    } else {
      inside = 'рамка без оборудования';
    }
  } else if (!img.truth && b === null) {
    inside = 'верно: нет';
  }
  rows.push(`| ${img.name} | ${j.kind ?? '—'}${j.no_equipment ? ' (нет оборудования)' : ''} | ${cell} | ${io} | ${inside} | ${j.ms ?? '—'} |`);
}
const md = [
  `# Рамка оборудования от ИИ — замер (${new Date().toISOString().slice(0, 16).replace('T', ' ')} UTC)`,
  '',
  `Снимков: ${total}; с рамкой: ${withBox}; IoU ≥ 0,5: ${good}; центр рамки попал в оборудование: ${centre}.`,
  'Метке важен центр: в него идёт hit-test. Если центр попадает реже, чем в 7 из 8 сцен с оборудованием — выключить рамку (секрет YANDEX_VISION_BOX = off), метка останется в точке прицела.',
  '',
  ...rows,
  '',
].join('\n');
writeFileSync(join(OUT, 'box_report.md'), md);
console.log(md);
