// Скриншоты веб-версии Hey Helpy для отчётов (команда /screens).
//
// Что делает:
//   1. Собирает веб-версию (flutter build web) с ключами из env.json и VOICE_MOCK=true —
//      в Playwright нет микрофона, голос «говорит» заготовленную фразу
//      (флаг --no-build — взять уже собранную build/web).
//   2. Поднимает локальный сервер и по очереди входит менеджером, исполнителем
//      и заявителем (логины — только из .env.demo в корне репозитория).
//   3. Снимает главные экраны (окно выбора подрядчика и голосовую заявку — у менеджера) в docs/screens/latest/ (папка очищается),
//      пишет там README.md с таблицей: что снято, что не открылось и почему.
//
// Пароли нигде не печатаются. Данные не меняет: только вход и просмотр (экран «Уведомления»
// сам отмечает их прочитанными у демо-пользователя, окно выбора подрядчика закрывается без назначения,
// голосовая заявка не отправляется — снимается только экран подтверждения).
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '../..');
const OUT = join(ROOT, 'docs/screens/latest');
const WEB = join(ROOT, 'build/web');
const MAX_PNG = 300 * 1024;

// Демо-заявка из supabase/seed/demo_history.sql (её видят все три роли).
const DEMO_ORDER = 'Шумит вентилятор в переговорной';

