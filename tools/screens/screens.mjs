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
// --pitch — 12 кадров для питча в docs/screens/pitch/ (см. PITCH ниже):
// без служебных пометок, разбор голосовой заявки — настоящий ИИ (VOICE_MOCK_AI).
const PITCH_MODE = process.argv.includes('--pitch');
// --out=<папка> — снимать в другую папку (для отладки, не трогая docs/screens/latest).
const OUT = resolve(process.argv.find((a) => a.startsWith('--out='))?.slice(6)
  ?? join(ROOT, PITCH_MODE ? 'docs/screens/pitch' : 'docs/screens/latest'));
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
// ПРЕДПРОСМОТР объектов по миру (шаг 13d): объекты 401–415, помещения 421–465,
// подрядчики 501–510 с закреплениями и заявки 223–253 из demo_history.sql.
// Пока Refresh demo после merge не запущен, их нет в базе — тогда у менеджера
// Playwright добавляет эти записи в ответы сервера (только в браузере, база
// не меняется), в README — пометка «ПРЕДПРОСМОТР». Поддерживаются простые
// фильтры запроса (eq, in, is, gte, lt, gt); запрос с or/and — без подстановки.
// ---------------------------------------------------------------------------
const SEED = readFileSync(join(ROOT, 'supabase/seed/demo_history.sql'), 'utf8');
const COMPANY = 'de300000-0000-4000-8000-000000000001';
const uuid = (n) => 'de300000-0000-4000-8000-' + String(n).padStart(12, '0');
const unq = (s) => s.replace(/''/g, "'");
const W_OBJECTS = [...SEED.matchAll(
  /^\s*\((4\d\d), '((?:[^']|'')+)',\s*'(\w+)',\s*'((?:[^']|'')+)',\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(\d+)\)/gm)]
  .map((m) => ({ id: uuid(m[1]), company_id: COMPANY, name: unq(m[2]), type: m[3],
    address: unq(m[4]), lat: +m[5], lng: +m[6], geofence_radius_m: +m[7],
    created_at: '2026-10-01T00:00:00Z' }));
const W_OBJ = Object.fromEntries(W_OBJECTS.map((o) => [o.id, o]));
const W_LOCATIONS = [...SEED.matchAll(/^\s*\((4[2-9]\d), (4[01]\d), '((?:[^']|'')+)'\)/gm)]
  .map((m) => ({ id: uuid(m[1]), object_id: uuid(m[2]), name: unq(m[3]),
    created_at: '2026-10-01T00:00:00Z' }));
const W_CONTRACTORS = [...SEED.matchAll(/^\s*\((5\d\d), '((?:[^']|'')+)'\)/gm)]
  .map((m) => ({ id: uuid(m[1]), company_id: COMPANY, org_name: unq(m[2]),
    created_at: '2026-10-01T00:00:00Z' }));
const W_BINDINGS = [...SEED.matchAll(/\((\d+), '(hvac|elec|plumb|clean|other)', (4\d\d), (null(?:::int)?|\d+)\)/g)]
  .map((m, i) => ({ id: uuid(900 + i), contractor_id: uuid(m[1]), layer: m[2], object_id: uuid(m[3]),
    visits_per_month: m[4].startsWith('null') ? null : +m[4], created_at: '2026-10-01T00:00:00Z' }));
