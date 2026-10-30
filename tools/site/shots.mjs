// Снимки сайта на телефоне и проверка вёрстки узкого экрана (шаг 32):
//   node tools/site/build.mjs --out build/site && node tools/site/serve.mjs build/site 8090 &
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node tools/site/shots.mjs http://localhost:8090/
// → docs/screens/site/home-360-ru.png, home-360-en.png, menu-360-ru.png, contact-360-ru.png.
// Проверяет на 360 и 412 px все страницы: нет горизонтальной прокрутки, кнопки шапки не налезают
// друг на друга, «Меню» видно и открывается. Ошибка — код выхода 1.
// Playwright — из tools/screens/node_modules (cd tools/screens && npm install).
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const { chromium } = createRequire(join(root, 'tools/screens/package.json'))('playwright');
const base = process.argv[2] || 'http://localhost:8090/';
const out = join(root, 'docs/screens/site');
mkdirSync(out, { recursive: true });
const PAGES = ['', 'features/', 'industries/', 'security/', 'faq/', 'contact/', 'privacy/'];
const errors = [];

const browser = await chromium.launch();
for (const width of [360, 412]) {
  // Плотность 1: снимок всей страницы выше ~16 000 px Chromium отдаёт с пустыми картинками.
  const page = await browser.newPage({ viewport: { width, height: 800 }, deviceScaleFactor: 1 });
  for (const lang of ['', 'ru/']) {
    for (const p of PAGES) {
      const url = base + lang + p;
      await page.goto(url);
      await page.evaluate(() => document.fonts.ready);
      const r = await page.evaluate(() => {
        const box = (s) => { const e = document.querySelector(s); if (!e) return null; const b = e.getBoundingClientRect(); return b.width ? b : null; };
        const items = ['.logo', '.lang', '.menu summary'].map(box);
        let overlap = false;
        for (let i = 0; i < items.length; i++) for (let j = i + 1; j < items.length; j++) {
          const a = items[i], b = items[j];
          if (a && b && a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom) overlap = true;
        }
        return { scroll: document.documentElement.scrollWidth, menu: !!items[2], overlap, wide: [...document.querySelectorAll('body *')].filter((e) => e.getBoundingClientRect().right > innerWidth + 1).map((e) => e.tagName + '.' + e.className).slice(0, 3) };
      });
      if (r.scroll > width) errors.push(`${width} ${url}: горизонтальная прокрутка ${r.scroll} px (${r.wide.join(', ')})`);
      if (!r.menu) errors.push(`${width} ${url}: «Меню» не видно`);
      if (r.overlap) errors.push(`${width} ${url}: элементы шапки налезают друг на друга`);
      // «Меню» открывается и пункты видны.
      await page.click('.menu summary');
      if (!(await page.locator('.menu ul').isVisible())) errors.push(`${width} ${url}: «Меню» не открывается`);
      if (width === 360 && p === '' ) await page.screenshot({ path: join(out, `menu-360-${lang ? 'ru' : 'en'}.png`) });
      await page.click('.menu summary');
      if (width === 360 && (p === '' || p === 'contact/')) {
        // Картинки с loading="lazy" грузятся только у экрана — для снимка всей страницы загрузить сразу.
        await page.evaluate(() => document.querySelectorAll('img[loading="lazy"]').forEach((i) => { i.loading = 'eager'; }));
        await page.waitForFunction(() => [...document.images].every((i) => i.complete), null, { timeout: 15000 });
        await page.screenshot({ path: join(out, `${p ? 'contact' : 'home'}-360-${lang ? 'ru' : 'en'}.png`), fullPage: true });
      }
    }
  }
  await page.close();
}
await browser.close();
if (errors.length) { console.error(errors.map((e) => '✗ ' + e).join('\n')); process.exit(1); }
console.log('✓ 360 и 412 px: без горизонтальной прокрутки, шапка не налезает, «Меню» работает. Снимки:', out);
