// Запасное видео демо (шаг 18): главный сценарий на локальной базе, без интернета.
//   node record_demo.mjs [--phone] [--out=<файл.mp4>]
// Запуск через record_demo.sh (база, сборка, PostgREST).
//
// Как устроено:
//   • локальный бэкенд (../screens/local_backend.mjs) с подменённым ИИ —
//     демо-данные «Демо БЦ», планы — нарисованные ДЕМО-СХЕМЫ;
//   • кадры — Chrome DevTools «screencast» (JPEG, по каждому изменению
//     экрана, с отметкой времени), потом ffmpeg собирает H.264 30 к/с;
//   • курсор и подписи внизу — элементы страницы поверх приложения
//     (в безголовом браузере своего курсора нет), без монтажа;
//   • за кадром исполнитель «КлиматСервиса» начинает работу в геозоне и
//     загружает фото «после» — в кадре менеджер видит доказательства и принимает.
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { startLocalBackend } from '../screens/local_backend.mjs';
import {
  ROOT, USERS, btn, chromium, home, login, openApp, profileTab, raw, see, settle, sql, startWeb, typeInto, uuid, waitDb,
} from './lib.mjs';

const PHONE = process.argv.includes('--phone');
const OUT = resolve(process.argv.find((a) => a.startsWith('--out='))?.slice(6)
  ?? join(ROOT, 'docs/demo', PHONE ? 'hey-helpy-demo-phone.mp4' : 'hey-helpy-demo.mp4'));
const VIEW = PHONE ? { width: 412, height: 915, scale: 2 } : { width: 1920, height: 1080, scale: 1 };
const FRAMES = mkdtempSync(join(tmpdir(), 'hh-demo-frames-'));
const TMP = mkdtempSync(join(tmpdir(), 'hh-demo-'));

process.env.HH_MOCK_AI = '1';
process.env.HH_MOCK_AI_MS = '1600';
const backend = await startLocalBackend({ port: 54321 });
const web = await startWeb();
const browser = await chromium.launch({ args: ['--disable-dev-shm-usage'] }); // /dev/shm в контейнере — 64 МБ
const base = web.base;

// Чистое состояние: убрать заявки прошлых записей, второму менеджеру — зона.
sql(`delete from work_orders where company_id = '${uuid(1)}' and id::text not like 'de300000-%'`);

// ---------------------------------------------------------------------------
// Курсор и подписи — поверх приложения.
// ---------------------------------------------------------------------------
const OVERLAY = () => {
  const add = () => {
    if (document.getElementById('hh-cursor')) return;
    const c = document.createElement('div');
    c.id = 'hh-cursor';
    c.style.cssText = 'position:fixed;left:-50px;top:-50px;width:26px;height:26px;z-index:2147483647;'
      + 'pointer-events:none;transition:transform .08s;';
    c.innerHTML = '<svg width="26" height="26" viewBox="0 0 26 26"><path d="M3 2 L3 21 L8.5 16 L12.5 24 L16 22.4 L12 14.6 L19.5 14.6 Z" '
      + 'fill="#111" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/></svg>';
    const ring = document.createElement('div');
    ring.id = 'hh-ring';
    ring.style.cssText = 'position:fixed;width:44px;height:44px;margin:-22px 0 0 -22px;border-radius:50%;'
      + 'border:3px solid rgba(45,184,154,.9);z-index:2147483646;pointer-events:none;opacity:0;transform:scale(.4);'
      + 'transition:opacity .35s, transform .35s;';
    const cap = document.createElement('div');
    cap.id = 'hh-caption';
    const small = innerWidth < 600;
    cap.style.cssText = `position:fixed;left:0;right:0;margin:0 auto;width:fit-content;bottom:${small ? 84 : 28}px;`
      + `max-width:${small ? 92 : 80}%;box-sizing:border-box;padding:${small ? '8px 14px' : '12px 26px'};border-radius:14px;`
      + 'background:rgba(6,43,35,.88);color:#fff;'
      + `font:600 ${small ? 17 : 26}px/1.3 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;text-align:center;`
      + 'z-index:2147483645;pointer-events:none;opacity:0;transition:opacity .4s;';
    const img = document.createElement('img');
    img.id = 'hh-pdf';
    img.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%) scale(.96);max-height:84%;'
      + 'max-width:80%;box-shadow:0 20px 60px rgba(0,0,0,.35);border-radius:6px;z-index:2147483644;'
      + 'pointer-events:none;opacity:0;transition:opacity .4s, transform .4s;background:#fff;';
    document.body.append(img, cap, ring, c);
    window.addEventListener('mousemove', (e) => {
      c.style.left = `${e.clientX - 3}px`;
      c.style.top = `${e.clientY - 2}px`;
    }, true);
    window.addEventListener('mousedown', (e) => {
      c.style.transform = 'scale(.85)';
      ring.style.left = `${e.clientX}px`;
      ring.style.top = `${e.clientY}px`;
      ring.style.transition = 'none';
      ring.style.opacity = '1';
      ring.style.transform = 'scale(.4)';
      requestAnimationFrame(() => {
        ring.style.transition = 'opacity .45s, transform .45s';
        ring.style.opacity = '0';
        ring.style.transform = 'scale(1.3)';
      });
    }, true);
    window.addEventListener('mouseup', () => { c.style.transform = ''; }, true);
  };
  if (document.body) add(); else document.addEventListener('DOMContentLoaded', add);
  window.__caption = (t) => {
    add();
    const cap = document.getElementById('hh-caption');
    if (!t) { cap.style.opacity = '0'; return; }
    cap.textContent = t;
    cap.style.opacity = '1';
  };
  window.__pdf = (src) => {
    add();
    const img = document.getElementById('hh-pdf');
    if (!src) { img.style.opacity = '0'; img.style.transform = 'translate(-50%,-50%) scale(.96)'; return; }
    img.src = src;
    img.style.opacity = '1';
    img.style.transform = 'translate(-50%,-50%) scale(1)';
  };
};

