// Снимки НОВЫХ экранов шага на локальной базе — ПРЕДПРОСМОТР до применения
// миграции в рабочей базе (шаг 16: 0015; шаг 17: 0016).
//
//   1. Локальный бэкенд (local_backend.mjs): PostgreSQL hh_test после
//      `bash tools/db_test/run.sh` (все миграции + демо-данные) и PostgREST.
//      Входы — демо-пользователи локальной базы (manager@ / executor@ /
//      requester@example.com, без пароля). Рабочая база не трогается.
//   2. Веб-версия собирается в build/web_local с адресом локального бэкенда
//      (ключ карты — из env.json, если есть; в лог не печатается).
//   3. Снимки — в docs/screens/preview/ (папка перезаписывается) + README.md.
//
// Запуск: cd tools/screens && PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers \
//   POSTGREST=<путь к postgrest> node local_screens.mjs [--no-build] [--only=<ключ>]
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { startLocalBackend } from './local_backend.mjs';

const ROOT = resolve(import.meta.dirname, '../..');
const OUT = resolve(process.argv.find((a) => a.startsWith('--out='))?.slice(6)
  ?? join(ROOT, process.argv.includes('--step=17') ? 'docs/screens/preview17' : 'docs/screens/preview'));
const WEB = join(ROOT, 'build/web_local');
const ONLY = process.argv.find((a) => a.startsWith('--only='))?.slice(7);
const STEP = process.argv.find((a) => a.startsWith('--step='))?.slice(7) ?? '16';
const PREVIEW_NOTE = `ПРЕДПРОСМОТР: локальная база с миграциями 0001–${STEP === '17' ? '0016' : '0015'} и демо-данными (demo.sql + demo_history.sql), не рабочая база`;
const USERS = { manager: 'manager@example.com', admin: 'manager@example.com', manager2: 'manager2@example.com',
  executor: 'executor@example.com', requester: 'requester@example.com' };
const uuid = (n) => 'de300000-0000-4000-8000-' + String(n).padStart(12, '0');

const backend = await startLocalBackend({ port: 54321 });

if (!process.argv.includes('--no-build')) {
  const defines = [`--dart-define=SUPABASE_URL=${backend.url}`, `--dart-define=SUPABASE_ANON_KEY=${backend.anonKey}`,
    '--dart-define=VOICE_MOCK=true'];
  const envJson = join(ROOT, 'env.json');
  if (existsSync(envJson)) {
    const key = JSON.parse(readFileSync(envJson, 'utf8')).MAP_TILE_KEY;
    if (key) defines.push(`--dart-define=MAP_TILE_KEY=${key}`);
  }
  console.log('Сборка веб-версии для локального бэкенда…');
  execFileSync('flutter', ['build', 'web', '--release', '--output', WEB, ...defines],
    { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] });
}

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.ico': 'image/x-icon', '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2', '.css': 'text/css' };
const server = createServer((req, res) => {
  const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let file = join(WEB, path);
  if (!file.startsWith(WEB) || !existsSync(file) || statSync(file).isDirectory()) file = join(WEB, 'index.html');
  res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream' });
  res.end(readFileSync(file));
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const BASE = `http://127.0.0.1:${server.address().port}/`;

// ---------------------------------------------------------------------------
// Помощники (как в screens.mjs)
// ---------------------------------------------------------------------------
const settle = (page, ms = 1500) => page.waitForTimeout(ms);
const ci = (t) => (t instanceof RegExp && !t.flags.includes('i') ? new RegExp(t.source, t.flags + 'i') : t);
const see = (page, text) => page.getByRole('tab', { name: ci(text) })
  .or(page.getByRole('button', { name: ci(text) }))
  .or(page.getByText(ci(text)))
  .or(page.getByLabel(ci(text))).first();
const btn = (page, name) => page.getByRole('button', { name, exact: false }).first();
const profileTab = (page) => page.getByRole('tab', { name: /^Профиль/ })
  .or(page.getByRole('button', { name: /^Профиль/ }))
  .or(page.getByLabel(/^Профиль(, \d+)?$/)).first();

async function openApp(page, path = '') {
  await page.goto(BASE + path, { waitUntil: 'load' });
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 60000 });
  await placeholder.evaluate((el) => el.click());
}

