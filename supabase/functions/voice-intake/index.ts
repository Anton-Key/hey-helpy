// Edge Function voice-intake: текст заявки → поля черновика (YandexGPT).
//
// POST { text, locale: "ru" | "en", objectId? }
//   200 { source: "ai", title, description, layer_id, layer, location_id,
//         location_hint, priority, confidence, transcript, model: "pro"|"lite" }
//   400 { error: "bad_request" | "bad_text" | "bad_locale" | "bad_object" }
//   401 { error: "unauthorized" }        — не вошедший пользователь
//   500 { error: "not_configured" }      — не заданы секреты
//   502 { error: "ai_unavailable" }      — модель недоступна или ответила не JSON
//
// YandexGPT: основная модель ждёт 7 с, затем один повтор на запасной
// (yandexgpt-lite/latest, секрет YANDEX_MODEL_LITE — заменить, "-" — без
// повтора), всего не дольше 14 с (yandex.ts).
//
// Справочники (слои, помещения) читаются ОТ ИМЕНИ ПОЛЬЗОВАТЕЛЯ, под RLS —
// service_role не используется. Ключи Yandex — только в секретах функции
// (YANDEX_API_KEY, YANDEX_FOLDER_ID, необязательные YANDEX_MODEL и
// YANDEX_MODEL_LITE). В логи — только служебное: длина текста, время, код
// ошибки, токены, какая модель ответила (model) и почему не основная (first).

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
import { AiError, aiFromEnv, complete } from "./yandex.ts";
import { corsHeaders, logFn } from "../_shared/http.ts";

const log = logFn("voice-intake");

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

  // Поставщик ИИ — по секретам (шаг 33): AI_* или, как раньше, YANDEX_*.
  const aiCfg = aiFromEnv((k) => Deno.env.get(k), "text");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!aiCfg || !supabaseUrl || !anonKey) {
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
    const ai = await complete(aiCfg, buildMessages(input, catalog));
    const which = {
      provider: aiCfg.provider,
      model: ai.model,
      first: ai.primaryError,
      first_error: ai.primaryDetail,
      format: ai.format,
    };
    const raw = parseModelJson(ai.content);
    if (!raw) {
      return reply(502, { error: "ai_unavailable" }, {
        code: "invalid_json",
        len: input.text.length,
        tokens: ai.totalTokens,
        ...which,
      });
    }
    const result = normalize(raw, catalog, input.text);
    return reply(200, { ...result, model: ai.model }, {
      ...which,
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
      provider: aiCfg.provider,
      len: input.text.length,
      // Только error.code / error.message ответа API, без base64 (≤ 300).
      ai_error: e instanceof AiError ? e.detail : undefined,
      tried: e instanceof AiError ? e.tried : undefined,
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
      // Номер помещения и город объекта — с 0015; без неё — как раньше.
      const query = (cols: string) => {
        let q = supabase.from("locations").select(cols);
        if (objectId) q = q.eq("object_id", objectId);
        return q.order("name").limit(PLACES_MAX);
      };
      return query("id,object_id,name,code,objects(name,city)").then(
        // deno-lint-ignore no-explicit-any
        (r: any) => r.error ? query("id,object_id,name,objects(name)") : r,
      );
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
      code?: string | null;
      objects?: { name?: string; city?: string | null } | null;
    },
  ) => ({
    id: r.id,
    object_id: r.object_id,
    name: r.name ?? "",
    object_name: r.objects?.name ?? null,
    object_city: r.objects?.city ?? null,
    code: r.code ?? null,
  }));
  return { layers, places };
}
