// Edge Function offline-sync (шаг 27): сверка отпечатков фото из очереди
// без сети. Приложение сначала загружает снимки в work-photos, потом
// вызывает функцию со своим JWT:
//   POST { photos: [{ path, sha256 }] } → 200 { results: [{ path, ok }] }
//   400 bad_request · 401 unauthorized · 500 not_configured
//
// • Файл скачивается ПОД RLS пользователя (видит ли он его — решает база),
//   SHA-256 считается здесь, по настоящим байтам.
// • service_role — ТОЛЬКО offline_photo_hash_put (0024): записать отпечаток,
//   посчитанный сервером. Потом offline_sync сверяет его с отпечатком,
//   который телефон посчитал в момент съёмки: не совпало — фото отклоняется.
// • В лог — число фото, время, совпадения; пути и фото — нет.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { corsHeaders, logFn } from "../_shared/http.ts";
import { parseInput, sha256Hex } from "./verify.ts";

const log = logFn("offline-sync");
const MAX_BYTES = 10 * 1024 * 1024;

Deno.serve(async (req) => {
  const started = Date.now();
  const cors = corsHeaders(req.headers.get("Origin"));
  const reply = (status: number, body: unknown, extra: Record<string, unknown> = {}) => {
    log({ status, ms: Date.now() - started, ...extra });
    return new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
    });
  };
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return reply(401, { error: "unauthorized" }, { code: "no_token" });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return reply(500, { error: "not_configured" }, { code: "not_configured" });

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "bad_request" }, { code: "bad_json" });
  }
  const photos = parseInput(body);
  if (!photos) return reply(400, { error: "bad_request" }, { code: "bad_input" });

  const user = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: u, error: ue } = await user.auth.getUser(jwt);
  if (ue || !u?.user) return reply(401, { error: "unauthorized" }, { code: "no_user" });
  const service = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  const results: { path: string; ok: boolean | null }[] = [];
  let matched = 0, mismatched = 0, missing = 0;
  for (const p of photos) {
    const { data, error } = await user.storage.from("work-photos").download(p.path);
    if (error || !data || data.size > MAX_BYTES) {
      missing++;
      results.push({ path: p.path, ok: null });
      continue;
    }
    const hash = await sha256Hex(new Uint8Array(await data.arrayBuffer()));
    const { error: pe } = await service.rpc("offline_photo_hash_put", { p_path: p.path, p_sha256: hash });
    if (pe) {
      missing++;
      results.push({ path: p.path, ok: null });
      continue;
    }
    const ok = hash === p.sha256;
    if (ok) matched++;
    else mismatched++;
    results.push({ path: p.path, ok });
  }
  return reply(200, { results }, { photos: photos.length, matched, mismatched, missing });
});