async function login(page, email) {
  await openApp(page);
  const emailBox = page.getByRole('textbox', { name: 'Email' });
  const first = await Promise.race([
    emailBox.waitFor({ timeout: 60000 }).then(() => 'login'),
    profileTab(page).waitFor({ timeout: 60000 }).then(() => 'home'),
  ]);
  if (first === 'home') return;
  const type = async (box, text) => {
    for (let attempt = 0; attempt < 3; attempt++) {
      await box.click();
      await page.waitForTimeout(500);
      await page.keyboard.press('ControlOrMeta+A');
      await page.keyboard.press('Backspace');
      await page.keyboard.type(text, { delay: 20 });
      const len = await page.evaluate(() => document.activeElement?.value?.length ?? -1);
      if (len === text.length) return;
    }
    throw new Error('Не удалось ввести текст в поле входа');
  };
  await type(emailBox, email);
  await type(page.getByRole('textbox', { name: 'Пароль' }), 'local-only');
  await btn(page, 'Войти').click();
  await profileTab(page).waitFor({ timeout: 30000 });
}

async function home(page, path = '') {
  await openApp(page, path);
  await profileTab(page).waitFor({ timeout: 60000 });
  await settle(page, 2500);
}

/** Раздел «ППР»: на ПК — пункт бокового меню, на телефоне — сегмент. */
async function openPpr(page) {
  await home(page);
  const item = page.getByRole('button', { name: /^ППР/ }).or(page.getByRole('tab', { name: /^ППР/ }))
    .or(page.getByText(/^ППР$/)).first();
  await item.click();
  await see(page, /выполнено \d+ из \d+/).waitFor({ timeout: 20000 });
  await settle(page, 1200);
}

async function openPlanCard(page, title = 'ТО кондиционеров') {
  await openPpr(page);
  await btn(page, new RegExp('^' + title)).click();
  await see(page, /История периодов/).waitFor({ timeout: 20000 });
  await settle(page, 1200);
}

async function openLocations(page) {
  await home(page);
  await page.getByRole('button', { name: /^Локации/ }).or(page.getByRole('tab', { name: /^Локации/ }))
    .or(page.getByText(/^Локации$/)).first().click();
  await settle(page, 2000);
  const list = page.getByRole('button', { name: /^Список/ }).or(page.getByText(/^Список$/)).first();
  if (await list.isVisible().catch(() => false)) await list.click();
  await settle(page, 1500);
}

async function openObjectCard(page, name = 'БЦ «Демо»') {
  await openLocations(page);
  await btn(page, new RegExp('^' + name)).click();
  await see(page, /Адрес|Этажи/).waitFor({ timeout: 20000 });
  await settle(page, 2000);
}

async function scrollTo(page, text) {
  const el = see(page, text);
  for (let i = 0; i < 20; i++) {
    if (await el.isVisible().catch(() => false)) {
      await el.scrollIntoViewIfNeeded().catch(() => {});
      return;
    }
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(250);
  }
  throw new Error(`Не найдено: ${text}`);
}

