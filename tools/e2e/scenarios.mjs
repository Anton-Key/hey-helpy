// Сценарии сквозных тестов. Каждый — отдельный тест: run(ctx) бросает
// исключение, если что-то не так. Проверки — и по экрану, и по базе.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  USERS, assert, btn, home, login, openApp, raw, profileTab, scrollTo, section, see, settle, sql, typeInto, uuid, waitDb,
} from './lib.mjs';

const TMP = mkdtempSync(join(tmpdir(), 'hh-e2e-'));
// Геопозиция «Demo Tower» (Belgrade) — визит в геозоне.
const BC_DEMO = { latitude: 44.80471, longitude: 20.44942, accuracy: 10 };

/** Открыть заявку по названию через поиск во вкладке «Заявки». */
async function openOrder(page, base, title) {
  await home(page, base);
  const search = page.getByRole('textbox').first();
  await typeInto(page, search, title.slice(0, 24));
  await settle(page, 1800);
  await btn(page, new RegExp(title.slice(0, 20).replace(/[.*+?^${}()|[\]\\«»]/g, '.'))).click();
  await settle(page, 2000);
}

async function clickAction(page, re, timeout = 15000) {
  const b = btn(page, re);
  await b.waitFor({ timeout });
  await b.click();
  await settle(page, 1500);
}

/** Фото «после» — живой камерой (шаг 26; в сборке e2e — заглушка камеры):
 * «Сфотографировать результат» → «Снять» → «Готово». Галереи нет. */
async function takeLivePhoto(page) {
  await clickAction(page, /Сфотографировать результат/);
  await btn(page, /^Снять/).waitFor({ timeout: 20000 });
  await btn(page, /^Снять/).click();
  await clickAction(page, /^Готово/);
}

/** Весь текст экрана (дерево доступности Flutter). */
export const screenText = (page) => page.evaluate(() => {
  const out = [];
  for (const el of document.querySelectorAll('flt-semantics, flt-semantics *')) {
    const t = el.getAttribute('aria-label');
    if (t) out.push(t);
    for (const n of el.childNodes) if (n.nodeType === 3 && n.textContent.trim()) out.push(n.textContent.trim());
  }
  return out.join('\n');
});

/** Плитки «Отчётов» за 30 дней: количество заявок и «приняты с первого раза из N». */
async function reportTiles(page, base) {
  await home(page, base);
  await section(page, /^Отчёты/);
  await see(page, /приняты с первого раза/).waitFor({ timeout: 20000 });
  await settle(page, 1500);
  const t = await screenText(page);
  const orders = +(t.match(/(\d+)\s*\n?\s*заяв/)?.[1] ?? NaN);
  const firstTime = +(t.match(/приняты с первого раза\s*\n?\s*из (\d+)/)?.[1] ?? NaN);
  return { orders, firstTime };
}

