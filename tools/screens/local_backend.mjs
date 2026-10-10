// Локальный «Supabase» для снимков новых экранов, пока миграция не применена
// в рабочей базе (шаг 16+). Ничего не трогает в рабочей базе.
//
// Что внутри:
//   • база — локальный PostgreSQL `hh_test` после `bash tools/db_test/run.sh`:
//     все миграции (включая новую), заглушки auth/storage и демо-данные
//     (demo.sql + demo_history.sql, пользователи manager@ / executor@ /
//     requester@example.com);
//   • /rest/v1/* — PostgREST (бинарник — переменная POSTGREST, по умолчанию
//     `postgrest` из PATH), права — те же политики RLS, что в рабочей базе;
//   • /auth/v1/* — вход по email без пароля: токен JWT (HS256) на локальном
//     секрете, роль authenticated, sub — id пользователя из auth.users;
//   • /storage/v1/* — картинки планов: этажам демо в локальной базе
//     прописывается plan_path = preview/<файл>, файл отдаётся из
//     assets/demo_plans (это ДЕМО-СХЕМЫ, не реальные планы);
//   • /functions/v1/* — 503 (голосовой разбор уходит в словарь).
//
// Запуск: node local_backend.mjs [--port=54321]
// Печатает адрес и анонимный ключ для сборки:
//   flutter build web --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
// Импорт: startLocalBackend({ port }) → { url, anonKey, stop() }.
import { createServer, request as httpRequest } from 'node:http';
import { spawn, execFileSync } from 'node:child_process';
import { createHmac } from 'node:crypto';
import { readFileSync, existsSync, writeFileSync, mkdtempSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const HERE = import.meta.dirname;
const ROOT = resolve(HERE, '../..');
const DB = process.env.HH_TEST_DB ?? 'hh_test';
// Подпись токенов только для локальной базы на этой машине (не ключ Supabase):
// постоянная, чтобы анонимный ключ в собранной веб-версии не устаревал.
const SECRET = process.env.HH_LOCAL_JWT_SECRET ?? 'hey-helpy-local-backend-for-screens-only-0001';

const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
export function signJwt(payload, secret = SECRET) {
  const head = b64({ alg: 'HS256', typ: 'JWT' });
  const body = b64(payload);
  const sig = createHmac('sha256', secret).update(`${head}.${body}`).digest('base64url');
  return `${head}.${body}.${sig}`;
}
function readJwt(token) {
  try {
    const [h, b, s] = token.split('.');
    const sig = createHmac('sha256', SECRET).update(`${h}.${b}`).digest('base64url');
    if (sig !== s) return null;
    return JSON.parse(Buffer.from(b, 'base64url').toString());
  } catch {
    return null;
  }
}

function psql(sql) {
  return execFileSync('sudo', ['-u', 'postgres', 'psql', '-X', '-At', '-d', DB, '-c', sql],
    { encoding: 'utf8' }).trim();
}

/** Пользователи локальной базы: email → id. */
function users() {
  const out = {};
  for (const line of psql('select lower(email) || \'|\' || id from auth.users where email is not null').split('\n')) {
    const [email, id] = line.split('|');
    if (email && id) out[email] = id;
  }
  return out;
}

function sessionFor(id, email) {
  const now = Math.floor(Date.now() / 1000);
  const user = {
    id, aud: 'authenticated', role: 'authenticated', email,
    app_metadata: { provider: 'email', providers: ['email'] }, user_metadata: {},
    created_at: '2026-10-01T00:00:00Z', updated_at: '2026-10-01T00:00:00Z',
    email_confirmed_at: '2026-10-01T00:00:00Z', identities: [],
  };
  const access = signJwt({ sub: id, email, role: 'authenticated', aud: 'authenticated',
    iat: now, exp: now + 3600, session_id: id });
  return { access_token: access, token_type: 'bearer', expires_in: 3600, expires_at: now + 3600,
    refresh_token: `r.${id}.${email}`, user };
}

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': '*',
  'access-control-allow-methods': 'GET,POST,PATCH,PUT,DELETE,OPTIONS,HEAD',
  'access-control-expose-headers': 'content-range, content-profile, x-client-info',
};

function send(res, status, body, headers = {}) {
  res.writeHead(status, { ...CORS, 'content-type': 'application/json', ...headers });
  res.end(body == null ? '' : (typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body)));
}

async function readBody(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  return Buffer.concat(chunks);
}

/** Этажам демо — картинки ДЕМО-СХЕМ (только в локальной базе). */
function linkDemoPlans() {
  const plans = JSON.parse(readFileSync(join(ROOT, 'tools/demo_plans/plans.json'), 'utf8'));
  for (const f of plans.floors) {
    const id = `de300000-0000-4000-8000-${String(f.id).padStart(12, '0')}`;
    psql(`update public.floors set plan_path = 'preview/${f.file}', plan_w = ${plans.width}, plan_h = ${plans.height} where id = '${id}'`);
  }
}