// ---------------------------------------------------------------------------
// Экраны шага 16
// ---------------------------------------------------------------------------
const SCREENS16 = [
  { key: 'ppr-list', title: 'ППР — список планов, сводка за месяц', run: openPpr },
  { key: 'ppr-filters', title: 'ППР — окно «Фильтры»', run: async (page) => {
    await openPpr(page);
    await btn(page, /^Фильтры/).click();
    await see(page, /Статус периода/).waitFor({ timeout: 10000 });
    await settle(page);
  } },
  { key: 'ppr-card', title: 'ППР — карточка плана (история периодов)', run: (p) => openPlanCard(p) },
  { key: 'ppr-card-history', title: 'ППР — карточка плана, чек-лист и история', run: async (page) => {
    await openPlanCard(page);
    await scrollTo(page, /История периодов/);
    await settle(page, 800);
  } },
  { key: 'ppr-task', title: 'Задача периода — карточка заявки «ППР · октябрь · до 31 окт.»', run: async (page) => {
    await openPlanCard(page);
    await btn(page, /ППР · .* · до/).click();
    await see(page, /Принять|Взять в работу|Отправить|Назначить|Чек-лист|Объект/).waitFor({ timeout: 20000 });
    await settle(page, 1500);
  } },
  { key: 'ppr-orders', title: 'Заявки с фильтром «Тип: ППР»', run: async (page) => {
    await home(page, '?rec=ppr');
    // У исполнителя «КлиматСервиса» задач ППР в демо нет — пустой список тоже годится.
    await see(page, /ППР · |Нет заявок|ничего не найдено|Ничего не найдено/).waitFor({ timeout: 20000 });
    await settle(page);
  } },
  { key: 'locations-regions', title: 'Локации по регионам → страна → город', run: async (page) => {
    await openLocations(page);
    await see(page, /ЕВРОПА|Европа/).waitFor({ timeout: 20000 });
  } },
  { key: 'object-picker', title: 'Окно выбора объектов: «Весь регион», «Вся страна», «Весь город»', run: async (page) => {
    await home(page);
    const pill = page.getByRole('button', { name: /^Объект/ }).first();
    if (await pill.isVisible().catch(() => false)) {
      await pill.click();
    } else {
      await btn(page, /^Фильтры/).click();
      await settle(page, 800);
      await btn(page, /^Объект/).click();
    }
    await see(page, /Весь регион|Вся страна/).waitFor({ timeout: 20000 });
    await settle(page);
  } },
  { key: 'object-geo', title: 'Карточка объекта: страна, город, регион', run: async (page) => {
    await openObjectCard(page);
    await scrollTo(page, /Страна/);
  } },
  { key: 'equipment', title: 'Карточка объекта: «Оборудование · N» по системам', run: async (page) => {
    await openObjectCard(page);
    await scrollTo(page, /Оборудование · \d+|ОБОРУДОВАНИЕ/);
    await page.mouse.wheel(0, 300);
    await settle(page, 800);
  } },
  { key: 'asset-card', title: 'Карточка оборудования: паспорт, где стоит, ППР, заявки', run: async (page) => {
    await openObjectCard(page);
    await scrollTo(page, /ИБП серверной 10 кВА/);
    await btn(page, /^ИБП серверной 10 кВА/).click();
    await see(page, /Создать заявку/).waitFor({ timeout: 20000 });
    await settle(page, 1500);
  } },
  { key: 'import-errors', title: 'Импорт оборудования: предпросмотр с ошибками по строкам', run: async (page) => {
    await openObjectCard(page);
    await scrollTo(page, /Импорт из Excel/);
    await btn(page, /Импорт из Excel/).click();
    await settle(page, 1500);
    const csv = join(tmpdir(), 'hh-import-demo.csv');
    writeFileSync(csv, [
      'Название;Помещение;Система;Инвентарный номер;Производитель;Модель;Серийный номер;Дата ввода',
      'Кондиционер №3;Переговорная, 3 этаж;Климат;KL-3-010;Daikin;FTXM25R;DK-1;2025-03-01',
      'Светильник;Нет такой комнаты;Электрика;EL-9-001;Philips;RC132V;PH-1;2025-03-01',
      'Насос;Кухня, 3 этаж;Лифты;PL-3-001;Grundfos;UPS;GR-1;2025-03-01',
      'ИБП;Серверная, 3 этаж;Электрика;ЭЛ-3-001;APC;SRT;AS-1;2025-13-40',
    ].join('\n'));
    const chooser = page.waitForEvent('filechooser', { timeout: 15000 });
    await btn(page, /Выбрать файл/).click();
    await (await chooser).setFiles(csv);
    await see(page, /Импортировать|ошиб/).waitFor({ timeout: 20000 });
    await settle(page, 1500);
  } },
  { key: 'plan-areas', title: 'План этажа: области и номера помещений', run: async (page) => {
    await page.goto('about:blank');
    await openApp(page, `#/objects/${uuid(10)}/floors/${uuid(602)}`);
    await see(page, /На плане · \d/).waitFor({ timeout: 60000 });
    await settle(page, 3000);
    // Приблизить, чтобы были видны подписи «301 · …» в областях.
    for (let i = 0; i < 2; i++) {
      const plus = page.getByRole('button', { name: /Приблизить|Увеличить/ }).first();
      if (await plus.isVisible().catch(() => false)) await plus.click();
      await settle(page, 600);
    }
  } },
  { key: 'reports-regions', title: 'Отчёты: блок «По регионам»', run: async (page) => {
    await home(page);
    await page.getByRole('button', { name: /^Отчёты/ }).or(page.getByRole('tab', { name: /^Отчёты/ })).first().click();
    await settle(page, 3000);
    await scrollTo(page, /По регионам|ПО РЕГИОНАМ/);
    await settle(page, 800);
  } },
  { key: 'regions', title: '«Моя компания» → «Регионы»', run: async (page) => {
    await home(page);
    await profileTab(page).click();
    await settle(page, 1000);
    await btn(page, /^Моя компания/).click();
    await settle(page, 2000);
    await scrollTo(page, /Регионы компании/);
    await btn(page, /Регионы компании/).click();
    await see(page, /Европа/).waitFor({ timeout: 20000 });
    await settle(page);
  } },
  { key: 'region-similar', title: 'Новый регион «Европпа» → «Похоже, такой регион уже есть»', run: async (page) => {
    await home(page);
    await profileTab(page).click();
    await settle(page, 1000);
    await btn(page, /^Моя компания/).click();
    await settle(page, 2000);
    await scrollTo(page, /Регионы компании/);
    await btn(page, /Регионы компании/).click();
    await see(page, /Европа/).waitFor({ timeout: 20000 });
    await btn(page, /^Добавить|Новый регион/).click();
    await settle(page, 800);
    const box = page.getByRole('textbox').first();
    await box.click();
    await page.keyboard.type('Европпа', { delay: 30 });
    await btn(page, /^Сохранить|^Создать|^Готово/).click();
    await see(page, /Похоже/).waitFor({ timeout: 10000 });
    await settle(page);
  } },
];