const W_ORDERS = [...SEED.matchAll(
  /^\s*\((2[2-9]\d),'(\w+)',(\d+),(\d+|null),'((?:[^']|'')*)','((?:[^']|'')*)','(\w+)','(\w+)','\w+','(\w+)',(\d+),(\d+),(?:null(?:::int)?|\d+),(?:null(?:::int)?|\d+),(?:null(?:::int)?|\d+),(\d+),(\d+),(?:null(?:::text)?|'(?:[^']|'')*'),(?:null(?:::int)?|\d+),(null(?:::text)?|'\w+')\)/gm)]
  .map((m) => {
    const today = new Date(); today.setUTCHours(0, 0, 0, 0);
    // Группы: 10 — дней назад, 11 — час, 12 — срок (ч), 14 — повторяющаяся.
    const created = today.getTime() - +m[10] * 864e5 + +m[11] * 36e5;
    const loc = W_LOCATIONS.find((l) => l.id === uuid(m[3]));
    return { id: uuid(m[1]), company_id: COMPANY, title: unq(m[5]), description: unq(m[6]),
      layer: m[2], priority: m[7], status: m[8], input_channel: m[9],
      object_id: loc?.object_id, location_id: loc?.id, locations: { name: loc?.name },
      assigned_contractor_id: m[4] === 'null' ? null : uuid(m[4]), assigned_executor_id: null,
      created_by: null, requires_photo: true, return_count: m[8] === 'returned' ? 1 : 0,
      recurrence: m[14].startsWith('null') ? null : { kind: 'regular', freq: m[14].replace(/'/g, ''), interval: 1 },
      created_at: new Date(created).toISOString(), due_at: new Date(created + +m[12] * 36e5).toISOString() };
  });
if (W_OBJECTS.length !== 15 || W_ORDERS.length !== 31 || W_CONTRACTORS.length !== 10) {
  console.error(`Предпросмотр: из demo_history.sql разобрано объектов ${W_OBJECTS.length}, заявок ${W_ORDERS.length}, подрядчиков ${W_CONTRACTORS.length}`);
}
// ПРЕДПРОСМОТР планов этажей (шаг 14b): этажи, помещения на планах,
// оборудование и заявки 254–257 — из tools/demo_plans/plans.json (тот же
// источник, что у SQL-блока 5d), картинки — assets/demo_plans/*.png.
const PLANS = JSON.parse(readFileSync(join(ROOT, 'tools/demo_plans/plans.json'), 'utf8'));
const pfrac = (v, max) => Math.round((v / max) * 10000) / 10000;
const P_FLOORS = PLANS.floors.map((f) => ({ id: uuid(f.id), object_id: uuid(f.object), company_id: COMPANY,
  name: f.name, level: f.level, sort: f.sort, plan_path: `preview/${f.file}`, plan_w: PLANS.width, plan_h: PLANS.height }));
const P_ROOM = Object.fromEntries(PLANS.floors.flatMap((f) => f.rooms.filter((r) => r.id).map((r) => [uuid(r.id), {
  floor_id: uuid(f.id), plan_x: pfrac(r.rect[0] + r.rect[2] / 2, PLANS.width), plan_y: pfrac(r.rect[1] + r.rect[3] / 2, PLANS.height),
  object_id: uuid(f.object), _name: r.name, _new: !!r.new }])));
const P_ROOMS = Object.entries(P_ROOM).filter(([, r]) => r._new).map(([id, r]) => ({ id, object_id: r.object_id,
  name: r._name, floor_id: r.floor_id, plan_x: r.plan_x, plan_y: r.plan_y, created_at: '2026-10-01T00:00:00Z' }));
const P_ROOM_NAME = Object.fromEntries(Object.entries(P_ROOM).map(([id, r]) => [id, r._name]));
for (const r of Object.values(P_ROOM)) { delete r._name; delete r._new; }
const P_FLOOR = Object.fromEntries(P_FLOORS.map((f) => [f.id, { name: f.name, level: f.level }]));
const P_ASSETS = PLANS.floors.flatMap((f) => f.assets.map((a) => ({ id: uuid(a.id), location_id: uuid(a.room), name: a.name,
  category: a.category, inventory_no: a.inv, meta: { kind: a.kind, demo: true }, floor_id: uuid(f.id),
  plan_x: pfrac(a.at[0], PLANS.width), plan_y: pfrac(a.at[1], PLANS.height), locations: { object_id: uuid(f.object) } })));
async function planOrders(route, page) {
  if (page.role !== 'manager') return [];
  const today = new Date(); today.setUTCHours(0, 0, 0, 0);
  const layerRes = await route.fetch({ url: `${new URL(route.request().url()).origin}/rest/v1/layers?select=id,name` }).catch(() => null);
  const layers = layerRes ? Object.fromEntries((await layerRes.json()).map((l) => [l.name, l.id])) : {};
  return PLANS.orders.map((o) => {
    const created = today.getTime() - o.d * 864e5 + o.h * 36e5;
    const room = P_ROOM[uuid(o.room)];
    return { id: uuid(o.id), company_id: COMPANY, title: o.title, description: o.descr, priority: o.priority,
      status: o.status, input_channel: o.channel, object_id: room.object_id, location_id: uuid(o.room),
      asset_id: uuid(o.asset), locations: { name: P_ROOM_NAME[uuid(o.room)] ?? null },
      layer_id: layers[LAYER_NAMES[o.layer]] ?? null, work_type: LAYER_NAMES[o.layer],
      assigned_contractor_id: o.contractor ? uuid(o.contractor) : null, assigned_executor_id: null, created_by: null,
      requires_photo: true, return_count: 0, recurrence: null, created_at: new Date(created).toISOString(),
      due_at: new Date(created + o.due_h * 36e5).toISOString() };
  });
}

const LAYER_NAMES = { hvac: 'Климат', elec: 'Электрика', plumb: 'Сантехника', clean: 'Клининг', other: 'Другое' };

// Подходит ли строка под фильтры PostgREST из адреса; null — фильтр не разобрать.
function applyFilters(rows, params) {
  for (const [k, v] of params) {
    if (['select', 'order', 'limit', 'offset', 'columns'].includes(k)) continue;
    if (k === 'or' || k === 'and' || k.includes('.')) return null;
    const m = v.match(/^(not\.)?(eq|in|is|gte|gt|lte|lt)\.(.*)$/);
    if (!m) return null;
    const [, not, op, val] = m;
    const cmp = (x) => {
      const a = Date.parse(x), b = Date.parse(val);
      return Number.isNaN(a) || Number.isNaN(b) ? (+x) - (+val) : a - b;
    };
    rows = rows.filter((r) => {
      const x = r[k];
      let ok;
      switch (op) {
        case 'eq': ok = String(x) === val; break;
        case 'in': ok = val.replace(/^\(|\)$/g, '').split(',').includes(String(x)); break;
        case 'is': ok = val === 'null' ? x == null : String(x) === val; break;
        case 'gte': ok = x != null && cmp(x) >= 0; break;
        case 'gt': ok = x != null && cmp(x) > 0; break;
        case 'lte': ok = x != null && cmp(x) <= 0; break;
        case 'lt': ok = x != null && cmp(x) < 0; break;
      }
      return not ? !ok : ok;
    });
  }
  return rows;
}

// Включить предпросмотр для страницы менеджера (один раз на вход).
async function routeWorldPreview(page) {
  page.worldPreview = false;
  page.previewUsed = false;
  let layers = null; // слои компании из базы: id нужны заявкам и закреплениям
  const rowsFor = async (table, route) => {
    if (!layers) {
      const url = new URL(route.request().url());
      const res = await route.fetch({ url: `${url.origin}/rest/v1/layers?select=id,name,name_i18n,sort` });
      layers = Object.fromEntries((await res.json()).map((l) => [l.name, l]));
    }
    const layer = (key) => layers[LAYER_NAMES[key]] ?? null;
    switch (table) {
      case 'objects': return W_OBJECTS;
      case 'locations': return W_LOCATIONS.map((l) => ({ ...l, objects: { name: W_OBJ[l.object_id].name, address: W_OBJ[l.object_id].address } }));
      case 'contractors': return W_CONTRACTORS;
      case 'contractor_layers': return W_BINDINGS.map(({ layer: k, ...b }) => ({ ...b, layer_id: layer(k)?.id,
        contractors: { org_name: W_CONTRACTORS.find((c) => c.id === b.contractor_id)?.org_name
          ?? (b.contractor_id.endsWith('31') ? 'КлиматСервис' : 'ЭлектроПро') },
        objects: { name: W_OBJ[b.object_id].name, address: W_OBJ[b.object_id].address }, layers: layer(k) }));
      case 'work_orders': return W_ORDERS.map(({ layer: k, ...o }) => ({ ...o, layer_id: layer(k)?.id, work_type: LAYER_NAMES[k] }));
    }
    return null;
  };
  // Отдать строки: массивом или одной записью (maybeSingle / single).
  const fulfillRows = (route, res, rows, single) => {
    if (single) {
      if (!rows.length) return route.fulfill({ response: res });
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(rows[0]) });
    }
    return route.fulfill({ status: 200, contentType: 'application/json', headers: res.headers(),
      body: JSON.stringify(rows) });
  };
  await page.route('**/rest/v1/**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const table = url.pathname.split('/rest/v1/')[1];
    const method = req.method();
    if (!['objects', 'locations', 'contractors', 'contractor_layers', 'work_orders', 'floors', 'assets'].includes(table) ||
        !['GET', 'HEAD'].includes(method)) {
      return route.fallback();
    }
    const res = await route.fetch();
    const single = (req.headers()['accept'] ?? '').includes('vnd.pgrst.object');
    try {
      // Этажи и оборудование (шаг 14b): пока Refresh demo не запущен — из plans.json.
      if (table === 'floors' || table === 'assets') {
        const real = res.ok() ? JSON.parse((await res.text()) || '[]') : [];
        const realRows = Array.isArray(real) ? real : [real];
        if (table === 'floors' && realRows.some((r) => r.id === uuid(601) && r.plan_path)) page.planPreview = 'off';
        if (page.planPreview === 'off' || method !== 'GET') return route.fulfill({ response: res });
        let extra = table === 'floors' ? P_FLOORS : P_ASSETS;
        const params = new URLSearchParams(url.searchParams);
        // assets?locations.object_id=eq.<id> — фильтр по объекту помещения.
        const byObj = params.get('locations.object_id');
        params.delete('locations.object_id');
        if (byObj) extra = extra.filter((a) => `eq.${a.locations.object_id}` === byObj);
        extra = applyFilters(extra, params) ?? [];
        if (!extra.length) return route.fulfill({ response: res });
        page.previewUsed = true;
        const have = new Set(extra.map((r) => r.id));
        return fulfillRows(route, res, [...extra, ...realRows.filter((r) => !have.has(r.id))], single);
      }
      let body = method === 'GET' && res.ok() ? JSON.parse(await res.text()) : null;
      const rows = Array.isArray(body) ? body : (body ? [body] : []);
      // Помещения на планах и заявки на оборудовании этажей (шаг 14b).
      const planExtra = page.planPreview === 'off' ? [] : (applyFilters(
        table === 'locations' ? P_ROOMS : table === 'work_orders' ? await planOrders(route, page) : [],
        url.searchParams) ?? []);
      const patchPlan = (list) => list.map((r) => {
        if (page.planPreview === 'off') return r;
        if (table === 'locations' && P_ROOM[r.id]) return { ...r, ...P_ROOM[r.id], name: r.name };
        // Строка заявки: этаж помещения («Холл · 1 эт.»).
        const room = table === 'work_orders' && P_ROOM[r.location_id];
        if (room && r.locations) return { ...r, locations: { ...r.locations, floors: P_FLOOR[room.floor_id] } };
        return r;
      });
      // Объекты по миру (шаг 13d).
      if (page.worldPreview !== 'off' && table === 'objects' && method === 'GET' && rows.some((r) => r.id === uuid(401))) {
        page.worldPreview = 'off';
      }
      const worldExtra = page.worldPreview === 'off' ? [] : (applyFilters(await rowsFor(table, route), url.searchParams) ?? []);
      const extra = [...worldExtra, ...planExtra];
      const patchable = page.planPreview !== 'off' &&
        rows.some((r) => P_ROOM[table === 'locations' ? r.id : r.location_id]);
      if (!extra.length && !patchable) {
        return route.fulfill({ response: res });
      }
      if (worldExtra.length) page.worldPreview = true;
      page.previewUsed = true;
      if (method === 'HEAD') {
        // count(): «0-36/37» → итог с подставленными
        const range = res.headers()['content-range'] ?? '';
        const total = +(range.split('/')[1] ?? 0) + extra.length;
        return route.fulfill({ response: res, headers: { ...res.headers(), 'content-range': `0-${total - 1}/${total}` } });
      }
      if (body == null) return route.fulfill({ response: res });
      const have = new Set(rows.map((r) => r.id));
      return fulfillRows(route, res, patchPlan([...rows, ...extra.filter((r) => !have.has(r.id))]), single);
    } catch {
      return route.fulfill({ response: res });
    }
  });
  // Картинки планов в предпросмотре: подписанная ссылка и сам файл — PNG
  // из assets/demo_plans (в Storage их нет, пока не загрузили через приложение).
  await page.route('**/storage/v1/object/**', async (route) => {
    const url = new URL(route.request().url());
    const m = url.pathname.match(/floor-plans\/(preview\/[\w.-]+\.png)$/);
    if (!m) return route.fallback();
    if (url.pathname.includes('/object/sign/') && route.request().method() === 'POST') {
      return route.fulfill({ status: 200, contentType: 'application/json',
        body: JSON.stringify({ signedURL: `/object/sign/floor-plans/${m[1]}?token=preview` }) });
    }
    page.previewUsed = true;
    return route.fulfill({ status: 200, contentType: 'image/png',
      headers: { 'access-control-allow-origin': '*' },
      body: readFileSync(join(ROOT, 'assets/demo_plans', m[1].slice('preview/'.length))) });
  });
}

// Старые вызовы (шаг 13) — предпросмотр теперь общий для всех снимков менеджера.
async function routeMapPreview() {}
async function unrouteMapPreview() {}

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

const previewNote = (text) => text;

// Чип города над картой («Белград · 3» или «Белград») — приблизить к городу.
async function openCity(page, city) {
  await page.getByRole('button', { name: new RegExp(`^${city}( · \\d+)?$`) }).first().click();
  await settle(page, 1500);
  await waitTiles(page);
}
const PREVIEW = process.argv.includes('--preview');
const PREVIEW_TEXT = 'ПРЕДПРОСМОТР: объекты, подрядчики и заявки шага 13d подставлены в ответы сервера из demo_history.sql — в базе появятся после Refresh demo';

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
    '--dart-define=VOICE_MOCK=true', ...(PITCH_MODE ? ['--dart-define=VOICE_MOCK_AI=true'] : [])],
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
// Пункт «Профиль»: вкладка нижней панели (телефон) или пункт бокового меню (ПК,
// подпись с бейджем — «Профиль, 1»).
const profileTab = (page) => page.getByRole('tab', { name: /^Профиль/ })
  .or(page.getByRole('button', { name: /^Профиль/ }))
  .or(page.getByLabel(/^Профиль(, \d+)?$/)).first();

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