// Окно выбора подрядчика — на заявке из демо-истории (не на тестовых заявках в базе).
// Сначала эта («Назначена», Электрика — видно закреплённого подрядчика), иначе первая
// из демо-истории в статусе, где менеджер может назначить подрядчика.
const PICKER_ORDER = 'Нет питания на розетках в переговорной';
const DEMO_TITLES = [...readFileSync(join(ROOT, 'supabase/seed/demo_history.sql'), 'utf8')
  .matchAll(/^\s*\(\d{3},'\w+','\w+','([^']+)'/gm)].map((m) => m[1]);
const ASSIGNABLE = /(Новая|Назначена|Возвращена)\s*$/;

// ---------------------------------------------------------------------------
// Карта «Локации»: объекты шага 13 из demo_history.sql (id …011–014, заявки 211–220).
// Пока Refresh demo после merge не запущен, их нет в базе — тогда снимки карты
// менеджера показывают их как ПРЕДПРОСМОТР: Playwright добавляет эти записи
// в ответ сервера (только в браузере, база не меняется), в README — пометка.
// ---------------------------------------------------------------------------
const SEED = readFileSync(join(ROOT, 'supabase/seed/demo_history.sql'), 'utf8');
const SEED_IDS = Object.fromEntries([...SEED.matchAll(/(c_obj_\w+)\s+constant uuid := '([0-9a-f-]+)'/g)]
  .map((m) => [m[1], m[2]]));
const SEED_OBJECTS = [...SEED.matchAll(
  /\((c_obj_\w+),\s*c_company,\s*'([^']+)',\s*'(\w+)',\s*'([^']+)',\s*([\d.]+),\s*([\d.]+),\s*(\d+)\)/g)]
  .map((m) => ({ id: SEED_IDS[m[1]], company_id: 'de300000-0000-4000-8000-000000000001', name: m[2],
    type: m[3], address: m[4], lat: +m[5], lng: +m[6], geofence_radius_m: +m[7],
    created_at: '2026-10-01T00:00:00Z' }));
const uuid = (n) => 'de300000-0000-4000-8000-' + String(n).padStart(12, '0');
const SEED_PLACE_OBJ = Object.fromEntries([...SEED.matchAll(/^\s*\((\d{2}), (\d{2}), '[^']+'\)/gm)]
  .map((m) => [m[1], uuid(m[2])]));
const SEED_ORDERS = [...SEED.matchAll(
  /^\s*\((2[1-4]\d),'\w+','(\d+)','(?:[^']|'')*','(?:[^']|'')*','(\w+)','(\w+)','\w+','\w+',(\d+),(\d+),(?:null|\d+),(?:null|\d+),(?:null|\d+),(\d+),/gm)]
  .map((m) => {
    const today = new Date(); today.setUTCHours(0, 0, 0, 0);
    const created = today.getTime() - +m[5] * 864e5 + +m[6] * 36e5;
    return { id: uuid(m[1]), object_id: SEED_PLACE_OBJ[m[2]], priority: m[3], status: m[4],
      due_at: new Date(created + +m[7] * 36e5).toISOString() };
  });
let mapPreview = false;

// Подмешать объекты и заявки шага 13 в ответы сервера (если их ещё нет в базе).
async function routeMapPreview(page) {
  mapPreview = false;
  const merge = (extra) => async (route) => {
    const url = decodeURIComponent(route.request().url());
    const res = await route.fetch();
    let body = await res.text();
    try {
      const rows = JSON.parse(body);
      const listQuery = Array.isArray(rows) && !/[?&]id=eq\./.test(url) &&
        (!url.includes('work_orders') || url.includes('select=id,object_id,status,priority,due_at'));
      if (listQuery && !rows.some((r) => r.id === extra[0].id)) {
        body = JSON.stringify([...rows, ...extra]);
        mapPreview = true;
      }
    } catch {}
    await route.fulfill({ response: res, body });
  };
  await page.route('**/rest/v1/objects?*', merge(SEED_OBJECTS));
  await page.route('**/rest/v1/work_orders?*', merge(SEED_ORDERS));
}

async function unrouteMapPreview(page) {
  await page.unroute('**/rest/v1/objects?*');
  await page.unroute('**/rest/v1/work_orders?*');
}

// Ждать, пока загрузятся плитки подложки (CARTO или OSM): нет запросов в полёте 1,5 с.
async function waitTiles(page, timeout = 25000) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    if (page.tilesPending === 0 && Date.now() - page.tilesLastDone > 1500 && page.tilesLoaded > 0) return;
    await page.waitForTimeout(250);
  }
  if (!page.tilesLoaded) throw new Error('Плитки карты не загрузились (нет доступа к серверу плиток?)');
}

function trackTiles(page) {
  page.tilesPending = 0;
  page.tilesLoaded = 0;
  page.tilesLastDone = 0;
  const isTile = (r) => /basemaps\.cartocdn\.com|tile\.openstreetmap\.org/.test(r.url());
  page.on('request', (r) => { if (isTile(r)) page.tilesPending++; });
  const done = (ok) => (r) => {
    if (!isTile(r)) return;
    page.tilesPending = Math.max(0, page.tilesPending - 1);
    page.tilesLastDone = Date.now();
    if (ok) page.tilesLoaded++;
  };
  page.on('requestfinished', done(true));
  page.on('requestfailed', done(false));
}

// Вкладка «Локации» → «Карта».
async function openMap(page, preview) {
  if (preview) await routeMapPreview(page);
  await home(page);
  await nav(page, 'Локации').click();
  await settle(page, 1200);
  await page.getByRole('button', { name: 'Карта', exact: true }).first().click();
  await see(page, /Объекты на карте|Поиск по названию/).waitFor({ timeout: 20000 });
  await settle(page, 1500);
  await waitTiles(page);
}

const previewNote = (text) => (mapPreview
  ? `${text}. ПРЕДПРОСМОТР: 4 объекта и 10 заявок шага 13 подставлены в ответ сервера из demo_history.sql — в базе появятся после Refresh demo`
  : text);

// ---------------------------------------------------------------------------
// Логины: .env.demo (KEY=VALUE, строки с # — комментарии)
// ---------------------------------------------------------------------------
const ENV_FILE = join(ROOT, '.env.demo');
const NEED = ['DEMO_MANAGER_EMAIL', 'DEMO_MANAGER_PASSWORD', 'DEMO_EXECUTOR_EMAIL',
  'DEMO_EXECUTOR_PASSWORD', 'DEMO_REQUESTER_EMAIL', 'DEMO_REQUESTER_PASSWORD'];

function readEnv(file) {
  const out = {};
  for (const raw of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const i = line.indexOf('=');
    if (i < 0) continue;
    let v = line.slice(i + 1).trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    out[line.slice(0, i).trim()] = v;
  }
  return out;
}

if (!existsSync(ENV_FILE)) {
  console.error('Нет файла .env.demo в корне репозитория. Нужны строки: ' + NEED.join(', '));
  process.exit(2);
}
const env = readEnv(ENV_FILE);
const missing = NEED.filter((k) => !env[k]);
if (missing.length) {
  console.error('В .env.demo не заполнено: ' + missing.join(', '));
  process.exit(2);
}

// ---------------------------------------------------------------------------
// Сборка и локальный сервер
// ---------------------------------------------------------------------------
if (!process.argv.includes('--no-build')) {
  if (!existsSync(join(ROOT, 'env.json'))) {
    console.error('Нет env.json (SUPABASE_URL, SUPABASE_ANON_KEY) — без него сайт не подключится к базе.');
    process.exit(2);
  }
  console.log('Сборка веб-версии…');
  execFileSync('flutter', ['build', 'web', '--release', '--dart-define-from-file=env.json',
    '--dart-define=VOICE_MOCK=true'],
    { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] });
}
if (!existsSync(join(WEB, 'index.html'))) {
  console.error('Нет build/web/index.html — сначала соберите веб-версию.');
  process.exit(2);
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
// Действия в приложении (через дерево доступности Flutter)
// ---------------------------------------------------------------------------
async function openApp(page) {
  await page.goto(BASE, { waitUntil: 'load' });
  // Flutter строит дерево доступности по нажатию на скрытую кнопку.
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 60000 });
  await placeholder.evaluate((el) => el.click());
}

const btn = (page, name) => page.getByRole('button', { name, exact: false }).first();
const settle = (page, ms = 1500) => page.waitForTimeout(ms);
// Нижнее меню у Flutter — вкладки (tab) с подписью, заявки и пункты — кнопки, в имени
// которых весь их текст; обычный текст — отдельными узлами. Ищем во всех трёх.
// Текст внутри блоков (группы, шторки) Flutter отдаёт подписью узла
// (aria-label), а не текстом — ищем и там. Подписи секций в новом дизайне
// прописные («СРОЧНОСТЬ»): регулярные выражения — без учёта регистра.
const ci = (text) => (text instanceof RegExp && !text.flags.includes('i')
  ? new RegExp(text.source, text.flags + 'i') : text);