/** PDF отчёта: веб-версия отдаёт Blob в окно печати — перехват в ctx.page(). */
async function capturePdf(page) {
  const print = page.getByRole('button', { name: /Печать|Распечатать|PDF/ });
  await ((await print.count()) > 1 ? print.nth(1) : print.first()).click();
  for (let i = 0; i < 120; i++) {
    if (await page.evaluate(() => !!window.__pdfBlob)) break;
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
  assert(b64, 'PDF не получен');
  const f = join(TMP, `report-${Date.now()}.pdf`);
  writeFileSync(f, Buffer.from(b64, 'base64'));
  return f;
}

// «К оплате» в акте — те же правила, что `buildAct` (act_logic.dart) и
// `ActsRepository` (шаг 27): фото «после» не «из файла», а снятое без сети —
// с подтверждённым временем, сверенным отпечатком и без пометки конфликта;
// визит в геозоне (без сети — с подтверждённым временем); весь чек-лист.
// Сомнительное — к оплате, только если менеджер последним решением
// «Подтвердить к оплате» (таблица 0024; без неё — только строгие правила).
const ACT_PAYABLE_SQL = `(not exists (select 1 from checklist_items c where c.work_order_id = w.id and not c.is_done))
  and (
    ((not w.requires_photo or exists (select 1 from attachments a where a.work_order_id = w.id and a.kind = 'photo'
          and a.stage = 'after' and a.source <> 'file'
          and (not coalesce((to_jsonb(a)->>'offline')::boolean, false)
               or (coalesce(to_jsonb(a)->>'time_trust', 'online') not in ('unverified', 'device_only')
                   and to_jsonb(a)->>'sync_note' is null and (to_jsonb(a)->>'sha256_ok')::boolean))))
     and (o.lat is null or exists (select 1 from visits v where v.work_order_id = w.id and v.in_geofence
          and coalesce(to_jsonb(v)->>'time_trust', 'online') not in ('unverified', 'device_only'))))
    or (to_regclass('public.act_proof_decisions') is not null
        and (not w.requires_photo or exists (select 1 from attachments a where a.work_order_id = w.id
              and a.kind = 'photo' and a.stage = 'after'))
        and (o.lat is null or exists (select 1 from visits v where v.work_order_id = w.id and v.in_geofence))
        and (select d->>'decision' from jsonb_path_query(
               coalesce((select jsonb_agg(to_jsonb(x) order by x.decided_at desc)
                         from act_proof_decisions x where x.work_order_id = w.id), '[]'::jsonb), '$[0]') d) = 'approve'))`;

export const SCENARIOS = [
  {
    id: 1,
    title: 'Главный сценарий: голос → ИИ → автоназначение → исполнитель (геозона, фото) → приёмка',
    async run(ctx) {
      const { base } = ctx;
      // Повторный запуск: убрать заявки прошлых прогонов этого сценария.
      sql(`delete from work_orders where company_id = '${uuid(1)}' and title like 'Не работает кондиционер%'
        and id::text not like 'de300000-%'`);
      const doneBefore = +sql(`select count(*) from work_orders where company_id = '${uuid(1)}' and status = 'done'`);
      // 1. Менеджер (администратор): голосовая заявка.
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      const before = await reportTiles(m, base);
      // Шаг 33: демо-данные на английском — фраза тоже английская (помещение
      // «Meeting room, floor 3» находит разбор по словарю в приложении).
      await home(m, base, `?voice=${encodeURIComponent('Hey, Helpy, the air conditioner in the meeting room on the third floor is not working, very hot')}`);
      await ctx.shot(m, 'home');
      await clickAction(m, /Нажми и говори/);
      await see(m, /air conditioner in the meeting room/).waitFor({ timeout: 15000 });
      await settle(m, 1500);
      await ctx.shot(m, 'listening');
      await clickAction(m, /^Готово/);
      await see(m, /Проверьте заявку/).waitFor({ timeout: 20000 });
      await see(m, /Разобрано ИИ/).waitFor({ timeout: 5000 });
      await ctx.shot(m, 'confirm');
      await clickAction(m, /^Отправить/);
      const id = await waitDb(`select id from work_orders where company_id = '${uuid(1)}' and created_at > now() - interval '2 minutes'
        and title like 'Не работает кондиционер%' order by created_at desc limit 1`, (v) => v.length > 0);
      const row = sql(`select w.status || '|' || coalesce(c.org_name, '-') || '|' || coalesce(l.name, '-') || '|' || w.input_channel
        from work_orders w left join contractors c on c.id = w.assigned_contractor_id left join locations l on l.id = w.location_id
        where w.id = '${id}'`);
      ctx.notes.push(`заявка: ${row}`);
      assert(row.startsWith('assigned|ClimaService|Meeting room'), `ждали «назначена ClimaService, Meeting room», в базе: ${row}`);
      await ctx.shot(m, 'sent');

      // 2. Исполнитель: начать работу (визит в геозоне), фото «после», на проверку.
      const e = await ctx.page({ width: 412, height: 915, geo: BC_DEMO });
      await login(e, base, USERS.executor);
      await openOrder(e, base, 'Не работает кондиционер');
      await ctx.shot(e, 'exec-card');
      await clickAction(e, /^Начать работу/);
      await waitDb(`select status from work_orders where id = '${id}'`, 'in_progress');
      const visit = await waitDb(`select coalesce(in_geofence::text, 'null') from visits where work_order_id = '${id}'`, (v) => v.length > 0);
      assert(visit === 'true', `визит должен быть в геозоне, в базе: ${visit}`);
      await ctx.shot(e, 'exec-started');
      await takeLivePhoto(e);
      await waitDb(`select count(*) from attachments where work_order_id = '${id}' and stage = 'after'`, '1', 20000);
      await settle(e, 2000);
      await ctx.shot(e, 'exec-photo');
      await clickAction(e, /Выполнено, на проверку/);
      await waitDb(`select status from work_orders where id = '${id}'`, 'on_review');
      await ctx.shot(e, 'exec-submitted');

      // 3. Менеджер принимает.
      await openOrder(m, base, 'Не работает кондиционер');
      await ctx.shot(m, 'review');
      await clickAction(m, /^Принять работу/);
      const confirm = btn(m, /^Принять$/);
      if (await confirm.isVisible().catch(() => false)) await confirm.click();
      await waitDb(`select status from work_orders where id = '${id}'`, 'done');
      const doneAfter = +sql(`select count(*) from work_orders where company_id = '${uuid(1)}' and status = 'done'`);
      assert(doneAfter === doneBefore + 1, `принятых было ${doneBefore}, стало ${doneAfter}`);
      // Отчёт: количество заявок за период и «приняты с первого раза» выросли на 1.
      const after = await reportTiles(m, base);
      ctx.notes.push(`отчёт: заявок ${before.orders} → ${after.orders}, приняты с первого раза из ${before.firstTime} → ${after.firstTime}`);
      assert(after.orders === before.orders + 1 && after.firstTime === before.firstTime + 1, 'отчёт не посчитал заявку');
      await scrollTo(m, /ClimaService/);
      await ctx.shot(m, 'report');
    },
  },
  {
    id: 2,
    title: 'ППР: «AC maintenance» → генерация задачи → исполнитель → принятие → «выполнено N из M»',
    async run(ctx) {
      const { base } = ctx;
      const plan = uuid(801);
      // Задача текущего периода ещё не создана (в демо она уже есть — убираем).
      sql(`delete from work_orders where plan_id = '${plan}' and period_end >= current_date`);
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await home(m, base);
      await section(m, /^Плановое ТО/);
      const summary = async () => {
        await see(m, /выполнено \d+ из \d+/).waitFor({ timeout: 20000 });
        const t = await screenText(m);
        const x = t.match(/выполнено (\d+) из (\d+)/);
        return { done: +x[1], total: +x[2] };
      };
      // Генерация — при входе менеджера; «Обновить» на всякий случай.
      const task = await waitDb(`select id from work_orders where plan_id = '${plan}' and period_end >= current_date`,
        (v) => v.length > 0, 20000);
      const row = sql(`select w.status || '|' || coalesce(c.org_name, '-') || '|' || w.title from work_orders w
        left join contractors c on c.id = w.assigned_contractor_id where w.id = '${task}'`);
      ctx.notes.push(`задача: ${row}`);
      assert(row.startsWith('assigned|NYC Climate'), `задача должна уйти NYC Climate: ${row}`);
      await home(m, base);
      await section(m, /^Плановое ТО/);
      const before = await summary();
      await ctx.shot(m, 'ppr-before');

      const e = await ctx.page({ width: 412, height: 915, geo: { latitude: 55.749, longitude: 37.537, accuracy: 10 } });
      await login(e, base, 'mosklimat@example.com');
      await openOrder(e, base, 'AC maintenance');
      await clickAction(e, /^Начать работу/);
      await waitDb(`select status from work_orders where id = '${task}'`, 'in_progress');
      await takeLivePhoto(e);
      await waitDb(`select count(*) from attachments where work_order_id = '${task}' and stage = 'after'`, '1', 20000);
      await settle(e, 1500);
      await clickAction(e, /Выполнено, на проверку/);
      await waitDb(`select status from work_orders where id = '${task}'`, 'on_review');

      await home(m, base);
      await section(m, /^Плановое ТО/);
      await btn(m, /^AC maintenance/).click();
      await see(m, /История периодов/).waitFor({ timeout: 20000 });
      await settle(m, 1200);
      await btn(m, /Плановое ТО · .* · до/).click();
      await clickAction(m, /^Принять работу/);
      const confirm = btn(m, /^Принять$/);
      if (await confirm.isVisible().catch(() => false)) await confirm.click();
      await waitDb(`select status from work_orders where id = '${task}'`, 'done');
      await home(m, base);
      await section(m, /^Плановое ТО/);
      const after = await summary();
      ctx.notes.push(`сводка: выполнено ${before.done} из ${before.total} → ${after.done} из ${after.total}`);
      assert(after.done === before.done + 1 && after.total === before.total, 'сводка ППР не изменилась');
      await btn(m, /^AC maintenance/).click();
      await see(m, /История периодов/).waitFor({ timeout: 20000 });
      await see(m, /Выполнено/).waitFor({ timeout: 10000 });
      await ctx.shot(m, 'ppr-card-done');
    },
  },
  {
    id: 3,
    title: 'План этажа: «Показать на плане» → маркер; расстановка → помещение, номер «305», область; голосом «в 305-й не работает свет»',
    async run(ctx) {
      const { base } = ctx;
      const room = uuid(23); // Open space, floor 2 — в демо без точки на плане
      sql(`update locations set code = null, floor_id = null, plan_x = null, plan_y = null, plan_shape = null where id = '${room}'`);
      sql(`delete from work_orders where company_id = '${uuid(1)}' and title like 'Не работает свет%' and id::text not like 'de300000-%'`);
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      // a) Заявка на оборудовании → «Показать на плане».
      await openOrder(m, base, 'Течёт конденсат из кондиционера');
      await clickAction(m, /Показать на плане/);
      await see(m, /На плане · \d/).waitFor({ timeout: 30000 });
      await settle(m, 1500);
      assert(/floors\//.test(m.url()) || await see(m, /Air conditioner, server room/).isVisible(), 'план не открылся');
      const focused = m.getByRole('button', { name: 'Air conditioner, server room' }).first();
      assert(await focused.isVisible().catch(() => false), 'маркер «Air conditioner, server room» не виден');
      ctx.notes.push('маркер оборудования на плане floor 3 виден');
      await ctx.shot(m, 'show-on-plan');

      // b) Режим расстановки floor 1: «Поставить сюда…» → Open space, номер 305, область.
      await openApp(m, base, `#/objects/${uuid(10)}/floors/${uuid(601)}?edit=1`);
      await see(m, /Режим расстановки/).waitFor({ timeout: 30000 });
      await settle(m, 1500);
      // Маркеры на холсте: «102 · Reception, floor 1, нет открытых заявок».
      const box = async (name) => m.getByRole('button', { name: new RegExp(`^\\d+ · ${name}, `) }).first().boundingBox();
      const a = await box('Reception, floor 1'); // (0.15, 0.5125)
      const b = await box('Hall, floor 1'); // (0.45, 0.5125)
      const c = await box('Electrical room, floor 1'); // (0.15, 0.2063)
      assert(a && b && c, 'маркеры floor 1 не найдены');
      const kx = (b.x - a.x) / 0.30;
      const ky = (a.y - c.y) / (0.5125 - 0.2063);
      const at = (fx, fy) => ({ x: a.x + a.width / 2 + (fx - 0.15) * kx, y: a.y + a.height / 2 + (fy - 0.5125) * ky });
      const spot = at(0.62, 0.80);
      await raw(m, () => m.mouse.click(spot.x, spot.y));
      await clickAction(m, /Поставить сюда/);
      // Пункт шторки (последний на экране; слева — такой же в списке «Не размещены»).
      await m.getByRole('button', { name: /^Open space, floor 2/ }).last().click();
      await settle(m, 1500);
      await waitDb(`select floor_id from locations where id = '${room}'`, uuid(601));
      const marker = () => m.getByRole('button', { name: /^(305 · )?Open space, floor 2, / }).first();
      await marker().click();
      await settle(m, 1000);
      await clickAction(m, /^Номер помещения/);
      await typeInto(m, m.getByRole('textbox').last(), '305');
      await clickAction(m, /^Сохранить/);
      await waitDb(`select code from locations where id = '${room}'`, '305');
      await marker().click();
      await settle(m, 1000);
      await clickAction(m, /^Обвести область/);
      // Область прямоугольником: протянуть мышью.
      const p1 = at(0.55, 0.70);
      const p2 = at(0.72, 0.92);
      await raw(m, async () => {
        await m.mouse.move(p1.x, p1.y);
        await m.mouse.down();
        await m.mouse.move((p1.x + p2.x) / 2, (p1.y + p2.y) / 2, { steps: 8 });
        await m.mouse.move(p2.x, p2.y, { steps: 8 });
        await m.mouse.up();
      });
      await settle(m, 800);
      await ctx.shot(m, 'area-draft');
      await clickAction(m, /^Готово/);
      const shape = await waitDb(`select plan_shape::text from locations where id = '${room}'`, (v) => v.length > 0);
      const pts = JSON.parse(shape).points;
      const xs = pts.map((q) => q[0]);
      const ys = pts.map((q) => q[1]);
      ctx.notes.push(`область: x ${Math.min(...xs).toFixed(2)}–${Math.max(...xs).toFixed(2)}, y ${Math.min(...ys).toFixed(2)}–${Math.max(...ys).toFixed(2)}`);
      assert(Math.abs(Math.min(...xs) - 0.55) < 0.04 && Math.abs(Math.max(...ys) - 0.92) < 0.04, 'область сохранилась не там, где рисовали');
      const pt = sql(`select plan_x || ',' || plan_y from locations where id = '${room}'`);
      const [px, py] = pt.split(',').map(Number);
      ctx.notes.push(`точка помещения: ${pt}`);
      assert(px >= Math.min(...xs) && px <= Math.max(...xs) && py >= Math.min(...ys) && py <= Math.max(...ys),
        'маркер помещения остался вне своей области');
      await ctx.shot(m, 'area-saved');

      // c) Голосом «в 305-й не работает свет» → помещение Open space найдено.
      await home(m, base, `?voice=${encodeURIComponent('Эй, Хелпи, в 305-й не работает свет')}`);
      await clickAction(m, /Нажми и говори/);
      await see(m, /не работает свет/).waitFor({ timeout: 15000 });
      await settle(m, 800);
      await clickAction(m, /^Готово/);
      await see(m, /Проверьте заявку/).waitFor({ timeout: 20000 });
      await see(m, /Open space/).waitFor({ timeout: 5000 });
      await ctx.shot(m, 'voice-305');
      await clickAction(m, /^Отправить/);
      const row = await waitDb(`select coalesce(l.name, '-') || '|' || coalesce(c.org_name, '-') from work_orders w
        left join locations l on l.id = w.location_id left join contractors c on c.id = w.assigned_contractor_id
        where w.company_id = '${uuid(1)}' and w.title like 'Не работает свет%' and w.created_at > now() - interval '2 minutes'`,
      (v) => v.length > 0);
      ctx.notes.push(`заявка «305»: ${row}`);
      assert(row.startsWith('Open space, floor 2|ElectroPro'), `ждали Open space и ElectroPro: ${row}`);
    },
  },
  {
    id: 4,
    title: 'Регионы: «Europpe» → «Использовать «Europe»»; объединение регионов; «Весь регион» в заявках и отчётах',
    async run(ctx) {
      const { base } = ctx;
      sql(`update objects set region_id = '${uuid(901)}' where region_id in (select id from regions where name in ('Europpe', 'Балканы'))`);
      sql(`delete from regions where company_id = '${uuid(1)}' and name in ('Europpe', 'Балканы')`);
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      const openRegions = async () => {
        await home(m, base);
        await profileTab(m).click();
        await settle(m, 1000);
        await btn(m, /^Моя компания/).click();
        await settle(m, 1500);
        await scrollTo(m, /Регионы компании/);
        await btn(m, /Регионы компании/).click();
        await see(m, /Europe/).waitFor({ timeout: 20000 });
        await settle(m, 800);
      };
      const addRegion = async (name) => {
        await clickAction(m, /Новый регион/);
        await typeInto(m, m.getByRole('textbox').last(), name);
        await clickAction(m, /^Сохранить|^Создать|^Готово|^Добавить/);
      };
      await openRegions();
      await addRegion('Europpe');
      await see(m, /Похоже/).waitFor({ timeout: 10000 });
      await ctx.shot(m, 'similar');
      await clickAction(m, /Использовать «Europe»/);
      assert(sql(`select count(*) from regions where company_id = '${uuid(1)}' and name = 'Europpe'`) === '0', '«Europpe» создан, хотя выбрали «Europe»');
      ctx.notes.push('«Europpe» → предложено «Europe», дубль не создан');

      // Объединение: новый «Балканы», объект «Belgrade · Hub 1» в нём → объединить с «Europe».
      await addRegion('Балканы');
      const balkans = await waitDb(`select id from regions where company_id = '${uuid(1)}' and name = 'Балканы'`, (v) => v.length > 0);
      sql(`update objects set region_id = '${balkans}' where id = '${uuid(401)}'`);
      await openRegions();
      await m.getByRole('button', { name: /Балканы/ }).first().click();
      await settle(m, 800);
      await clickAction(m, /Объединить с/);
      await clickAction(m, /^Europe/);
      await ctx.shot(m, 'merge-confirm');
      await clickAction(m, /^Объединить$/);
      await waitDb(`select count(*) from regions where id = '${balkans}'`, '0');
      assert(sql(`select region_id from objects where id = '${uuid(401)}'`) === uuid(901), 'объект не перешёл в «Europe»');
      ctx.notes.push('«Балканы» объединён с «Europe», объект перешёл');

      // «Весь регион» в заявках: North America.
      await home(m, base);
      const pill = m.getByRole('button', { name: /^Объект/ }).first();
      if (await pill.isVisible().catch(() => false)) await pill.click();
      else { await btn(m, /^Фильтры/).click(); await settle(m, 800); await btn(m, /^Объект/).click(); }
      await settle(m, 1000);
      await scrollTo(m, /North America/);
      const whole = m.getByRole('button', { name: /Весь регион/ }).or(m.getByText(/Весь регион/));
      const n = await whole.count();
      // «Весь регион» — под заголовком региона; у North America — второй по порядку (Europe, North America, …).
      let clicked = false;
      for (let i = 0; i < n && !clicked; i++) {
        const el = whole.nth(i);
        const label = (await el.getAttribute('aria-label').catch(() => '')) ?? '';
        if (/North America/.test(label)) { await el.click(); clicked = true; }
      }
      if (!clicked) await whole.nth(1).click();
      await settle(m, 600);
      const apply = btn(m, /^Применить|^Показать|^Готово/);
      if (await apply.isVisible().catch(() => false)) await apply.click();
      await settle(m, 2000);
      await ctx.shot(m, 'requests-region');
      const t = await screenText(m);
      const shown = (t.match(/(\d+) из \d+/) ?? [])[1];
      const all = +sql(`select count(*) from work_orders w join objects o on o.id = w.object_id
        where w.company_id = '${uuid(1)}' and o.region_id = '${uuid(902)}'`);
      assert(+shown === all, `фильтр «Весь регион North America»: на экране ${shown}, заявок региона в базе ${all}`);
      ctx.notes.push(`заявки «Весь регион North America»: ${shown} = в базе ${all}`);

      // Отчёты: фильтр «Регион» = North America.
      await home(m, base);
      await section(m, /^Отчёты/);
      await see(m, /приняты с первого раза/).waitFor({ timeout: 20000 });
      await btn(m, /^Регион/).click();
      await settle(m, 800);
      await clickAction(m, /^North America/);
      const ap = btn(m, /^Применить|^Показать|^Готово/);
      if (await ap.isVisible().catch(() => false)) await ap.click();
      await settle(m, 2500);
      const rt = await screenText(m);
      const orders = +(rt.match(/(\d+)\s*\n?\s*заяв/)?.[1] ?? NaN);
      const dbOrders = +sql(`select count(*) from work_orders w join objects o on o.id = w.object_id
        where w.company_id = '${uuid(1)}' and o.region_id = '${uuid(902)}' and w.created_at >= now() - interval '30 days'`);
      ctx.notes.push(`отчёт по North America: заявок ${orders}, в базе за 30 дней ${dbOrders}`);
      assert(orders > 0 && orders <= dbOrders + 1 && !/Europe\s*\n?\s*Заявок/.test(rt), 'отчёт с фильтром «North America» неверен');
      await ctx.shot(m, 'report-region');
    },
  },
  {
    id: 5,
    title: 'PDF: отчёт по региону → файл создан, страниц > 0, в тексте фильтры',
    async run(ctx) {
      const { base } = ctx;
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await home(m, base);
      await section(m, /^Отчёты/);
      await see(m, /приняты с первого раза/).waitFor({ timeout: 20000 });
      await btn(m, /^Регион/).click();
      await settle(m, 800);
      await clickAction(m, /^North America/);
      const ap = btn(m, /^Применить|^Показать|^Готово/);
      if (await ap.isVisible().catch(() => false)) await ap.click();
      await settle(m, 2000);
      const pdf = await capturePdf(m);
      const pages = +(execFileSync('pdfinfo', [pdf], { encoding: 'utf8' }).match(/Pages:\s+(\d+)/)?.[1] ?? 0);
      const text = execFileSync('pdftotext', ['-layout', pdf, '-'], { encoding: 'utf8' });
      ctx.notes.push(`PDF: ${pages} стр., ${Math.round(statSync(pdf).size / 1024)} КБ`);
      assert(pages > 0, 'в PDF нет страниц');
      assert(/North America/.test(text), 'в тексте PDF нет фильтра «North America»');
      assert(!/Europe|Belgrade|Dubai/.test(text), 'в PDF по North America попали другие регионы');
      assert(/New York|NYC Climate/.test(text), 'в PDF нет данных региона');
    },
  },
  {
    id: 6,
    title: 'Реестр оборудования: импорт CSV с ошибками → предпросмотр ошибок → импорт корректных строк',
    async run(ctx) {
      const { base } = ctx;
      sql(`delete from assets where inventory_no in ('E2E-001', 'E2E-002', 'E2E-003', 'E2E-004')`);
      const before = +sql(`select count(*) from assets a join locations l on l.id = a.location_id where l.object_id = '${uuid(10)}'`);
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await home(m, base);
      await section(m, /^Локации/);
      const list = m.getByRole('button', { name: /^Список/ }).or(m.getByText(/^Список$/)).first();
      if (await list.isVisible().catch(() => false)) await list.click();
      await settle(m, 1200);
      await btn(m, /^Demo Tower/).click();
      await see(m, /Адрес|Этажи/).waitFor({ timeout: 20000 });
      await settle(m, 1500);
      await scrollTo(m, /Импорт из Excel/);
      await btn(m, /Импорт из Excel/).click();
      await settle(m, 1200);
      const csv = join(TMP, 'import.csv');
      writeFileSync(csv, [
        'Название;Помещение;Система;Инвентарный номер;Производитель;Модель;Серийный номер;Дата ввода',
        'Air conditioner №3;Meeting room, floor 3;Климат;E2E-001;Daikin;FTXM25R;DK-1;2025-03-01',
        'Светильник;Нет такой комнаты;Электрика;E2E-002;Philips;RC132V;PH-1;2025-03-01',
        'Насос;Kitchen, floor 3;Лифты;E2E-003;Grundfos;UPS;GR-1;2025-03-01',
        'ИБП;Server room, floor 3;Электрика;E2E-004;APC;SRT;AS-1;2025-13-40',
        'Щит освещения;Hall, floor 1;Электрика;E2E-005;ABB;MISTRAL;AB-1;01.02.2024',
      ].join('\n'));
      const chooser = m.waitForEvent('filechooser', { timeout: 15000 });
      await btn(m, /Выбрать файл/).click();
      await (await chooser).setFiles(csv);
      await see(m, /Строк: 5 · готово: 2 · с ошибками: 3/).waitFor({ timeout: 20000 });
      await ctx.shot(m, 'preview');
      for (const issue of [/нет помещения «Нет такой комнаты»/, /нет системы «Лифты»/, /дата не распознана/]) {
        assert(await see(m, issue).isVisible().catch(() => false) || /./.test(await screenText(m).then((t) => (issue.test(t) ? 'x' : ''))),
          `в предпросмотре нет ошибки ${issue}`);
      }
      await clickAction(m, /Импортировать 2 строки/);
      await waitDb(`select count(*) from assets a join locations l on l.id = a.location_id where l.object_id = '${uuid(10)}'`,
        String(before + 2), 20000);
      const got = sql(`select string_agg(inventory_no, ',' order by inventory_no) from assets where inventory_no like 'E2E-%'`);
      ctx.notes.push(`импортировано: ${got}`);
      assert(got === 'E2E-001,E2E-005', `ждали E2E-001 и E2E-005, в базе: ${got}`);
      sql(`delete from assets where inventory_no like 'E2E-%'`);
    },
  },
  {
    id: 7,
    title: 'Доступ: администратор задаёт зону «Климат + Сантехника · New York» → второй менеджер не видит лишнего (списки, карта, отчёты, PDF); бригада «Riyadh» не видит Abu Dhabi',
    async run(ctx) {
      const { base } = ctx;
      const m2 = 'd0000000-0000-4000-8000-000000000004';
      sql(`delete from access_zones where profile_id = '${m2}'`);
      const a = await ctx.page();
      await login(a, base, USERS.admin);
      await home(a, base);
      await profileTab(a).click();
      await settle(a, 1000);
      await btn(a, /^Моя компания/).click();
      await settle(a, 1500);
      await scrollTo(a, /New York Manager/);
      await btn(a, /New York Manager/).click();
      await settle(a, 800);
      await clickAction(a, /^Зона доступа/);
      await see(a, /Вся компания/).waitFor({ timeout: 20000 });
      await ctx.shot(a, 'zone-empty');
      // Выключить «Вся компания» (переключатель), добавить правило.
      const sw = a.getByRole('switch').or(a.getByRole('checkbox')).first();
      if (await sw.isVisible().catch(() => false)) await sw.click(); else await btn(a, /^Вся компания/).click();
      await settle(a, 800);
      await clickAction(a, /Добавить правило/);
      await ctx.shot(a, 'rule');
      for (const sys of ['Климат', 'Сантехника']) {
        await a.getByRole('button', { name: new RegExp(`^${sys}$`) }).or(a.getByRole('checkbox', { name: new RegExp(`^${sys}$`) }))
          .or(a.getByText(new RegExp(`^${sys}$`))).last().click();
        await settle(a, 400);
      }
      await clickAction(a, /Выбрать места/);
      await scrollTo(a, /Весь город: New York/);
      await see(a, /Весь город: New York/).click();
      await settle(a, 600);
      await ctx.shot(a, 'picker');
      await clickAction(a, /^Применить|^Показать|^Готово|^Выбрать/);
      await ctx.shot(a, 'rule-filled');
      for (let i = 0; i < 2; i++) {
        const save = btn(a, /^Сохранить|^Готово/);
        if (await save.isVisible().catch(() => false)) { await save.click(); await settle(a, 1500); }
      }
      const zone = await waitDb(`select z.scope_kind || ':' || z.scope_ref || ':' ||
          (select string_agg(l.name, '+' order by l.name) from layers l where l.id = any(z.layer_ids))
        from access_zones z where z.profile_id = '${m2}'`, (v) => v.length > 0, 15000);
      ctx.notes.push(`зона в базе: ${zone}`);
      assert(/^city:New York:Климат\+Сантехника$/.test(zone), `зона сохранилась не так: ${zone}`);

      // Что второму менеджеру видеть нельзя: объекты не в New York, заявки других систем, чужие подрядчики.
      const ids = (q) => new Set(sql(q).split('\n').filter(Boolean));
      const C = uuid(1);
      const badObjects = ids(`select id from objects where company_id = '${C}' and coalesce(city, '') <> 'New York'`);
      const badOrders = ids(`select w.id from work_orders w left join layers l on l.id = w.layer_id left join objects o on o.id = w.object_id
        where w.company_id = '${C}' and (coalesce(o.city, '') <> 'New York' or coalesce(l.name, '') not in ('Климат', 'Сантехника'))
          and w.created_by is distinct from '${m2}'`);
      const okContractors = ids(`select distinct cl.contractor_id from contractor_layers cl join layers l on l.id = cl.layer_id
        left join objects o on o.id = cl.object_id where l.name in ('Климат', 'Сантехника') and (cl.object_id is null or o.city = 'New York')
          and l.company_id = '${C}'`);
      const badContractors = new Set([...ids(`select id from contractors where company_id = '${C}'`)].filter((x) => !okContractors.has(x)));
      const m = await ctx.page();
      const seen = new Map();
      m.on('response', async (r) => {
        if (!r.url().includes('/rest/v1/')) return;
        try {
          const body = await r.text();
          for (const id of body.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g) ?? []) {
            if (!seen.has(id)) seen.set(id, r.url().split('/rest/v1/')[1].split('?')[0]);
          }
        } catch { /* ответ без тела */ }
      });
      await login(m, base, USERS.manager2);
      await home(m, base);
      await ctx.shot(m, 'm2-requests');
      const t1 = await screenText(m);
      for (const w of ['Belgrade', 'Dubai', 'Riyadh', 'Электрика']) assert(!t1.includes(w), `в заявках второго менеджера есть «${w}»`);
      await section(m, /^Локации/);
      const mapBtn = m.getByRole('button', { name: /^Карта/ }).or(m.getByText(/^Карта$/)).first();
      if (await mapBtn.isVisible().catch(() => false)) { await mapBtn.click(); await settle(m, 3000); }
      await ctx.shot(m, 'm2-map');
      await section(m, /^Подрядчики/);
      await ctx.shot(m, 'm2-contractors');
      const t3 = await screenText(m);
      for (const w of ['ElectroPro', 'Gulf FM', 'Riyadh FM']) assert(!t3.includes(w), `в подрядчиках второго менеджера есть «${w}»`);
      await home(m, base);
      await section(m, /^Отчёты/);
      await see(m, /приняты с первого раза/).waitFor({ timeout: 20000 });
      await settle(m, 1500);
      await ctx.shot(m, 'm2-reports');
      const t4 = await screenText(m);
      for (const w of ['Europe', 'Middle East', 'ElectroPro', 'ClimaService']) assert(!t4.includes(w), `в отчётах второго менеджера есть «${w}»`);
      const pdf = await capturePdf(m);
      const text = execFileSync('pdftotext', ['-layout', pdf, '-'], { encoding: 'utf8' });
      for (const w of ['Belgrade', 'Dubai', 'ElectroPro', 'ClimaService']) assert(!text.includes(w), `в PDF второго менеджера есть «${w}»`);
      await section(m, /^Плановое ТО/);
      await settle(m, 1500);
      const t5 = await screenText(m);
      assert(!/Dubai|London|Demo Tower/.test(t5), 'в ППР второго менеджера чужие объекты');
      const leaks = [...seen].filter(([id]) => badObjects.has(id) || badOrders.has(id) || badContractors.has(id));
      ctx.notes.push(`ответов сервера: ${seen.size} id, запрещённых: ${leaks.length}`);
      assert(leaks.length === 0, `сервер отдал запрещённое: ${leaks.slice(0, 3).map(([id, t]) => `${t}:${id.slice(-3)}`).join(', ')}`);

      // Бригада «Riyadh» Riyadh FM: исполнитель не видит Abu Dhabi.
      const e = await ctx.page({ width: 412, height: 915 });
      const eSeen = new Set();
      e.on('response', async (r) => {
        if (!r.url().includes('/rest/v1/work_orders')) return;
        try { for (const id of (await r.text()).match(/[0-9a-f-]{36}/g) ?? []) eSeen.add(id); } catch { /* */ }
      });
      await login(e, base, 'beijing@example.com');
      await home(e, base);
      await ctx.shot(e, 'crew-beijing');
      const szOrders = ids(`select w.id from work_orders w join objects o on o.id = w.object_id where o.city = 'Abu Dhabi'`);
      const bjOrders = ids(`select w.id from work_orders w join objects o on o.id = w.object_id
        where o.city = 'Riyadh' and w.assigned_contractor_id = '${uuid(509)}'`);
      const te = await screenText(e);
      assert(!te.includes('Abu Dhabi'), 'исполнитель бригады «Riyadh» видит Abu Dhabi');
      assert(![...szOrders].some((x) => eSeen.has(x)), 'сервер отдал бригаде «Riyadh» заявки Abu Dhabi');
      ctx.notes.push(`бригада «Riyadh»: заявок Riyadh видно ${[...bjOrders].filter((x) => eSeen.has(x)).length} из ${bjOrders.size}, Abu Dhabi — 0`);
    },
  },
  {
    id: 8,
    title: 'Изоляция компаний: вторая компания с теми же названиями — ни один экран не показывает её данные',
    async run(ctx) {
      const { base } = ctx;
      // В локальной базе две тестовые компании «Demo Properties» (id c1…/c2…) — с теми же
      // названиями объектов, регионов, подрядчиков. Любой их id в ответах сервера — утечка.
      const m = await ctx.page();
      const foreign = [];
      m.on('response', async (r) => {
        if (!r.url().includes('/rest/v1/') && !r.url().includes('/storage/v1/')) return;
        try {
          const b = await r.text();
          const hit = b.match(/c[12]000000-0000-4000-8000-\d{12}/);
          if (hit) foreign.push(`${r.url().split('/v1/')[1].split('?')[0]}:${hit[0]}`);
        } catch { /* */ }
      });
      await login(m, base, USERS.admin);
      const visit = [
        async () => home(m, base),
        async () => section(m, /^Плановое ТО/),
        async () => { await home(m, base); await section(m, /^Подрядчики/); },
        async () => { await home(m, base); await section(m, /^Локации/); },
        async () => { const b = m.getByRole('button', { name: /^Карта/ }).or(m.getByText(/^Карта$/)).first();
          if (await b.isVisible().catch(() => false)) { await b.click(); await settle(m, 2500); } },
        async () => { await home(m, base); await section(m, /^История/); },
        async () => { await home(m, base); await section(m, /^Отчёты/); await settle(m, 2000); },
        async () => { await home(m, base); await profileTab(m).click(); await settle(m, 800);
          await btn(m, /^Моя компания/).click(); await settle(m, 2000); },
        async () => { await openApp(m, base, `#/objects/${uuid(10)}/floors/${uuid(601)}`); await settle(m, 3000); },
      ];
      for (const v of visit) await v();
      await ctx.shot(m, 'last');
      ctx.notes.push(`экранов: ${visit.length}, чужих id в ответах: ${foreign.length}`);
      assert(foreign.length === 0, `утечка: ${foreign.slice(0, 3).join(', ')}`);
    },
  },
  {
    id: 9,
    db: 'hh_old',
    title: 'Старая база (без 0015/0016, как рабочая сейчас): приложение работает, новые разделы — «Нужна миграция …», без красных ошибок',
    async run(ctx) {
      const { base } = ctx;
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      const bad = /Не удалось загрузить|Что-то пошло не так|permission denied|does not exist|PostgrestException/;
      const check = async (where) => {
        await settle(m, 1500);
        const t = await screenText(m);
        assert(!bad.test(t), `${where}: ошибка на экране — ${(t.match(bad) ?? [''])[0]}`);
        return t;
      };
      await home(m, base);
      const t0 = await check('Заявки');
      assert(/Протечка|кондиционер|Не работает|\d+ из \d+/i.test(t0) || t0.length > 200, 'список заявок пуст');
      await ctx.shot(m, 'requests');
      await section(m, /^Плановое ТО/);
      const t1 = await screenText(m);
      assert(/Нужна миграция 0015|миграци/i.test(t1), 'ППР: нет «Нужна миграция 0015»');
      ctx.notes.push('ППР: «Нужна миграция 0015»');
      await ctx.shot(m, 'ppr');
      await home(m, base);
      await section(m, /^Локации/);
      await check('Локации');
      await btn(m, /^Demo Tower/).click();
      await settle(m, 2500);
      await check('Карточка объекта');
      await ctx.shot(m, 'object');
      await home(m, base);
      await section(m, /^Подрядчики/);
      await check('Подрядчики');
      await home(m, base);
      await section(m, /^Отчёты/);
      await check('Отчёты');
      await ctx.shot(m, 'reports');
      await home(m, base);
      await section(m, /^История/);
      await check('История');
      await home(m, base);
      await profileTab(m).click();
      await settle(m, 800);
      await btn(m, /^Моя компания/).click();
      await check('Моя компания');
      await scrollTo(m, /Регионы компании/);
      await btn(m, /Регионы компании/).click();
      await settle(m, 2000);
      const t2 = await screenText(m);
      assert(/миграци/i.test(t2), 'Регионы: нет «Нужна миграция 0015»');
      await ctx.shot(m, 'regions');
      // Голосовая заявка на старой базе: создаётся и назначается.
      await home(m, base);
      await clickAction(m, /Нажми и говори/);
      await see(m, /не работает кондиционер/).waitFor({ timeout: 15000 });
      await clickAction(m, /^Готово/);
      await see(m, /Проверьте заявку/).waitFor({ timeout: 20000 });
      await clickAction(m, /^Отправить/);
      const row = await waitDb(`select status from work_orders where title like 'Не работает кондиционер%'
        and created_at > now() - interval '2 minutes' order by created_at desc limit 1`, (v) => v.length > 0);
      ctx.notes.push(`заявка на старой базе: ${row}`);
      assert(row === 'assigned', `заявка на старой базе: ${row}`);
      const js = ctx.errors.filter((e) => !/ResizeObserver/.test(e));
      assert(js.length === 0, `ошибки JavaScript: ${js.slice(0, 2).join(' | ')}`);
    },
  },
  {
    id: 10,
    title: '«Узнать по фото» (заглушка) → «Это он» → заявка с фото «до» → фото видно в карточке и на весь экран',
    async run(ctx) {
      const { base } = ctx;
      sql(`delete from work_orders where company_id = '${uuid(1)}' and input_channel = 'camera'
        and id::text not like 'de300000-%'`);
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      // «Где я» запоминается на устройстве: сразу «Demo Tower», без выбора.
      const uid = sql(`select id from auth.users where email = '${USERS.admin}'`);
      await m.evaluate(([k, v]) => localStorage.setItem(k, JSON.stringify(v)),
        [`flutter.photo_here_v1_${uid}`, `${uuid(10)}|`]);
      await home(m, base);
      // «По фото» открывает «Камеру» (шаг 25); выбор снимка — «Выбрать фото».
      await section(m, /^По фото/);
      await clickAction(m, /^Выбрать фото/, 30000);
      await clickAction(m, /^Сфотографировать/);
      await btn(m, /^Это он/).waitFor({ timeout: 30000 });
      await ctx.shot(m, 'identified');
      await clickAction(m, /^Это он/);
      await see(m, /Снимок будет приложен/).waitFor({ timeout: 15000 });
      await see(m, /из «Узнать по фото»/).waitFor({ timeout: 5000 });
      await ctx.shot(m, 'form');
      await clickAction(m, /^Создать/);
      const id = await waitDb(`select id from work_orders where company_id = '${uuid(1)}' and input_channel = 'camera'
        and created_at > now() - interval '2 minutes' order by created_at desc limit 1`, (v) => v.length > 0, 20000);
      await waitDb(`select count(*) from attachments where work_order_id = '${id}' and stage = 'before'`, '1', 20000);
      const title = sql(`select title from work_orders where id = '${id}'`);
      ctx.notes.push(`заявка: ${title}`);
      // Карточка: ссылки на фото подписываются, миниатюра «До · 1» видна.
      const signed = [];
      m.on('response', (r) => { if (/\/object\/sign\/work-photos/.test(r.url())) signed.push(r.status()); });
      await openOrder(m, base, title);
      await see(m, /До · 1/).waitFor({ timeout: 15000 });
      await settle(m, 1500);
      assert(signed.includes(200), `подписанные ссылки на фото: ${signed.join(',') || 'не запрошены'}`);
      await ctx.shot(m, 'card-photo');
      // На весь экран: подпись «До · <кто> · <когда> · …».
      await btn(m, /^До$/).click();
      await settle(m, 2000);
      const viewer = await screenText(m);
      assert(/До · .+ · .+/.test(viewer), 'в просмотре нет подписи «До · кто · когда»');
      await ctx.shot(m, 'viewer');
      await m.keyboard.press('Escape');
      await settle(m, 800);
      ctx.notes.push('фото «до» в карточке и в просмотре видно');
    },
  },
  {
    id: 11,
    title: 'Форма новой заявки: прошлое место не подставляется; GPS рядом с объектом → «Рядом с вами»',
    async run(ctx) {
      const { base } = ctx;
      sql(`delete from work_orders where company_id = '${uuid(1)}' and title like 'E2E форма%'`);
      // 1. Без геопозиции: создать заявку на «Demo Tower», открыть форму снова — объект пуст.
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await home(m, base);
      await clickAction(m, /^(\+ )?Заявка$/);
      await see(m, /Новая заявка/).waitFor({ timeout: 10000 });
      await typeInto(m, m.getByRole('textbox').first(), 'E2E форма 1');
      await btn(m, /^Выберите объект/).click();
      await settle(m, 800);
      await m.getByRole('menuitem', { name: /Demo Tower/ }).or(m.getByRole('option', { name: /Demo Tower/ }))
        .or(m.getByText(/Demo Tower/)).first().click();
      await settle(m, 800);
      await clickAction(m, /^Создать заявку$/);
      await waitDb(`select count(*) from work_orders where title = 'E2E форма 1'`, '1');
      await settle(m, 1500);
      await clickAction(m, /^(\+ )?Заявка$/);
      await see(m, /Новая заявка/).waitFor({ timeout: 10000 });
      await settle(m, 3800); // GPS ждём не дольше 3 с
      await ctx.shot(m, 'form-empty');
      assert(await btn(m, /^Выберите объект/).isVisible(), 'в новой форме подставился объект прошлой заявки');
      await see(m, /Недавние/).waitFor({ timeout: 5000 });
      ctx.notes.push('после заявки на «Demo Tower» новая форма пустая, есть «Недавние»');
      // 2. С геопозицией в 40 м от «Demo Tower» — объект подставлен, без помещения.
      const g = await ctx.page({ geo: { latitude: 44.80507, longitude: 20.44942, accuracy: 10 } });
      await login(g, base, USERS.admin);
      await home(g, base);
      await clickAction(g, /^(\+ )?Заявка$/);
      await see(g, /Рядом с вами · \d+ м/).waitFor({ timeout: 8000 });
      await ctx.shot(g, 'form-gps');
      const t = await screenText(g);
      assert(/Demo Tower/.test(t), 'по GPS не подставлен «Demo Tower»');
      ctx.notes.push(`GPS: ${t.match(/Рядом с вами · \d+ м/)?.[0]}`);
    },
  },
  {
    id: 12,
    title: 'Документы: прикрепить PDF к заявке → строка «Документы · 1» → «Открыть» (новая вкладка)',
    async run(ctx) {
      const { base } = ctx;
      const id = uuid(114);
      sql(`delete from attachments where work_order_id = '${id}' and kind = 'document'`);
      const f = join(TMP, 'akt-e2e.pdf');
      // Простейший PDF из одной пустой страницы (сгенерирован, не реальный документ).
      writeFileSync(f, '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n');
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await home(m, base);
      await m.evaluate((h) => { location.hash = h; }, `/orders/${id}`);
      await see(m, /Создана/).waitFor({ timeout: 20000 });
      await scrollTo(m, /Прикрепить файл/);
      const chooser = m.waitForEvent('filechooser', { timeout: 15000 });
      await btn(m, /^Прикрепить файл/).click();
      await (await chooser).setFiles(f);
      const row = await waitDb(`select file_name || '|' || mime || '|' || size_bytes || '|' || storage_path from attachments
        where work_order_id = '${id}' and kind = 'document'`, (v) => v.length > 0, 20000);
      ctx.notes.push(`в базе: ${row.split('|').slice(0, 3).join(' · ')}`);
      assert(row.includes(`|${uuid(1)}/${id}/`) && row.endsWith('-akt-e2e.pdf'), `путь файла: ${row}`);
      await see(m, /Документы · 1/).waitFor({ timeout: 15000 });
      await ctx.shot(m, 'docs');
      await btn(m, /^akt-e2e\.pdf/).click();
      await settle(m, 800);
      // Вкладка открывается с noopener — её адрес Playwright не видит, поэтому
      // проверяем, что браузер запросил файл по подписанной ссылке.
      const opened = m.context().waitForEvent('request', {
        predicate: (r) => /\/object\/sign\/order-files\/.+akt-e2e\.pdf\?token=/.test(r.url()) && r.method() === 'GET',
        timeout: 15000,
      });
      await btn(m, /^Открыть$/).click();
      const req = await opened;
      ctx.notes.push(`открыт по подписанной ссылке: …${req.url().split('?')[0].slice(-24)}`);
    },
  },
  {
    id: 13,
    title: '«Системы»: администратор создаёт систему; менеджер с зоной «Климат + Сантехника» её не видит',
    async run(ctx) {
      const { base } = ctx;
      sql(`delete from layers where company_id = '${uuid(1)}' and name = 'E2E Лифты'`);
      sql(`delete from access_zones where profile_id = 'd0000000-0000-4000-8000-000000000004';
        insert into access_zones(company_id, profile_id, layer_ids, scope_kind, scope_ref)
        select '${uuid(1)}', 'd0000000-0000-4000-8000-000000000004',
          array(select id from layers where company_id = '${uuid(1)}' and name in ('Климат', 'Сантехника')), 'city', 'New York'`);
      const a = await ctx.page();
      await login(a, base, USERS.admin);
      await home(a, base);
      await profileTab(a).click();
      await settle(a, 1000);
      await btn(a, /^Моя компания/).click();
      await scrollTo(a, /^Системы/);
      await btn(a, /^Системы/).click();
      await see(a, /Оборудование: \d+/).waitFor({ timeout: 20000 });
      await btn(a, /^Система$/).click();
      await see(a, /Новая система/).waitFor({ timeout: 10000 });
      await typeInto(a, a.getByRole('textbox').first(), 'E2E Лифты');
      await typeInto(a, a.getByRole('textbox').nth(1), 'E2E Lifts');
      await clickAction(a, /^Создать систему/);
      const row = await waitDb(`select name_i18n->>'en' || '|' || coalesce(icon, '-') || '|' || color from layers
        where company_id = '${uuid(1)}' and name = 'E2E Лифты'`, (v) => v.length > 0);
      ctx.notes.push(`создана: ${row}`);
      await see(a, /E2E Лифты/).waitFor({ timeout: 10000 });
      await ctx.shot(a, 'admin');
      const m = await ctx.page();
      await login(m, base, USERS.manager2);
      await home(m, base);
      await profileTab(m).click();
      await settle(m, 1000);
      await btn(m, /^Моя компания/).click();
      await scrollTo(m, /^Системы/);
      await btn(m, /^Системы/).click();
      await see(m, /Оборудование: \d+/).waitFor({ timeout: 20000 });
      await settle(m, 1500);
      await ctx.shot(m, 'manager2');
      const t = await screenText(m);
      assert(!/E2E Лифты/.test(t), 'менеджер с зоной видит систему вне своей зоны');
      assert(/Климат/.test(t) && !/Электрика/.test(t), 'менеджер с зоной видит не те системы');
      assert(!/Новая система|^Система$/m.test(t), 'у менеджера есть кнопка «+ Система»');
      ctx.notes.push('менеджер с зоной видит только «Климат» и «Сантехника»');
    },
  },
  {
    id: 14,
    title: 'Акт подрядчику «ClimaService» за месяц: в «К оплате» только доказанные заявки → «Сформировать акт» → номер и PDF',
    async run(ctx) {
      const { base } = ctx;
      // Сколько доказанных по правилам акта — тем же расчётом в SQL.
      const proven = +sql(`select count(*) from work_orders w left join objects o on o.id = w.object_id
        where w.assigned_contractor_id = '${uuid(31)}' and w.status = 'done'
          and coalesce(w.accepted_at, w.submitted_at, w.updated_at) >= date_trunc('month', now())
          and ${ACT_PAYABLE_SQL}`);
      const before = +sql(`select count(*) from contractor_acts where contractor_id = '${uuid(31)}'`);
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await home(m, base);
      await section(m, /^Отчёты/);
      await scrollTo(m, /Акты подрядчикам/);
      await btn(m, /^Акты подрядчикам/).click();
      await see(m, /К оплате · \d+/).waitFor({ timeout: 30000 });
      await settle(m, 1500);
      const t = await screenText(m);
      const shown = +(t.match(/К оплате · (\d+)/i)?.[1] ?? NaN);
      ctx.notes.push(`к оплате на экране ${shown}, по базе ${proven}`);
      assert(shown === proven && proven > 0, `«К оплате»: на экране ${shown}, доказанных в базе ${proven}`);
      // Группа «Без доказательства» — под «Требует решения» (шаг 27), ниже
      // экрана: прокрутка до строки с причиной (нет — исключение).
      await scrollTo(m, /нет фото «после»|визит вне геозоны|не принята менеджером|нет отметки визита/)
        .catch(() => { throw new Error('нет списка «без доказательства» с причинами'); });
      await ctx.shot(m, 'act');
      await clickAction(m, /^Сформировать акт/);
      // Есть «Требует решения» (демо 109, 112, шаг 27) — предупреждение.
      const without = btn(m, /^Сформировать без них/);
      if (await without.waitFor({ timeout: 4000 }).then(() => true, () => false)) await without.click();
      // PDF загружается после выдачи номера — ждём путь файла в акте.
      const act = await waitDb(`select number || '|' || (totals->>'paid') || '|' || coalesce(pdf_path, '-') from contractor_acts
        where contractor_id = '${uuid(31)}' order by created_at desc limit 1`,
        (v) => v.length > 0 && !v.endsWith('|-') && +sql(`select count(*) from contractor_acts where contractor_id = '${uuid(31)}'`) > before, 40000);
      ctx.notes.push(`акт: ${act.split('|').slice(0, 2).join(', к оплате ')}`);
      const [num, paid, pdf] = act.split('|');
      assert(/^АКТ-\d{4}-\d{3}$/.test(num), `номер акта: ${num}`);
      assert(+paid === proven, `в акте к оплате ${paid}, ждали ${proven}`);
      assert(pdf.endsWith('.pdf'), `PDF акта не сохранён: ${pdf}`);
    },
  },
  {
    id: 15,
    title: '«Камера-помощник» (заглушка камеры и ИИ, телефон): «Что это?» → «AC-301 · 91 %» и карточка → «Создать заявку» → заявка с фото',
    async run(ctx) {
      const { base } = ctx;
      sql(`delete from work_orders where company_id = '${uuid(1)}' and input_channel = 'camera'
        and id::text not like 'de300000-%'`);
      const m = await ctx.page({ width: 412, height: 915 });
      await login(m, base, USERS.admin);
      // «Где я» — переговорная 301 «Demo Tower» (запомнено на устройстве).
      const uid = sql(`select id from auth.users where email = '${USERS.admin}'`);
      await m.evaluate(([k, v]) => localStorage.setItem(k, JSON.stringify(v)),
        [`flutter.photo_here_v1_${uid}`, `${uuid(10)}|${uuid(21)}`]);
      await home(m, base);
      await btn(m, /Узнать оборудование по фото/).click();
      await btn(m, /^Что это\?/).waitFor({ timeout: 30000 });
      await see(m, /Meeting room/).waitFor({ timeout: 15000 });
      await ctx.shot(m, 'live');
      await btn(m, /^Что это\?/).click();
      await see(m, /AC-301 · 91 %/).waitFor({ timeout: 30000 });
      await see(m, /Плановое ТО|ТО не запланировано/).waitFor({ timeout: 15000 });
      await settle(m, 800);
      const t = await screenText(m);
      assert(/Air conditioner AC-301/.test(t), 'в карточке нет «Air conditioner AC-301»');
      assert(/Открытые заявки · \d+|Нет открытых заявок/.test(t), 'в карточке нет открытых заявок');
      assert(/Последняя работа|Выполненных работ ещё не было/.test(t), 'в карточке нет последней работы');
      ctx.notes.push('карточка: ' + (t.match(/Открытые заявки · \d+|Нет открытых заявок/)?.[0] ?? '?')
        + '; ' + (t.match(/Плановое ТО[^\n]*|ТО не запланировано/)?.[0] ?? '?'));
      await ctx.shot(m, 'card');
      await clickAction(m, /^Создать заявку/);
      await see(m, /Снимок будет приложен/).waitFor({ timeout: 15000 });
      await see(m, /с камеры/).waitFor({ timeout: 5000 });
      await ctx.shot(m, 'form');
      // Кнопка формы — последняя «Создать заявку» (первая — в карточке под шторкой).
      await m.getByRole('button', { name: /^Создать заявку$/ }).last().click();
      const id = await waitDb(`select id from work_orders where company_id = '${uuid(1)}' and input_channel = 'camera'
        and created_at > now() - interval '2 minutes' order by created_at desc limit 1`, (v) => v.length > 0, 20000);
      await waitDb(`select count(*) from attachments where work_order_id = '${id}' and stage = 'before'`, '1', 20000);
      const row = sql(`select coalesce(asset_id::text, '-') || '|' || coalesce(location_id::text, '-') || '|' || title from work_orders where id = '${id}'`);
      ctx.notes.push(`заявка: ${row.split('|')[2]}`);
      assert(row.startsWith(`${uuid(708)}|${uuid(21)}|`), `оборудование и помещение заявки: ${row}`);
    },
  },
  {
    id: 16,
    title: 'Роли (шаг 26): менеджер не начинает работу за подрядчика → исполнитель (живой снимок «после») сдаёт → менеджер принимает → в акте «к оплате»',
    async run(ctx) {
      const { base } = ctx;
      const title = 'E2E-16 Шумит кондиционер';
      sql(`delete from work_orders where company_id = '${uuid(1)}' and title = '${title}'`);
      const id = sql(`insert into work_orders(company_id, object_id, location_id, layer_id, work_type, title, status,
          created_by, assigned_contractor_id, requires_photo)
        select '${uuid(1)}', '${uuid(10)}', '${uuid(21)}', l.id, l.name, '${title}', 'assigned',
          (select id from auth.users where email = '${USERS.requester}'), '${uuid(31)}', true
          from layers l where l.company_id = '${uuid(1)}' and l.name = 'Климат' returning id`).split('\n')[0];

      // 1. Менеджер: кнопок исполнителя нет.
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await openOrder(m, base, title);
      let t = await screenText(m);
      assert(!/Начать работу|Сфотографировать результат|Выполнено, на проверку/.test(t),
        'у менеджера не должно быть кнопок исполнителя');
      await ctx.shot(m, 'manager-assigned');

      // 2. Исполнитель «ClimaService»: начать, живой снимок «после», сдать.
      const e = await ctx.page({ width: 412, height: 915, geo: BC_DEMO });
      await login(e, base, USERS.executor);
      await openOrder(e, base, title);
      await clickAction(e, /^Начать работу/);
      await waitDb(`select status from work_orders where id = '${id}'`, 'in_progress');

      // Менеджер видит ход работы, а не кнопки.
      await openOrder(m, base, title);
      await see(m, /Выполняет ClimaService/).waitFor({ timeout: 15000 });
      t = await screenText(m);
      assert(!/Выполнено, на проверку|Сфотографировать результат/.test(t), 'у менеджера в работе — только строка-статус');
      await ctx.shot(m, 'manager-progress');

      await takeLivePhoto(e);
      const src = await waitDb(`select string_agg(source, ',') from attachments where work_order_id = '${id}' and stage = 'after'`,
        (v) => v.length > 0, 20000);
      ctx.notes.push(`источник фото «после»: ${src}`);
      assert(src === 'camera', `фото «после» должно быть с камеры, в базе: ${src}`);
      await settle(e, 1500);
      await ctx.shot(e, 'exec-photo');
      await clickAction(e, /Выполнено, на проверку/);
      await waitDb(`select status from work_orders where id = '${id}'`, 'on_review');
      const by = sql(`select p.email from work_orders w join auth.users p on p.id = w.submitted_by where w.id = '${id}'`);
      assert(by === USERS.executor, `submitted_by: ${by}`);

      // 3. Менеджер принимает.
      await openOrder(m, base, title);
      await clickAction(m, /^Принять работу/);
      const confirm = btn(m, /^Принять$/);
      if (await confirm.isVisible().catch(() => false)) await confirm.click();
      await waitDb(`select status from work_orders where id = '${id}'`, 'done');

      // 4. Акт «ClimaService» за месяц: заявка — в «К оплате».
      await home(m, base);
      await section(m, /^Отчёты/);
      await scrollTo(m, /Акты подрядчикам/);
      await btn(m, /^Акты подрядчикам/).click();
      await see(m, /К оплате · \d+/).waitFor({ timeout: 30000 });
      await settle(m, 1500);
      t = await screenText(m);
      const shown = +(t.match(/К оплате · (\d+)/i)?.[1] ?? NaN);
      // Те же правила акта в SQL (как сценарий 14, фото «из файла» — не доказательство).
      const proven = sql(`select string_agg(w.id::text, ',') from work_orders w left join objects o on o.id = w.object_id
        where w.assigned_contractor_id = '${uuid(31)}' and w.status = 'done'
          and coalesce(w.accepted_at, w.submitted_at, w.updated_at) >= date_trunc('month', now())
          and ${ACT_PAYABLE_SQL}`).split(',');
      ctx.notes.push(`в акте к оплате на экране ${shown}, по базе ${proven.length}, заявка среди них: ${proven.includes(id)}`);
      assert(proven.includes(id), 'заявка должна быть доказанной по правилам акта');
      assert(shown === proven.length, `«К оплате»: на экране ${shown}, по базе ${proven.length}`);
      await scrollTo(m, new RegExp(title));
      await ctx.shot(m, 'act');
    },
  },
  {
    id: 17,
    title: 'Без сети (шаг 27): исполнитель начинает, отмечает чек-лист, снимает «после», сдаёт → сеть → «на проверке», время по монотонным часам; часы +2 ч → «Требует решения» → менеджер подтверждает',
    async run(ctx) {
      const { base } = ctx;
      const mk = (title) => {
        sql(`delete from work_orders where company_id = '${uuid(1)}' and title = '${title}'`);
        const id = sql(`insert into work_orders(company_id, object_id, location_id, layer_id, work_type, title, status,
            created_by, assigned_contractor_id, requires_photo)
          select '${uuid(1)}', '${uuid(10)}', '${uuid(21)}', l.id, l.name, '${title}', 'assigned',
            (select id from auth.users where email = '${USERS.requester}'), '${uuid(31)}', true
            from layers l where l.company_id = '${uuid(1)}' and l.name = 'Климат' returning id`).split('\n')[0];
        sql(`insert into checklist_items(work_order_id, text) values ('${id}', 'Очистить фильтры'), ('${id}', 'Проверить дренаж')`);
        return id;
      };
      /** Открыть заявку без перезагрузки страницы (очередь в тестовом режиме — в памяти). */
      const openInApp = async (page, title) => {
        const search = page.getByRole('textbox').first();
        await typeInto(page, search, title.slice(0, 24));
        await settle(page, 1800);
        await btn(page, new RegExp(title.slice(0, 20))).click();
        await settle(page, 2500);
      };
      const net = (page) => page.getByRole('switch').first();
      const runOffline = async (title, skewMin, shotPrefix) => {
        const id = mk(title);
        const e = await ctx.page({ width: 412, height: 915, geo: BC_DEMO });
        await login(e, base, USERS.executor);
        await openApp(e, base, `?offline=1&clockSkewMin=${skewMin}`);
        await profileTab(e).waitFor({ timeout: 60000 });
        await settle(e, 4000); // якорь часов и предзагрузка своих заявок
        await openInApp(e, title);
        // Сеть «выключена» (тест): всё — в очередь телефона.
        await net(e).click();
        await settle(e, 800);
        await clickAction(e, /^Начать работу/);
        await btn(e, /Очистить фильтры/).click();
        await settle(e, 600);
        await btn(e, /Проверить дренаж/).click();
        await settle(e, 600);
        await takeLivePhoto(e);
        await settle(e, 1500);
        await clickAction(e, /Выполнено, на проверку/);
        await see(e, /Нет сети — сохранено на телефоне: \d+/).waitFor({ timeout: 15000 });
        const t = await screenText(e);
        const n = +(t.match(/сохранено на телефоне: (\d+)/)?.[1] ?? NaN);
        ctx.notes.push(`${title}: в очереди ${n} действий`);
        assert(n === 6, `в очереди должно быть 6 действий (начать, визит, 2 пункта, фото, сдать), на экране ${n}`);
        assert(sql(`select status from work_orders where id = '${id}'`) === 'assigned', 'без сети сервер не должен меняться');
        if (shotPrefix) {
          await settle(e, 4000); // сообщение сверху закрывается — видна плашка
          await e.mouse.wheel(0, -2000);
          await settle(e, 800);
          await ctx.shot(e, `${shotPrefix}-queued`);
        }
        // Сеть вернулась — очередь уходит сама.
        await net(e).click();
        await waitDb(`select status from work_orders where id = '${id}'`, 'on_review', 30000);
        await see(e, /Отправлено ✓|на проверке/i).waitFor({ timeout: 15000 }).catch(() => {});
        return { id, e };
      };

      // 1. Честные часы: время по монотонным часам, отпечаток сверен.
      const a = await runOffline('E2E-17 Без сети: фильтр', 0, 'offline');
      const p = sql(`select offline || ',' || time_trust || ',' || coalesce(sha256_ok::text, 'null') || ',' || source
        from attachments where work_order_id = '${a.id}' and stage = 'after'`);
      ctx.notes.push(`фото: ${p}`);
      assert(p === 'true,monotonic,true,camera', `фото «после»: ${p}`);
      const v = sql(`select offline || ',' || time_trust || ',' || coalesce(in_geofence::text, 'null') from visits where work_order_id = '${a.id}'`);
      assert(v === 'true,monotonic,true', `визит: ${v}`);
      assert(sql(`select count(*) from checklist_items where work_order_id = '${a.id}' and is_done`) === '2', 'оба пункта отмечены');
      assert(sql(`select count(*) from offline_actions where work_order_id = '${a.id}'`) === '6', 'в журнале 6 действий');

      // 2. Часы телефона переведены на 2 ч → время не подтверждено.
      const b = await runOffline('E2E-17b Без сети: часы', 120, null);
      const pb = sql(`select time_trust || ',' || time_drift_s from attachments where work_order_id = '${b.id}' and stage = 'after'`);
      ctx.notes.push(`фото при часах +2 ч: ${pb}`);
      assert(pb.startsWith('unverified,') && Math.abs(+pb.split(',')[1] - 7200) < 120, `ожидалось unverified ≈ 7200 с: ${pb}`);

      // Исполнитель решать не может — проверка базы.
      sql(`update work_orders set status = 'done', accepted_at = now() where id in ('${a.id}', '${b.id}')`);
      const exUid = sql(`select id from auth.users where email = '${USERS.executor}'`);
      let denied = false;
      try {
        sql(`select set_config('request.jwt.claim.sub', '${exUid}', false); set role authenticated;
             select public.act_proof_decide('${b.id}', 'approve', 'сам себе')`);
      } catch { denied = true; }
      assert(denied, 'исполнитель не должен решать по оплате');

      // 3. Менеджер: карточка и акт — «Требует решения менеджера» → «Подтвердить к оплате».
      const mp = await ctx.page({ width: 412, height: 915 });
      await login(mp, base, USERS.admin);
      await openOrder(mp, base, 'E2E-17 Без сети: фильтр');
      await scrollTo(mp, /Снято без сети в/);
      await mp.mouse.move(200, 500);
      await mp.mouse.wheel(0, 600);
      await settle(mp, 1000);
      await ctx.shot(mp, 'card-proof');
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await home(m, base);
      await section(m, /^Отчёты/);
      await scrollTo(m, /Акты подрядчикам/);
      await btn(m, /^Акты подрядчикам/).click();
      await see(m, /Требует решения менеджера · \d+/).waitFor({ timeout: 30000 });
      await scrollTo(m, /E2E-17b/);
      await ctx.shot(m, 'act-review');
      const row = m.getByRole('button', { name: /Подтвердить к оплате/ });
      const count = await row.count();
      assert(count > 0, 'нет кнопки «Подтвердить к оплате»');
      // Кнопка именно у E2E-17b: последняя в группе по дате (заявка сдана сейчас).
      await row.nth(count - 1).click();
      await settle(m, 800);
      await typeInto(m, m.getByRole('textbox').last(), 'Звонил исполнителю, визит подтверждён охраной');
      await btn(m, /^Подтвердить к оплате$/).click();
      await waitDb(`select decision from act_proof_decisions where work_order_id = '${b.id}' order by decided_at desc limit 1`, 'approve', 20000);
      await see(m, /решение менеджера/).waitFor({ timeout: 20000 });
      await scrollTo(m, /E2E-17b/);
      await ctx.shot(m, 'act-approved');
    },
  },
  {
    id: 19,
    title: 'Новая заявка без сети (шаг 32): заявитель создаёт заявку с фото «до» → она на телефоне, на сервере её нет → сеть → заявка на сервере, время доверенное, у менеджера «Создано без сети · отправлено в …»',
    async run(ctx) {
      const { base } = ctx;
      const TITLE = 'E2E-19 Без сети: течёт кран';
      sql(`delete from work_orders where company_id = '${uuid(1)}' and title = '${TITLE}'`);
      const net = (page) => page.getByRole('switch').first();
      const r = await ctx.page({ geo: BC_DEMO });
      await login(r, base, USERS.requester);
      await openApp(r, base, '?offline=1');
      await profileTab(r).waitFor({ timeout: 60000 });
      await settle(r, 5000); // якорь часов и предзагрузка справочников
      // Сеть «выключена» (тест).
      await net(r).click();
      await settle(r, 800);
      await clickAction(r, /^(\+ )?Заявка$/);
      await see(r, /Новая заявка/).waitFor({ timeout: 10000 });
      await see(r, /Нет сети: заявка сохранится на телефоне/).waitFor({ timeout: 10000 });
      await typeInto(r, r.getByRole('textbox').first(), TITLE);
      // Объект: по GPS («Рядом с вами») или вручную — справочник с телефона.
      await settle(r, 3500);
      if (await btn(r, /^Выберите объект/).isVisible().catch(() => false)) {
        await btn(r, /^Выберите объект/).click();
        await settle(r, 800);
        await r.getByRole('menuitem', { name: /Demo Tower/ }).or(r.getByRole('option', { name: /Demo Tower/ }))
          .or(r.getByText(/Demo Tower/)).first().click();
        await settle(r, 800);
      }
      await btn(r, /^Сантехника$/).click();
      await settle(r, 500);
      // Фото «до» — живой камерой (в сборке e2e — заглушка камеры).
      await clickAction(r, /Снять фото «до»/);
      await btn(r, /^Снять/).waitFor({ timeout: 20000 });
      await btn(r, /^Снять/).click();
      await clickAction(r, /^Готово/);
      await see(r, /Снимок будет приложен/).waitFor({ timeout: 10000 });
      await ctx.shot(r, 'form');
      await r.getByRole('button', { name: /^Создать заявку$/ }).last().click();
      await settle(r, 2500);
      assert(sql(`select count(*) from work_orders where title = '${TITLE}'`) === '0', 'без сети на сервере заявки быть не должно');
      await see(r, /Нет сети — сохранено на телефоне: 2/).waitFor({ timeout: 15000 });
      let t = await screenText(r);
      assert(t.includes(TITLE), 'заявка, созданная без сети, должна быть в списке на телефоне');
      ctx.notes.push('без сети: заявка в списке на телефоне, в очереди 2 действия (заявка и фото «до»)');
      await settle(r, 3500); // сообщение сверху закрывается — видна плашка
      await ctx.shot(r, 'queued');
      // Карточка до отправки — «ждёт отправки».
      await btn(r, new RegExp(TITLE.slice(0, 20))).click();
      await see(r, /Создано без сети · ждёт отправки/).waitFor({ timeout: 10000 });
      await ctx.shot(r, 'card-pending');

      // Сеть вернулась — очередь уходит сама: сначала заявка, потом фото «до».
      await net(r).click();
      const id = await waitDb(`select id from work_orders where title = '${TITLE}'`, (v) => v.length > 0, 30000);
      await waitDb(`select count(*) from attachments where work_order_id = '${id}' and stage = 'before'`, '1', 30000);
      const row = sql(`select w.status || ',' || w.input_channel || ',' || l.name || ',' || (w.created_by = u.id)
          from work_orders w join layers l on l.id = w.layer_id, auth.users u
         where w.id = '${id}' and u.email = '${USERS.requester}'`);
      ctx.notes.push(`заявка на сервере: ${row}`);
      assert(/^(new|assigned),button,Сантехника,true$/.test(row), `поля заявки: ${row}`);
      const act = sql(`select result || ',' || time_trust from offline_actions where work_order_id = '${id}' and kind = 'create'`);
      assert(act.startsWith('applied,') && act !== 'applied,device_only', `журнал create: ${act}`);
      const ph = sql(`select offline || ',' || time_trust || ',' || source from attachments where work_order_id = '${id}' and stage = 'before'`);
      ctx.notes.push(`create: ${act}; фото «до»: ${ph}`);
      assert(/^true,(monotonic|gps),camera$/.test(ph), `фото «до»: ${ph}`);
      const drift = +sql(`select abs(extract(epoch from w.created_at - o.trusted_at))::int from work_orders w
          join offline_actions o on o.work_order_id = w.id and o.kind = 'create' where w.id = '${id}'`);
      assert(drift <= 1, `время создания заявки — доверенное время действия (разница ${drift} с)`);

      // Менеджер видит заявку и пометку.
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await openOrder(m, base, TITLE);
      await see(m, /Создано без сети · отправлено в \d{1,2}:\d{2}/).waitFor({ timeout: 20000 });
      t = await screenText(m);
      ctx.notes.push('у менеджера: ' + (t.match(/Создано без сети · отправлено в \d{1,2}:\d{2}/)?.[0] ?? '?'));
      await ctx.shot(m, 'manager');
    },
  },
  {
    id: 18,
    title: 'Место оборудования (шаг 27): форма → «Указать на плане» → точка (нажатие и перетаскивание) → сохранено → маркер на плане в этом месте',
    async run(ctx) {
      const { base } = ctx;
      const NAME = 'E2E Датчик протечки';
      const room = uuid(21); // 301 · Meeting room, floor 3 (этаж 602)
      const floor = uuid(602);
      sql(`delete from assets where name = '${NAME}'`);
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await home(m, base);
      await section(m, /^Локации/);
      const list = m.getByRole('button', { name: /^Список/ }).or(m.getByText(/^Список$/)).first();
      if (await list.isVisible().catch(() => false)) await list.click();
      await settle(m, 1200);
      await btn(m, /^Demo Tower/).click();
      await see(m, /Адрес|Этажи/).waitFor({ timeout: 20000 });
      await settle(m, 1500);
      // 1. Форма «Новое оборудование»: название, помещение, «где именно».
      await scrollTo(m, /Добавить оборудование/);
      await btn(m, /Добавить оборудование/).click();
      await see(m, /Новое оборудование/).waitFor({ timeout: 15000 });
      await settle(m, 1000);
      await typeInto(m, m.getByRole('textbox').first(), NAME);
      await see(m, /Выберите помещение/).click();
      await settle(m, 800);
      await m.getByRole('menuitem', { name: /^301 · Meeting room/ }).or(m.getByRole('option', { name: /^301 · Meeting room/ }))
        .or(m.getByRole('button', { name: /^301 · Meeting room/ })).last().click();
      await settle(m, 800);
      await scrollTo(m, /^Потолок$/);
      await btn(m, /^Потолок$/).click();
      await typeInto(m, m.getByRole('textbox', { name: /Высота, м/ }), '2,8');
      await ctx.shot(m, 'form');
      // 2. «Место на плане» → экран выбора точки (план floor 3 у переговорной).
      await scrollTo(m, /Место на плане/);
      await btn(m, /^Место на плане/).click();
      const marker = m.getByRole('button', { name: /метка на плане/ }).or(m.getByLabel(/метка на плане/)).first();
      await marker.waitFor({ timeout: 30000 });
      await see(m, /Floor 3 · 301 · Meeting room/).waitFor({ timeout: 10000 });
      await settle(m, 1500);
      await ctx.shot(m, 'picker');
      // Нажатие по плану правее и ниже маркера → маркер туда; затем
      // перетащить мышью чуть влево.
      const b0 = await marker.boundingBox();
      const c0 = { x: b0.x + b0.width / 2, y: b0.y + b0.height / 2 };
      await raw(m, () => m.mouse.click(c0.x + 70, c0.y + 50));
      await settle(m, 800);
      await ctx.shot(m, 'picker-tap');
      const b1 = await marker.boundingBox();
      const c1 = { x: b1.x + b1.width / 2, y: b1.y + b1.height / 2 };
      ctx.notes.push(`маркер после нажатия: сдвиг ${Math.round(c1.x - c0.x)}, ${Math.round(c1.y - c0.y)} px (ждали 70, 50)`);
      assert(Math.abs(c1.x - c0.x - 70) < 4 && Math.abs(c1.y - c0.y - 50) < 4, 'маркер не встал туда, где нажали');
      await raw(m, async () => {
        await m.mouse.move(c1.x, c1.y);
        await m.mouse.down();
        await m.mouse.move(c1.x - 15, c1.y + 5, { steps: 6 });
        await m.mouse.move(c1.x - 30, c1.y + 10, { steps: 6 });
        await m.mouse.up();
      });
      await settle(m, 800);
      const b2 = await marker.boundingBox();
      const c2 = { x: b2.x + b2.width / 2, y: b2.y + b2.height / 2 };
      ctx.notes.push(`после перетаскивания: ${Math.round(c2.x - c1.x)}, ${Math.round(c2.y - c1.y)} px (ждали −30, 10)`);
      assert(Math.abs(c2.x - c1.x + 30) < 4 && Math.abs(c2.y - c1.y - 10) < 4, 'маркер не перетащился');
      await ctx.shot(m, 'picker-moved');
      await clickAction(m, /^Готово/);
      await see(m, /Floor 3 · 301 · Meeting room.* · Изменить/).waitFor({ timeout: 10000 });
      // 3. Сохранить → в базе этаж 602, точка внутри переговорной, монтаж в meta.
      await clickAction(m, /^Сохранить/);
      const saved = await waitDb(`select id || '|' || floor_id || '|' || plan_x || '|' || plan_y || '|' || location_id || '|'
        || coalesce(meta->>'mount', '-') || '|' || coalesce(meta->>'height_m', '-') from assets where name = '${NAME}'`,
      (v) => v.split('|').length === 7, 20000);
      const [assetId, fl, sx, sy, loc, mount, height] = saved.split('|');
      const [ax, ay] = [Number(sx), Number(sy)];
      ctx.notes.push(`в базе: этаж ${fl === floor ? '602' : fl}, точка ${ax}, ${ay}, монтаж ${mount}, высота ${height}`);
      assert(fl === floor && loc === room, 'этаж или помещение сохранились не те');
      assert(mount === 'ceiling' && height === '2.8', 'монтаж и высота не сохранились в meta');
      // Meeting room на схеме: rect [120, 120, 640, 560] из 2400×1600.
      assert(ax > 0.05 && ax < 0.317 && ay > 0.075 && ay < 0.425, 'точка вне переговорной');
      const [rx, ry] = sql(`select plan_x || ',' || plan_y from locations where id = '${room}'`).split(',').map(Number);
      assert(ax > rx && ay > ry, 'точка не сдвинулась вправо-вниз от точки помещения');
      // 4. План floor 3: маркер оборудования там же — пересчёт по двум помещениям.
      await openApp(m, base, `#/objects/${uuid(10)}/floors/${floor}`);
      await see(m, /На плане · \d/).waitFor({ timeout: 30000 });
      await settle(m, 2000);
      const ref = sql(`select code || '|' || name || '|' || plan_x || '|' || plan_y from locations
        where floor_id = '${floor}' and plan_x is not null and code is not null order by plan_x limit 1`) + '\n'
        + sql(`select code || '|' || name || '|' || plan_x || '|' || plan_y from locations
        where floor_id = '${floor}' and plan_x is not null and code is not null order by plan_x desc limit 1`);
      const [p1, p2] = ref.split('\n').map((r) => r.split('|'));
      const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const centre = async (name) => {
        const bb = await m.getByRole('button', { name: new RegExp(`^${name}`) }).first().boundingBox();
        return bb && { x: bb.x + bb.width / 2, y: bb.y + 22 }; // 22 — половина цели нажатия маркера
      };
      const q1 = await centre(`${esc(p1[0])} · ${esc(p1[1])}, `);
      const q2 = await centre(`${esc(p2[0])} · ${esc(p2[1])}, `);
      const qa = await centre(`${esc(NAME)}, `);
      assert(q1 && q2 && qa, 'маркеры на плане не найдены');
      // Экранных px на долю: по x — из двух помещений; по y — тот же масштаб
      // на высоту картинки (план не растягивается).
      const [pw, ph] = sql(`select plan_w || ',' || plan_h from floors where id = '${floor}'`).split(',').map(Number);
      const kx = (q2.x - q1.x) / (Number(p2[2]) - Number(p1[2]));
      const ky = kx * ph / pw;
      const want = { x: q1.x + (ax - Number(p1[2])) * kx, y: q1.y + (ay - Number(p1[3])) * ky };
      ctx.notes.push(`маркер на плане: ${Math.round(qa.x)}, ${Math.round(qa.y)}; по точке из базы: ${Math.round(want.x)}, ${Math.round(want.y)}`);
      assert(Math.abs(qa.x - want.x) < 6 && Math.abs(qa.y - want.y) < 6, 'маркер на плане не там, где поставили');
      // Выбранный маркер: под названием «потолок · 2,8 м» (видно на снимке;
      // шторка маркера закрывает план от диктора — текстом не проверить).
      await m.getByRole('button', { name: new RegExp(`^${esc(NAME)}, `) }).first().click();
      await settle(m, 1200);
      await ctx.shot(m, 'plan');
      sql(`delete from assets where id = '${assetId}'`);
    },
  },
];
