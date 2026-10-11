// Снимки главных экранов для проверки вёрстки (шаг 18, блок E): 360 / 412 /
// 1280 / 1920, русский и английский, локальная база с 0016 (администратор).
//   node polish_shots.mjs [--lang=ru|en|all] [--widths=360,412,1280,1920] [--only=<ключ>]
// Снимки — tools/e2e/out/polish/<язык>-<ширина>-<экран>.png (в git не идут).
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { startLocalBackend } from '../screens/local_backend.mjs';
import { USERS, chromium, login, openApp, profileTab, settle, startWeb, typeInto, uuid } from './lib.mjs';

const OUT = join(import.meta.dirname, 'out/polish');
mkdirSync(OUT, { recursive: true });
const LANG = process.argv.find((a) => a.startsWith('--lang='))?.slice(7) ?? 'all';
const WIDTHS = (process.argv.find((a) => a.startsWith('--widths='))?.slice(9) ?? '360,412,1280,1920').split(',').map(Number);
const ONLY = process.argv.find((a) => a.startsWith('--only='))?.slice(7);
const H = { 360: 780, 412: 915, 1280: 800, 1920: 1080 };

const backend = await startLocalBackend({ port: 54321 });
const web = await startWeb();
const browser = await chromium.launch();
const base = web.base;

const T = {
  ru: { home: /^Главная/, ppr: /^ППР/, loc: /^Локации/, map: /^Карта/, list: /^Список/, contr: /^Подрядчики/, rep: /^Отчёты/,
    hist: /^История/, prof: /^Профиль/, company: /^Моя компания/, regions: /Регионы компании/, audit: /Журнал изменений доступа/,
    zone: /^Зона доступа/, m2: /Менеджер Москва/, bc: /^БЦ «Демо»/, show: /Показать на плане/, settings: /^Настройки/ },
  en: { home: /^Home/, ppr: /^(PPM|Preventive|PM)/, loc: /^Locations/, map: /^Map/, list: /^List/, contr: /^Contractors/, rep: /^Reports/,
    hist: /^History/, prof: /^Profile/, company: /^My company/, regions: /Company regions|Regions/, audit: /Access change log/,
    zone: /^Access zone/, m2: /Менеджер Москва/, bc: /^БЦ «Демо»/, show: /Show on (the )?plan/, settings: /^Settings/ },
};

async function go(page, path = '') {
  await openApp(page, base, path);
  await profileTab(page).or(page.getByRole('tab', { name: /^Profile/ })).or(page.getByRole('button', { name: /^Profile/ }))
    .first().waitFor({ timeout: 60000 }).catch(() => {});
  await settle(page, 2200);
}
const click = async (page, re, ms = 1800) => {
  await page.getByRole('button', { name: re }).or(page.getByRole('tab', { name: re })).first().click({ timeout: 15000 });
  await settle(page, ms);
};
async function scrollFind(page, re) {
  const el = page.getByRole('button', { name: re }).first();
  const vp = page.viewportSize();
  await page.mouse.move(vp.width * 0.6, vp.height * 0.6);
  for (let i = 0; i < 25 && !(await el.isVisible().catch(() => false)); i++) {
    await page.mouse.wheel(0, 400);
    await page.waitForTimeout(200);
  }
  return el;
}

async function openOrder(p) {
  await go(p);
  await typeInto(p, p.getByRole('textbox').first(), 'Течёт конденсат');
  await settle(p, 1800);
  await click(p, /^Течёт конденсат/, 2200);
}