const see = (page, text) => page.getByRole('tab', { name: ci(text) })
  .or(page.getByRole('button', { name: ci(text) }))
  .or(page.getByText(ci(text)))
  .or(page.getByLabel(ci(text))).first();
const profileTab = (page) => page.getByRole('tab', { name: 'Профиль' });

async function login(page, email, password) {
  await openApp(page);
  const emailBox = page.getByRole('textbox', { name: 'Email' });
  // Уже вошли (сессия сохранилась) — сразу главный экран.
  const first = await Promise.race([
    emailBox.waitFor({ timeout: 60000 }).then(() => 'login'),
    profileTab(page).waitFor({ timeout: 60000 }).then(() => 'home'),
  ]);
  if (first === 'home') return;
  // fill() не всегда доходит до поля Flutter: нажать на поле и набрать по буквам.
  // Первая буква теряется, пока Flutter ставит фокус, — пауза и проверка длины.
  const type = async (box, text) => {
    for (let attempt = 0; attempt < 3; attempt++) {
      await box.click();
      await page.waitForTimeout(500);
      await page.keyboard.press('ControlOrMeta+A');
      await page.keyboard.press('Backspace');
      await page.keyboard.type(text, { delay: 30 });
      const len = await page.evaluate(() => document.activeElement?.value?.length ?? -1);
      if (len === text.length) return;
    }
    throw new Error('Не удалось ввести текст в поле входа');
  };
  await type(emailBox, email);
  await type(page.getByRole('textbox', { name: 'Пароль' }), password);
  await btn(page, 'Войти').click();
  await profileTab(page).waitFor({ timeout: 30000 });
}

async function home(page) {
  await openApp(page);
  await profileTab(page).waitFor({ timeout: 60000 });
  await settle(page, 2500);
}

// Фильтр списка заявок хранится на устройстве (localStorage, ключ
// flutter.orders_filter.<uid>) — после снимков с фильтром его убираем,
// чтобы остальные снимки видели полный список.
async function resetOrderFilter(page) {
  await page.evaluate(() => {
    for (const k of Object.keys(localStorage)) {
      if (k.startsWith('flutter.orders_filter.')) localStorage.removeItem(k);
    }
  }).catch(() => {});
}

// Главный экран по ссылке с фильтром (`#/?pri=critical&…`) — как ссылка от коллеги.
async function homeWith(page, query) {
  await page.goto('about:blank');
  await page.goto(`${BASE}#/?${query}`, { waitUntil: 'load' });
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 60000 });
  await placeholder.evaluate((el) => el.click());
  await profileTab(page).waitFor({ timeout: 60000 });
  await settle(page, 2500);
}

// «Таблетка» фильтра по подписи (у активной — «Статус: Новая +1»).
// Имя узла — подпись таблетки и её текст через перевод строки.
const chip = (page, label) => page.getByRole('button', { name: new RegExp(`^${label}(?=:|\\s|$)`) }).first();

// Закрыть окно фильтра без «Применить» (Esc; на всякий случай — второй раз для календаря).
async function closePicker(page) {
  await page.keyboard.press('Escape').catch(() => {});
  await settle(page, 400);
  await page.keyboard.press('Escape').catch(() => {});
  await settle(page, 400);
}

const nav = (page, label) => page.getByRole('tab', { name: label })
  .or(page.getByRole('button', { name: label, exact: true })).first();

async function openVoice(page) {
  await home(page);
  await page.getByRole('button', { name: 'Нажми и говори' }).first().click();
  await see(page, 'очень жарко').waitFor({ timeout: 20000 });
  await settle(page, 1000);
}

// Экран «Проверьте заявку» из голосовой заявки (VOICE_MOCK). «Отправить» не нажимаем.
async function openConfirm(page) {
  await openVoice(page);
  await btn(page, 'Готово').click();
  await see(page, 'Проверьте заявку').waitFor({ timeout: 20000 });
  await settle(page, 2000);
}

// Когда появилось сообщение (для проверки, что оно исчезает само).
let messageShownAt = 0;
// Карточка сообщения в дереве доступности Flutter — группа с подписью (liveRegion).
const messageLocator = (page) =>
  page.getByRole('group', { name: 'Напишите, что случилось' }).first();

