// Синтетические ДЕМО-СХЕМЫ этажей для компании «Демо БЦ» (шаг 14b).
//
// Источник один — plans.json рядом: по нему этот скрипт
//   1) рисует SVG и через Playwright (Chromium) сохраняет PNG 2400×1600
//      в assets/demo_plans/ (папка не подключена в pubspec — в приложение
//      не попадает; файлы загружают через приложение: объект → этаж →
//      «Загрузить план»);
//   2) пишет SQL-блок «5d» в supabase/seed/demo_history.sql между строками
//      «-- >>> demo_plans» и «-- <<< demo_plans»: этажи 601–603, помещения
//      на планах, оборудование 701–720, заявки 254–257 — с теми же точками,
//      что на картинках.
// /screens читает тот же plans.json для предпросмотра.
//
// Схемы выдуманы и не повторяют никакой реальный план. Реальные планы
// зданий в репозиторий и в «Демо БЦ» не загружать.
//
// Запуск: cd tools/demo_plans && PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node generate.mjs
//   --sql-only — только SQL-блок, без картинок.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const HERE = import.meta.dirname;
const ROOT = resolve(HERE, '../..');
const PLANS = JSON.parse(readFileSync(join(HERE, 'plans.json'), 'utf8'));
const OUT = join(ROOT, 'assets/demo_plans');
const SEED = join(ROOT, 'supabase/seed/demo_history.sql');
const W = PLANS.width, H = PLANS.height;

const uuid = (n) => `'de300000-0000-4000-8000-${String(n).padStart(12, '0')}'::uuid`;
const q = (s) => (s == null ? 'null' : `'${String(s).replace(/'/g, "''")}'`);
const frac = (v, max) => Math.round((v / max) * 10000) / 10000;
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/** Точка помещения на плане — центр прямоугольника, доли 0..1. */
export function roomPoint(room) {
  const [x, y, w, h] = room.rect;
  return [frac(x + w / 2, W), frac(y + h / 2, H)];
}

/** Область помещения на плане — прямоугольник комнаты, доли 0..1 (plan_shape, шаг 16). */
export function roomShape(room) {
  const [x, y, w, h] = room.rect;
  return {
    type: 'polygon',
    points: [[x, y], [x + w, y], [x + w, y + h], [x, y + h]].map(([px, py]) => [frac(px, W), frac(py, H)]),
  };
}

// ---------------------------------------------------------------------------
// SVG
// ---------------------------------------------------------------------------
const INK = '#2F3A37';
const PAPER = '#FBFBF8';
const ROOM = '#FFFFFF';
const DECOR = '#F1F3F2';
const DOOR = 96;

function door(rect, [side, at]) {
  const [x, y, w, h] = rect;
  let gx, gy, horizontal;
  switch (side) {
    case 'bottom': gx = x + w * at; gy = y + h; horizontal = true; break;
    case 'top': gx = x + w * at; gy = y; horizontal = true; break;
    case 'left': gx = x; gy = y + h * at; horizontal = false; break;
    default: gx = x + w; gy = y + h * at; horizontal = false;
  }
  const half = DOOR / 2;
  // Проём (перекрыть стену фоном) и дуга открывания.
  const gap = horizontal
    ? `<line x1="${gx - half}" y1="${gy}" x2="${gx + half}" y2="${gy}" stroke="${ROOM}" stroke-width="14"/>`
    : `<line x1="${gx}" y1="${gy - half}" x2="${gx}" y2="${gy + half}" stroke="${ROOM}" stroke-width="14"/>`;
  const inward = side === 'bottom' ? -1 : side === 'top' ? 1 : side === 'left' ? 1 : -1;
  const arc = horizontal
    ? `<path d="M ${gx - half} ${gy} L ${gx - half} ${gy + inward * DOOR} A ${DOOR} ${DOOR} 0 0 ${inward < 0 ? 1 : 0} ${gx + half} ${gy}" fill="none" stroke="${INK}" stroke-width="3" stroke-dasharray="10 8"/>`
    : `<path d="M ${gx} ${gy - half} L ${gx + inward * DOOR} ${gy - half} A ${DOOR} ${DOOR} 0 0 ${inward < 0 ? 0 : 1} ${gx} ${gy + half}" fill="none" stroke="${INK}" stroke-width="3" stroke-dasharray="10 8"/>`;
  return gap + arc;
}

