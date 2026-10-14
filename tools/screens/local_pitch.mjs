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
import { ROOT, USERS, btn, chromium, home, login, scrollTo, see, settle, sql, startWeb, uuid } from '../e2e/lib.mjs';

const OUT = join(ROOT, 'docs/screens/pitch');
const ONLY = process.argv.find((a) => a.startsWith('--only='))?.slice(7).split(',');
const TMP = mkdtempSync(join(tmpdir(), 'hh-pitch-'));

async function phone(browser) {
  const ctx = await browser.newContext({ viewport: { width: 412, height: 915 }, locale: 'ru-RU', deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  await login(page, web.base, USERS.admin);
  return page;
}

/** «Где я» запоминается на устройстве: переговорная 301 «БЦ «Демо»». */
async function hereMeetingRoom(page) {
  const uid = sql(`select id from auth.users where email = '${USERS.admin}'`);
  await page.evaluate(([k, v]) => localStorage.setItem(k, JSON.stringify(v)),
    [`flutter.photo_here_v1_${uid}`, `${uuid(10)}|${uuid(21)}`]);
}

const FRAMES = [
  {
    file: '21-camera-card-phone',
    async run(page) {
      await hereMeetingRoom(page);
      await home(page, web.base);
      await btn(page, /Узнать оборудование по фото/).click();
      await btn(page, /^Что это\?/).waitFor({ timeout: 30000 });
      await see(page, /Переговорная/).waitFor({ timeout: 15000 });
      await settle(page, 1000);
      await btn(page, /^Что это\?/).click();
      await see(page, /КД-301 · \d+ %/).waitFor({ timeout: 30000 });
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
      const f = join(TMP, 'akt-to-kd.pdf');
      writeFileSync(f, '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n');
      await home(page, web.base);
      await page.evaluate((h) => { location.hash = h; }, `/orders/${id}`);
      await see(page, /Создана/).waitFor({ timeout: 20000 });
      await scrollTo(page, /Прикрепить файл/);
      const chooser = page.waitForEvent('filechooser', { timeout: 15000 });
      await btn(page, /^Прикрепить файл/).click();
      await (await chooser).setFiles(f);
      await see(page, /Документы · 1/).waitFor({ timeout: 20000 });
      await settle(page, 1000);
      await scrollTo(page, /Фото · 2/);
      await see(page, /Фото · 2/).scrollIntoViewIfNeeded();
      // «Фото · 2» — у верхнего края: ниже видны «До», «После» и документы.
      const box = await see(page, /Фото · 2/).boundingBox();
      if (box) await page.mouse.wheel(0, box.y - 110);
      await settle(page, 2500);
    },
  },
];

process.env.HH_MOCK_AI = '1';
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
      await page.screenshot({ path });
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
