// Edge Function recognition-eval: тест точности распознавания (шаг 34).
//
// Вызывает только администратор компании (приложение, «Моя компания» →
// «Тест распознавания»). Распознаёт фото набора ТЕМ ЖЕ путём, что «Узнать по
// фото» у пользователя (_shared/identify_run.ts: та же подсказка, модель,
// справочники под RLS, сопоставление с реестром, контекст — объект и
// помещение фото), и записывает ответ в recognition_eval_results.
//
// POST { action: "providers" }
//   200 { providers: [{ id: "default"|"yandex"|"openai", provider, model }] }
// POST { action: "run", runId, sampleId }
//   200 { ok: true, row }  | { ok: false, error, row } (ошибка ИИ записана) |
//       { skipped: true } (ответ уже есть)
//   400 bad_request | provider_not_configured; 404 not_found; 409 run_closed
// POST { action: "report", runId }
//   200 { run, metrics, headline, rows, examples, names }
// 401 unauthorized; 500 not_configured.
//
// Чтение — от имени пользователя под RLS (прогон, фото, набор видны только
// администратору своей компании). service_role — ТОЛЬКО для
// recognition_eval_put_result (0028): записать ответ; функция в базе ещё раз
// проверяет, что пользователь — администратор компании прогона. Фото и ответ
// модели не логируются.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { parseIdentifyInput } from "../_shared/identify.ts";
import { identifyPhoto, promptHash } from "../_shared/identify_run.ts";
import { corsHeaders, logFn } from "../_shared/http.ts";
import {
  computeMetrics,
  type EvalResult,
  type EvalSample,
  headline,
} from "../_shared/eval_metrics.ts";
import {
  errorRow,
  EVAL_LOCALE,
  parseEvalRequest,
  pickConfig,
  providerList,
  toBase64,
  toResultRow,
} from "./eval.ts";

const log = logFn("recognition-eval");
const MAX_ROWS = 5000;