function furniture(room) {
  const [x, y, w, h] = room.rect;
  const out = [];
  const n = room.name.toLowerCase();
  if (n.includes('open space') || n.includes('рабочая зона')) {
    // Ряды столов.
    for (let ry = y + 180; ry + 120 < y + h - 60; ry += 240) {
      for (let rx = x + 120; rx + 200 < x + w - 80; rx += 280) {
        out.push(`<rect x="${rx}" y="${ry}" width="200" height="90" rx="10" fill="none" stroke="#B9C2BF" stroke-width="4"/>`);
      }
    }
  } else if (n.includes('переговорная')) {
    out.push(`<rect x="${x + w / 2 - 170}" y="${y + h / 2 + 60}" width="340" height="120" rx="60" fill="none" stroke="#B9C2BF" stroke-width="4"/>`);
  } else if (n.includes('лестница') || n.includes('лифт')) {
    for (let i = 0; i < 9; i++) {
      out.push(`<line x1="${x + 60}" y1="${y + 90 + i * 28}" x2="${x + 300}" y2="${y + 90 + i * 28}" stroke="#B9C2BF" stroke-width="4"/>`);
    }
    out.push(`<rect x="${x + w - 330}" y="${y + 80}" width="120" height="140" fill="none" stroke="#B9C2BF" stroke-width="4"/>`);
    out.push(`<rect x="${x + w - 190}" y="${y + 80}" width="120" height="140" fill="none" stroke="#B9C2BF" stroke-width="4"/>`);
  } else if (n.includes('серверная')) {
    for (let i = 0; i < 3; i++) {
      out.push(`<rect x="${x + 220 + i * 80}" y="${y + h - 230}" width="60" height="160" fill="none" stroke="#B9C2BF" stroke-width="4"/>`);
    }
  }
  return out.join('');
}