const SCREENS = [
  { key: 'requests', title: 'Список заявок', run: async (p) => { await home(p); } },
  // Список, прокрученный до конца: последняя карточка не под плавающими кнопками.
  { key: 'requests-end', title: 'Список заявок — конец списка', run: async (p) => {
      await home(p);
      const vp = p.viewportSize();
      await p.mouse.move(vp.width / 3, vp.height / 2);
      for (let i = 0; i < 15; i++) { await p.mouse.wheel(0, 2000); await p.waitForTimeout(150); }
      await settle(p);
    } },
  // Строка фильтров с активными таблетками — открыта по ссылке с параметрами
  // (заодно проверка, что ссылка применяет фильтр). Фильтр потом убирается.
  { key: 'filters-active', title: 'Заявки — фильтры по ссылке: срочность, статус «Просрочено» и др., сортировка по срочности', run: async (p) => {
      await homeWith(p, 'pri=critical,high&st=overdue,new,assigned,in_progress&sort=priority');
      // Активная таблетка: «Срочность: Критический +1» — значит, ссылка применилась.
      await p.getByRole('button', { name: /^Срочность: Критический \+1/ }).first().waitFor({ timeout: 15000 });
      await see(p, /Найдено \d+ из \d+/).waitFor({ timeout: 15000 });
      return 'ссылка #/?pri=critical,high&st=overdue,new,assigned,in_progress&sort=priority; группы по срочности';
    }, after: async (p) => { await resetOrderFilter(p); } },
  // Окно фильтра «Статус»: на 412 — шторка, на 1280 — выпадающее окно под таблеткой.
  // Отмечаются 2 пункта, окно закрывается без «Применить».
  { key: 'filter-picker', title: 'Окно фильтра «Статус» (412 — шторка, 1280 — выпадающее окно)', managerOnly: true, run: async (p) => {
      await home(p);
      await chip(p, 'Статус').click();
      await see(p, 'Применить').waitFor({ timeout: 10000 });
      await settle(p, 600);
      await p.getByRole('button', { name: 'Просрочено', exact: true }).last().click();
      await p.getByRole('button', { name: 'Новая', exact: true }).last().click();
      await see(p, 'Применить (2)').waitFor({ timeout: 5000 });
      await settle(p, 800);
      return p.viewportSize().width >= 900
        ? 'выпадающее окно под таблеткой; отмечены «Просрочено» и «Новая», закрыто без применения'
        : 'шторка; отмечены «Просрочено» и «Новая», закрыто без применения';
    }, after: async (p) => { await closePicker(p); await resetOrderFilter(p); } },
  // «Период» → «Свой период…»: календарь выбора дат.
  { key: 'filter-period', title: 'Фильтр «Период» → «Свой период…» (календарь)', managerOnly: true, run: async (p) => {
      await home(p);
      await chip(p, 'Период').click();
      await see(p, 'По сроку').waitFor({ timeout: 10000 });
      await settle(p, 600);
      await p.getByRole('button', { name: /Свой период/ }).last().click();
      await settle(p, 1500);
      return 'окно «Период» (по дате создания / по сроку, пресеты) и календарь «с — по»; закрыто без выбора';
    }, after: async (p) => { await closePicker(p); await resetOrderFilter(p); } },
  // Окно сортировки (справа в строке фильтров).
  { key: 'filter-sort', title: 'Сортировка списка заявок', managerOnly: true, run: async (p) => {
      await home(p);
      await chip(p, 'Сначала новые').click();
      await see(p, 'По срочности').waitFor({ timeout: 10000 });
      await settle(p, 800);
      return '6 вариантов; выбор сразу применяется (здесь закрыто без выбора)';
    }, after: async (p) => { await closePicker(p); await resetOrderFilter(p); } },
  // Ничего не найдено: повторяющиеся критические (таких в демо нет).
  { key: 'filter-empty', title: 'Заявки — «Ничего не найдено» и «Сбросить фильтры»', run: async (p) => {
      await homeWith(p, 'rec=recurring&pri=critical');
      await see(p, 'Сбросить фильтры').waitFor({ timeout: 15000 });
      await settle(p, 800);
      return 'ссылка #/?rec=recurring&pri=critical';
    }, after: async (p) => { await resetOrderFilter(p); } },
  { key: 'order', title: `Карточка заявки «${DEMO_ORDER}»`, run: async (p) => {
      await home(p);
      await p.getByRole('button', { name: DEMO_ORDER }).first().click();
      await see(p, 'Подрядчик').waitFor({ timeout: 20000 });
      await settle(p);
    } },
  // Меню «⋯» в шапке карточки → «Удалить» → диалог. Нажимается только «Отмена»:
  // заявка НЕ удаляется (и в after — тоже «Отмена», если что-то пошло не так).
  { key: 'order-delete', title: 'Карточка заявки — меню «⋯» и диалог удаления', managerOnly: true, run: async (p) => {
      await home(p);
      await p.getByRole('button', { name: DEMO_ORDER }).first().click();
      await see(p, 'Подрядчик').waitFor({ timeout: 20000 });
      await settle(p);
      const menu = btn(p, 'Ещё');
      const box = await menu.boundingBox();
      if (!box || box.y > 80) throw new Error('Кнопки «⋯» нет в шапке карточки');
      await menu.click();
      await p.getByRole('menuitem', { name: 'Удалить' }).waitFor({ timeout: 5000 });
      await p.getByRole('menuitem', { name: 'Отменить' }).waitFor({ timeout: 2000 });
      await p.getByRole('menuitem', { name: 'Удалить' }).click();
      await see(p, 'Удалить заявку безвозвратно?').waitFor({ timeout: 5000 });
      await settle(p, 800);
      return 'меню «⋯» в шапке: «Отменить», «Удалить»; диалог закрыт кнопкой «Отмена»';
    }, after: async (p) => {
      const cancel = p.getByRole('button', { name: 'Отмена', exact: true }).first();
      if (await cancel.isVisible().catch(() => false)) await cancel.click();
      await settle(p, 500);
    } },
  // Окно только открывается и закрывается (Escape): подрядчик не назначается.
  { key: 'picker', title: 'Выбор подрядчика', managerOnly: true, run: async (p) => {
      await home(p);
      const titles = [PICKER_ORDER, ...DEMO_TITLES.filter((t) => t !== PICKER_ORDER)];
      let chosen = null;
      for (const t of titles) {
        const card = p.getByRole('button', { name: t }).first();
        if (!(await card.count())) continue;
        // Текст карточки: название, место, статус — статус последней строкой.
        if (!ASSIGNABLE.test((await card.innerText()).trim())) continue;
        await card.click();
        chosen = t;
        break;
      }
      if (!chosen) throw new Error('В списке нет заявки из демо-истории со статусом «Новая», «Назначена» или «Возвращена»');
      await see(p, 'Подрядчик').waitFor({ timeout: 20000 });
      await settle(p);
      await p.getByRole('button', { name: /Назначить|Изменить/ }).first().click();
      // Подписи секций в шторке — прописными («ЗАКРЕПЛЕНЫ ЗА…»): без учёта регистра.
      await see(p, /^Подрядчики$|Закреплены за этим видом работ|никто не закреплён/i)
        .waitFor({ timeout: 20000 });
      await settle(p);
      return `заявка «${chosen}»`;
    }, after: async (p) => { await p.keyboard.press('Escape'); } },
  // Голос в режиме VOICE_MOCK: фраза «произносится» по словам, ждём её конец.
  { key: 'voice', title: 'Голосовая заявка — распознавание', managerOnly: true, run: async (p) => {
      await openVoice(p);
    } },
  // «Готово» → разбор → экран подтверждения. «Отправить» не нажимаем.
  { key: 'voice-confirm', title: 'Голосовая заявка — подтверждение', managerOnly: true, run: async (p) => {
      await openVoice(p);
      await btn(p, 'Готово').click();
      await see(p, 'Проверьте заявку').waitFor({ timeout: 20000 });
      await see(p, 'Вы сказали').waitFor({ timeout: 20000 });
      await settle(p, 2000);
    } },
  // То же при низком окне (ноутбук 1280×720, телефон 412×700): кнопка
  // «Отправить» закреплена внизу и должна быть видна без прокрутки.
  { key: 'voice-confirm-low', title: 'Голосовая заявка — подтверждение, низкое окно', managerOnly: true, run: async (p) => {
      const vp = p.viewportSize();
      const low = { width: vp.width, height: vp.width > 600 ? 720 : 700 };
      await p.setViewportSize(low);
      await openVoice(p);
      await btn(p, 'Готово').click();
      await see(p, 'Проверьте заявку').waitFor({ timeout: 20000 });
      await settle(p, 2000);
      const box = await btn(p, 'Отправить').boundingBox();
      if (!box || box.y < 0 || box.y + box.height > low.height) {
        throw new Error(`Кнопка «Отправить» не видна в окне ${low.width}×${low.height}`);
      }
      return `окно ${low.width}×${low.height}, «Отправить» видна (низ кнопки — ${Math.round(box.y + box.height)} px)`;
    }, after: async (p) => {
      const vp = p.viewportSize();
      await p.setViewportSize({ width: vp.width, height: vp.width > 600 ? 800 : 915 });
    } },
  // Прокрутка «Проверьте заявку» в низком окне: колесом мыши и клавишами
  // (Home, щелчок в пустое место, PageDown). Меряем, куда уехала подпись «Срочность».
  { key: 'confirm-scroll', title: 'Проверьте заявку — прокрутка колесом и PageDown', managerOnly: true, run: async (p) => {
      const vp = p.viewportSize();
      // После редизайна 13b экран компактнее: при 1280×720 прокручивается
      // всего ~35 px. Окно 560 — чтобы было что прокручивать.
      const low = { width: vp.width, height: vp.width > 600 ? 560 : 700 };
      await p.setViewportSize(low);
      await openConfirm(p);
      const label = p.getByText('Срочность').first();
      const y = async () => (await label.boundingBox())?.y ?? NaN;
      const y0 = await y();
      await p.mouse.move(low.width / 2, low.height / 2);
      await p.mouse.wheel(0, 400);
      await settle(p, 800);
      const yWheel = await y();
      if (!(y0 - yWheel > 40)) throw new Error(`Колесо не прокрутило: ${Math.round(y0)} → ${Math.round(yWheel)} px`);
      await p.keyboard.press('Home');
      await settle(p, 800);
      const yHome = await y();
      if (Math.abs(yHome - y0) > 5) throw new Error(`Home не вернул в начало: ${Math.round(yHome)} вместо ${Math.round(y0)} px`);
      // Щелчок в пустое место у левого края (поля списка), потом PageDown.
      await p.mouse.click(6, Math.round(low.height / 2));
      await p.keyboard.press('PageDown');
      await settle(p, 800);
      const yPage = await y();
      if (!(y0 - yPage > 40)) throw new Error(`PageDown не прокрутил: ${Math.round(y0)} → ${Math.round(yPage)} px`);
      return `окно ${low.width}×${low.height}: колесо ${Math.round(y0)}→${Math.round(yWheel)} px, Home ${Math.round(yHome)}, PageDown →${Math.round(yPage)} px`;
    }, after: async (p) => {
      const vp = p.viewportSize();
      await p.setViewportSize({ width: vp.width, height: vp.width > 600 ? 800 : 915 });
    } },
  // «Ввести текстом» на «Слушаю» — с первого нажатия, курсор сразу в поле.
  { key: 'voice-type', title: '«Слушаю» → «Ввести текстом» с одного нажатия', managerOnly: true, run: async (p) => {
      await openVoice(p);
      await btn(p, 'Ввести текстом').click();
      await see(p, 'Опишите заявку').waitFor({ timeout: 3000 })
        .catch(() => { throw new Error('После одного нажатия «Ввести текстом» поле не открылось'); });
      await settle(p, 800);
      const tag = await p.evaluate(() => document.activeElement?.tagName ?? '');
      if (!/INPUT|TEXTAREA/.test(tag)) throw new Error(`Курсор не в поле (фокус: ${tag || 'нет'})`);
      return 'поле открылось с первого нажатия, курсор в поле';
    } },
  // Сообщение: на «Проверьте заявку» стираем «Что случилось?» и жмём «Отправить» —
  // заявка не уходит, появляется подсказка. На ПК — справа сверху, не над кнопкой.
  { key: 'message', title: 'Сообщение «Напишите, что случилось»', managerOnly: true, run: async (p) => {
      await openConfirm(p);
      const field = p.getByRole('textbox', { name: 'Что случилось?' });
      await field.click();
      await settle(p, 500);
      await p.keyboard.press('ControlOrMeta+A');
      await p.keyboard.press('Backspace');
      await settle(p, 300);
      const len = await p.evaluate(() => document.activeElement?.value?.length ?? -1);
      if (len !== 0) throw new Error('Не удалось стереть поле «Что случилось?»');
      await btn(p, 'Отправить').click();
      const msg = messageLocator(p);
      await msg.waitFor({ timeout: 3000 });
      messageShownAt = Date.now();
      await settle(p, 400);
      const box = await msg.boundingBox({ timeout: 3000 });
      const send = await btn(p, 'Отправить').boundingBox();
      const vp = p.viewportSize();
      if (!box) throw new Error('Сообщение не найдено на экране');
      if (box.y > 200) throw new Error(`Сообщение не сверху: y = ${Math.round(box.y)} px`);
      if (vp.width >= 700 && box.x < vp.width / 2) throw new Error(`На ПК сообщение не справа: x = ${Math.round(box.x)} px`);
      if (send && box.y + box.height > send.y) throw new Error('Сообщение перекрывает кнопку «Отправить»');
      return `сверху ${vp.width >= 700 ? 'справа ' : ''}(x ${Math.round(box.x)}, y ${Math.round(box.y)} px), кнопка «Отправить» открыта`;
    } },
  { key: 'message-gone', title: 'Сообщение исчезает само (~3 с)', managerOnly: true, run: async (p) => {
      await messageLocator(p).waitFor({ state: 'hidden', timeout: 8000 });
      const sec = (Date.now() - messageShownAt) / 1000;
      if (sec < 2.5 || sec > 4.5) throw new Error(`Сообщение исчезло через ${sec.toFixed(1)} с, ждали ~3 с`);
      return `исчезло через ${sec.toFixed(1)} с`;
    } },
  { key: 'reports', title: 'Отчёты (30 дней)', managerOnly: true, run: async (p) => {
      await home(p);
      await nav(p, 'Отчёты').click();
      await see(p, '30 дней').waitFor({ timeout: 20000 });
      await settle(p, 3000);
    } },
  { key: 'history', title: 'История', run: async (p) => {
      await home(p);
      await nav(p, 'История').click();
      await settle(p, 3000);
    } },
  { key: 'contractors', title: 'Подрядчики', run: async (p) => {
      await home(p);
      await nav(p, 'Подрядчики').click();
      await settle(p, 2500);
    } },
  { key: 'locations', title: 'Локации', run: async (p) => {
      await home(p);
      await nav(p, 'Локации').click();
      await settle(p, 2500);
    } },
  // Карта объектов (шаг 13). После снимков вкладка возвращается в «Список»
  // (в конце map-orders; у исполнителя и заявителя режим остаётся только в их браузере).
  { key: 'map', jpeg: true, title: 'Локации — карта, все объекты', run: async (p) => {
      // Предпросмотр — только у менеджера: исполнитель и заявитель видят то, что есть в базе.
      await openMap(p, p.role === 'manager');
      return previewNote('все объекты, маркер — число открытых заявок');
    }, after: async (p) => { await unrouteMapPreview(p); } },
  { key: 'map-selected', jpeg: true, title: 'Локации — карта, выбранный объект', managerOnly: true, run: async (p) => {
      await openMap(p, true);
      const name = SEED_OBJECTS[0]?.name ?? 'БЦ «Демо»';
      const row = p.getByRole('button', { name }).first();
      await (await row.count() ? row : p.getByRole('button', { name: 'БЦ «Демо»' }).first()).click();
      await see(p, 'Открыть объект').waitFor({ timeout: 10000 });
      await settle(p, 1500);
      await waitTiles(p);
      return previewNote('карточка объекта, круг геозоны');
    }, after: async (p) => { await unrouteMapPreview(p); } },
  { key: 'map-area', jpeg: true, title: 'Локации — карта, выделенная область', managerOnly: true, run: async (p) => {
      await openMap(p, true);
      await btn(p, 'Выделить область').click();
      await see(p, 'Протяните рамку по карте').waitFor({ timeout: 5000 });
      const vp = p.viewportSize();
      const wide = vp.width >= 900;
      // Рамка — внутри карты, мимо кнопок справа и подсказки слева сверху
      // (на телефоне — над панелью списка).
      const [x0, y0, x1, y1] = wide
        ? [560, 250, 1060, 620]
        : [30, 240, 300, 520];
      // Протянуть рамку; если строка «сбросить» не появилась — ещё раз (бывает,
      // что первое нажатие приходит, пока карта перерисовывается).
      for (let attempt = 0; ; attempt++) {
        await settle(p, 600);
        await p.mouse.move(x0, y0);
        await p.mouse.down();
        for (let i = 1; i <= 10; i++) await p.mouse.move(x0 + (x1 - x0) * i / 10, y0 + (y1 - y0) * i / 10);
        await p.mouse.up();
        try {
          await btn(p, 'сбросить').waitFor({ timeout: 4000 });
          break;
        } catch (e) {
          if (attempt >= 1) throw e;
          if (!(await see(p, 'Протяните рамку по карте').isVisible().catch(() => false))) {
            await btn(p, 'Выделить область').click();
          }
        }
      }
      await settle(p, 1000);
      return previewNote('рамка протянута мышью, список — только объекты внутри');
    }, after: async (p) => { await unrouteMapPreview(p); } },
  // Правый клик по карте → «Объекты рядом»: круг и ползунок радиуса.
  { key: 'map-nearby', jpeg: true, title: 'Локации — карта, «Объекты рядом» (правый клик)', managerOnly: true, run: async (p) => {
      await openMap(p, true);
      const vp = p.viewportSize();
      const [x, y] = vp.width >= 900 ? [820, 470] : [200, 420];
      await p.mouse.click(x, y, { button: 'right' });
      await see(p, /Объекты рядом/).waitFor({ timeout: 5000 });
      await settle(p, 1200);
      await waitTiles(p);
      return previewNote('радиус 3 км, список — по удалённости');
    }, after: async (p) => { await unrouteMapPreview(p); } },
  // «Изменить место на карте»: перекрестие и «Сохранить здесь». Нажимается только
  // «Отмена» — место НЕ сохраняется.
  { key: 'map-place', jpeg: true, title: 'Локации — карта, «Изменить место на карте»', managerOnly: true, run: async (p) => {
      await openMap(p, false);
      await p.getByRole('button', { name: 'БЦ «Демо»' }).first().click();
      await see(p, 'Открыть объект').waitFor({ timeout: 10000 });
      await btn(p, 'Изменить место на карте').click();
      await btn(p, 'Сохранить здесь').waitFor({ timeout: 5000 });
      await settle(p, 1200);
      await waitTiles(p);
      return 'перекрестие по центру; закрыто кнопкой «Отмена», место не сохранено';
    }, after: async (p) => {
      await btn(p, 'Отмена').click().catch(() => {});
      await settle(p, 500);
    } },
  // Карточка объекта → «Заявки»: вкладка «Заявки» с фильтром по объекту (крестик снимает).
  { key: 'map-orders', title: 'Карта → «Заявки» объекта (фильтр)', managerOnly: true, run: async (p) => {
      await openMap(p, false);
      await p.getByRole('button', { name: 'БЦ «Демо»' }).first().click();
      await see(p, 'Открыть объект').waitFor({ timeout: 10000 });
      await settle(p, 800);
      await p.getByRole('button', { name: 'Заявки', exact: true }).last().click();
      await chip(p, 'Объект').waitFor({ timeout: 15000 });
      await btn(p, 'Объект: БЦ «Демо»').waitFor({ timeout: 15000 });
      await settle(p, 2000);
      return 'фильтр «Объект» = БЦ «Демо» (та же таблетка, что в строке фильтров), снимается крестиком';
    }, after: async (p) => {
      await resetOrderFilter(p);
      await nav(p, 'Локации').click().catch(() => {});
      await settle(p, 800);
      await p.getByRole('button', { name: 'Список', exact: true }).first().click().catch(() => {});
      await settle(p, 500);
    } },
  { key: 'profile', title: 'Профиль', run: async (p) => {
      await home(p);
      await nav(p, 'Профиль').click();
      await see(p, /Моя компания|Настройки/).waitFor({ timeout: 15000 });
      await settle(p);
    } },
  { key: 'notifications', title: 'Уведомления', run: async (p) => {
      await home(p);
      await p.getByRole('button', { name: /^Уведомления/ }).first().click();
      await see(p, /За последние 14 дней|Уведомлений нет/).waitFor({ timeout: 20000 });
      await settle(p, 2500);
    } },
];