async function context({ geo, record = false } = {}) {
  const ctx = await browser.newContext({
    viewport: { width: VIEW.width, height: VIEW.height }, deviceScaleFactor: VIEW.scale, locale: 'ru-RU',
    ...(geo ? { geolocation: geo, permissions: ['geolocation'] } : {}),
  });
  await ctx.addInitScript(() => {
    const orig = URL.createObjectURL;
    URL.createObjectURL = function (obj) {
      try { if (obj && obj.type === 'application/pdf') window.__pdfBlob = obj; } catch {}
      return orig.call(URL, obj);
    };
    window.print = () => {};
  });
  if (record) await ctx.addInitScript(OVERLAY);
  return ctx;
}

// ---------------------------------------------------------------------------
// Запись кадров (CDP screencast).
// ---------------------------------------------------------------------------
let frameN = 0;
let recording = false;
const frameTimes = [];
// Пауза записи (исполнитель работает за кадром): время паузы вычитается.
let paused = 0;
let pauseAt = 0;
const pause = () => { recording = false; pauseAt = Date.now() / 1000; };
const resume = () => { paused += Date.now() / 1000 - pauseAt; recording = true; };
async function startRecording(page) {
  const cdp = await page.context().newCDPSession(page);
  cdp.on('Page.screencastFrame', async (f) => {
    if (recording) {
      const n = frameN++;
      writeFileSync(join(FRAMES, `f${String(n).padStart(6, '0')}.jpg`), Buffer.from(f.data, 'base64'));
      frameTimes.push(f.metadata.timestamp - paused);
    }
    await cdp.send('Page.screencastFrameAck', { sessionId: f.sessionId }).catch(() => {});
  });
  await cdp.send('Page.startScreencast', {
    format: 'jpeg', quality: 92, maxWidth: VIEW.width * VIEW.scale, maxHeight: VIEW.height * VIEW.scale, everyNthFrame: 1,
  });
  recording = true;
  return async () => {
    recording = false;
    await cdp.send('Page.stopScreencast').catch(() => {});
  };
}

