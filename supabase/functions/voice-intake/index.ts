// Edge Function voice-intake: текст заявки → поля черновика (YandexGPT).
//
// POST { text, locale: "ru" | "en", objectId? }
//   200 { source: "ai", title, description, layer_id, layer, location_id,
//         location_hint, priority, confidence, transcript }
//   400 { error: "bad_request" | "bad_text" | "bad_locale" | "bad_object" }
//   401 { error: "unauthorized" }        — не вошедший пользователь
//   500 { error: "not_configured" }      — не заданы секреты
//   502 { error: "ai_unavailable" }      — модель недоступна или ответила не JSON
//
// Справочники (слои, помещения) читаются ОТ ИМЕНИ ПОЛЬЗОВАТЕЛЯ, под RLS —
// service_role не используется. Ключи Yandex — только в секретах функции
// (YANDEX_API_KEY, YANDEX_FOLDER_ID, необязательный YANDEX_MODEL).
// В логи — только служебное: длина текста, время, код ошибки, токены.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import {
  buildMessages,
  type Catalog,
  type LayerRef,
  normalize,
  parseInput,
  parseModelJson,
  type PlaceRef,
  PLACES_MAX,
} from "./schema.ts";
import { AiError, complete, DEFAULT_MODEL } from "./yandex.ts";

const ALLOWED_ORIGIN = "https://anton-key.github.io";
const LOCALHOST = /^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;

function corsHeaders(origin: string | null): Record<string, string> {
  const h: Record<string, string> = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
  if (origin && (origin === ALLOWED_ORIGIN || LOCALHOST.test(origin))) {
    h["Access-Control-Allow-Origin"] = origin;
  }
  return h;
}

function log(fields: Record<string, unknown>) {
  console.log(JSON.stringify({ fn: "voice-intake", ...fields }));
}

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
  const model = Deno.env.get("YANDEX_MODEL")?.trim() || DEFAULT_MODEL;
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
  const parsed = parseInput(body);
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
      len: input.text.length,
    });
  }

  const catalog = await loadCatalog(supabase, input.objectId);

  try {
    const ai = await complete(
      { apiKey, folderId, model },
      buildMessages(input, catalog),
    );
    const raw = parseModelJson(ai.content);
    if (!raw) {
      return reply(502, { error: "ai_unavailable" }, {
        code: "invalid_json",
        len: input.text.length,
        tokens: ai.totalTokens,
      });
    }
    const result = normalize(raw, catalog, input.text);
    return reply(200, result, {
      len: input.text.length,
      tokens: ai.totalTokens,
      layers: catalog.layers.length,
      places: catalog.places.length,
      layer: result.layer_id !== null,
      place: result.location_id !== null,
    });
  } catch (e) {
    const code = e instanceof AiError ? e.code : "unexpected";
    return reply(502, { error: "ai_unavailable" }, {
      code,
      len: input.text.length,
    });
  }
});

/** Слои и помещения, доступные пользователю (RLS). Ошибка → пустой список. */
async function loadCatalog(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  objectId?: string,
): Promise<Catalog> {
  const [layersRes, placesRes] = await Promise.all([
    supabase.from("layers").select("id,name,name_i18n").order("sort").order(
      "name",
    ),
    (() => {
      let q = supabase.from("locations").select(
        "id,object_id,name,objects(name)",
      );
      if (objectId) q = q.eq("object_id", objectId);
      return q.order("name").limit(PLACES_MAX);
    })(),
  ]);
  if (layersRes.error) log({ code: "layers_failed" });
  if (placesRes.error) log({ code: "places_failed" });
  const layers: LayerRef[] = (layersRes.data ?? []).map((r: LayerRef) => ({
    id: r.id,
    name: r.name ?? "",
    name_i18n: r.name_i18n ?? null,
  }));
  const places: PlaceRef[] = (placesRes.data ?? []).map((
    r: {
      id: string;
      object_id: string;
      name: string;
      objects?: { name?: string } | null;
    },
  ) => ({
    id: r.id,
    object_id: r.object_id,
    name: r.name ?? "",
    object_name: r.objects?.name ?? null,
  }));
  return { layers, places };
}
