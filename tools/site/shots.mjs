// Снимки сайта на телефоне и проверка вёрстки узкого экрана (шаг 32):
//   node tools/site/build.mjs --out build/site && node tools/site/serve.mjs build/site 8090 &
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node tools/site/shots.mjs http://localhost:8090/
// → docs/screens/site/home-360-ru.png, home-360-en.png, menu-360-ru.png, contact-360-ru.png,
//   roi-{360,412,1280}-{en,ru}[-nojs].png (шаг 35: калькулятор окупаемости с JS и без JS).
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
const PAGES = ['', 'features/', 'industries/', 'security/', 'roi/', 'faq/', 'contact/', 'privacy/'];
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
      if ((width === 360 && (p === '' || p === 'contact/')) || (width === 412 && p === '')) {
        // Картинки с loading="lazy" грузятся только у экрана — для снимка всей страницы загрузить сразу.
        await page.evaluate(() => document.querySelectorAll('img[loading="lazy"]').forEach((i) => { i.loading = 'eager'; }));
        await page.waitForFunction(() => [...document.images].every((i) => i.complete), null, { timeout: 15000 });
        await page.screenshot({ path: join(out, `${p ? 'contact' : 'home'}-${width}-${lang ? 'ru' : 'en'}.png`), fullPage: true });
      }
    }
  }
  await page.close();
}

// Шаг 35b: главная на ПК (1280), EN и RU — английские кадры и постер ролика.
{
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 1 });
  for (const lang of ['', 'ru/']) {
    await page.goto(base + lang);
    await page.evaluate(() => document.fonts.ready);
    await page.evaluate(() => document.querySelectorAll('img[loading="lazy"]').forEach((i) => { i.loading = 'eager'; }));
    await page.waitForFunction(() => [...document.images].every((i) => i.complete), null, { timeout: 15000 });
    // Прокрутить до конца: картинки декодируются и рисуются только побывав на экране.
    for (let y = 0; y < 9000; y += 600) { await page.evaluate((v) => scrollTo(0, v), y); await page.waitForTimeout(120); }
    await page.evaluate(() => scrollTo(0, 0));
    await page.waitForTimeout(800);
    await page.screenshot({ path: join(out, `home-1280-${lang ? 'ru' : 'en'}.png`), fullPage: true });
  }
  await page.close();
}

// Шаг 35: калькулятор окупаемости roi/ — 360 / 412 / 1280 px, EN и RU, с JS и без JS.
// С JS: форма видна, контрольный пример США (1 объект, 5 000 м², 3 %) даёт ×2.6 и $738.
// Без JS: формы не видно, таблица контрольных примеров на месте. На ПК — меню шапки в одну строку.
for (const js of [true, false]) {
  const ctx = await browser.newContext({ javaScriptEnabled: js, deviceScaleFactor: 1 });
  for (const width of [360, 412, 1280]) {
    const page = await ctx.newPage();
    await page.setViewportSize({ width, height: width > 900 ? 900 : 800 });
    const pageErrors = [];
    page.on('pageerror', (e) => pageErrors.push(e.message));
    for (const lang of ['', 'ru/']) {
      const url = `${base}${lang}roi/`;
      await page.goto(url);
      await page.evaluate(() => document.fonts.ready);
      const r = await page.evaluate(() => ({
        scroll: document.documentElement.scrollWidth,
        form: !!document.querySelector('#roi-form') && !document.querySelector('#roi-form').hidden,
        table: !!document.querySelector('table'),
        roi: document.getElementById('roi-o-roi')?.textContent,
        net: document.getElementById('roi-o-net-m')?.textContent,
        navRows: (() => { const n = [...document.querySelectorAll('.nav-d a')].filter((a) => a.getBoundingClientRect().width); return new Set(n.map((a) => Math.round(a.getBoundingClientRect().top))).size; })(),
      }));
      const tag = `${width} ${js ? 'JS' : 'без JS'} ${url}`;
      if (r.scroll > width) errors.push(`${tag}: горизонтальная прокрутка ${r.scroll} px`);
      if (!r.table) errors.push(`${tag}: нет таблицы контрольных примеров`);
      if (js && !r.form) errors.push(`${tag}: форма не показалась`);
      if (!js && r.form) errors.push(`${tag}: форма видна без JS`);
      if (js && (r.roi !== (lang ? '×2,6' : '×2.6') || r.net !== '$738')) errors.push(`${tag}: контрольный пример США — ${r.roi} / ${r.net}, ждали ×2.6 / $738`);
      if (width > 960 && r.navRows > 1) errors.push(`${tag}: меню шапки в ${r.navRows} строки`);
      const name = `roi-${width}-${lang ? 'ru' : 'en'}${js ? '' : '-nojs'}.png`;
      await page.evaluate(() => document.querySelectorAll('img[loading="lazy"]').forEach((i) => { i.loading = 'eager'; }));
      await page.screenshot({ path: join(out, name), fullPage: width !== 1280 || !js });
      if (js && width === 1280) await page.screenshot({ path: join(out, `roi-${width}-${lang ? 'ru' : 'en'}-full.png`), fullPage: true });
    }
    if (pageErrors.length) errors.push(`${width}: ошибки скрипта — ${pageErrors.join('; ')}`);
    await page.close();
  }
  await ctx.close();
}

await browser.close();
if (errors.length) { console.error(errors.map((e) => '✗ ' + e).join('\n')); process.exit(1); }
console.log('✓ 360 и 412 px: без горизонтальной прокрутки, шапка не налезает, «Меню» работает. Снимки:', out);