// Открыть заявку из списка. Если её строки нет на экране (список длинный,
// Flutter не показывает дальние строки в дереве доступности) — найти поиском.
async function openOrder(page, title) {
  const row = page.getByRole('button', { name: title }).first();
  if (!(await row.isVisible().catch(() => false))) {
    // На ширине < 400 подсказка поля — «Поиск».
    const box = page.getByRole('textbox', { name: /^Поиск( по заявкам)?$/ }).first();
    await box.click();
    await page.waitForTimeout(400);
    await page.keyboard.type(title.split(' ').slice(0, 2).join(' '), { delay: 30 });
    await settle(page, 800);
  }
  await row.click();
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

// План этажа по ссылке: #/objects/<объект>/floors/<этаж> (номера demo-id).
async function openPlan(page, objectN, floorN) {
  await page.goto('about:blank');
  await page.goto(`${BASE}#/objects/${uuid(objectN)}/floors/${uuid(floorN)}`, { waitUntil: 'load' });
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 60000 });
  await placeholder.evaluate((el) => el.click());
  await see(page, /На плане · \d/).waitFor({ timeout: 60000 });
  await settle(page, 2500);
}

// Окно «Фильтры»: на телефоне — кнопка «Фильтры», на ПК — «Все фильтры».
async function openAllFilters(page) {
  await page.getByRole('button', { name: /^(Все фильтры|Фильтры)(:| ·|$)/ }).first().click();
  await see(page, /^Показать/).waitFor({ timeout: 10000 });
  await settle(page, 400);
}

