// OG-картинка 1200×630 (RU и EN) для соцсетей и мессенджеров: фон бренда, заголовок, два кадра телефона.
// Без людей и без реальных объектов — только экраны приложения на демо-данных.
// Запуск: PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node tools/site/og.mjs → assets/site/og-ru.png, og-en.png
// (Playwright — из tools/screens/node_modules: cd tools/screens && npm install).
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(join(root, 'tools/screens/package.json'));
const { chromium } = require('playwright');
const b64 = (f) => readFileSync(join(root, f)).toString('base64');
const font = (w) => `@font-face{font-family:Onest;font-weight:${w};src:url(data:font/woff2;base64,${b64(`site/fonts/onest-${w}.woff2`)})}`;
const img = (n) => `data:image/webp;base64,${b64(`assets/site/${n}.webp`)}`;

const T = {
  ru: { brand: 'Эй, Helpy', h: 'ИИ-сервис эксплуатации недвижимости и контроля подрядчиков', s: 'Платим подрядчику только за доказанную работу' },
  en: { brand: 'Hey Helpy', h: 'AI service for property maintenance and contractor control', s: 'Pay contractors only for proven work' },
};

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
for (const [lang, t] of Object.entries(T)) {
  await page.setContent(`<!doctype html><style>${font(400)}${font(600)}
  body{margin:0;width:1200px;height:630px;overflow:hidden;background:#0F1A17;font-family:Onest;color:#fff;position:relative}
  .t{position:absolute;left:64px;top:64px;width:600px}
  .b{display:flex;align-items:center;gap:14px;font-weight:600;font-size:34px;color:#8FD9C6}
  .b i{width:52px;height:52px;border-radius:14px;background:#2DB89A;display:grid;place-items:center}
  h1{font-weight:600;font-size:50px;line-height:1.12;margin:44px 0 24px}
  p{font-size:28px;color:#D5DEDA;margin:0}
  .s{display:inline-block;margin-top:28px;background:#2DB89A;color:#062B23;font-weight:600;padding:12px 22px;border-radius:999px;font-size:22px}
  img{position:absolute;width:250px;border-radius:24px;box-shadow:0 20px 60px rgba(0,0,0,.5)}
  .p1{left:700px;top:70px;transform:rotate(-4deg)}.p2{left:930px;top:120px;transform:rotate(4deg)}
  </style><div class="t"><div class="b"><i><svg width="30" height="30" viewBox="0 0 32 32"><path d="M9 9v14M23 9v14M9 16h14" stroke="#062B23" stroke-width="3.4" stroke-linecap="round"/></svg></i>${t.brand}</div>
  <h1>${t.h}</h1><div class="s">${t.s}</div></div>
  <img class="p1" src="${img('voice')}"><img class="p2" src="${img('camera')}">`);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: join(root, `assets/site/og-${lang}.png`) });
}
await browser.close();
console.log('готово: assets/site/og-ru.png, og-en.png');
