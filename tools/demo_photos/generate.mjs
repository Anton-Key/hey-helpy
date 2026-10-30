// Нарисованный «снимок» оборудования для «Узнать по фото» (шаг 22):
// внутренний блок настенного кондиционера на стене переговорной. Нужен
// заглушке (VOICE_MOCK: в браузере Playwright нет камеры) и кадру питча 18.
//
// Это рисунок (SVG → JPEG), а не фото реального объекта: лицензия — та же,
// что у репозитория; сторонних изображений нет. Реальные фото объектов в
// репозиторий не класть.
//
// Запуск: cd tools/demo_photos && PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node generate.mjs
// Результат: assets/demo_photos/ac_indoor.jpg (1280×960, JPEG ~80 %) и
// ac_after.jpg — тот же блок после ремонта, без подтёка (фото «после» в
// демо-истории, шаг 24: путь вложения demo/ac_after.jpg — картинка из сборки).
import { mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const HERE = import.meta.dirname;
const ROOT = resolve(HERE, '../..');
const OUT = join(ROOT, 'assets/demo_photos');
const W = 1280, H = 960;

const draw = (leak) => `
<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="wall" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#e9e4dc"/><stop offset="1" stop-color="#d6d0c6"/>
    </linearGradient>
    <linearGradient id="body" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fbfbfa"/><stop offset="0.75" stop-color="#eeeeec"/><stop offset="1" stop-color="#d9d9d6"/>
    </linearGradient>
    <linearGradient id="flap" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#d8d8d5"/><stop offset="1" stop-color="#b9b9b5"/>
    </linearGradient>
    <radialGradient id="light" cx="0.3" cy="0.15" r="0.9">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.35"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="140%">
      <feDropShadow dx="0" dy="18" stdDeviation="16" flood-color="#5b5246" flood-opacity="0.35"/>
    </filter>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#wall)"/>
  <rect width="${W}" height="${H}" fill="url(#light)"/>
  <!-- угол потолка -->
  <path d="M0 0 H${W} V70 H0 Z" fill="#f3f0ea"/>
  <path d="M0 70 H${W}" stroke="#c9c2b6" stroke-width="3"/>
  <!-- корпус внутреннего блока -->
  <g filter="url(#shadow)">
    <rect x="200" y="250" width="880" height="270" rx="34" fill="url(#body)" stroke="#c8c8c4" stroke-width="3"/>
  </g>
  <!-- решётка сверху -->
  ${Array.from({ length: 34 }, (_, i) => `<rect x="${250 + i * 23.5}" y="268" width="12" height="40" rx="5" fill="#dcdcd8"/>`).join('')}
  <!-- лицевая панель -->
  <rect x="226" y="326" width="828" height="122" rx="16" fill="#f7f7f5" stroke="#e0e0dc" stroke-width="2"/>
  <!-- заслонка (жалюзи) -->
  <path d="M232 470 Q640 520 1048 470 L1048 500 Q640 548 232 500 Z" fill="url(#flap)"/>
  <path d="M260 512 Q640 552 1020 512" stroke="#9f9f9a" stroke-width="3" fill="none"/>
  <!-- дисплей и индикаторы -->
  <rect x="900" y="360" width="110" height="50" rx="10" fill="#1f2a2e"/>
  <text x="955" y="396" font-family="Arial, Helvetica, sans-serif" font-size="30" font-weight="700" fill="#66e0c7" text-anchor="middle">22°</text>
  <circle cx="1028" cy="372" r="6" fill="#2DB89A"/>
  <circle cx="1028" cy="396" r="6" fill="#c7c7c2"/>
  <!-- логотип выдуманного производителя -->
  <text x="268" y="402" font-family="Arial, Helvetica, sans-serif" font-size="34" font-weight="700" letter-spacing="6" fill="#9aa4a8">AIRDEMO</text>
  <!-- трасса и подтёк воды под блоком (видимая неисправность) -->
  <rect x="1060" y="470" width="26" height="490" fill="#ecebe7" stroke="#d2d0ca" stroke-width="2"/>
  ${leak ? `<path d="M640 548 C 636 600, 646 640, 640 700 C 637 740, 650 760, 644 800" stroke="#7fb3c8" stroke-width="8" fill="none" stroke-linecap="round" opacity="0.65"/>
  <ellipse cx="644" cy="812" rx="16" ry="10" fill="#7fb3c8" opacity="0.6"/>` : `<rect x="520" y="600" width="240" height="44" rx="10" fill="#ffffff" stroke="#2DB89A" stroke-width="3"/>
  <text x="640" y="630" font-family="Arial, Helvetica, sans-serif" font-size="22" font-weight="700" fill="#0B7A62" text-anchor="middle">Serviced ✓ 10.2026</text>`}
  <!-- наклейка-шильдик сбоку -->
  <rect x="1000" y="452" width="56" height="20" rx="3" fill="#ffffff" stroke="#bdbdb8"/>
  <text x="1028" y="466" font-family="Arial, Helvetica, sans-serif" font-size="11" fill="#555" text-anchor="middle">AC-301</text>
  <!-- розетка на стене -->
  <rect x="140" y="760" width="90" height="90" rx="12" fill="#f6f5f2" stroke="#cfcac1" stroke-width="3"/>
  <circle cx="170" cy="805" r="7" fill="#9b968d"/><circle cx="200" cy="805" r="7" fill="#9b968d"/>
</svg>`;

mkdirSync(OUT, { recursive: true });
const { chromium } = await import(new URL('../screens/node_modules/playwright/index.mjs', import.meta.url));
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H } });
for (const [name, leak] of [['ac_indoor.jpg', true], ['ac_after.jpg', false]]) {
  await page.setContent(`<html><body style="margin:0">${draw(leak)}</body></html>`);
  await page.screenshot({ path: join(OUT, name), type: 'jpeg', quality: 80 });
  console.log(`assets/demo_photos/${name}`);
}
await browser.close();