// ---------------------------------------------------------------------------
// Экраны шага 17 (--step=17): зона доступа, шаблоны, бригады, вид менеджера
// с зоной. В локальной базе hh_test17 перед съёмкой — второй менеджер
// «Менеджер Москва» (manager2@example.com) с зоной «Климат + Сантехника ·
// город Москва» (только локально; в рабочей базе его заводит владелец).
// ---------------------------------------------------------------------------
const PREP17 = `
insert into auth.users(id, email) values ('d0000000-0000-4000-8000-000000000004', 'manager2@example.com')
  on conflict do nothing;
update public.profiles set company_id = '${uuid(1)}', role = 'manager', full_name = 'Менеджер Москва'
 where id = 'd0000000-0000-4000-8000-000000000004';
delete from public.access_zones where profile_id = 'd0000000-0000-4000-8000-000000000004';
insert into public.access_zones(company_id, profile_id, layer_ids, scope_kind, scope_ref)
select '${uuid(1)}', 'd0000000-0000-4000-8000-000000000004',
       array(select id from public.layers where company_id = '${uuid(1)}' and name in ('Климат', 'Сантехника') order by sort),
       'city', 'Москва';
`;

async function openMembers(page) {
  await home(page);
  await profileTab(page).click();
  await settle(page, 1000);
  await btn(page, /^Моя компания/).click();
  await see(page, /Менеджер Москва/).waitFor({ timeout: 20000 });
  await scrollTo(page, /Менеджер Москва/);
  await settle(page, 800);
}

async function openZone(page) {
  await openMembers(page);
  await btn(page, /Менеджер Москва/).click();
  await settle(page, 800);
  await btn(page, /^Зона доступа/).click();
  await see(page, /Вся компания/).waitFor({ timeout: 20000 });
  await settle(page, 1500);
}