export async function startLocalBackend({ port = 54321, postgrest = process.env.POSTGREST ?? 'postgrest' } = {}) {
  linkDemoPlans();
  const pgPort = port + 1;
  const dir = mkdtempSync(join(tmpdir(), 'hh-postgrest-'));
  const conf = join(dir, 'postgrest.conf');
  writeFileSync(conf, [
    `db-uri = "postgres://authenticator:local-only@127.0.0.1:5432/${DB}"`,
    'db-schemas = "public"',
    'db-anon-role = "anon"',
    `jwt-secret = "${SECRET}"`,
    `server-port = ${pgPort}`,
    'server-host = "127.0.0.1"',
    'db-max-rows = 1000',
    'log-level = "error"',
  ].join('\n'));
  const pg = spawn(postgrest, [conf], { stdio: ['ignore', 'inherit', 'inherit'] });
  // Ждём, пока PostgREST поднимется.
  for (let i = 0; i < 50; i++) {
    const ok = await new Promise((done) => {
      const r = httpRequest({ host: '127.0.0.1', port: pgPort, path: '/', method: 'HEAD' },
        (x) => { x.resume(); done(true); });
      r.on('error', () => done(false));
      r.end();
    });
    if (ok) break;
    await new Promise((d) => setTimeout(d, 200));
  }

  const server = createServer(async (req, res) => {
    const url = new URL(req.url, 'http://x');
    const path = url.pathname;
    // Предзапрос CORS: «*» в allow-headers не покрывает Authorization —
    // разрешаем ровно те заголовки, что просит браузер.
    if (req.method === 'OPTIONS') {
      return send(res, 204, null, {
        'access-control-allow-headers': req.headers['access-control-request-headers'] ?? '*',
      });
    }

    if (path.startsWith('/rest/v1/')) {
      const body = await readBody(req);
      const headers = { ...req.headers };
      delete headers.host;
      delete headers.apikey;
      const up = httpRequest({ host: '127.0.0.1', port: pgPort, method: req.method,
        path: path.slice('/rest/v1'.length) + url.search, headers }, (x) => {
        res.writeHead(x.statusCode, { ...x.headers, ...CORS });
        x.pipe(res);
      });
      up.on('error', (e) => send(res, 502, { message: String(e) }));
      up.end(body);
      return;
    }

    if (path.startsWith('/auth/v1/')) {
      const op = path.slice('/auth/v1/'.length);
      if (op === 'token' && req.method === 'POST') {
        const b = JSON.parse((await readBody(req)).toString() || '{}');
        if (url.searchParams.get('grant_type') === 'refresh_token') {
          const [, id, email] = String(b.refresh_token ?? '').split('.');
          if (!id) return send(res, 400, { error: 'invalid_grant', error_description: 'Invalid Refresh Token' });
          return send(res, 200, sessionFor(id, email));
        }
        const email = String(b.email ?? '').toLowerCase();
        const id = users()[email];
        if (!id) return send(res, 400, { error: 'invalid_grant', error_description: 'Invalid login credentials', code: 'invalid_credentials' });
        return send(res, 200, sessionFor(id, email));
      }
      if (op === 'user') {
        const t = (req.headers.authorization ?? '').replace(/^Bearer /, '');
        const p = readJwt(t);
        if (!p?.sub) return send(res, 401, { message: 'invalid token' });
        return send(res, 200, sessionFor(p.sub, p.email).user);
      }
      if (op === 'logout') return send(res, 204, null);
      return send(res, 404, { message: 'not supported locally' });
    }

    if (path.startsWith('/storage/v1/')) {
      const m = path.match(/floor-plans\/(preview\/[\w.-]+\.png)$/);
      if (m && path.includes('/object/sign/') && req.method === 'POST') {
        return send(res, 200, { signedURL: `/object/sign/floor-plans/${m[1]}?token=local` });
      }
      if (m && (req.method === 'GET' || req.method === 'HEAD')) {
        const file = join(ROOT, 'assets/demo_plans', m[1].slice('preview/'.length));
        if (existsSync(file)) {
          res.writeHead(200, { ...CORS, 'content-type': 'image/png' });
          return res.end(req.method === 'HEAD' ? undefined : readFileSync(file));
        }
      }
      return send(res, 404, { statusCode: '404', error: 'not_found', message: 'Object not found' });
    }

    if (path.startsWith('/functions/v1/')) {
      return send(res, 503, { error: 'ai_unavailable' });
    }
    return send(res, 404, { message: 'not found' });
  });
  await new Promise((ok) => server.listen(port, '127.0.0.1', ok));
  const anonKey = signJwt({ role: 'anon', iss: 'local', iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 86400 });
  return {
    url: `http://127.0.0.1:${port}`,
    anonKey,
    stop: () => { server.close(); pg.kill(); },
  };
}

if (process.argv[1] === import.meta.filename) {
  const port = +(process.argv.find((a) => a.startsWith('--port='))?.split('=')[1] ?? 54321);
  const b = await startLocalBackend({ port });
  console.log(`URL=${b.url}`);
  console.log(`ANON_KEY=${b.anonKey}`);
}
