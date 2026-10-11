// Сквозные сценарии на локальной базе (шаг 18). Запуск — tools/e2e/run.sh.
//   node e2e.mjs [--only=1,3] [--shots]   (--shots — снимок после каждого шага)
// Итоги — tools/e2e/out/results.json и results.md (таблица для отчёта).
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { startLocalBackend } from '../screens/local_backend.mjs';
import { DB, chromium, startWeb } from './lib.mjs';
import { SCENARIOS } from './scenarios.mjs';

const OUT = join(import.meta.dirname, 'out');
const ONLY = process.argv.find((a) => a.startsWith('--only='))?.slice(7).split(',');
const SHOTS = process.argv.includes('--shots');
// --keep — дописать итоги к прошлому запуску (run.sh: сценарий 9 на базе hh_old).
if (!process.argv.includes('--keep')) rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
const OLD = DB === 'hh_old';

process.env.HH_MOCK_AI = '1';
const backend = await startLocalBackend({ port: 54321 });
const web = await startWeb();
const browser = await chromium.launch({ args: ['--disable-dev-shm-usage'] }); // /dev/shm в контейнере — 64 МБ
const results = [];

for (const s of SCENARIOS) {
  if (ONLY && !ONLY.includes(String(s.id))) continue;
  if ((s.db === 'hh_old') !== OLD) continue;
  const t0 = Date.now();
  const contexts = [];
  let shot = 0;
  const errors = [];
  const ctx = {
    base: web.base,
    async page({ width = 1280, height = 800, geo, locale = 'ru-RU' } = {}) {
      const c = await browser.newContext({ viewport: { width, height }, locale, deviceScaleFactor: 1,
        ...(geo ? { geolocation: geo, permissions: ['geolocation'] } : {}) });
      await c.addInitScript(() => {
        const orig = URL.createObjectURL;
        URL.createObjectURL = function (obj) {
          try { if (obj && obj.type === 'application/pdf') window.__pdfBlob = obj; } catch {}
          return orig.call(URL, obj);
        };
        window.print = () => {};
      });
      contexts.push(c);
      const p = await c.newPage();
      p.on('pageerror', (e) => errors.push(String(e.message).slice(0, 200)));
      return p;
    },
    async shot(page, name) {
      if (SHOTS) await page.screenshot({ path: join(OUT, `${s.id}-${String(++shot).padStart(2, '0')}-${name}.png`) });
    },
    notes: [],
    errors,
  };
  let ok = true;
  let err = '';
  try {
    await s.run(ctx);
  } catch (e) {
    ok = false;
    err = String(e.message).split('\n')[0].slice(0, 300);
    for (const c of contexts) {
      for (const p of c.pages()) {
        await p.screenshot({ path: join(OUT, `${s.id}-fail-${contexts.indexOf(c)}.png`) }).catch(() => {});
      }
    }
  }
  for (const c of contexts) await c.close().catch(() => {});
  if (errors.length) ctx.notes.push('JS: ' + [...new Set(errors)].join(' | ').slice(0, 300));
  const r = { id: s.id, title: s.title, ok, error: err, notes: ctx.notes, sec: Math.round((Date.now() - t0) / 1000) };
  results.push(r);
  console.log(`${ok ? '✅' : '❌'} ${s.id}. ${s.title} (${r.sec} с)${err ? ' — ' + err : ''}`);
  for (const n of ctx.notes) console.log(`     ${n}`);
}

await browser.close();
web.stop();
backend.stop();
const prev = process.argv.includes('--keep') && existsSync(join(OUT, 'results.json'))
  ? JSON.parse(readFileSync(join(OUT, 'results.json'), 'utf8')) : [];
results.unshift(...prev.filter((p) => !results.some((r) => r.id === p.id)));
results.sort((a, b) => a.id - b.id);
writeFileSync(join(OUT, 'results.json'), JSON.stringify(results, null, 2));
writeFileSync(join(OUT, 'results.md'), [
  '| № | Сценарий | Итог | Время | Примечание |', '|---|---|---|---|---|',
  ...results.map((r) => `| ${r.id} | ${r.title} | ${r.ok ? '✅ прошёл' : '❌ не прошёл'} | ${r.sec} с | ${[r.error, ...r.notes].filter(Boolean).join('; ')} |`),
].join('\n') + '\n');
const failed = results.filter((r) => !r.ok).length;
console.log(`Итого: ${results.length - failed} из ${results.length} прошли`);
process.exit(failed ? 1 : 0);