// ---------------------------------------------------------------------------
// Действия «как человек»: плавно подвести курсор, нажать, подождать.
// ---------------------------------------------------------------------------
let cur = { x: VIEW.width / 2, y: VIEW.height / 2 };
async function moveTo(page, x, y, ms = 520) {
  const steps = Math.max(8, Math.round(ms / 16));
  const from = { ...cur };
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    const e = t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2; // плавно
    await page.mouse.move(from.x + (x - from.x) * e, from.y + (y - from.y) * e);
    await page.waitForTimeout(ms / steps);
  }
  cur = { x, y };
}
async function tap(page, locator, { pause = 900, ms } = {}) {
  await locator.waitFor({ timeout: 20000 });
  await locator.scrollIntoViewIfNeeded().catch(() => {});
  const b = await locator.boundingBox();
  await moveTo(page, b.x + b.width / 2, b.y + b.height / 2, ms);
  await page.waitForTimeout(180);
  await page.mouse.click(cur.x, cur.y);
  await page.waitForTimeout(pause);
}
const caption = (page, t) => page.evaluate((x) => window.__caption?.(x), t);
const hold = (page, ms) => page.waitForTimeout(ms * (PHONE ? 0.8 : 0.4));
async function section(page, re) {
  await tap(page, page.getByRole('button', { name: re }).or(page.getByRole('tab', { name: re })).first(), { pause: 1600 });
}
async function search(page, text) {
  const box = page.getByRole('textbox').first();
  const b = await box.boundingBox();
  await moveTo(page, b.x + 60, b.y + b.height / 2);
  await box.click();
  await page.keyboard.type(text, { delay: 55 });
  await page.waitForTimeout(1500);
}
async function wheel(page, dy, times = 4) {
  for (let i = 0; i < times; i++) {
    await page.mouse.wheel(0, dy / times);
    await page.waitForTimeout(90);
  }
}

// ---------------------------------------------------------------------------
// За кадром: исполнитель «КлиматСервиса» — начать работу в геозоне, фото «после».
// ---------------------------------------------------------------------------
async function executorOffscreen(orderTitle) {
  const ctx = await context({ geo: { latitude: 44.80471, longitude: 20.44942, accuracy: 8 } });
  const e = await ctx.newPage();
  await login(e, base, USERS.executor);
  await home(e, base);
  await typeInto(e, e.getByRole('textbox').first(), orderTitle.slice(0, 24));
  await settle(e, 1500);
  await btn(e, new RegExp(orderTitle.slice(0, 18))).click();
  await settle(e, 1500);
  await btn(e, /^Начать работу/).click();
  // Заявка, созданная в кадре (не демо-заявка с похожим названием).
  const id = await waitDb(`select id from work_orders where title like '${orderTitle}%' and status = 'in_progress'
    and id::text not like 'de300000-%' order by created_at desc limit 1`, (v) => v.length > 0);
  await settle(e, 1500);
  const photo = join(TMP, 'after.jpg');
  // Картинка «после» — нарисованная (не реальное фото): чистый кондиционер.
  execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-f', 'lavfi', '-i',
    'color=c=0xEEF4F2:s=1200x900,drawbox=x=250:y=260:w=700:h=260:color=0xFFFFFF:t=fill,'
    + 'drawbox=x=250:y=260:w=700:h=260:color=0x9AA9A4:t=6,drawbox=x=300:y=440:w=600:h=18:color=0x6B7B76:t=fill,'
    + 'drawbox=x=820:y=300:w=80:h=40:color=0x2DB89A:t=fill', '-frames:v', '1', photo]);
  const chooser = e.waitForEvent('filechooser', { timeout: 15000 });
  await btn(e, /Сфотографировать результат/).click();
  await (await chooser).setFiles(photo);
  await waitDb(`select count(*) from attachments where work_order_id = '${id}' and stage = 'after'`, '1', 20000);
  await settle(e, 1500);
  await btn(e, /Выполнено, на проверку/).click();
  await waitDb(`select status from work_orders where id = '${id}'`, 'on_review');
  // Визит длился бы дольше: для кадра «время на объекте» — 42 минуты.
  sql(`update visits set started_at = now() - interval '47 minutes', ended_at = now() - interval '5 minutes'
    where work_order_id = '${id}'`);
  await ctx.close();
  return id;
}