function svgFor(floor) {
  const parts = [];
  parts.push(`<rect width="${W}" height="${H}" fill="${PAPER}"/>`);
  // Сетка 40 px — как миллиметровка.
  parts.push(`<defs><pattern id="g" width="40" height="40" patternUnits="userSpaceOnUse"><path d="M40 0H0V40" fill="none" stroke="#ECEFED" stroke-width="1"/></pattern></defs>`);
  parts.push(`<rect width="${W}" height="${H}" fill="url(#g)"/>`);
  for (const r of floor.rooms) {
    const [x, y, w, h] = r.rect;
    parts.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${r.id ? ROOM : DECOR}" stroke="${INK}" stroke-width="10"/>`);
    parts.push(furniture(r));
  }
  // Наружные стены — толще.
  const xs = floor.rooms.flatMap((r) => [r.rect[0], r.rect[0] + r.rect[2]]);
  const ys = floor.rooms.flatMap((r) => [r.rect[1], r.rect[1] + r.rect[3]]);
  const [bx0, bx1, by0, by1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
  parts.push(`<rect x="${bx0}" y="${by0}" width="${bx1 - bx0}" height="${by1 - by0}" fill="none" stroke="${INK}" stroke-width="22"/>`);
  for (const r of floor.rooms) if (r.door) parts.push(door(r.rect, r.door));
  // Подписи помещений: названия — как в базе.
  for (const r of floor.rooms) {
    const [x, y, w, h] = r.rect;
    // Подпись — у стены без двери (дуга двери не наезжает на текст);
    // центр комнаты свободен под маркер приложения.
    const top = r.door?.[0] !== 'top';
    const cx = x + w / 2, cy = r.id ? (top ? y + 70 : y + h - 60) : y + h / 2 + (r.name.toLowerCase().includes('рабочая') ? 150 : 0);
    const size = r.id ? 34 : 30;
    parts.push(`<text x="${cx}" y="${cy}" text-anchor="middle" dominant-baseline="middle" font-family="Onest, Arial, sans-serif" font-size="${size}" font-weight="${r.id ? 600 : 400}" fill="${r.id ? INK : '#7A8682'}"${r.id ? '' : ' font-style="italic"'}>${esc(r.name)}</text>`);
  }
  // Штамп.
  parts.push(`<rect x="${W - 860}" y="${H - 104}" width="740" height="64" rx="10" fill="#FFF4D6" stroke="#C8A44A" stroke-width="3"/>`);
  parts.push(`<text x="${W - 490}" y="${H - 72}" text-anchor="middle" dominant-baseline="middle" font-family="Onest, Arial, sans-serif" font-size="30" font-weight="700" fill="#6B5414">ДЕМО-СХЕМА · не реальный план</text>`);
  parts.push(`<text x="120" y="${H - 72}" dominant-baseline="middle" font-family="Onest, Arial, sans-serif" font-size="30" font-weight="600" fill="${INK}">${esc(floor.objectName)} · ${esc(floor.name)}</text>`);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${parts.join('')}</svg>`;
}

// ---------------------------------------------------------------------------
// SQL
// ---------------------------------------------------------------------------
function sqlBlock() {
  const L = [];
  const floors = PLANS.floors;
  L.push('  -- >>> demo_plans: сгенерировано tools/demo_plans/generate.mjs из plans.json — руками не править');
  L.push('  -- 5d. Этажи и ДЕМО-СХЕМЫ планов (шаг 14b): этажи 601–603, помещения на планах,');
  L.push('  --     оборудование 701–720, заявки 254–257 на этом оборудовании (254 — просрочена).');
  L.push('  --     plan_path / plan_w / plan_h НЕ трогаются: картинки загружают через приложение');
  L.push('  --     (assets/demo_plans/*.png), повторный запуск их не затирает.');
  // Этаж с тем же названием, созданный руками, мешал бы (название уникально в объекте).
  L.push('  update public.floors f set name = left(f.name, 50) || \' (старый)\'');
  L.push('   where f.company_id = c_company');
  L.push(`     and f.id not in (${floors.map((f) => uuid(f.id)).join(', ')})`);
  L.push('     and exists (select 1 from (values');
  L.push(floors.map((f) => `       (${uuid(f.object)}, ${q(f.name)})`).join(',\n'));
  L.push('     ) as d(o, n) where d.o = f.object_id and d.n = f.name);');
  L.push('  insert into public.floors (id, company_id, object_id, name, level, sort) values');
  L.push(floors.map((f) => `    (${uuid(f.id)}, c_company, ${uuid(f.object)}, ${q(f.name)}, ${f.level}, ${f.sort})`).join(',\n'));
  L.push('  on conflict (id) do update set name = excluded.name, level = excluded.level, sort = excluded.sort;');
  L.push('');
  const fresh = floors.flatMap((f) => f.rooms.filter((r) => r.id && r.new).map((r) => ({ f, r })));
  L.push('  -- Новые помещения на схемах.');
  L.push('  insert into public.locations (id, object_id, name) values');
  L.push(fresh.map(({ f, r }) => `    (${uuid(r.id)}, ${uuid(f.object)}, ${q(r.name)})`).join(',\n'));
  L.push('  on conflict (id) do update set name = excluded.name, object_id = excluded.object_id;');
  const placed = floors.flatMap((f) => f.rooms.filter((r) => r.id).map((r) => ({ f, r })));
  // Номер помещения уникален в объекте (0015): тот же номер у помещения,
  // созданного руками, снимаем, чтобы не мешал.
  L.push('  -- Номера помещений (шаг 16): тот же номер у помещения, созданного руками, снимается.');
  L.push('  update public.locations l set code = null');
  L.push('    from (values');
  L.push(placed.map(({ f, r }) => `      (${uuid(r.id)}, ${uuid(f.object)}, ${q(r.code)})`).join(',\n'));
  L.push('    ) as v(id, o, code)');
  L.push('   where l.object_id = v.o and lower(btrim(l.code)) = lower(v.code) and l.id <> v.id');
  L.push(`     and l.id not in (${placed.map(({ r }) => uuid(r.id)).join(', ')});`);
  L.push('  -- Этаж, точка (центр комнаты на схеме, доли 0..1), номер и область помещения');
  L.push('  -- (прямоугольник комнаты — многоугольник из 4 точек, шаг 16).');
  L.push('  update public.locations l set floor_id = v.f, plan_x = v.x, plan_y = v.y, code = v.code, plan_shape = v.shape');
  L.push('    from (values');
  L.push(placed.map(({ f, r }) => {
    const [x, y] = roomPoint(r);
    return `      (${uuid(r.id)}, ${uuid(f.id)}, ${x}::real, ${y}::real, ${q(r.code)}, '${JSON.stringify(roomShape(r))}'::jsonb)`;
  }).join(',\n'));
  L.push('    ) as v(id, f, x, y, code, shape)');
  L.push('   where l.id = v.id;');
  L.push('');
  L.push('  -- Оборудование: вид (meta.kind) — для значка на плане.');
  L.push('  insert into public.assets (id, location_id, name, category, inventory_no, meta, floor_id, plan_x, plan_y) values');
  const assets = floors.flatMap((f) => f.assets.map((a) => ({ f, a })));
  L.push(assets.map(({ f, a }) =>
    `    (${uuid(a.id)}, ${uuid(a.room)}, ${q(a.name)}, ${q(a.category)}, ${q(a.inv)}, '{"kind":"${a.kind}","demo":true}'::jsonb, ${uuid(f.id)}, ${frac(a.at[0], W)}, ${frac(a.at[1], H)})`
  ).join(',\n'));
  L.push('  on conflict (id) do update set');
  L.push('    location_id = excluded.location_id, name = excluded.name, category = excluded.category,');
  L.push('    inventory_no = excluded.inventory_no, meta = excluded.meta, floor_id = excluded.floor_id,');
  L.push('    plan_x = excluded.plan_x, plan_y = excluded.plan_y;');
  L.push('');
  L.push('  -- Заявки на оборудовании этажей. Колонки как в 5c, плюс a — оборудование.');
  L.push('  insert into public.work_orders (');
  L.push('    id, company_id, object_id, location_id, asset_id, title, description, work_type, layer_id,');
  L.push('    priority, status, requires_photo, input_channel, created_by,');
  L.push('    assigned_contractor_id, assigned_by, due_at, created_at, updated_at, started_at,');
  L.push('    return_count, recurrence)');
  L.push('  select');
  L.push("    ('de300000-0000-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,");
  L.push('    c_company, lo.object_id, lo.id,');
  L.push("    ('de300000-0000-4000-8000-' || lpad(t.a::text, 12, '0'))::uuid,");
  L.push('    t.title, t.descr, ly.name, ly.id, t.priority, t.status, ly.requires_photo, t.channel,');
  L.push("    case t.author when 'mgr' then v_manager else v_requester end,");
  L.push("    case when t.c is not null then ('de300000-0000-4000-8000-' || lpad(t.c::text, 12, '0'))::uuid end,");
  L.push("    case when t.c is not null then 'rule' end,");
  L.push('    x.created + make_interval(hours => t.due_h),');
  L.push('    x.created,');
  L.push("    case when t.r is not null then x.created + make_interval(mins => t.r) else x.created end,");
  L.push('    case when t.r is not null then x.created + make_interval(mins => t.r) end,');
  L.push('    0, null');
  L.push('  from (values');
  L.push(PLANS.orders.map((o, i) =>
    `    (${o.id},${q(o.layer)},${o.room},${o.asset},${o.contractor ?? 'null'}${i === 0 ? '::int' : ''},${q(o.title)},${q(o.descr)},${q(o.priority)},${q(o.status)},${q(o.author)},${q(o.channel)},${o.d},${o.h},${o.r ?? 'null'}${i === 0 ? '::int' : ''},${o.due_h})`
  ).join(',\n'));
  L.push('  ) as t(n, layer, loc, a, c, title, descr, priority, status, author, channel, d, h, r, due_h)');
  L.push('  cross join lateral (');
  L.push('    select v_today - make_interval(days => t.d) + make_interval(hours => t.h) as created');
  L.push('  ) x');
  L.push('  join public.locations lo');
  L.push("    on lo.id = ('de300000-0000-4000-8000-' || lpad(t.loc::text, 12, '0'))::uuid");
  L.push('  join public.layers ly');
  L.push("    on ly.id = case t.layer when 'hvac' then v_layer_hvac when 'elec' then v_layer_elec");
  L.push("                            when 'plumb' then v_layer_plumb when 'clean' then v_layer_clean");
  L.push('                            else v_layer_other end');
  L.push('  on conflict (id) do update set');
  L.push('    company_id = excluded.company_id, object_id = excluded.object_id,');
  L.push('    location_id = excluded.location_id, asset_id = excluded.asset_id,');
  L.push('    title = excluded.title, description = excluded.description,');
  L.push('    work_type = excluded.work_type, layer_id = excluded.layer_id,');
  L.push('    priority = excluded.priority, status = excluded.status, recurrence = null,');
  L.push('    requires_photo = excluded.requires_photo, requires_scan = false,');
  L.push('    input_channel = excluded.input_channel, created_by = excluded.created_by,');
  L.push('    assigned_contractor_id = excluded.assigned_contractor_id,');
  L.push('    assigned_executor_id = null, assigned_by = excluded.assigned_by,');
  L.push('    due_at = excluded.due_at, time_spent_minutes = null,');
  L.push('    created_at = excluded.created_at, updated_at = excluded.updated_at,');
  L.push('    started_at = excluded.started_at, submitted_at = null,');
  L.push('    accepted_at = null, accepted_by = null,');
  L.push('    return_reason = null, return_count = 0;');
  L.push('  get diagnostics v_plan_orders = row_count;');
  L.push('  v_orders := v_orders + v_plan_orders;');
  L.push('  -- <<< demo_plans');
  return L.join('\n');
}

function writeSql() {
  const seed = readFileSync(SEED, 'utf8');
  const start = seed.indexOf('  -- >>> demo_plans');
  const endMark = '  -- <<< demo_plans';
  const end = seed.indexOf(endMark);
  if (start < 0 || end < 0) throw new Error('В demo_history.sql нет строк «-- >>> demo_plans» / «-- <<< demo_plans»');
  const next = seed.slice(0, start) + sqlBlock() + seed.slice(end + endMark.length);
  writeFileSync(SEED, next);
  console.log('SQL-блок 5d обновлён: supabase/seed/demo_history.sql');
}

async function writePngs() {
  const { chromium } = await import(new URL('../screens/node_modules/playwright/index.mjs', import.meta.url));
  mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
    // Шрифт приложения (Onest, OFL) — из assets/fonts, без сети.
    const face = (file, weight) => `@font-face{font-family:Onest;font-weight:${weight};src:url(data:font/ttf;base64,${
      readFileSync(join(ROOT, 'assets/fonts', file)).toString('base64')})}`;
    const fontFace = face('Onest-Regular.ttf', 400) + face('Onest-SemiBold.ttf', 600) + face('Onest-Bold.ttf', 700);
    for (const f of PLANS.floors) {
      await page.setContent(`<!doctype html><html><head><style>${fontFace}html,body{margin:0}</style></head><body>${svgFor(f)}</body></html>`);
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({ path: join(OUT, f.file), clip: { x: 0, y: 0, width: W, height: H } });
      console.log('PNG:', join('assets/demo_plans', f.file));
    }
  } finally {
    await browser.close();
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  writeSql();
  if (!process.argv.includes('--sql-only')) await writePngs();
}