Deno.serve(async (req) => {
  const started = Date.now();
  const cors = corsHeaders(req.headers.get("Origin"));
  const reply = (
    status: number,
    body: unknown,
    extra: Record<string, unknown> = {},
  ) => {
    log({ status, ms: Date.now() - started, ...extra });
    return new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
    });
  };

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const env = (k: string) => Deno.env.get(k);
  const supabaseUrl = env("SUPABASE_URL");
  const anonKey = env("SUPABASE_ANON_KEY");
  const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return reply(500, { error: "not_configured" }, { code: "not_configured" });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return reply(401, { error: "unauthorized" }, { code: "no_token" });

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "bad_request" }, { code: "bad_json" });
  }
  const parsed = parseEvalRequest(body);
  if (!parsed.ok) {
    return reply(400, { error: parsed.error }, { code: parsed.error });
  }
  const request = parsed.value;

  const db = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await db.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return reply(401, { error: "unauthorized" }, { code: "no_user" });
  }
  const userId = userData.user.id;

  // Раздел — только администратору: без строки профиля admin — 404 на всё.
  const prof = await db.from("profiles").select("role").eq("id", userId)
    .maybeSingle();
  if (prof.data?.role !== "admin") {
    return reply(404, { error: "not_found" }, {
      code: "not_admin",
      action: request.action,
    });
  }

  if (request.action === "providers") {
    return reply(200, { providers: providerList(env) }, {
      action: "providers",
    });
  }

  const runRes = await db.from("recognition_eval_runs").select("*").eq(
    "id",
    request.runId,
  ).maybeSingle();
  const run = runRes.data;
  if (!run) {
    return reply(404, { error: "not_found" }, {
      code: "no_run",
      action: request.action,
    });
  }

  if (request.action === "report") {
    const [samplesRes, resultsRes] = await Promise.all([
      db.from("recognition_eval_samples").select("*").eq("set_id", run.set_id)
        .eq("split", run.split).order("created_at").range(0, MAX_ROWS - 1),
      db.from("recognition_eval_results").select("*").eq("run_id", run.id)
        .range(0, MAX_ROWS - 1),
    ]);
    if (samplesRes.error || resultsRes.error) {
      return reply(502, { error: "read_failed" }, {
        code: "read_failed",
        action: "report",
      });
    }
    const samples = (samplesRes.data ?? []) as (EvalSample & {
      photo_path: string;
    })[];
    const results = ((resultsRes.data ?? []) as EvalResult[]).map((r) => ({
      ...r,
      confidence: r.confidence === null ? null : Number(r.confidence),
      candidates: Array.isArray(r.candidates) ? r.candidates : [],
    }));
    const metrics = computeMetrics(samples, results);
    // Названия для отчёта: оборудование (правильное и названное ИИ),
    // объекты и помещения — под RLS пользователя.
    const assetIds = new Set<string>();
    for (const s of samples) {
      if (s.true_equipment_id) assetIds.add(s.true_equipment_id);
    }
    for (const r of results) {
      for (const c of r.candidates) assetIds.add(c.asset_id);
    }
    const [assets, rooms, sites] = await Promise.all([
      assetIds.size
        ? db.from("assets").select("id,name").in("id", [...assetIds])
        : Promise.resolve({ data: [] }),
      db.from("locations").select("id,name,code").in("id", [
        ...new Set(samples.map((s) => s.room_id)),
      ]),
      db.from("objects").select("id,name").in("id", [
        ...new Set(samples.map((s) => s.site_id)),
      ]),
    ]);
    const names: Record<string, string> = {};
    for (const a of assets.data ?? []) names[a.id] = a.name;
    for (const l of rooms.data ?? []) {
      names[l.id] = l.code && !String(l.name).startsWith(l.code)
        ? `${l.code} ${l.name}`
        : l.name;
    }
    for (const o of sites.data ?? []) names[o.id] = o.name;
    const byId = new Map(results.map((r) => [r.sample_id, r]));
    const rows = samples.map((s) => {
      const r = byId.get(s.id);
      const top = r && !r.error && !r.abstained
        ? r.candidates[0]?.asset_id ?? null
        : null;
      return {
        sample_id: s.id,
        photo_path: s.photo_path,
        site_id: s.site_id,
        room_id: s.room_id,
        true_equipment_id: s.true_equipment_id,
        true_kind: s.true_kind,
        unregistered: s.true_is_unregistered,
        similar_in_room: s.similar_in_room,
        light: s.light,
        distance: s.distance,
        angle: s.angle,
        occlusion: s.occlusion,
        predicted_equipment_id: top,
        top3: r && !r.error ? r.candidates.map((c) => c.asset_id) : [],
        predicted_kind: r?.predicted_kind ?? null,
        confidence: r?.confidence ?? null,
        ms: r?.ms ?? null,
        error: r ? r.error : "missing",
      };
    });
    const examples = metrics.error_examples.map((e) => ({
      ...e,
      ...rows.find((r) => r.sample_id === e.sample_id),
    }));
    return reply(200, {
      run,
      metrics,
      headline: headline(metrics),
      rows,
      examples,
      names,
    }, { action: "report", photos: samples.length, results: results.length });
  }

  // action: "run" — одно фото.
  if (run.status !== "running") {
    return reply(409, { error: "run_closed" }, {
      code: "run_closed",
      action: "run",
    });
  }
  const sampleRes = await db.from("recognition_eval_samples").select("*").eq(
    "id",
    request.sampleId,
  ).maybeSingle();
  const sample = sampleRes.data;
  if (!sample || sample.set_id !== run.set_id || sample.split !== run.split) {
    return reply(400, { error: "bad_request" }, {
      code: "bad_sample",
      action: "run",
    });
  }
  const prev = await db.from("recognition_eval_results").select("error").eq(
    "run_id",
    run.id,
  ).eq("sample_id", sample.id).maybeSingle();
  if (prev.data && prev.data.error === null) {
    return reply(200, { skipped: true }, { action: "run", skipped: true });
  }

  const aiCfg = pickConfig(env, run.provider_requested);
  if (!aiCfg) {
    return reply(400, { error: "provider_not_configured" }, {
      code: "provider_not_configured",
      action: "run",
    });
  }
  const provider = aiCfg.provider ?? "yandex";
  const hash = await promptHash(EVAL_LOCALE);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const put = async (row: Record<string, unknown>) => {
    const r = await admin.rpc("recognition_eval_put_result", {
      p_user: userId,
      p_run: run.id,
      p_sample: sample.id,
      p_provider: provider,
      p_model: aiCfg.model,
      p_prompt_hash: hash,
      p_result: row,
    });
    return r.error ? String(r.error.message ?? "put_failed") : null;
  };

  // Фото — из закрытого хранилища под RLS пользователя.
  const file = await db.storage.from("eval-photos").download(sample.photo_path);
  if (file.error || !file.data) {
    return reply(404, { error: "not_found" }, {
      code: "no_photo",
      action: "run",
    });
  }
  const bytes = new Uint8Array(await file.data.arrayBuffer());
  const input = parseIdentifyInput({
    image: toBase64(bytes),
    locale: EVAL_LOCALE,
    objectId: sample.site_id,
    locationId: sample.room_id,
  });
  if (!input.ok) {
    const row = errorRow(input.error, 0);
    const putErr = await put(row as unknown as Record<string, unknown>);
    return reply(200, { ok: false, error: input.error, row }, {
      code: input.error,
      action: "run",
      put: putErr ? "failed" : "ok",
    });
  }

  const t0 = Date.now();
  const out = await identifyPhoto(db, aiCfg, input.value, { box: false, log });
  const ms = Date.now() - t0;
  const row = out.ok
    ? toResultRow(out.result, {
      ms,
      tokens: typeof out.log.tokens === "number" ? out.log.tokens : null,
      model: out.model,
    })
    : errorRow(out.code, ms);
  const putErr = await put(row as unknown as Record<string, unknown>);
  if (putErr) {
    // Сообщения базы — коды (eval_config_changed, eval_run_closed…).
    const code = /eval_[a-z_]+/.exec(putErr)?.[0] ?? "put_failed";
    return reply(409, { error: code }, { code, action: "run" });
  }
  return reply(
    200,
    out.ok ? { ok: true, row } : { ok: false, error: out.code, row },
    {
      action: "run",
      ...out.log,
      eval_ms: ms,
    },
  );
});