// --only=map — снять только экраны, чей ключ начинается с «map» (для отладки;
// README тогда содержит только их).
const ONLY = process.argv.find((a) => a.startsWith('--only='))?.slice(7) ?? '';

const RUNS = [
  { role: 'manager', label: 'Менеджер', width: 1280, height: 800 },
  { role: 'manager', label: 'Менеджер', width: 412, height: 915 },
  { role: 'executor', label: 'Исполнитель', width: 412, height: 915 },
  { role: 'requester', label: 'Заявитель', width: 412, height: 915 },
];

// ---------------------------------------------------------------------------
// Съёмка
// ---------------------------------------------------------------------------
rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
const results = [];
const browser = await chromium.launch();
try {
  for (const r of RUNS) {
    const up = r.role.toUpperCase();
    const ctx = await browser.newContext({
      viewport: { width: r.width, height: r.height }, locale: 'ru-RU', deviceScaleFactor: 1 });
    const page = await ctx.newPage();
    trackTiles(page);
    page.role = r.role;
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e.message).slice(0, 200)));
    let loggedIn = true;
    try {
      await login(page, env[`DEMO_${up}_EMAIL`], env[`DEMO_${up}_PASSWORD`]);
    } catch (e) {
      loggedIn = false;
      const name = `${r.role}-${r.width}-login-error.png`;
      // Репозиторий публичный: поля входа (почта) на снимке закрыты плашкой.
      await page.screenshot({ path: join(OUT, name), mask: [page.getByRole('textbox')] }).catch(() => {});
      results.push({ ...r, key: 'login', title: 'Вход', ok: false, file: name,
        note: 'Не удалось войти: ' + String(e.message).split('\n')[0] });
    }
    for (const s of SCREENS) {
      if (!loggedIn) break;
      if (ONLY && !s.key.startsWith(ONLY)) continue;
      if (s.managerOnly && r.role !== 'manager') {
        results.push({ ...r, key: s.key, title: s.title, ok: null, note: 'Нет у этой роли (так задумано)' });
        continue;
      }
      // Карта — JPEG: плитки подложки похожи на фото, в PNG снимок весит 600–850 КБ.
      const ext = s.jpeg ? '.jpg' : '.png';
      const name = `${r.role}-${r.width}-${s.key}${ext}`;
      const shot = s.jpeg ? { type: 'jpeg', quality: 80 } : {};
      try {
        const note = await s.run(page);
        await page.screenshot({ path: join(OUT, name), ...shot });
        results.push({ ...r, key: s.key, title: s.title, ok: true, file: name,
          note: typeof note === 'string' ? note : undefined });
        if (s.after) await s.after(page).catch(() => {});
      } catch (e) {
        await page.screenshot({ path: join(OUT, name.replace(ext, '-error' + ext)), ...shot }).catch(() => {});
        if (s.after) await s.after(page).catch(() => {});
        results.push({ ...r, key: s.key, title: s.title, ok: false, file: name.replace(ext, '-error' + ext),
          note: String(e.message).split('\n')[0].slice(0, 200) });
      }
    }
    if (errors.length) results.push({ ...r, key: 'js', title: 'Ошибки JavaScript', ok: false, note: errors.join(' | ') });
    await ctx.close();
  }
} finally {
  await browser.close();
  server.close();
}

