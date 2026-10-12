// Edge Function photo-identify: снимок оборудования → вид, система, шильдик,
// видимая неисправность и до 3 кандидатов из реестра («какая это единица»).
//
// POST { image: base64 JPEG/PNG/WebP (≤ 1,5 МБ), locale: "ru" | "en",
//        objectId?, floorId?, locationId?, orderId? }
//   200 { source: "ai", kind, kind_label, layer_id, layer, nameplate, defect,
//         confidence, candidates: [{ asset_id, name, location_id,
//         location_label, floor_label, score, reasons[], reason_text }],
//         model: "main"|"lite", ms }
//   400 { error: "bad_request" | "bad_image" | "too_large" | "bad_locale" |
//         "bad_place" }
//   401 { error: "unauthorized" }        — не вошедший пользователь
//   500 { error: "not_configured" }      — не заданы секреты
//   502 { error: "ai_unavailable" }      — модель недоступна или ответила не JSON
//
// Тонкая HTTP-обёртка: подсказка, проверка ответа и сопоставление с реестром —
// в _shared/ (их же вызовет Telegram-бот шага 23).
//
// Справочники (слои, оборудование, помещения) читаются ОТ ИМЕНИ ПОЛЬЗОВАТЕЛЯ,
// под RLS — service_role не используется. Ключи — только в секретах функции
// (YANDEX_API_KEY, YANDEX_FOLDER_ID, необязательные YANDEX_VISION_MODEL и
// YANDEX_VISION_MODEL_LITE). Фото нигде не сохраняется и не логируется; в логе
// — только размер, время, модель, токены, код ошибки, число кандидатов.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import {
  buildResult,
  buildVisionMessages,
  normalizeVision,
  parseIdentifyInput,
  stripThinking,
} from "../_shared/identify.ts";
import { parseModelJson } from "../_shared/intake.ts";
import { corsHeaders, logFn } from "../_shared/http.ts";
import { loadAssets, loadLayers, resolveHere } from "../_shared/registry.ts";
import { callVision, visionModels } from "../_shared/vision.ts";
import { AiError } from "../_shared/yandex.ts";

const log = logFn("photo-identify");

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

  const apiKey = Deno.env.get("YANDEX_API_KEY")?.trim();
  const folderId = Deno.env.get("YANDEX_FOLDER_ID")?.trim();
  const { model, liteModel } = visionModels((k) => Deno.env.get(k));
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!apiKey || !folderId || !supabaseUrl || !anonKey) {
    return reply(500, { error: "not_configured" }, { code: "not_configured" });
  }

  // verify_jwt пропускает и anon-ключ (он тоже JWT) — проверяем, что вошёл человек.
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return reply(401, { error: "unauthorized" }, { code: "no_token" });

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "bad_request" }, { code: "bad_json" });
  }
  const parsed = parseIdentifyInput(body);
  body = null; // снимок больше не нужен в исходном виде
  if (!parsed.ok) {
    return reply(400, { error: parsed.error }, { code: parsed.error });
  }
  const input = parsed.value;

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return reply(401, { error: "unauthorized" }, {
      code: "no_user",
      bytes: input.bytes,
    });
  }

  // Справочники читаем, пока модель смотрит на снимок.
  const layers = await loadLayers(supabase, log);
  const registry = (async () => {
    const here = await resolveHere(supabase, input);
    return { here, assets: await loadAssets(supabase, here, log) };
  })().catch(() => {
    log({ code: "registry_failed" });
    return { here: {}, assets: [] };
  });

  try {
    const aiStarted = Date.now();
    const ai = await callVision(
      { apiKey, folderId, model, liteModel },
      buildVisionMessages(input, layers),
    );
    const aiMs = Date.now() - aiStarted;
    const which = {
      model: ai.model === "pro" ? "main" : "lite",
      first: ai.primaryError,
    };
    const raw = parseModelJson(stripThinking(ai.content));
    if (!raw) {
      return reply(502, { error: "ai_unavailable" }, {
        code: "invalid_json",
        bytes: input.bytes,
        tokens: ai.totalTokens,
        ai_ms: aiMs,
        ...which,
      });
    }
    const { here, assets } = await registry;
    const result = buildResult(
      normalizeVision(raw, layers),
      assets,
      here,
      input.locale,
    );
    const ms = Date.now() - started;
    return reply(200, { ...result, model: which.model, ms }, {
      ...which,
      bytes: input.bytes,
      mime: input.mime,
      tokens: ai.totalTokens,
      ai_ms: aiMs,
      assets: assets.length,
      candidates: result.candidates.length,
      kind: result.kind,
      plate: result.nameplate !== null,
    });
  } catch (e) {
    const code = e instanceof AiError ? e.code : "unexpected";
    return reply(502, { error: "ai_unavailable" }, {
      code,
      bytes: input.bytes,
    });
  }
});