// Окно одного фильтра: на ПК — таблетка рядом с поиском (если она там есть),
// на телефоне — строка в окне «Фильтры».
async function openFilterKind(page, label) {
  if (page.viewportSize().width >= 900 && await chip(page, label).isVisible().catch(() => false)) {
    await chip(page, label).click();
    return;
  }
  await openAllFilters(page);
  await page.getByRole('button', { name: new RegExp(`^${label}(\\s|$)`) }).last().click();
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

// Песочница для сценария «загрузка плана»: этаж 601 без картинки в ответах
// сервера, любые записи (не GET/HEAD) к базе и Storage — ответ «успех» без
// отправки на сервер. Подписанные ссылки на загруженный «файл» — картинка
// из assets/demo_plans.
async function sandboxPlanUpload(page) {
  page.sandboxWrites = [];
  page.sandboxFile = null;
  page.sandboxRest = async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    if (!['GET', 'HEAD'].includes(req.method())) {
      page.sandboxWrites.push(`${req.method()} ${url.pathname}`);
      const id = (url.searchParams.get('id') ?? '').replace(/^eq\./, '');
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify([{ id }]) });
    }
    if (url.pathname.endsWith('/rest/v1/floors') && req.method() === 'GET' && !page.sandboxFile) {
      const res = await route.fetch();
      const body = JSON.parse((await res.text()) || '[]');
      const strip = (r) => (r.id === uuid(601) ? { ...r, plan_path: null, plan_w: null, plan_h: null } : r);
      return route.fulfill({ response: res, body: JSON.stringify(Array.isArray(body) ? body.map(strip) : strip(body)) });
    }
    return route.fallback();
  };
  page.sandboxStorage = async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    if (!url.pathname.includes('/floor-plans/')) return route.fallback();
    // Подписанная ссылка на файл, «загруженный» в песочнице.
    if (url.pathname.includes('/object/sign/')) {
      if (page.sandboxFile && url.pathname.endsWith(page.sandboxFile)) {
        if (req.method() === 'POST') {
          return route.fulfill({ status: 200, contentType: 'application/json',
            body: JSON.stringify({ signedURL: `/object/sign/floor-plans/${page.sandboxFile}?token=sandbox` }) });
        }
        return route.fulfill({ status: 200, contentType: 'image/png', headers: { 'access-control-allow-origin': '*' },
          body: readFileSync(join(ROOT, 'assets/demo_plans/bc-demo-floor-1.png')) });
      }
      return route.fallback();
    }
    if (!['GET', 'HEAD'].includes(req.method())) {
      page.sandboxWrites.push(`${req.method()} ${url.pathname}`);
      // POST /storage/v1/object/floor-plans/<путь> — «загрузка».
      if (req.method() === 'POST') page.sandboxFile = url.pathname.split('/floor-plans/')[1];
      return route.fulfill({ status: 200, contentType: 'application/json',
        body: JSON.stringify({ Key: `floor-plans/${page.sandboxFile}`, Id: 'sandbox' }) });
    }
    return route.fallback();
  };
  await page.route('**/rest/v1/**', page.sandboxRest);
  await page.route('**/storage/v1/object/**', page.sandboxStorage);
}

