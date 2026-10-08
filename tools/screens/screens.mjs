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
const see = (page, text) => page.getByRole('tab', { name: text })
  .or(page.getByRole('button', { name: text }))
  .or(page.getByText(text)).first();
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

const nav = (page, label) => page.getByRole('tab', { name: label })
  .or(page.getByRole('button', { name: label, exact: true })).first();

async function openVoice(page) {
  await home(page);
  await page.getByRole('button', { name: 'Нажми и говори' }).first().click();
  await see(page, 'очень жарко').waitFor({ timeout: 20000 });
  await settle(page, 1000);
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
  { key: 'order', title: `Карточка заявки «${DEMO_ORDER}»`, run: async (p) => {
      await home(p);
      await p.getByRole('button', { name: DEMO_ORDER }).first().click();
      await see(p, 'Подрядчик').waitFor({ timeout: 20000 });
      await settle(p);
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
      await see(p, /^Подрядчики$|Закреплены за этим видом работ|никто не закреплён/)
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
      if (s.managerOnly && r.role !== 'manager') {
        results.push({ ...r, key: s.key, title: s.title, ok: null, note: 'Нет у этой роли (так задумано)' });
        continue;
      }
      const name = `${r.role}-${r.width}-${s.key}.png`;
      try {
        const note = await s.run(page);
        await page.screenshot({ path: join(OUT, name) });
        results.push({ ...r, key: s.key, title: s.title, ok: true, file: name,
          note: typeof note === 'string' ? note : undefined });
        if (s.after) await s.after(page).catch(() => {});
      } catch (e) {
        await page.screenshot({ path: join(OUT, name.replace('.png', '-error.png')) }).catch(() => {});
        if (s.after) await s.after(page).catch(() => {});
        results.push({ ...r, key: s.key, title: s.title, ok: false, file: name.replace('.png', '-error.png'),
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
for (const f of readdirSync(OUT).filter((f) => f.endsWith('.png'))) {
  const size = statSync(join(OUT, f)).size;
  if (size > MAX_PNG) {
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