const SCREENS17 = [
  { key: 'zone', title: 'Сотрудник → «Зона доступа»: правила (системы × места)', role: 'admin', run: openZone },
  { key: 'zone-templates', title: 'Зона доступа — «Шаблоны»', role: 'admin', run: async (page) => {
    await openZone(page);
    await btn(page, /Шаблоны/).click();
    await settle(page, 1200);
  } },
  { key: 'crews', title: 'Карточка подрядчика Huaxin FM → «Бригады»', role: 'admin', run: async (page) => {
    await home(page);
    await page.getByRole('button', { name: /^Подрядчики/ }).or(page.getByRole('tab', { name: /^Подрядчики/ }))
      .or(page.getByText(/^Подрядчики$/)).first().click();
    await settle(page, 2000);
    await scrollTo(page, /Huaxin FM/);
    await btn(page, /^Huaxin FM/).click();
    await settle(page, 2000);
    await scrollTo(page, /Бригады|БРИГАДЫ/);
    await page.mouse.wheel(0, 300);
    await settle(page, 1000);
  } },
  { key: 'restricted-requests', title: 'Менеджер с зоной «Климат, Сантехника · Москва» — заявки', role: 'manager2', run: async (page) => {
    await home(page);
    await settle(page, 1500);
  } },
  { key: 'restricted-locations', title: 'Менеджер с зоной — «Локации» (только Москва)', role: 'manager2', run: openLocations },
  { key: 'restricted-contractors', title: 'Менеджер с зоной — подрядчики (только с закреплениями в зоне)', role: 'manager2', run: async (page) => {
    await home(page);
    await page.getByRole('button', { name: /^Подрядчики/ }).or(page.getByRole('tab', { name: /^Подрядчики/ }))
      .or(page.getByText(/^Подрядчики$/)).first().click();
    await settle(page, 2500);
  } },
];

/** PDF отчёта: перехватываем Blob, который веб-версия отдаёт в окно печати. */
async function capturePdf(page) {
  await home(page);
  await page.getByRole('button', { name: /^Отчёты/ }).or(page.getByRole('tab', { name: /^Отчёты/ })).first().click();
  await settle(page, 3000);
  await page.getByRole('button', { name: /Печать|Распечатать|PDF/ }).first().click();
  for (let i = 0; i < 120; i++) {
    const has = await page.evaluate(() => !!window.__pdfBlob);
    if (has) break;
    await page.waitForTimeout(500);
  }
  const b64 = await page.evaluate(async () => {
    const blob = window.__pdfBlob;
    if (!blob) return null;
    const buf = new Uint8Array(await blob.arrayBuffer());
    let s = '';
    for (let i = 0; i < buf.length; i += 0x8000) s += String.fromCharCode(...buf.subarray(i, i + 0x8000));
    return btoa(s);
  });
  if (!b64) {
    await page.screenshot({ path: join(OUT, 'manager-report-pdf-error.png') }).catch(() => {});
    throw new Error('PDF не получен (снимок экрана — manager-report-pdf-error.png)');
  }
  const pdf = join(tmpdir(), 'hh-report.pdf');
  writeFileSync(pdf, Buffer.from(b64, 'base64'));
  return pdf;
}

