// Сценарии сквозных тестов. Каждый — отдельный тест: run(ctx) бросает
// исключение, если что-то не так. Проверки — и по экрану, и по базе.
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  USERS, assert, btn, home, login, openApp, raw, profileTab, scrollTo, section, see, settle, sql, typeInto, uuid, waitDb,
} from './lib.mjs';

const TMP = mkdtempSync(join(tmpdir(), 'hh-e2e-'));
/** Снимок «после» — сгенерированная картинка (не реальное фото). */
function photoFile() {
  const f = join(TMP, 'after.jpg');
  if (!existsSync(f)) {
    execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-f', 'lavfi', '-i', 'testsrc=size=800x600:rate=1',
      '-frames:v', '1', f]);
  }
  return f;
}
// Геопозиция «БЦ «Демо»» (Белград) — визит в геозоне.
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

/** Плитки «Отчётов» за 30 дней: число заявок и «приняты с первого раза из N». */
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
      await home(m, base);
      await ctx.shot(m, 'home');
      await clickAction(m, /Нажми и говори/);
      await see(m, /не работает кондиционер/).waitFor({ timeout: 15000 });
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
      assert(row.startsWith('assigned|КлиматСервис|Переговорная'), `ждали «назначена КлиматСервис, Переговорная», в базе: ${row}`);
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
      const chooser = e.waitForEvent('filechooser', { timeout: 15000 });
      await clickAction(e, /Сфотографировать результат/);
      await (await chooser).setFiles(photoFile());
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
      // Отчёт: число заявок за период и «приняты с первого раза» выросли на 1.
      const after = await reportTiles(m, base);
      ctx.notes.push(`отчёт: заявок ${before.orders} → ${after.orders}, приняты с первого раза из ${before.firstTime} → ${after.firstTime}`);
      assert(after.orders === before.orders + 1 && after.firstTime === before.firstTime + 1, 'отчёт не посчитал заявку');
      await scrollTo(m, /КлиматСервис/);
      await ctx.shot(m, 'report');
    },
  },
  {
    id: 2,
    title: 'ППР: «ТО кондиционеров» → генерация задачи → исполнитель → принятие → «выполнено N из M»',
    async run(ctx) {
      const { base } = ctx;
      const plan = uuid(801);
      // Задача текущего периода ещё не создана (в демо она уже есть — убираем).
      sql(`delete from work_orders where plan_id = '${plan}' and period_end >= current_date`);
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      await home(m, base);
      await section(m, /^ППР/);
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
      assert(row.startsWith('assigned|МосКлимат'), `задача должна уйти МосКлимат: ${row}`);
      await home(m, base);
      await section(m, /^ППР/);
      const before = await summary();
      await ctx.shot(m, 'ppr-before');

      const e = await ctx.page({ width: 412, height: 915, geo: { latitude: 55.749, longitude: 37.537, accuracy: 10 } });
      await login(e, base, 'mosklimat@example.com');
      await openOrder(e, base, 'ТО кондиционеров');
      await clickAction(e, /^Начать работу/);
      await waitDb(`select status from work_orders where id = '${task}'`, 'in_progress');
      const chooser = e.waitForEvent('filechooser', { timeout: 15000 });
      await clickAction(e, /Сфотографировать результат/);
      await (await chooser).setFiles(photoFile());
      await waitDb(`select count(*) from attachments where work_order_id = '${task}' and stage = 'after'`, '1', 20000);
      await settle(e, 1500);
      await clickAction(e, /Выполнено, на проверку/);
      await waitDb(`select status from work_orders where id = '${task}'`, 'on_review');

      await home(m, base);
      await section(m, /^ППР/);
      await btn(m, /^ТО кондиционеров/).click();
      await see(m, /История периодов/).waitFor({ timeout: 20000 });
      await settle(m, 1200);
      await btn(m, /ППР · .* · до/).click();
      await clickAction(m, /^Принять работу/);
      const confirm = btn(m, /^Принять$/);
      if (await confirm.isVisible().catch(() => false)) await confirm.click();
      await waitDb(`select status from work_orders where id = '${task}'`, 'done');
      await home(m, base);
      await section(m, /^ППР/);
      const after = await summary();
      ctx.notes.push(`сводка: выполнено ${before.done} из ${before.total} → ${after.done} из ${after.total}`);
      assert(after.done === before.done + 1 && after.total === before.total, 'сводка ППР не изменилась');
      await btn(m, /^ТО кондиционеров/).click();
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
      const room = uuid(23); // Open space, 2 этаж — в демо без точки на плане
      sql(`update locations set code = null, floor_id = null, plan_x = null, plan_y = null, plan_shape = null where id = '${room}'`);
      sql(`delete from work_orders where company_id = '${uuid(1)}' and title like 'Не работает свет%' and id::text not like 'de300000-%'`);
      const m = await ctx.page();
      await login(m, base, USERS.admin);
      // a) Заявка на оборудовании → «Показать на плане».
      await openOrder(m, base, 'Течёт конденсат из кондиционера');
      await clickAction(m, /Показать на плане/);
      await see(m, /На плане · \d/).waitFor({ timeout: 30000 });
      await settle(m, 1500);
      assert(/floors\//.test(m.url()) || await see(m, /Кондиционер серверной/).isVisible(), 'план не открылся');
      const focused = m.getByRole('button', { name: 'Кондиционер серверной' }).first();
      assert(await focused.isVisible().catch(() => false), 'маркер «Кондиционер серверной» не виден');
      ctx.notes.push('маркер оборудования на плане 3 этажа виден');
      await ctx.shot(m, 'show-on-plan');

      // b) Режим расстановки 1 этажа: «Поставить сюда…» → Open space, номер 305, область.
      await openApp(m, base, `#/objects/${uuid(10)}/floors/${uuid(601)}?edit=1`);
      await see(m, /Режим расстановки/).waitFor({ timeout: 30000 });
      await settle(m, 1500);
      // Маркеры на холсте: «102 · Ресепшен, 1 этаж, нет открытых заявок».
      const box = async (name) => m.getByRole('button', { name: new RegExp(`^\\d+ · ${name}, `) }).first().boundingBox();
      const a = await box('Ресепшен, 1 этаж'); // (0.15, 0.5125)
      const b = await box('Холл, 1 этаж'); // (0.45, 0.5125)
      const c = await box('Электрощитовая, 1 этаж'); // (0.15, 0.2063)
      assert(a && b && c, 'маркеры 1 этажа не найдены');
      const kx = (b.x - a.x) / 0.30;
      const ky = (a.y - c.y) / (0.5125 - 0.2063);
      const at = (fx, fy) => ({ x: a.x + a.width / 2 + (fx - 0.15) * kx, y: a.y + a.height / 2 + (fy - 0.5125) * ky });
      const spot = at(0.62, 0.80);
      await raw(m, () => m.mouse.click(spot.x, spot.y));
      await clickAction(m, /Поставить сюда/);
      // Пункт шторки (последний на экране; слева — такой же в списке «Не размещены»).
      await m.getByRole('button', { name: /^Open space, 2 этаж/ }).last().click();
      await settle(m, 1500);
      await waitDb(`select floor_id from locations where id = '${room}'`, uuid(601));
      const marker = () => m.getByRole('button', { name: /^(305 · )?Open space, 2 этаж, / }).first();
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
      assert(row.startsWith('Open space, 2 этаж|ЭлектроПро'), `ждали Open space и ЭлектроПро: ${row}`);
    },
  },
  {
    id: 4,
    title: 'Регионы: «Европпа» → «Использовать «Европа»»; объединение регионов; «Весь регион» в заявках и отчётах',
    async run(ctx) {
      const { base } = ctx;
      sql(`update objects set region_id = '${uuid(901)}' where region_id in (select id from regions where name in ('Европпа', 'Балканы'))`);
      sql(`delete from regions where company_id = '${uuid(1)}' and name in ('Европпа', 'Балканы')`);
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
        await see(m, /Европа/).waitFor({ timeout: 20000 });
        await settle(m, 800);
      };
      const addRegion = async (name) => {
        await clickAction(m, /Новый регион/);
        await typeInto(m, m.getByRole('textbox').last(), name);
        await clickAction(m, /^Сохранить|^Создать|^Готово|^Добавить/);
      };
      await openRegions();
      await addRegion('Европпа');
      await see(m, /Похоже/).waitFor({ timeout: 10000 });
      await ctx.shot(m, 'similar');
      await clickAction(m, /Использовать «Европа»/);
      assert(sql(`select count(*) from regions where company_id = '${uuid(1)}' and name = 'Европпа'`) === '0', '«Европпа» создан, хотя выбрали «Европа»');
      ctx.notes.push('«Европпа» → предложено «Европа», дубль не создан');

      // Объединение: новый «Балканы», объект «Белград · Хаб 1» в нём → объединить с «Европа».
      await addRegion('Балканы');
      const balkans = await waitDb(`select id from regions where company_id = '${uuid(1)}' and name = 'Балканы'`, (v) => v.length > 0);
      sql(`update objects set region_id = '${balkans}' where id = '${uuid(401)}'`);
      await openRegions();
      await m.getByRole('button', { name: /Балканы/ }).first().click();
      await settle(m, 800);
      await clickAction(m, /Объединить с/);
      await clickAction(m, /^Европа/);
      await ctx.shot(m, 'merge-confirm');
      await clickAction(m, /^Объединить$/);
      await waitDb(`select count(*) from regions where id = '${balkans}'`, '0');
      assert(sql(`select region_id from objects where id = '${uuid(401)}'`) === uuid(901), 'объект не перешёл в «Европа»');
      ctx.notes.push('«Балканы» объединён с «Европа», объект перешёл');

      // «Весь регион» в заявках: СНГ.
      await home(m, base);
      const pill = m.getByRole('button', { name: /^Объект/ }).first();
      if (await pill.isVisible().catch(() => false)) await pill.click();
      else { await btn(m, /^Фильтры/).click(); await settle(m, 800); await btn(m, /^Объект/).click(); }
      await settle(m, 1000);
      await scrollTo(m, /СНГ/);
      const whole = m.getByRole('button', { name: /Весь регион/ }).or(m.getByText(/Весь регион/));
      const n = await whole.count();
      // «Весь регион» — под заголовком региона; у СНГ — второй по порядку (Европа, СНГ, …).
      let clicked = false;
      for (let i = 0; i < n && !clicked; i++) {
        const el = whole.nth(i);
        const label = (await el.getAttribute('aria-label').catch(() => '')) ?? '';
        if (/СНГ/.test(label)) { await el.click(); clicked = true; }
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
      assert(+shown === all, `фильтр «Весь регион СНГ»: на экране ${shown}, заявок региона в базе ${all}`);
      ctx.notes.push(`заявки «Весь регион СНГ»: ${shown} = в базе ${all}`);

      // Отчёты: фильтр «Регион» = СНГ.
      await home(m, base);
      await section(m, /^Отчёты/);
      await see(m, /приняты с первого раза/).waitFor({ timeout: 20000 });
      await btn(m, /^Регион/).click();
      await settle(m, 800);
      await clickAction(m, /^СНГ/);
      const ap = btn(m, /^Применить|^Показать|^Готово/);
      if (await ap.isVisible().catch(() => false)) await ap.click();
      await settle(m, 2500);
      const rt = await screenText(m);
      const orders = +(rt.match(/(\d+)\s*\n?\s*заяв/)?.[1] ?? NaN);
      const dbOrders = +sql(`select count(*) from work_orders w join objects o on o.id = w.object_id
        where w.company_id = '${uuid(1)}' and o.region_id = '${uuid(902)}' and w.created_at >= now() - interval '30 days'`);
      ctx.notes.push(`отчёт по СНГ: заявок ${orders}, в базе за 30 дней ${dbOrders}`);
      assert(orders > 0 && orders <= dbOrders + 1 && !/Европа\s*\n?\s*Заявок/.test(rt), 'отчёт с фильтром «СНГ» неверен');
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
      await clickAction(m, /^СНГ/);
      const ap = btn(m, /^Применить|^Показать|^Готово/);
      if (await ap.isVisible().catch(() => false)) await ap.click();
      await settle(m, 2000);
      const pdf = await capturePdf(m);
      const pages = +(execFileSync('pdfinfo', [pdf], { encoding: 'utf8' }).match(/Pages:\s+(\d+)/)?.[1] ?? 0);
      const text = execFileSync('pdftotext', ['-layout', pdf, '-'], { encoding: 'utf8' });
      ctx.notes.push(`PDF: ${pages} стр., ${Math.round(statSync(pdf).size / 1024)} КБ`);
      assert(pages > 0, 'в PDF нет страниц');
      assert(/СНГ/.test(text), 'в тексте PDF нет фильтра «СНГ»');
      assert(!/Европа|Белград|Дубай/.test(text), 'в PDF по СНГ попали другие регионы');
      assert(/Москва|МосКлимат/.test(text), 'в PDF нет данных региона');
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
      await btn(m, /^БЦ «Демо»/).click();
      await see(m, /Адрес|Этажи/).waitFor({ timeout: 20000 });
      await settle(m, 1500);
      await scrollTo(m, /Импорт из Excel/);
      await btn(m, /Импорт из Excel/).click();
      await settle(m, 1200);
      const csv = join(TMP, 'import.csv');
      writeFileSync(csv, [
        'Название;Помещение;Система;Инвентарный номер;Производитель;Модель;Серийный номер;Дата ввода',
        'Кондиционер №3;Переговорная, 3 этаж;Климат;E2E-001;Daikin;FTXM25R;DK-1;2025-03-01',
        'Светильник;Нет такой комнаты;Электрика;E2E-002;Philips;RC132V;PH-1;2025-03-01',
        'Насос;Кухня, 3 этаж;Лифты;E2E-003;Grundfos;UPS;GR-1;2025-03-01',
        'ИБП;Серверная, 3 этаж;Электрика;E2E-004;APC;SRT;AS-1;2025-13-40',
        'Щит освещения;Холл, 1 этаж;Электрика;E2E-005;ABB;MISTRAL;AB-1;01.02.2024',
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
    title: 'Доступ: администратор задаёт зону «Климат + Сантехника · Москва» → второй менеджер не видит лишнего (списки, карта, отчёты, PDF); бригада «Пекин» не видит Шэньчжэнь',
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
      await scrollTo(a, /Менеджер Москва/);
      await btn(a, /Менеджер Москва/).click();
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
      await scrollTo(a, /Весь город: Москва/);
      await see(a, /Весь город: Москва/).click();
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
      assert(/^city:Москва:Климат\+Сантехника$/.test(zone), `зона сохранилась не так: ${zone}`);

      // Что второму менеджеру видеть нельзя: объекты не в Москве, заявки других систем, чужие подрядчики.
      const ids = (q) => new Set(sql(q).split('\n').filter(Boolean));
      const C = uuid(1);
      const badObjects = ids(`select id from objects where company_id = '${C}' and coalesce(city, '') <> 'Москва'`);
      const badOrders = ids(`select w.id from work_orders w left join layers l on l.id = w.layer_id left join objects o on o.id = w.object_id
        where w.company_id = '${C}' and (coalesce(o.city, '') <> 'Москва' or coalesce(l.name, '') not in ('Климат', 'Сантехника'))
          and w.created_by is distinct from '${m2}'`);
      const okContractors = ids(`select distinct cl.contractor_id from contractor_layers cl join layers l on l.id = cl.layer_id
        left join objects o on o.id = cl.object_id where l.name in ('Климат', 'Сантехника') and (cl.object_id is null or o.city = 'Москва')
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
      for (const w of ['Белград', 'Дубай', 'Пекин', 'Электрика']) assert(!t1.includes(w), `в заявках второго менеджера есть «${w}»`);
      await section(m, /^Локации/);
      const mapBtn = m.getByRole('button', { name: /^Карта/ }).or(m.getByText(/^Карта$/)).first();
      if (await mapBtn.isVisible().catch(() => false)) { await mapBtn.click(); await settle(m, 3000); }
      await ctx.shot(m, 'm2-map');
      await section(m, /^Подрядчики/);
      await ctx.shot(m, 'm2-contractors');
      const t3 = await screenText(m);
      for (const w of ['ЭлектроПро', 'Gulf FM', 'Huaxin']) assert(!t3.includes(w), `в подрядчиках второго менеджера есть «${w}»`);
      await home(m, base);
      await section(m, /^Отчёты/);
      await see(m, /приняты с первого раза/).waitFor({ timeout: 20000 });
      await settle(m, 1500);
      await ctx.shot(m, 'm2-reports');
      const t4 = await screenText(m);
      for (const w of ['Европа', 'Азия', 'ЭлектроПро', 'КлиматСервис']) assert(!t4.includes(w), `в отчётах второго менеджера есть «${w}»`);
      const pdf = await capturePdf(m);
      const text = execFileSync('pdftotext', ['-layout', pdf, '-'], { encoding: 'utf8' });
      for (const w of ['Белград', 'Дубай', 'ЭлектроПро', 'КлиматСервис']) assert(!text.includes(w), `в PDF второго менеджера есть «${w}»`);
      await section(m, /^ППР/);
      await settle(m, 1500);
      const t5 = await screenText(m);
      assert(!/Дубай|Абиджан|БЦ «Демо»/.test(t5), 'в ППР второго менеджера чужие объекты');
      const leaks = [...seen].filter(([id]) => badObjects.has(id) || badOrders.has(id) || badContractors.has(id));
      ctx.notes.push(`ответов сервера: ${seen.size} id, запрещённых: ${leaks.length}`);
      assert(leaks.length === 0, `сервер отдал запрещённое: ${leaks.slice(0, 3).map(([id, t]) => `${t}:${id.slice(-3)}`).join(', ')}`);

      // Бригада «Пекин» Huaxin FM: исполнитель не видит Шэньчжэнь.
      const e = await ctx.page({ width: 412, height: 915 });
      const eSeen = new Set();
      e.on('response', async (r) => {
        if (!r.url().includes('/rest/v1/work_orders')) return;
        try { for (const id of (await r.text()).match(/[0-9a-f-]{36}/g) ?? []) eSeen.add(id); } catch { /* */ }
      });
      await login(e, base, 'beijing@example.com');
      await home(e, base);
      await ctx.shot(e, 'crew-beijing');
      const szOrders = ids(`select w.id from work_orders w join objects o on o.id = w.object_id where o.city = 'Шэньчжэнь'`);
      const bjOrders = ids(`select w.id from work_orders w join objects o on o.id = w.object_id
        where o.city = 'Пекин' and w.assigned_contractor_id = '${uuid(509)}'`);
      const te = await screenText(e);
      assert(!te.includes('Шэньчжэнь'), 'исполнитель бригады «Пекин» видит Шэньчжэнь');
      assert(![...szOrders].some((x) => eSeen.has(x)), 'сервер отдал бригаде «Пекин» заявки Шэньчжэня');
      ctx.notes.push(`бригада «Пекин»: заявок Пекина видно ${[...bjOrders].filter((x) => eSeen.has(x)).length} из ${bjOrders.size}, Шэньчжэня — 0`);
    },
  },
  {
    id: 8,
    title: 'Изоляция компаний: вторая компания с теми же названиями — ни один экран не показывает её данные',
    async run(ctx) {
      const { base } = ctx;
      // В локальной базе две тестовые компании «Демо БЦ» (id c1…/c2…) — с теми же
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
        async () => section(m, /^ППР/),
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
      await section(m, /^ППР/);
      const t1 = await screenText(m);
      assert(/Нужна миграция 0015|миграци/i.test(t1), 'ППР: нет «Нужна миграция 0015»');
      ctx.notes.push('ППР: «Нужна миграция 0015»');
      await ctx.shot(m, 'ppr');
      await home(m, base);
      await section(m, /^Локации/);
      await check('Локации');
      await btn(m, /^БЦ «Демо»/).click();
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
];