// ---------------------------------------------------------------------------
// Сценарий
// ---------------------------------------------------------------------------
async function pcScenario(page) {
  await caption(page, 'Эй, Helpy — ИИ-сервис эксплуатации зданий: все заявки в одном месте');
  await moveTo(page, 600, 420, 900);
  await hold(page, 3500);

  // 1. Заявка голосом.
  await caption(page, 'Заявка голосом: «Эй, Хелпи, в переговорной не работает кондиционер…»');
  await tap(page, page.getByRole('button', { name: /Нажми и говори|^Эй, Helpy/ }).first(), { pause: 600 });
  await see(page, /очень жарко/).waitFor({ timeout: 20000 });
  await hold(page, 1400);
  await tap(page, btn(page, /^Готово/), { pause: 200 });
  await caption(page, 'ИИ разбирает речь…');
  await see(page, /Проверьте заявку/).waitFor({ timeout: 20000 });
  await caption(page, 'Заявка голосом — ИИ разобрал за 2 секунды: что, где, насколько срочно');
  await moveTo(page, 1100, 330, 700);
  await hold(page, 3800);
  await tap(page, btn(page, /^Отправить/), { pause: 1800 });

  // 2. Подрядчик назначен автоматически.
  await caption(page, 'Подрядчик назначен автоматически — по виду работ и объекту');
  await tap(page, btn(page, /^Не работает кондиционер/), { pause: 1800 });
  await see(page, /КлиматСервис/).waitFor({ timeout: 20000 });
  await moveTo(page, 1250, 420, 700);
  await hold(page, 3000);

  // 3. За кадром исполнитель отработал заявку.
  await caption(page, 'Исполнитель отмечается на объекте и фотографирует результат…');
  await hold(page, 2200);
  pause();
  await executorOffscreen('Не работает кондиционер');
  await page.keyboard.press('Escape').catch(() => {});
  await section(page, /^Главная/);
  const refresh = page.getByRole('button', { name: /^Обновить/ }).first();
  if (await refresh.isVisible().catch(() => false)) await refresh.click();
  await page.waitForTimeout(1500);
  resume();
  await tap(page, btn(page, /^Не работает кондиционер/), { pause: 1800 });
  await caption(page, 'Доказательство работы: визит в геозоне, время на объекте, фото «после»');
  await wheel(page, 700, 6);
  await hold(page, 3800);
  await caption(page, 'Заявку нельзя закрыть без подтверждения — менеджер принимает работу');
  await tap(page, btn(page, /^Принять работу/), { pause: 900 });
  const confirm = btn(page, /^Принять$/);
  if (await confirm.isVisible().catch(() => false)) await tap(page, confirm, { pause: 1200 });
  await hold(page, 1500);

  // 4. План этажа с волнами.
  await section(page, /^Главная/);
  await caption(page, 'Где проблема — сразу видно на плане этажа');
  await search(page, 'Течёт конденсат');
  await tap(page, btn(page, /^Течёт конденсат/), { pause: 1500 });
  await tap(page, btn(page, /Показать на плане/), { pause: 300 });
  await see(page, /На плане · \d/).waitFor({ timeout: 30000 });
  await caption(page, 'План этажа: маркер оборудования с просроченной заявкой «дышит» (ДЕМО-СХЕМА)');
  await moveTo(page, 1250, 700, 900);
  await hold(page, 4500);

  // 5. Карта мира.
  await section(page, /^Главная/);
  await section(page, /^Локации/);
  const map = page.getByRole('button', { name: /^Карта/ }).first();
  if (await map.isVisible().catch(() => false)) await tap(page, map, { pause: 2500 });
  await caption(page, 'Все объекты на карте мира: 20 объектов в 7 городах, цвет — по самой тревожной заявке');
  await moveTo(page, 1300, 500, 900);
  await hold(page, 4500);

  // 6. ППР.
  await section(page, /^ППР/);
  await caption(page, 'ППР: плановые работы по графику — задачи создаются сами');
  await moveTo(page, 900, 300, 800);
  await hold(page, 3800);

  // 7. Отчёты и PDF.
  await section(page, /^Отчёты/);
  await see(page, /приняты с первого раза/).waitFor({ timeout: 20000 });
  await caption(page, 'Контроль подрядчиков цифрами: в срок, с первого раза, визиты в геозоне');
  await moveTo(page, 1000, 260, 800);
  await hold(page, 3000);
  const print = page.getByRole('button', { name: /Печать|Распечатать|PDF/ });
  await tap(page, (await print.count()) > 1 ? print.nth(1) : print.first(), { pause: 400 });
  await caption(page, 'PDF-отчёт для собственника — одним нажатием');
  pause();
  for (let i = 0; i < 160 && !(await page.evaluate(() => !!window.__pdfBlob)); i++) await page.waitForTimeout(250);
  const png = await pdfFirstPage(page);
  resume();
  if (png) await page.evaluate((s) => window.__pdf(s), png);
  else console.error('PDF не получен — кадр без страницы отчёта');
  // Кадры идут, когда экран меняется: курсор медленно ходит по странице PDF.
  await moveTo(page, 820, 420, 900);
  await moveTo(page, 1100, 640, 900);
  await moveTo(page, 900, 520, 700);
  await page.evaluate(() => window.__pdf(null));
  await caption(page, '');
  await hold(page, 400);

  // 8. Зона доступа менеджера.
  await section(page, /^Главная/);
  await tap(page, profileTab(page), { pause: 1200 });
  await tap(page, btn(page, /^Моя компания/), { pause: 1800 });
  const m2 = btn(page, /Менеджер Москва/);
  await m2.scrollIntoViewIfNeeded().catch(() => {});
  await tap(page, m2, { pause: 900 });
  await tap(page, btn(page, /^Зона доступа/), { pause: 1800 });
  await caption(page, 'Каждому менеджеру — своя зона доступа: только Москва, только климат и сантехника');
  await moveTo(page, 1100, 500, 800);
  await hold(page, 4500);
  await caption(page, 'Эй, Helpy: приём → отправка → исполнение → контроль');
  await hold(page, 3500);
}