const RUNS = STEP === '17' ? [
  // После 0016 демо-менеджер — администратор «Демо БЦ» (в компании не было администратора).
  { role: 'admin', label: 'Администратор', width: 1280, height: 800 },
  { role: 'admin', label: 'Администратор', width: 412, height: 915 },
  { role: 'manager2', label: 'Менеджер с зоной', width: 1280, height: 800 },
  { role: 'manager2', label: 'Менеджер с зоной', width: 412, height: 915 },
] : [
  { role: 'manager', label: 'Менеджер', width: 1280, height: 800 },
  { role: 'manager', label: 'Менеджер', width: 412, height: 915 },
  { role: 'manager', label: 'Менеджер', width: 360, height: 780, only: ['ppr-list', 'locations-regions'] },
  { role: 'executor', label: 'Исполнитель', width: 412, height: 915, only: ['ppr-list', 'ppr-orders'] },
];
const SCREENS = STEP === '17' ? SCREENS17 : SCREENS16;
if (STEP === '17') {
  execFileSync('sudo', ['-u', 'postgres', 'psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-d',
    process.env.HH_TEST_DB ?? 'hh_test', '-c', PREP17], { stdio: 'inherit' });
}

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
const results = [];
const browser = await chromium.launch();
try {
  for (const r of RUNS) {
    const ctx = await browser.newContext({ viewport: { width: r.width, height: r.height }, locale: 'ru-RU', deviceScaleFactor: 1 });
    await ctx.addInitScript(() => {
      const orig = URL.createObjectURL;
      URL.createObjectURL = function (obj) {
        try { if (obj && obj.type === 'application/pdf') window.__pdfBlob = obj; } catch {}
        return orig.call(URL, obj);
      };
      window.print = () => {};
    });
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e.message).slice(0, 200)));
    try {
      await login(page, USERS[r.role]);
    } catch (e) {
      results.push({ ...r, title: 'Вход', ok: false, note: String(e.message).split('\n')[0] });
      await ctx.close();
      continue;
    }
    for (const s of SCREENS) {
      if (ONLY && !s.key.startsWith(ONLY)) continue;
      if (r.only && !r.only.includes(s.key)) continue;
      if (s.role && s.role !== r.role) continue;
      const name = `${r.role}-${r.width}-${s.key}.png`;
      try {
        await s.run(page);
        await page.screenshot({ path: join(OUT, name) });
        results.push({ ...r, title: s.title, ok: true, file: name });
      } catch (e) {
        await page.screenshot({ path: join(OUT, name.replace('.png', '-error.png')) }).catch(() => {});
        results.push({ ...r, title: s.title, ok: false, file: name.replace('.png', '-error.png'),
          note: String(e.message).split('\n')[0].slice(0, 200) });
      }
      await page.keyboard.press('Escape').catch(() => {});
    }
    // PDF — один раз, у менеджера на ПК.
    if (STEP !== '17' && r.role === 'manager' && r.width === 1280 && (!ONLY || 'report-pdf'.startsWith(ONLY))) {
      const name = 'manager-report-pdf-page1.png';
      try {
        const pdf = await capturePdf(page);
        execFileSync('pdftoppm', ['-png', '-r', '80', '-f', '1', '-l', '1', '-singlefile', pdf, join(OUT, 'manager-report-pdf-page1')]);
        const pages = execFileSync('pdfinfo', [pdf], { encoding: 'utf8' }).match(/Pages:\s+(\d+)/)?.[1];
        results.push({ ...r, title: 'PDF отчёта — первая страница (файл из веб-версии)', ok: true, file: name,
          note: `страниц в PDF: ${pages ?? '?'}` });
      } catch (e) {
        results.push({ ...r, title: 'PDF отчёта — первая страница', ok: false, note: String(e.message).split('\n')[0] });
      }
    }
    if (errors.length) results.push({ ...r, title: 'Ошибки JavaScript', ok: false, note: errors.join(' | ') });
    await ctx.close();
  }
} finally {
  await browser.close();
  server.close();
  backend.stop();
}

for (const f of readdirSync(OUT).filter((f) => f.endsWith('.png'))) {
  try { execFileSync('pngquant', ['--force', '--skip-if-larger', '--quality=65-90', '--ext', '.png', join(OUT, f)]); } catch {}
}
const mark = (ok) => (ok === true ? '✅' : ok === false ? '❌' : '—');
const kb = (f) => (f && existsSync(join(OUT, f)) ? Math.round(statSync(join(OUT, f)).size / 1024) + ' КБ' : '');
writeFileSync(join(OUT, 'README.md'), [
  `# ПРЕДПРОСМОТР новых экранов (шаг ${STEP})`,
  '',
  `Снято: ${new Date().toISOString().slice(0, 16).replace('T', ' ')} UTC, \`tools/screens/local_screens.mjs\`.`,
  '',
  `⚠️ ${PREVIEW_NOTE}. После слияния и «Apply migration» те же экраны будут на рабочей базе.`,
  '',
  '| Роль | Ширина | Экран | Итог | Файл | Примечание |',
  '|---|---|---|---|---|---|',
  ...results.map((x) => `| ${x.label} | ${x.width} | ${x.title} | ${mark(x.ok)} | ${x.file ? `[${x.file}](${x.file}) ${kb(x.file)}` : ''} | ${x.note ?? ''} |`),
  '',
].join('\n'));
const bad = results.filter((x) => x.ok === false);
console.log(`Готово: ${results.filter((x) => x.ok).length} снимков, проблем: ${bad.length}`);
for (const x of bad) console.log(`  ❌ ${x.label} ${x.width} — ${x.title}: ${x.note ?? ''}`);
process.exit(0);
