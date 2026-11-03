// Шаг 34: сквозная проверка теста распознавания на ЛОКАЛЬНОЙ базе — без
// рабочей базы и без настоящего ИИ.
//
//   bash tools/db_test/run.sh             # база hh_test с 0028 и демо-данными
//   POSTGREST=<postgrest> node tools/e2e/recognition_eval.mjs [--keep]
//
// Что запускается: локальный «Supabase» (tools/screens/local_backend.mjs:
// PostgREST + вход + хранилище), заглушка ИИ (OpenAI-совместимый
// /v1/chat/completions, ответ зависит от снимка — не «умный», только чтобы
// пройти путь целиком) и НАСТОЯЩАЯ функция supabase/functions/recognition-eval
// (deno). Сценарий: администратор создаёт набор, загружает фото с разметкой,
// база раскладывает dev / test по единицам, заморозка, прогоны dev и test
// через функцию, отчёт; цифры функции сверяются с независимым подсчётом по
// таблице результатов. Плюс проверки прав: исполнитель и чужие вызовы.
// Итог — tools/e2e/out/recognition_eval.md. Цифры точности здесь — заглушка,
// а не замер.
//
// --keep — не останавливать сервисы (для снимков экранов приложения):
// HH_EVAL_FN_URL уже направлен на функцию.

import { spawn, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '../..');
const FN_PORT = 54391;
const AI_PORT = 54390;
process.env.HH_EVAL_FN_URL = `http://127.0.0.1:${FN_PORT}`;
const { startLocalBackend, signJwt } = await import('../screens/local_backend.mjs');

const DB = process.env.HH_DB ?? 'hh_test';
const psql = (sql) => execFileSync('sudo', ['-u', 'postgres', 'psql', '-X', '-At', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', sql],
  { encoding: 'utf8' }).trim();

const id = (n) => `de300000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const COMPANY = id(1);
const SITE = id(10);
const ROOMS = { meeting: id(21), director: id(54), hall: id(24), server: id(55) };

// Демо-менеджер — администратор (только в локальной базе), исполнитель — для проверки прав.
const admin = psql(`select id from auth.users where email = 'manager@example.com'`);
const executor = psql(`select id from auth.users where email = 'executor@example.com'`);
psql(`update public.profiles set role = 'admin' where id = '${admin}'`);
psql(`grant service_role to authenticator`);
psql(`delete from public.recognition_eval_sets where company_id = '${COMPANY}'`);

const now = Math.floor(Date.now() / 1000);
const tok = (sub, email) => signJwt({ sub, email, role: 'authenticated', aud: 'authenticated', iat: now, exp: now + 7200 });
const ADMIN = tok(admin, 'manager@example.com');
const EXEC = tok(executor, 'executor@example.com');
const SERVICE = signJwt({ role: 'service_role', iss: 'local', iat: now, exp: now + 7200 });

// --- заглушка ИИ ------------------------------------------------------------
const KINDS = ['ac', 'ac', 'ac', 'ac', 'ac', 'ac', 'smoke', 'fancoil', 'light', 'other'];
let aiCalls = 0;
const ai = createServer(async (req, res) => {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const body = JSON.parse(Buffer.concat(chunks).toString() || '{}');
  aiCalls++;
  const img = JSON.stringify(body.messages ?? '').match(/base64,([A-Za-z0-9+/=]+)/)?.[1] ?? '';
  const h = createHash('sha256').update(img).digest();
  const content = JSON.stringify({
    equipment: true, kind: KINDS[h[0] % KINDS.length], layer: null, nameplate: null, defect: null,
    confidence: 0.6 + (h[1] % 40) / 100,
  });
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ choices: [{ message: { content } }], usage: { total_tokens: 900 + (h[2] % 200) } }));
});
await new Promise((ok) => ai.listen(AI_PORT, '127.0.0.1', ok));

// --- локальный Supabase и функция --------------------------------------------
const backend = await startLocalBackend({ port: 54321 });
const fn = spawn('deno', ['run', '-A', join(ROOT, 'supabase/functions/recognition-eval/index.ts')], {
  env: {
    ...process.env,
    DENO_SERVE_ADDRESS: `tcp:127.0.0.1:${FN_PORT}`,
    SUPABASE_URL: backend.url,
    SUPABASE_ANON_KEY: backend.anonKey,
    SUPABASE_SERVICE_ROLE_KEY: SERVICE,
    AI_BASE_URL: `http://127.0.0.1:${AI_PORT}/v1`,
    AI_API_KEY: 'local-mock',
    AI_MODEL_VISION: 'mock-vision',
  },
  stdio: ['ignore', 'ignore', 'inherit'],
});
for (let i = 0; i < 100; i++) {
  const ok = await fetch(`http://127.0.0.1:${FN_PORT}`, { method: 'OPTIONS' }).then(() => true, () => false);
  if (ok) break;
  await new Promise((d) => setTimeout(d, 200));
}

const checks = [];
const check = (ok, msg) => { checks.push({ ok: !!ok, msg }); console.log(`${ok ? '✅' : '❌'} ${msg}`); };

