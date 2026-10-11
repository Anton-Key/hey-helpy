// Общие помощники сквозных тестов (tools/e2e): веб-сервер сборки
// build/web_e2e, вход, поиск по доступности Flutter, запросы к локальной базе.
import { chromium } from '../screens/node_modules/playwright/index.mjs';
import { execFileSync } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';

export { chromium };
export const ROOT = resolve(import.meta.dirname, '../..');
export const WEB = join(ROOT, process.env.HH_WEB ?? 'build/web_e2e');
export const DB = process.env.HH_TEST_DB ?? 'hh_test';
export const uuid = (n) => 'de300000-0000-4000-8000-' + String(n).padStart(12, '0');
export const COMPANY = uuid(1);
export const USERS = {
  admin: 'manager@example.com', manager2: 'manager2@example.com',
  executor: 'executor@example.com', requester: 'requester@example.com',
};

/** Запрос к локальной базе от postgres (проверки итогов). */
export function sql(q) {
  return execFileSync('sudo', ['-u', 'postgres', 'psql', '-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', q],
    { encoding: 'utf8' }).trim();
}

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.ico': 'image/x-icon', '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2', '.css': 'text/css' };

export async function startWeb() {
  if (!existsSync(join(WEB, 'index.html'))) throw new Error(`Нет сборки ${WEB}: bash tools/e2e/build.sh`);
  const server = createServer((req, res) => {
    const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    let file = join(WEB, path);
    if (!file.startsWith(WEB) || !existsSync(file) || statSync(file).isDirectory()) file = join(WEB, 'index.html');
    res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream' });
    res.end(readFileSync(file));
  });
  await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
  return { base: `http://127.0.0.1:${server.address().port}/`, stop: () => server.close() };
}

export const ci = (t) => (t instanceof RegExp && !t.flags.includes('i') ? new RegExp(t.source, t.flags + 'i') : t);
/** Первый видимый элемент с текстом / подписью (вкладка, кнопка, текст). */
export const see = (page, text) => page.getByRole('tab', { name: ci(text) })
  .or(page.getByRole('button', { name: ci(text) }))
  .or(page.getByText(ci(text)))
  .or(page.getByLabel(ci(text))).first();
export const btn = (page, name) => page.getByRole('button', { name, exact: false }).first();
export const profileTab = (page) => page.getByRole('tab', { name: /^Профиль/ })
  .or(page.getByRole('button', { name: /^Профиль/ }))
  .or(page.getByLabel(/^Профиль(, \d+)?$/)).first();
export const settle = (page, ms = 1200) => page.waitForTimeout(ms);

export async function openApp(page, base, path = '') {
  // Смена только «#…» не перезагружает страницу — сначала пустая страница.
  if (page.url().startsWith(base)) await page.goto('about:blank');
  await page.goto(base + path, { waitUntil: 'load' });
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 60000 });
  await placeholder.evaluate((el) => el.click());
}

/** Ввод текста в поле Flutter (фокус, очистка, печать, проверка длины). */
export async function typeInto(page, box, text) {
  for (let attempt = 0; attempt < 3; attempt++) {
    await box.click();
    await page.waitForTimeout(400);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(text, { delay: 15 });
    const len = await page.evaluate(() => document.activeElement?.value?.length ?? -1);
    if (len === text.length) return;
  }
  throw new Error('Не удалось ввести текст');
}

export async function login(page, base, email) {
  await openApp(page, base);
  const emailBox = page.getByRole('textbox', { name: 'Email' });
  const first = await Promise.race([
    emailBox.waitFor({ timeout: 60000 }).then(() => 'login'),
    profileTab(page).waitFor({ timeout: 60000 }).then(() => 'home'),
  ]);
  if (first === 'home') return;
  await typeInto(page, emailBox, email);
  await typeInto(page, page.getByRole('textbox', { name: /Пароль|Password/ }), 'local-only');
  await btn(page, /^(Войти|Sign in|Log in)/).click();
  await profileTab(page).waitFor({ timeout: 30000 });
  await settle(page, 1500);
}

export async function home(page, base, path = '') {
  await openApp(page, base, path);
  await profileTab(page).waitFor({ timeout: 60000 });
  await settle(page, 2000);
}

/** Пункт бокового меню (ПК) или сегмент (телефон). */
export async function section(page, re) {
  await page.getByRole('button', { name: re }).or(page.getByRole('tab', { name: re }))
    .or(page.getByText(re)).first().click();
  await settle(page, 1800);
}

export async function scrollTo(page, text, { max = 25 } = {}) {
  const el = see(page, text);
  const vp = page.viewportSize();
  await page.mouse.move(vp.width * 0.6, vp.height * 0.6);
  for (let i = 0; i < max; i++) {
    if (await el.isVisible().catch(() => false)) {
      await el.scrollIntoViewIfNeeded().catch(() => {});
      return el;
    }
    await page.mouse.wheel(0, 450);
    await page.waitForTimeout(250);
  }
  throw new Error(`Не найдено на экране: ${text}`);
}

/** Ждать, пока условие в базе станет истинным (до timeout мс). */
export async function waitDb(q, expect, timeout = 15000) {
  const t0 = Date.now();
  let last;
  while (Date.now() - t0 < timeout) {
    last = sql(q);
    if (typeof expect === 'function' ? expect(last) : last === String(expect)) return last;
    await new Promise((d) => setTimeout(d, 400));
  }
  throw new Error(`База: «${q.slice(0, 80)}…» = ${last}, ждали ${expect}`);
}

export function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

/**
 * Нажатия мышью мимо слоя доступности Flutter: с включённой доступностью
 * клик по узлу холста превращается в «нажатие по центру узла» (план этажа
 * получал точку 0.5, 0.5). На время действия слой не принимает мышь.
 */
export async function raw(page, fn) {
  await page.evaluate(() => {
    for (const el of document.querySelectorAll('flt-semantics-host')) el.style.pointerEvents = 'none';
  });
  try {
    await fn();
  } finally {
    await page.evaluate(() => {
      for (const el of document.querySelectorAll('flt-semantics-host')) el.style.pointerEvents = '';
    });
  }
}