async function unsandbox(page) {
  if (page.sandboxRest) await page.unroute('**/rest/v1/**', page.sandboxRest);
  if (page.sandboxStorage) await page.unroute('**/storage/v1/object/**', page.sandboxStorage);
  page.sandboxRest = page.sandboxStorage = null;
}

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
  // Свёрнутая шапка: крупный заголовок ушёл, поиск и «Фильтры» закреплены,
  // сегменты спрятались (прокрутка вниз).
  { key: 'requests-collapsed', title: 'Заявки — свёрнутая шапка при прокрутке', run: async (p) => {
      await home(p);
      const vp = p.viewportSize();
      await p.mouse.move(vp.width / 3, vp.height / 2);
      for (let i = 0; i < 4; i++) { await p.mouse.wheel(0, 250); await p.waitForTimeout(120); }
      await settle(p, 1000);
      return 'поиск и фильтры закреплены сверху, сегменты спрятаны';
    } },
  // Строка применённых фильтров — открыта по ссылке с параметрами
  // (заодно проверка, что ссылка применяет фильтр). Фильтр потом убирается.
  { key: 'filters-active', title: 'Заявки — применённые фильтры по ссылке (таблетки «×», «Сбросить всё»)', run: async (p) => {
      await homeWith(p, 'pri=critical,high&st=overdue,new,assigned,in_progress&period=30d&sort=priority');
      // Таблетка «Срочность: Критический +1» — значит, ссылка применилась.
      await p.getByRole('button', { name: /^Срочность: Критический \+1/ }).first().waitFor({ timeout: 15000 });
      // «Найдено N из M» — теперь подпись сегментов для диктора; на экране —
      // «Все · N из M» у выбранного сегмента (на ширине < 400 — «N»).
      await see(p, /Найдено \d+ из \d+/).waitFor({ timeout: 15000 });
      await see(p, 'Сбросить всё').waitFor({ timeout: 5000 });
      return 'ссылка #/?pri=critical,high&st=overdue,new,assigned,in_progress&period=30d&sort=priority';
    }, after: async (p) => { await resetOrderFilter(p); } },
  // Окно «Фильтры»: 360/412 — шторка на весь экран, 1280 — панель справа.
  { key: 'filters-panel', title: 'Окно «Фильтры» с «Показать N заявок»', managerOnly: true, run: async (p) => {
      await homeWith(p, 'period=30d&st=overdue');
      await openAllFilters(p);
      const label = await see(p, /Показать \d+ заяв/).textContent({ timeout: 10000 }).catch(() => null);
      await see(p, /Показать \d+ заяв/).waitFor({ timeout: 10000 });
      await settle(p, 600);
      return `${p.viewportSize().width >= 900 ? 'панель справа' : 'шторка на весь экран'}; число считает сервер${label ? '' : ''}`;
    }, after: async (p) => { await closePicker(p); await resetOrderFilter(p); } },
  // Окно фильтра «Статус»: 1280 — выпадающее окно под таблеткой, на телефоне —
  // из окна «Фильтры». Отмечаются 2 пункта, окно закрывается без «Применить».
  { key: 'filter-picker', title: 'Окно фильтра «Статус»', managerOnly: true, run: async (p) => {
      await home(p);
      await openFilterKind(p, 'Статус');
      await see(p, 'Применить').waitFor({ timeout: 10000 });
      await settle(p, 600);
      await p.getByRole('button', { name: 'Просрочено', exact: true }).last().click();
      await p.getByRole('button', { name: 'Новая', exact: true }).last().click();
      await see(p, 'Применить (2)').waitFor({ timeout: 5000 });
      await settle(p, 800);
      return p.viewportSize().width >= 900
        ? 'выпадающее окно под таблеткой; отмечены «Просрочено» и «Новая», закрыто без применения'
        : 'шторка поверх окна «Фильтры»; отмечены «Просрочено» и «Новая», закрыто без применения';
    }, after: async (p) => { await closePicker(p); await resetOrderFilter(p); } },
  // «Период» → «Свой период…»: календарь выбора дат.
  { key: 'filter-period', title: 'Фильтр «Период» → «Свой период…» (календарь)', managerOnly: true, run: async (p) => {
      await home(p);
      await openFilterKind(p, 'Период');
      await see(p, 'По сроку').waitFor({ timeout: 10000 });
      await settle(p, 600);
      await p.getByRole('button', { name: /Свой период/ }).last().click();
      await settle(p, 1500);
      return 'окно «Период» (по дате создания / по сроку, пресеты) и календарь «с — по»; закрыто без выбора';
    }, after: async (p) => { await closePicker(p); await resetOrderFilter(p); } },
  // Сортировка — отдельная кнопка справа от «Фильтры».
  { key: 'filter-sort', title: 'Сортировка списка заявок', managerOnly: true, run: async (p) => {
      await home(p);
      await p.getByRole('button', { name: /^(Сначала новые|Новые)$/ }).first().click();
      await see(p, 'По срочности').waitFor({ timeout: 10000 });
      await settle(p, 800);
      return '6 вариантов, галочка у текущей; выбор сразу применяется (здесь закрыто без выбора)';
    }, after: async (p) => { await closePicker(p); await resetOrderFilter(p); } },
  // Ничего не найдено: повторяющиеся критические (таких в демо нет).
  { key: 'filter-empty', title: 'Заявки — «Ничего не найдено» и «Сбросить фильтры»', run: async (p) => {
      await homeWith(p, 'rec=recurring&pri=critical');
      await see(p, 'Сбросить фильтры').waitFor({ timeout: 15000 });
      await settle(p, 800);
      return 'ссылка #/?rec=recurring&pri=critical';
    }, after: async (p) => { await resetOrderFilter(p); } },
  // Фильтр «Объект»: секции по городам, поиск «Москва», «Весь город».
  // Окно закрывается без «Применить»; затем тот же выбор — по ссылке.
  { key: 'filter-object', title: 'Фильтр «Объект»: секции по городам, «Весь город» (Москва)', managerOnly: true, run: async (p) => {
      await home(p);
      await openFilterKind(p, 'Объект');
      await see(p, 'Применить').waitFor({ timeout: 10000 });
      await settle(p, 600);
      await p.getByRole('button', { name: 'Весь город: Москва' }).first().click();
      await see(p, 'Применить (5)').waitFor({ timeout: 5000 });
      await settle(p, 800);
      return 'отмечен «Весь город» у Москвы — «Применить (5)»; закрыто без применения';
    }, after: async (p) => { await closePicker(p); await resetOrderFilter(p); } },
  // Таблетка «Москва (5)» и строки заявок «Москва · Офис 3 · …» — по ссылке.
  { key: 'filter-object-city', title: 'Заявки с фильтром «Москва (5)», строки «Москва · Офис N»', managerOnly: true, run: async (p) => {
      await homeWith(p, `obj=${[403, 404, 405, 406, 407].map(uuid).join(',')}`);
      await p.getByRole('button', { name: /^Объект: Москва \(5\)/ }).first().waitFor({ timeout: 15000 });
      await settle(p, 800);
      return 'ссылка #/?obj=<5 объектов Москвы>';
    }, after: async (p) => { await resetOrderFilter(p); } },
  // Подрядчики: под названием — города и число объектов; карточка «ЭлектроСити».
  { key: 'contractor-card', title: 'Карточка подрядчика «ЭлектроСити» (2 объекта из 5 в Москве)', managerOnly: true, run: async (p) => {
      await home(p);
      await nav(p, 'Подрядчики').click();
      await p.getByRole('button', { name: /ЭлектроСити/ }).first().click();
      await see(p, /Виды работ/).waitFor({ timeout: 15000 });
      await settle(p, 1200);
      return 'виды работ; объекты по городам: МОСКВА · 2';
    } },
  { key: 'order', title: `Карточка заявки «${DEMO_ORDER}»`, run: async (p) => {
      await home(p);
      await openOrder(p, DEMO_ORDER);
      await see(p, 'Подрядчик').waitFor({ timeout: 20000 });
      await settle(p);
    } },
  // Меню «⋯» в шапке карточки → «Удалить» → диалог. Нажимается только «Отмена»:
  // заявка НЕ удаляется (и в after — тоже «Отмена», если что-то пошло не так).
  { key: 'order-delete', title: 'Карточка заявки — меню «⋯» и диалог удаления', managerOnly: true, run: async (p) => {
      await home(p);
      await openOrder(p, DEMO_ORDER);
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
  // Чип «Москва» над картой: карта плавно приближается к объектам города.
  { key: 'map-city', jpeg: true, title: 'Локации — карта, выбран город «Москва»', managerOnly: true, run: async (p) => {
      await openMap(p, true);
      await openCity(p, 'Москва');
      return 'чип «Москва» — объекты города; список — секции по городам';
    } },
  { key: 'map-selected', jpeg: true, title: 'Локации — карта, выбранный объект', managerOnly: true, run: async (p) => {
      await openMap(p, true);
      await openCity(p, 'Белград');
      await p.getByRole('button', { name: 'БЦ «Демо»' }).first().click();
      await see(p, 'Открыть объект').waitFor({ timeout: 10000 });
      await settle(p, 1500);
      await waitTiles(p);
      return previewNote('карточка объекта, круг геозоны');
    }, after: async (p) => { await unrouteMapPreview(p); } },
  { key: 'map-area', jpeg: true, title: 'Локации — карта, выделенная область', managerOnly: true, run: async (p) => {
      await openMap(p, true);
      await openCity(p, 'Белград');
      await btn(p, 'Выделить область').click();
      await see(p, 'Протяните рамку по карте').waitFor({ timeout: 5000 });
      const vp = p.viewportSize();
      const wide = vp.width >= 900;
      // Рамка — внутри карты, мимо кнопок справа и подсказки слева сверху
      // (на телефоне — над панелью списка).
      // ПК: слева боковое меню и список (~600 px), карта — правее.
      const [x0, y0, x1, y1] = wide
        ? [Math.round(vp.width * 0.55), 300, vp.width - 140, 650]
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
      await openCity(p, 'Белград');
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
      await btn(p, 'Объект: Белград · БЦ «Демо»').waitFor({ timeout: 15000 });
      await settle(p, 2000);
      return 'фильтр «Объект» = БЦ «Демо» (та же таблетка, что в строке фильтров), снимается крестиком';
    }, after: async (p) => {
      await resetOrderFilter(p);
      await nav(p, 'Локации').click().catch(() => {});
      await settle(p, 800);
      await p.getByRole('button', { name: 'Список', exact: true }).first().click().catch(() => {});
      await settle(p, 500);
    } },
  // ---- Планы этажей (шаг 14b). Пока Refresh demo и загрузка картинок не
  // сделаны — ПРЕДПРОСМОТР из plans.json и assets/demo_plans/*.png.
  // Карточка объекта «БЦ «Демо»»: раздел «Этажи · 2», помещения с этажами.
  { key: 'plan-object', title: 'Карточка объекта — «Этажи · N» и помещения с этажами', run: async (p) => {
      await home(p);
      await nav(p, 'Локации').click();
      await settle(p, 1500);
      await p.getByRole('button', { name: 'Список', exact: true }).first().click().catch(() => {});
      await settle(p, 800);
      await p.getByRole('button', { name: /БЦ «Демо»/ }).first().click();
      await see(p, /Этажи · \d/).waitFor({ timeout: 20000 });
      await settle(p, 1500);
      // До раздела «Этажи» (под адресом и координатами).
      await see(p, /Этажи · \d/).scrollIntoViewIfNeeded().catch(() => {});
      const vp = p.viewportSize();
      await p.mouse.move(vp.width / 2, vp.height / 2);
      await p.mouse.wheel(0, vp.width >= 900 ? 250 : 380);
      await settle(p, 1500);
      return p.role === 'manager' ? 'у менеджера — «+ Этаж», «+» и «⋯» у этажа' : 'только чтение: без «+» и «⋯»';
    } },
  // План по ссылке (как от коллеги): /objects/<объект>/floors/<этаж>.
  { key: 'plan', title: 'План этажа «3 этаж» (открыт по ссылке)', run: async (p) => {
      await openPlan(p, 10, 602);
      return p.role === 'manager' ? 'ссылка #/objects/…/floors/…; маркеры помещений и оборудования, фильтр, список'
        : 'только чтение: нет «Редактировать»';
    } },
  // Шторка оборудования с просроченной заявкой (на телефоне при «вписать»
  // маркер помещения «Серверная» закрыт маркером стойки — берём кондиционер).
  { key: 'plan-marker', title: 'План — шторка маркера «Кондиционер серверной»', run: async (p) => {
      await openPlan(p, 10, 602);
      await p.getByRole('button', { name: /^Кондиционер серверной, / }).first().click({ force: true });
      await see(p, 'Создать заявку здесь').waitFor({ timeout: 10000 });
      await settle(p, 1000);
      return 'подзаголовок без повтора этажа («… · Серверная, 3 этаж»), открытая просроченная заявка, «Создать заявку здесь»';
    }, after: async (p) => { await p.keyboard.press('Escape'); await settle(p, 400); } },
  // Шаг 15 (H): оборудование цвета статуса с бейджем, просроченное «дышит».
  { key: 'plan-overdue', title: 'План — оборудование с просроченной заявкой (красное, «дышит»)', managerOnly: true, run: async (p) => {
      await openPlan(p, 10, 602);
      await p.mouse.move(5, 5);
      await settle(p, 1200);
      return 'план целиком: квадраты оборудования — цвет статуса и бейдж числа заявок, «Кондиционер серверной» (просрочено) — красный ореол «дышит»; подписи помещений скрыты (они на картинке)';
    } },
  { key: 'plan-edit', title: 'План — режим расстановки', managerOnly: true, run: async (p) => {
      await openPlan(p, 10, 601);
      await p.getByRole('button', { name: 'Редактировать' }).first().click();
      await see(p, 'Режим расстановки').waitFor({ timeout: 5000 });
      await settle(p, 800);
      return 'плашка «Режим расстановки · Готово»; маркеры перетаскиваются (здесь ничего не меняется)';
    } },
  // Загрузка плана с экрана плана (шаг 15): этаж «1 этаж» показывается без
  // картинки (ответ сервера в браузере без plan_path), «Загрузить план» →
  // файл assets/demo_plans/bc-demo-floor-1.png. ВСЕ записи (загрузка в
  // Storage, этаж, перенос маркера) перехватываются в браузере и в базу НЕ
  // уходят — сервер «отвечает» успехом.
  { key: 'plan-upload-empty', title: 'План без картинки — «Загрузить план» (менеджер)', managerOnly: true, run: async (p) => {
      await sandboxPlanUpload(p);
      await openPlan(p, 10, 601);
      await btn(p, 'Загрузить план').waitFor({ timeout: 10000 });
      await settle(p, 800);
      return 'ответ сервера в браузере — этаж без plan_path; база не меняется';
    } },
  { key: 'plan-upload-done', title: 'План сразу после загрузки (без перезахода)', managerOnly: true, run: async (p) => {
      const chooser = p.waitForEvent('filechooser', { timeout: 15000 });
      chooser.catch(() => {}); // если кнопки нет — ошибка ниже, а не падение всего скрипта
      await btn(p, 'Загрузить план').click();
      await (await chooser).setFiles(join(ROOT, 'assets/demo_plans/bc-demo-floor-1.png'));
      await see(p, 'План загружен').waitFor({ timeout: 20000 });
      await settle(p, 3000);
      if (await btn(p, 'Загрузить план').isVisible().catch(() => false)) {
        throw new Error('После загрузки осталась плашка «План не загружен»');
      }
      return 'файл подставлен Playwright; загрузка и запись этажа перехвачены в браузере';
    } },
  { key: 'plan-upload-edit', title: '«Редактировать» — режим расстановки и перетаскивание', managerOnly: true, run: async (p) => {
      await p.getByRole('button', { name: 'Редактировать' }).first().click();
      await see(p, 'Режим расстановки').waitFor({ timeout: 5000 });
      await settle(p, 1200);
      // Перетащить маркер помещения мышью на 60 px вправо и 40 px вниз.
      // Маркер — не строка списка слева (на ПК у неё та же подпись): подпись
      // маркера — «Кафе, 1 этаж, нет открытых заявок» одной строкой.
      const marker = p.getByRole('button', { name: /^Кафе, 1 этаж, / }).first();
      const box = await marker.boundingBox();
      if (!box) throw new Error('Маркер «Кафе» не найден');
      const x = box.x + box.width / 2, y = box.y + 22;
      await p.mouse.move(x, y);
      await p.mouse.down();
      for (let i = 1; i <= 10; i++) await p.mouse.move(x + 6 * i, y + 4 * i);
      await p.mouse.up();
      await see(p, 'Сохранено').waitFor({ timeout: 10000 });
      await settle(p, 800);
      // С шага 16 у помещений есть области: под курсором может оказаться
      // маркер оборудования внутри «Кафе» — годится любой перенос.
      if (!p.sandboxWrites.some((w) => w.includes('/locations') || w.includes('/assets'))) {
        throw new Error('Перенос маркера не дошёл до сохранения');
      }
      return `плашка режима, контур маркеров; перенос «Кафе» перехвачен (${p.sandboxWrites.length} записей не ушли в базу)`;
    }, after: async (p) => { await unsandbox(p); } },
  { key: 'plan-unplaced', title: 'План — список «На плане / Не размещены»', managerOnly: true, run: async (p) => {
      await openPlan(p, 10, 601);
      const vp = p.viewportSize();
      if (vp.width < 900) {
        // Выдвижная панель: нажать на её заголовок — раскрывается.
        await p.getByRole('button', { name: /^На плане · \d+, Не размещены/ }).first().click();
        await settle(p, 1200);
      }
      await see(p, /Не размещены · \d/).waitFor({ timeout: 5000 });
      return '«Open space, 2 этаж» — без этажа, в «Не размещены»';
    } },
  { key: 'plan-info', title: 'Подсказка ⓘ «Что значат маркеры»', managerOnly: true, run: async (p) => {
      await openPlan(p, 10, 602);
      await btn(p, 'Подсказка: Что значат маркеры').click();
      await see(p, 'Понятно').waitFor({ timeout: 5000 });
      await settle(p, 800);
    }, after: async (p) => { await p.keyboard.press('Escape'); await settle(p, 400); } },
  // Карточка заявки на оборудовании этажа: «Показать на плане».
  { key: 'plan-order', title: 'Карточка заявки — «Показать на плане»', managerOnly: true, run: async (p) => {
      await home(p);
      await openOrder(p, 'Течёт конденсат из кондиционера серверной');
      await see(p, 'Показать на плане').waitFor({ timeout: 20000 });
      await see(p, 'Показать на плане').scrollIntoViewIfNeeded().catch(() => {});
      await settle(p, 1500);
      return 'превью плана, «3 этаж · N открытых заявок рядом»';
    } },
  { key: 'plan-from-order', title: 'План, открытый из заявки (маркер подсвечен)', managerOnly: true, run: async (p) => {
      await home(p);
      await openOrder(p, 'Течёт конденсат из кондиционера серверной');
      await btn(p, 'Показать на плане').click();
      await see(p, /Не размещены|На плане/).waitFor({ timeout: 20000 });
      // Волны идут 4 с после открытия: кадр — пока они видны (после
      // приближения ~0,6 с), затем — спокойный ореол.
      await settle(p, 1400);
      return 'план центрирован на «Кондиционер серверной»: красные волны (просрочено), маркер ×1,25, подпись полужирная';
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

// --width=360 — снять только одну ширину (для отладки).
const WIDTH = +(process.argv.find((a) => a.startsWith('--width='))?.slice(8) ?? 0);

const RUNS = [
  // ПК: широкое меню слева (≥ 1200) и служебные кнопки справа вверху.
  { role: 'manager', label: 'Менеджер', width: 1920, height: 1080 },
  { role: 'manager', label: 'Менеджер', width: 1280, height: 800 },
  { role: 'manager', label: 'Менеджер', width: 412, height: 915 },
  // Недорогие Android (Galaxy A17, HONOR X6c, Xiaomi): 360 px.
  { role: 'manager', label: 'Менеджер', width: 360, height: 780 },
  { role: 'executor', label: 'Исполнитель', width: 412, height: 915 },
  { role: 'requester', label: 'Заявитель', width: 412, height: 915 },
];

// ---------------------------------------------------------------------------
// Кадры для питча (--pitch): менеджер, 412 (телефон) и 1920 (ПК). Описания
// и тезисы — docs/screens/pitch/README.md (пишется руками, не перезаписывается).
// ---------------------------------------------------------------------------
const PITCH = [
  { file: '01-requests-phone', width: 412, key: 'requests' },
  { file: '02-filters-phone', width: 412, key: 'filters-panel' },
  { file: '03-voice-listening-phone', width: 412, key: 'voice' },
  { file: '04-voice-ai-check-phone', width: 412, key: 'voice-ai', run: async (p) => {
      await openVoice(p);
      await btn(p, 'Готово').click();
      await see(p, 'Проверьте заявку').waitFor({ timeout: 20000 });
      // Настоящий разбор YandexGPT (Edge Function voice-intake); «Отправить» не нажимаем.
      await see(p, 'Разобрано ИИ').waitFor({ timeout: 20000 })
        .catch(() => { throw new Error('Нет пометки «Разобрано ИИ» — сервер не ответил, разбор по словарю'); });
      await settle(p, 1500);
    } },
  { file: '05-order-show-on-plan-phone', width: 412, key: 'plan-order' },
  // План целиком на 1920: из заявки, затем «Вписать план».
  { file: '06-floor-plan-desktop', width: 1920, key: 'plan-from-order', run: async (p) => {
      await home(p);
      await openOrder(p, 'Течёт конденсат из кондиционера серверной');
      await btn(p, 'Показать на плане').click();
      await see(p, /Не размещены|На плане/).waitFor({ timeout: 20000 });
      await settle(p, 200);
      await btn(p, 'Вписать план').click();
      await p.mouse.move(5, 5);
      // Снимок 1920 в контейнере идёт ~3 с — дольше окна волн (4 с), на кадре —
      // спокойный ореол; волны — в docs/screens/latest/*-plan-from-order.png.
      await settle(p, 1200);
    } },
  { file: '07-floor-plan-marker-phone', width: 412, key: 'plan-marker' },
  { file: '08-world-map-desktop', width: 1920, key: 'map' },
  { file: '09-moscow-map-phone', width: 412, key: 'map-city' },
  { file: '10-reports-desktop', width: 1920, key: 'reports' },
  // Подрядчик в двух городах (Шэньчжэнь и Пекин) — видны секции по городам.
  { file: '11-contractor-card-desktop', width: 1920, key: 'contractor-card', run: async (p) => {
      await home(p);
      await nav(p, 'Подрядчики').click();
      await p.getByRole('button', { name: /Huaxin FM/ }).first().click();
      await see(p, /Виды работ/).waitFor({ timeout: 15000 });
      await settle(p, 1200);
    } },
  { file: '12-home-desktop', width: 1920, key: 'requests' },
];

if (PITCH_MODE) {
  mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  const failed = [];
  try {
    for (const width of [412, 1920].filter((w) => PITCH.some((x) => x.width === w && (!ONLY || x.file.startsWith(ONLY))))) {
      const ctx = await browser.newContext({ viewport: { width, height: width > 600 ? 1080 : 915 },
        locale: 'ru-RU', deviceScaleFactor: width > 600 ? 1 : 2 });
      const page = await ctx.newPage();
      trackTiles(page);
      page.role = 'manager';
      await login(page, env.DEMO_MANAGER_EMAIL, env.DEMO_MANAGER_PASSWORD);
      for (const f of PITCH.filter((x) => x.width === width && (!ONLY || x.file.startsWith(ONLY)))) {
        const s = SCREENS.find((x) => x.key === f.key);
        const name = `${f.file}.png`;
        try {
          await (f.run ?? s.run)(page);
          await page.screenshot({ path: join(OUT, name) });
          console.log(`  ✅ ${name}`);
        } catch (e) {
          failed.push(`${name}: ${String(e.message).split('\n')[0]}`);
          console.log(`  ❌ ${name}: ${String(e.message).split('\n')[0]}`);
        }
        if (s?.after) await s.after(page).catch(() => {});
      }
      await ctx.close();
    }
  } finally {
    await browser.close();
    server.close();
  }
  for (const f of readdirSync(OUT).filter((f) => f.endsWith('.png'))) {
    try { execFileSync('pngquant', ['--force', '--skip-if-larger', '--quality=70-95', '--ext', '.png', join(OUT, f)]); } catch {}
  }
  console.log(`Питч: ${PITCH.length - failed.length} из ${PITCH.length} кадров — ${OUT}`);
  process.exit(failed.length ? 1 : 0);
}

// ---------------------------------------------------------------------------
// Съёмка
// ---------------------------------------------------------------------------
rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
const results = [];
const browser = await chromium.launch();
try {
  for (const r of RUNS) {
    if (WIDTH && r.width !== WIDTH) continue;
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
    // Предпросмотр (шаги 13d, 14b) — только с флагом --preview: с шага 15
    // объекты по миру, этажи, оборудование и картинки планов уже в базе.
    if (loggedIn && PREVIEW) {
      await routeWorldPreview(page);
      if (r.role !== 'manager') page.worldPreview = 'off';
    }
    for (const s of SCREENS) {
      if (!loggedIn) break;
      page.previewUsed = false;
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
        const text = [typeof note === 'string' ? note : null,
          page.previewUsed ? PREVIEW_TEXT : null].filter(Boolean).join('. ');
        results.push({ ...r, key: s.key, title: s.title, ok: true, file: name,
          note: text || undefined });
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