const SCREENS = (t) => [
  ['requests', (p) => go(p)],
  ['order-card', async (p) => { await openOrder(p); }],
  ['plan', async (p) => { await openOrder(p); await click(p, t.show, 4000); }],
  ['ppr', async (p) => { await go(p); await click(p, t.ppr, 2500); }],
  ['ppr-card', async (p) => { await go(p); await click(p, t.ppr, 2500); await click(p, /^ТО кондиционеров/); }],
  ['locations', async (p) => { await go(p); await click(p, t.loc); const l = p.getByRole('button', { name: t.list }).first();
    if (await l.isVisible().catch(() => false)) await l.click(); await settle(p, 1500); }],
  ['map', async (p) => { await go(p); await click(p, t.loc); await click(p, t.map, 3500); }],
  ['object', async (p) => { await go(p); await click(p, t.loc); const l = p.getByRole('button', { name: t.list }).first();
    if (await l.isVisible().catch(() => false)) await l.click(); await settle(p, 1200); await click(p, t.bc, 2500); }],
  ['object-equipment', async (p) => { await go(p); await click(p, t.loc); const l = p.getByRole('button', { name: t.list }).first();
    if (await l.isVisible().catch(() => false)) await l.click(); await settle(p, 1200); await click(p, t.bc, 2500);
    await (await scrollFind(p, /ИБП серверной 10 кВА/)).scrollIntoViewIfNeeded().catch(() => {}); await settle(p, 800); }],
  ['contractors', async (p) => { await go(p); await click(p, t.contr); }],
  ['contractor-card', async (p) => { await go(p); await click(p, t.contr); await (await scrollFind(p, /^Huaxin FM/)).click();
    await settle(p, 2500); }],
  ['reports', async (p) => { await go(p); await click(p, t.rep, 3000); }],
  ['history', async (p) => { await go(p); await click(p, t.hist, 2500); }],
  ['profile', async (p) => { await go(p); await click(p, t.prof, 1500); }],
  ['company', async (p) => { await go(p); await click(p, t.prof, 1200); await click(p, t.company, 2200); }],
  ['regions', async (p) => { await go(p); await click(p, t.prof, 1200); await click(p, t.company, 2000);
    await (await scrollFind(p, t.regions)).click(); await settle(p, 2000); }],
  ['audit', async (p) => { await go(p); await click(p, t.prof, 1200); await click(p, t.company, 2000);
    await (await scrollFind(p, t.audit)).click(); await settle(p, 2500); }],
  ['zone', async (p) => { await go(p); await click(p, t.prof, 1200); await click(p, t.company, 2000);
    await (await scrollFind(p, t.m2)).click(); await settle(p, 800); await click(p, t.zone, 2200); }],
  ['settings', async (p) => { await go(p); await click(p, t.prof, 1200); await click(p, t.settings, 1800); }],
  ['plan-floor', async (p) => { await openApp(p, base, `#/objects/${uuid(10)}/floors/${uuid(601)}`); await settle(p, 4500); }],
];

const results = [];
for (const lang of LANG === 'all' ? ['ru', 'en'] : [LANG]) {
  for (const w of WIDTHS) {
    if (lang === 'en' && LANG === 'all' && ![412, 1280].includes(w)) continue;
    const ctx = await browser.newContext({ viewport: { width: w, height: H[w] ?? 900 }, locale: lang === 'en' ? 'en-US' : 'ru-RU' });
    const page = await ctx.newPage();
    const errs = [];
    page.on('pageerror', (e) => errs.push(String(e.message).slice(0, 160)));
    await login(page, base, USERS.admin);
    if (lang === 'en') {
      // Язык профиля → английский (на устройстве и в профиле).
      await go(page);
      const en = page.getByRole('button', { name: /^EN$/ }).first();
      if (await en.isVisible().catch(() => false)) await en.click();
      // Нет переключателя (телефон): язык уже английский — браузер en-US, в профиле язык не задан.
      await settle(page, 2500);
    }
    for (const [key, run] of SCREENS(T[lang])) {
      if (ONLY && !key.startsWith(ONLY)) continue;
      const file = `${lang}-${w}-${key}.png`;
      try {
        await run(page);
        await page.screenshot({ path: join(OUT, file) });
        results.push(`✅ ${file}`);
      } catch (e) {
        await page.screenshot({ path: join(OUT, file.replace('.png', '-error.png')) }).catch(() => {});
        results.push(`❌ ${file}: ${String(e.message).split('\n')[0].slice(0, 120)}`);
      }
      await page.keyboard.press('Escape').catch(() => {});
    }
    if (errs.length) results.push(`⚠️ ${lang}-${w} JS: ${[...new Set(errs)].join(' | ')}`);
    await ctx.close();
  }
}
await browser.close();
web.stop();
backend.stop();
console.log(results.join('\n'));
process.exit(0);