/** Кнопка «назад» в шапке (на телефоне карточки открыты поверх вкладок). */
async function back(page) {
  const b = page.getByRole('button', { name: /^(Заявки|Заявка|Назад|Back)$/ }).first();
  await tap(page, b, { pause: 1300 });
}

async function phoneScenario(page) {
  await caption(page, 'Эй, Helpy — заявки здания в кармане');
  await moveTo(page, 200, 400, 800);
  await hold(page, 3000);
  await caption(page, 'Заявка голосом');
  await tap(page, page.getByRole('button', { name: /^Эй, Helpy|Нажми и говори/ }).first(), { pause: 600 });
  await see(page, /очень жарко/).waitFor({ timeout: 20000 });
  await hold(page, 1200);
  await tap(page, btn(page, /^Готово/), { pause: 200 });
  await caption(page, 'ИИ разбирает речь…');
  await see(page, /Проверьте заявку/).waitFor({ timeout: 20000 });
  await caption(page, 'ИИ разобрал за 2 секунды');
  await hold(page, 3500);
  await tap(page, btn(page, /^Отправить/), { pause: 1800 });
  await caption(page, 'Подрядчик назначен автоматически');
  await tap(page, btn(page, /^Не работает кондиционер/), { pause: 1800 });
  await hold(page, 3200);
  await back(page);
  await caption(page, 'Где проблема — на плане этажа (ДЕМО-СХЕМА)');
  await search(page, 'Течёт конденсат');
  await tap(page, btn(page, /^Течёт конденсат/), { pause: 1500 });
  await tap(page, btn(page, /Показать на плане/), { pause: 300 });
  await see(page, /На плане · \d|Кондиционер серверной/).waitFor({ timeout: 30000 });
  await hold(page, 4500);
  await page.goBack();
  await page.waitForTimeout(1200);
  await back(page);
  await caption(page, 'Все объекты на карте');
  await section(page, /^Локации/);
  const map = page.getByRole('button', { name: /^Карта/ }).first();
  if (await map.isVisible().catch(() => false)) await tap(page, map, { pause: 2500 });
  await hold(page, 4000);
  await caption(page, 'ППР по графику');
  await section(page, /^ППР/);
  await hold(page, 3500);
  await caption(page, 'Эй, Helpy: приём → отправка → исполнение → контроль');
  await hold(page, 3000);
}

