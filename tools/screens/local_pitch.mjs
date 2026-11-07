// Кадры питча на ЛОКАЛЬНОЙ базе (шаг 25) — когда в рабочей базе ещё нет
// нужных демо-данных (до Refresh demo) или их туда не положить (документ
// заявки). Локальная база hh_test (tools/db_test/run.sh) + PostgREST +
// заглушки входа и хранилища (local_backend.mjs), сборка build/web_e2e
// (tools/e2e/build.sh: VOICE_MOCK — камера и ответ ИИ — заглушки).
//   POSTGREST=<путь> PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node local_pitch.mjs [--only=21,24]
// Снимки — docs/screens/pitch/<кадр>.png (перезаписываются). Только
// нарисованные картинки и сгенерированный PDF, без реальных фото и документов.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { startLocalBackend } from './local_backend.mjs';
import { EN_INIT, englishPage } from './en_ui.mjs';
import { ROOT, USERS, btn, chromium, home, login, scrollTo, see, settle, sql, startWeb, uuid } from '../e2e/lib.mjs';

const OUT = join(ROOT, 'docs/screens/pitch');
const ONLY = process.argv.find((a) => a.startsWith('--only='))?.slice(7).split(',');
const TMP = mkdtempSync(join(tmpdir(), 'hh-pitch-'));

async function phone(browser) {
  // Шаг 35b: кадры питча — на английском (интерфейс и демо-данные).
  const ctx = await browser.newContext({ viewport: { width: 412, height: 915 }, locale: 'en-US', deviceScaleFactor: 2 });
  await ctx.addInitScript(EN_INIT);
  // PDF плаката: запомнить Blob для окна печати, само окно не открывать.
  await ctx.addInitScript(() => {
    const orig = URL.createObjectURL;
    URL.createObjectURL = function (obj) {
      try { if (obj && obj.type === 'application/pdf') window.__pdfBlob = obj; } catch {}
      return orig.call(URL, obj);
    };
    window.print = () => {};
  });
  const page = englishPage(await ctx.newPage());
  await login(page, web.base, USERS.admin);
  return page;
}

/** «Где я» запоминается на устройстве: переговорная 301 «Demo Tower». */
async function hereMeetingRoom(page) {
  const uid = sql(`select id from auth.users where email = '${USERS.admin}'`);
  await page.evaluate(([k, v]) => localStorage.setItem(k, JSON.stringify(v)),
    [`flutter.photo_here_v1_${uid}`, `${uuid(10)}|${uuid(21)}`]);
}

const FRAMES = [
  // Шаг 35b: плакат A4 с QR объекта «Demo Tower» (PDF из приложения → PNG 150 dpi, как прежний кадр).
  {
    file: '19-telegram-qr-poster',
    pdf: true,
    async run(page) {
      await home(page, web.base);
      await page.getByRole('button', { name: /^Локации/ }).or(page.getByRole('tab', { name: /^Локации/ }))
        .or(page.getByText(/^Локации$/)).first().click();
      await settle(page, 2000);
      const list = page.getByRole('button', { name: /^Список/ }).or(page.getByText(/^Список$/)).first();
      if (await list.isVisible().catch(() => false)) await list.click();
      await settle(page, 1500);
      await btn(page, /^Demo Tower/).click();
      await settle(page, 2500);
      await scrollTo(page, /Заявки через Telegram/);
      await btn(page, /^Заявки через Telegram/).click();
      await settle(page, 2500);
      const create = btn(page, /^Создать ссылку и QR-код/);
      if (await create.isVisible().catch(() => false)) { await create.click(); await settle(page, 2500); }
      await btn(page, /^Плакат для печати \(PDF\)/).click();
      for (let i = 0; i < 120 && !(await page.evaluate(() => !!window.__pdfBlob)); i++) await page.waitForTimeout(500);
      const b64 = await page.evaluate(async () => {
        const blob = window.__pdfBlob;
        if (!blob) return null;
        const buf = new Uint8Array(await blob.arrayBuffer());
        let s = '';
        for (let i = 0; i < buf.length; i += 0x8000) s += String.fromCharCode(...buf.subarray(i, i + 0x8000));
        return btoa(s);
      });
      if (!b64) throw new Error('PDF плаката не получен');
      const pdf = join(TMP, 'poster.pdf');
      writeFileSync(pdf, Buffer.from(b64, 'base64'));
      execFileSync('pdftoppm', ['-png', '-r', '150', '-f', '1', '-l', '1', '-singlefile', pdf, join(OUT, '19-telegram-qr-poster')]);
    },
  },
  {
    file: '21-camera-card-phone',
    async run(page) {
      await hereMeetingRoom(page);
      await home(page, web.base);
      await btn(page, /Узнать оборудование по фото/).click();
      await btn(page, /^Что это\?/).waitFor({ timeout: 30000 });
      await see(page, /Meeting room/).waitFor({ timeout: 15000 });
      await settle(page, 1000);
      await btn(page, /^Что это\?/).click();
      await see(page, /AC-301 · \d+ %/).waitFor({ timeout: 30000 });
      await see(page, /Открытые заявки · 1/).waitFor({ timeout: 20000 });
      await settle(page, 1500);
    },
  },
  {
    file: '24-order-photos-phone',
    async run(page) {
      const id = uuid(111);
      sql(`delete from attachments where work_order_id = '${id}' and kind = 'document'`);
      // Сгенерированный PDF в одну пустую страницу — не реальный документ.
      const f = join(TMP, 'maintenance-certificate.pdf');
      writeFileSync(f, '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n');
      await home(page, web.base);
      await page.evaluate((h) => { location.hash = h; }, `/orders/${id}`);
      await see(page, /Создана/).waitFor({ timeout: 20000 });
      await scrollTo(page, /Прикрепить файл/);
      const chooser = page.waitForEvent('filechooser', { timeout: 15000 });
      await btn(page, /^Прикрепить файл/).click();
      await (await chooser).setFiles(f);
      await see(page, /(Документы|Documents) · 1/i).waitFor({ timeout: 20000 });
      await settle(page, 1000);
      await scrollTo(page, /(Фото|Photos?) · 2/i);
      await see(page, /(Фото|Photos?) · 2/i).scrollIntoViewIfNeeded();
      // «Фото · 2» — у верхнего края: ниже видны «До», «После» и документы.
      const box = await see(page, /(Фото|Photos?) · 2/i).boundingBox();
      await page.mouse.move(206, 500);
      if (box) await page.mouse.wheel(0, box.y - 110);
      await settle(page, 2500);
    },
  },
];

process.env.HH_MOCK_AI = '1';
sql(`update profiles set locale = 'en' where company_id = '${uuid(1)}'`);
const backend = await startLocalBackend({ port: 54321 });
const web = await startWeb();
const browser = await chromium.launch({ args: ['--disable-dev-shm-usage'] });
let failed = 0;
try {
  for (const fr of FRAMES) {
    if (ONLY && !ONLY.some((o) => fr.file.startsWith(o))) continue;
    const page = await phone(browser);
    try {
      await fr.run(page);
      const path = join(OUT, `${fr.file}.png`);
      if (!fr.pdf) await page.screenshot({ path });
      try { execFileSync('pngquant', ['--force', '--skip-if-larger', '--quality=70-95', '--ext', '.png', path]); } catch {}
      console.log(`  ✅ ${fr.file}.png`);
    } catch (e) {
      failed++;
      console.log(`  ❌ ${fr.file}.png: ${String(e.message).split('\n')[0]}`);
    }
    await page.context().close();
  }
} finally {
  await browser.close();
  web.stop();
  backend.stop();
}
process.exit(failed ? 1 : 0);
