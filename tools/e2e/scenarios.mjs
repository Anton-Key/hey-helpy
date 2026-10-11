// Сценарии сквозных тестов. Каждый — отдельный тест: run(ctx) бросает
// исключение, если что-то не так. Проверки — и по экрану, и по базе.
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  USERS, assert, btn, home, login, profileTab, scrollTo, section, see, settle, sql, typeInto, uuid, waitDb,
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
];