// ---------------------------------------------------------------------------
// Размер PNG и README с итогами
// ---------------------------------------------------------------------------
let big = [];
for (const f of readdirSync(OUT).filter((f) => /\.(png|jpg)$/.test(f))) {
  const size = statSync(join(OUT, f)).size;
  if (size > MAX_PNG && f.endsWith('.jpg')) big.push(f);
  else if (size > MAX_PNG) {
    try { execFileSync('pngquant', ['--force', '--skip-if-larger', '--quality=60-90', '--ext', '.png', join(OUT, f)]); } catch {}
    if (statSync(join(OUT, f)).size > MAX_PNG) big.push(f);
  }
}

const mark = (ok) => (ok === true ? '✅' : ok === false ? '❌' : '—');
const kb = (f) => (f && existsSync(join(OUT, f)) ? Math.round(statSync(join(OUT, f)).size / 1024) + ' КБ' : '');
const lines = [
  '# Скриншоты веб-версии',
  '',
  `Снято: ${new Date().toISOString().slice(0, 16).replace('T', ' ')} UTC, команда \`/screens\` (\`tools/screens/screens.mjs\`).`,
  '',
  '| Роль | Ширина | Экран | Итог | Файл | Примечание |',
  '|---|---|---|---|---|---|',
  ...results.map((x) => `| ${x.label} | ${x.width} | ${x.title} | ${mark(x.ok)} | ${x.file ? `[${x.file}](${x.file}) ${kb(x.file)}` : ''} | ${x.note ?? ''} |`),
  '',
];
if (big.length) lines.push(`⚠️ Больше 300 КБ: ${big.join(', ')}`, '');
writeFileSync(join(OUT, 'README.md'), lines.join('\n'));

const ok = results.filter((x) => x.ok === true).length;
const bad = results.filter((x) => x.ok === false);
console.log(`Готово: ${ok} снимков, проблем: ${bad.length}. Итоги — docs/screens/latest/README.md`);
for (const x of bad) console.log(`  ❌ ${x.label} ${x.width} — ${x.title}: ${x.note ?? ''}`);
process.exit(bad.length ? 1 : 0);