/** Первая страница PDF отчёта → PNG (data:) для показа поверх экрана. */
async function pdfFirstPage(page) {
  const b64 = await page.evaluate(async () => {
    const blob = window.__pdfBlob;
    if (!blob) return null;
    const buf = new Uint8Array(await blob.arrayBuffer());
    let s = '';
    for (let i = 0; i < buf.length; i += 0x8000) s += String.fromCharCode(...buf.subarray(i, i + 0x8000));
    return btoa(s);
  });
  if (!b64) return null;
  const pdf = join(TMP, 'report.pdf');
  writeFileSync(pdf, Buffer.from(b64, 'base64'));
  execFileSync('pdftoppm', ['-png', '-r', '110', '-f', '1', '-l', '1', '-singlefile', pdf, join(TMP, 'report')]);
  const { readFileSync } = await import('node:fs');
  return 'data:image/png;base64,' + readFileSync(join(TMP, 'report.png')).toString('base64');
}

// ---------------------------------------------------------------------------
let ok = true;
try {
  // Зона «Климат + Сантехника · Москва» второму менеджеру (её показываем в конце).
  sql(`delete from access_zones where profile_id = 'd0000000-0000-4000-8000-000000000004';
    insert into access_zones(company_id, profile_id, layer_ids, scope_kind, scope_ref)
    select '${uuid(1)}', 'd0000000-0000-4000-8000-000000000004',
      array(select id from layers where company_id = '${uuid(1)}' and name in ('Климат', 'Сантехника')), 'city', 'Москва'`);
  const ctx = await context({ record: true });
  const page = await ctx.newPage();
  // Вход и прогрев — до записи.
  await login(page, base, USERS.admin);
  await openApp(page, base, `?voice=${encodeURIComponent('Эй, Хелпи, в переговорной на третьем этаже не работает кондиционер, очень жарко')}`);
  await profileTab(page).waitFor({ timeout: 60000 });
  await settle(page, 3000);
  await page.evaluate(() => window.__caption?.(''));
  const stop = await startRecording(page);
  try {
    if (PHONE) await phoneScenario(page); else await pcScenario(page);
  } finally {
    await caption(page, '');
    await page.waitForTimeout(400);
    await stop();
  }
  await ctx.close();
} catch (e) {
  ok = false;
  console.error('Запись прервана:', String(e.message).split('\n')[0]);
}
await browser.close();
web.stop();
backend.stop();

// ---------------------------------------------------------------------------
// Сборка видео: кадры с длительностями → H.264, 30 к/с, ≤ 20 МБ.
// ---------------------------------------------------------------------------
const files = readdirSync(FRAMES).filter((f) => f.endsWith('.jpg')).sort();
if (files.length < 10) {
  console.error(`Мало кадров (${files.length}) — видео не собрано`);
  process.exit(1);
}
const list = [];
for (let i = 0; i < files.length; i++) {
  const d = i + 1 < files.length ? Math.max(0.001, frameTimes[i + 1] - frameTimes[i]) : 0.5;
  list.push(`file '${join(FRAMES, files[i])}'`, `duration ${d.toFixed(4)}`);
}
list.push(`file '${join(FRAMES, files[files.length - 1])}'`);
writeFileSync(join(TMP, 'list.txt'), list.join('\n'));
mkdirSync(resolve(OUT, '..'), { recursive: true });
const total = frameTimes[frameTimes.length - 1] - frameTimes[0];
const scale = PHONE ? 'scale=720:-2' : 'scale=1920:1080';
for (const crf of [24, 28, 32]) {
  execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', join(TMP, 'list.txt'),
    '-vf', `${scale}:flags=lanczos,fps=30,format=yuv420p`, '-c:v', 'libx264', '-preset', 'slow', '-crf', String(crf),
    '-profile:v', 'high', '-movflags', '+faststart', '-an', OUT]);
  if (statSync(OUT).size <= 20 * 1024 * 1024) break;
}
rmSync(FRAMES, { recursive: true, force: true });
console.log(`${ok ? 'Готово' : 'Частично'}: ${OUT} — ${Math.round(total)} с, ${(statSync(OUT).size / 1024 / 1024).toFixed(1)} МБ, кадров ${files.length}`);
process.exit(ok ? 0 : 1);