const rest = async (token, path, { method = 'GET', body, prefer } = {}) => {
  const r = await fetch(`${backend.url}/rest/v1/${path}`, {
    method,
    headers: { apikey: backend.anonKey, authorization: `Bearer ${token}`, 'content-type': 'application/json',
      ...(prefer ? { prefer } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await r.text();
  return { status: r.status, data: text ? JSON.parse(text) : null };
};
const call = async (token, body) => {
  const r = await fetch(`${backend.url}/functions/v1/recognition-eval`, {
    method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: r.status, data: await r.json().catch(() => null) };
};

try {
  // Поставщики.
  const prov = await call(ADMIN, { action: 'providers' });
  check(prov.status === 200 && prov.data.providers?.[0]?.model === 'mock-vision', `поставщики: ${JSON.stringify(prov.data)}`);
  check(!JSON.stringify(prov.data).includes('local-mock'), 'ключ ИИ не уходит в приложение');
  const denied = await call(EXEC, { action: 'providers' });
  check(denied.status === 404, `исполнителю раздел не отвечает (${denied.status})`);

  // Набор и фото.
  const set = (await rest(ADMIN, 'recognition_eval_sets?select=*', { method: 'POST', prefer: 'return=representation',
    body: { company_id: COMPANY, name: 'E2E set', created_by: admin } })).data[0];
  check(set?.id, 'администратор создаёт набор');
  const units = [
    [708, 'meeting'], [737, 'meeting'], [709, 'meeting'], [736, 'director'], [710, 'director'],
    [703, 'hall'], [704, 'hall'], [705, 'hall'], [713, 'server'], [711, 'server'],
  ];
  const base = readFileSync(join(ROOT, 'assets/demo_photos/ac_indoor.jpg'));
  const conds = [['good', 'close', 'front'], ['dim', 'medium', 'side'], ['backlight', 'far', 'front']];
  let n = 0;
  const upload = async (unit, room, k, series) => {
    // Разные байты после конца JPEG — у заглушки ИИ разные «снимки».
    const jpeg = Buffer.concat([base, Buffer.from(`#${unit}-${k}-${n++}`)]);
    const path = `${COMPANY}/${set.id}/${crypto.randomUUID()}.jpg`;
    const up = await fetch(`${backend.url}/storage/v1/object/eval-photos/${path}`, {
      method: 'POST', headers: { authorization: `Bearer ${ADMIN}`, 'content-type': 'image/jpeg' }, body: jpeg });
    if (!up.ok) throw new Error(`upload ${up.status}`);
    const [light, distance, angle] = conds[k % 3];
    const r = await rest(ADMIN, 'recognition_eval_samples?select=*', { method: 'POST', prefer: 'return=representation',
      body: { set_id: set.id, company_id: COMPANY, created_by: admin, photo_path: path, site_id: SITE, room_id: ROOMS[room],
        true_equipment_id: unit ? id(unit) : null, true_is_unregistered: !unit, series_id: series, light, distance, angle,
        occlusion: k === 2, split: 'test' } });
    if (r.status >= 300) throw new Error(`sample ${r.status} ${JSON.stringify(r.data)}`);
    return r.data[0];
  };
  for (const [u, room] of units) for (let k = 0; k < 3; k++) await upload(u, room, k, null);
  for (let s = 0; s < 4; s++) {
    const series = crypto.randomUUID();
    for (let k = 0; k < 2; k++) await upload(null, ['meeting', 'hall', 'director', 'server'][s], k, series);
  }
  const samples = (await rest(ADMIN, `recognition_eval_samples?set_id=eq.${set.id}&select=*`)).data;
  check(samples.length === 38, `38 фото в наборе (${samples.length})`);
  const leak = new Map();
  for (const s of samples) {
    const key = s.true_equipment_id ?? s.series_id;
    leak.set(key, (leak.get(key) ?? new Set()).add(s.split));
  }
  check([...leak.values()].every((x) => x.size === 1), 'все фото одной единицы (серии) — в одном наборе');
  const devUnits = units.filter(([u]) => samples.find((s) => s.true_equipment_id === id(u))?.split === 'dev').length;
  check(devUnits >= 2 && devUnits <= 4, `dev — около 30 % единиц: ${devUnits} из ${units.length}`);
  check(samples.some((s) => s.true_is_unregistered && s.split === 'test') && samples.some((s) => s.true_is_unregistered && s.split === 'dev'),
    '«нет в реестре» — и в dev, и в test');
  check(samples.filter((s) => s.room_id === ROOMS.director && s.true_kind === 'ac').every((s) => s.similar_in_room === 1),
    'снимок «похожих в помещении» посчитан базой');

  // Прогон test до заморозки — нельзя; заморозка; прогоны.
  const early = await rest(ADMIN, 'rpc/recognition_eval_run_start', { method: 'POST', body: { p_set: set.id, p_split: 'test', p_provider: 'default' } });
  check(early.status >= 400, `test до заморозки не запускается (${early.status})`);
  const fr = await rest(ADMIN, 'rpc/recognition_eval_freeze', { method: 'POST', body: { p_set: set.id } });
  check(fr.status === 200, 'заморозка');
  const add = await upload(708, 'meeting', 0, null).then(() => 'ok', (e) => String(e));
  check(add !== 'ok', 'после заморозки фото не добавить');

  const forged = await rest(ADMIN, 'rpc/recognition_eval_put_result', { method: 'POST', body: {
    p_user: admin, p_run: set.id, p_sample: samples[0].id, p_provider: 'openai', p_model: 'x', p_prompt_hash: 'a'.repeat(64), p_result: {} } });
  check(forged.status >= 400, `записать результат из приложения нельзя (${forged.status})`);

  const reports = {};
  for (const split of ['dev', 'test']) {
    const run = (await rest(ADMIN, 'rpc/recognition_eval_run_start', { method: 'POST', body: { p_set: set.id, p_split: split, p_provider: 'default' } })).data;
    const ids = samples.filter((s) => s.split === split).map((s) => s.id);
    const started = Date.now();
    const queue = [...ids];
    const statuses = [];
    await Promise.all([0, 1, 2].map(async () => {
      while (queue.length) {
        const r = await call(ADMIN, { action: 'run', runId: run, sampleId: queue.shift() });
        statuses.push(r.status === 200 && r.data.ok ? 'ok' : `${r.status}:${JSON.stringify(r.data).slice(0, 80)}`);
      }
    }));
    check(statuses.every((s) => s === 'ok'), `${split}: ${ids.length} фото распознаны функцией за ${Math.round((Date.now() - started) / 1000)} с`);
    const again = await call(ADMIN, { action: 'run', runId: run, sampleId: ids[0] });
    check(again.data?.skipped === true, `${split}: повтор того же фото не перезаписывает ответ`);
    const execRun = await call(EXEC, { action: 'run', runId: run, sampleId: ids[0] });
    check(execRun.status === 404, `${split}: исполнитель не запускает (${execRun.status})`);
    const fin = await rest(ADMIN, 'rpc/recognition_eval_run_finish', { method: 'POST', body: { p_run: run, p_cancel: false } });
    check(fin.data === 'done', `${split}: прогон закрыт (${JSON.stringify(fin.data)})`);
    const rep = await call(ADMIN, { action: 'report', runId: run });
    reports[split] = rep.data;
    const m = rep.data.metrics;
    // Независимый подсчёт Top-1 по таблице результатов.
    const top1 = psql(`select count(*) filter (where r.predicted_equipment_id = s.true_equipment_id and r.error is null and not r.abstained) || '/' || count(*)
      from recognition_eval_samples s join recognition_eval_results r on r.sample_id = s.id
      where r.run_id = '${run}' and s.true_equipment_id is not null`);
    check(`${m.top1.k}/${m.top1.n}` === top1, `${split}: Top-1 функции ${m.top1.k}/${m.top1.n} = подсчёт по базе ${top1}`);
    check(m.photos === ids.length && m.results === ids.length && m.missing === 0, `${split}: в отчёте ${m.photos} фото, ответов ${m.results}`);
    check(/^Top-1: \d+\.\d% \(95% CI \d+\.\d–\d+\.\d%\), n = \d+ photos, \d+ units, \d+ rooms, \d+ sites$/.test(rep.data.headline), `${split}: ${rep.data.headline}`);
    const runRow = (await rest(ADMIN, `recognition_eval_runs?id=eq.${run}&select=provider,model_vision,prompt_hash`)).data[0];
    check(runRow.provider === 'openai' && runRow.model_vision === 'mock-vision' && /^[0-9a-f]{64}$/.test(runRow.prompt_hash),
      `${split}: прогон записал поставщика, модель и хеш подсказки`);
  }
  const tm = reports.test.metrics;
  const lines = [
    '# Тест распознавания — локальная сквозная проверка (шаг 34)',
    '',
    `Запуск: ${new Date().toISOString()}. База \`${DB}\` (локально), функция \`recognition-eval\` (deno), ИИ — **заглушка** (${aiCalls} вызовов).`,
    'Цифры ниже — НЕ замер точности: заглушка отвечает по хешу снимка. Проверяется только путь «фото → функция → результаты → отчёт».',
    '',
    `| | Итог |`, `|---|---|`,
    ...checks.map((c) => `| ${c.ok ? '✅' : '❌'} | ${c.msg.replaceAll('|', '\\|')} |`),
    '',
    `Отчёт test (заглушка): ${reports.test.headline}; пороги: ${tm.thresholds.map((t) => `${t.threshold}: ${t.coverage.k}/${t.coverage.n}`).join(', ')}.`,
  ];
  const out = join(ROOT, 'tools/e2e/out/recognition_eval.md');
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, lines.join('\n') + '\n');
  console.log(`\n${checks.filter((c) => c.ok).length} из ${checks.length} ✓ → ${out}`);
} finally {
  if (!process.argv.includes('--keep')) {
    fn.kill();
    ai.close();
    backend.stop();
  } else {
    console.log(`KEEP: backend ${backend.url}, anon ${backend.anonKey}`);
  }
}
process.exitCode = checks.every((c) => c.ok) ? 0 : 1;
