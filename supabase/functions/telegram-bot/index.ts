// Edge Function telegram-bot: вебхук @HeyHelpy_bot (шаг 23).
//
// POST (от Telegram) с заголовком X-Telegram-Bot-Api-Secret-Token
//   = секрет TELEGRAM_WEBHOOK_SECRET (сравнение за постоянное время);
//   не совпал или секрет не задан → 401, ничего не делаем.
//   Иначе — всегда 200 (даже при ошибке внутри): Telegram не повторяет одно
//   и то же, а человек получает понятный ответ. Повтор update_id — сразу 200.
//
// verify_jwt = false (Telegram не присылает JWT) — вместо него секрет вебхука.
//
// ⚠️ service_role: Supabase сам передаёт функции SUPABASE_SERVICE_ROLE_KEY.
// Им вызываются ТОЛЬКО функции tg_* (миграция 0018: каждая сама проверяет,
// кто пишет, по chat_id — аккаунт, гость своей ссылки, группа объекта) и
// загрузка / удаление фото в work-photos по пути <компания>/<заявка>/tg_….jpg.
// Прямых select / insert в таблицы с этим ключом нет.
//
// Секреты: TELEGRAM_BOT_TOKEN, TELEGRAM_WEBHOOK_SECRET, YANDEX_API_KEY,
// YANDEX_FOLDER_ID (+ необязательные YANDEX_MODEL*, YANDEX_VISION_MODEL*,
// TELEGRAM_LEADS_CHAT_ID — чат владельца для заявок на демо, шаг 29).
// В лог — только тип сообщения, время этапов, модель, коды ошибок, гость /
// пользователь. Текст, расшифровка, фото, имена и chat_id не пишутся.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import {
  buildMessages,
  normalize,
  parseModelJson,
} from "../_shared/intake.ts";
import {
  buildVisionMessages,
  normalizeVision,
  stripThinking,
} from "../_shared/identify.ts";
import { logFn } from "../_shared/http.ts";
import { callVision, visionModels } from "../_shared/vision.ts";
import { AiError, aiFromEnv, complete } from "../_shared/ai.ts";
import { type Ai, type Ctx, type Db, type Deps, handleUpdate, leadsChatId, type Session, type Storage, type Who } from "./bot.ts";
import type { AssignInfo } from "./assign.ts";
import { sttFromEnv } from "./stt.ts";
import { parseUpdate, secretMatches, telegramApi } from "./telegram.ts";
import { langOf, t } from "./texts.ts";

const log = logFn("telegram-bot");

/** Адрес веб-приложения: ссылка «Открыть в приложении». */
const APP_URL = "https://anton-key.github.io/hey-helpy/";
const PHOTO_BUCKET = "work-photos";

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined;

Deno.serve(async (req) => {
  const started = Date.now();
  const ok = () => new Response("ok", { status: 200 });
  if (req.method !== "POST") return new Response(null, { status: 405 });

  const secret = Deno.env.get("TELEGRAM_WEBHOOK_SECRET")?.trim() ?? "";
  if (!secretMatches(req.headers.get("X-Telegram-Bot-Api-Secret-Token"), secret)) {
    log({ status: 401, code: secret ? "bad_secret" : "no_secret" });
    return new Response("unauthorized", { status: 401 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    log({ status: 200, code: "bad_json" });
    return ok();
  }
  const update = parseUpdate(body);
  if (!update) {
    log({ status: 200, code: "bad_update" });
    return ok();
  }

  const deps = makeDeps();
  if (!deps) {
    log({ status: 200, code: "not_configured" });
    return ok();
  }

  const work = handleUpdate(update, deps)
    .then((fields) => log({ status: 200, ms: Date.now() - started, ...fields }))
    .catch(async (e) => {
      log({ status: 200, ms: Date.now() - started, code: codeOf(e) });
      // Человеку — понятный ответ; повторять Telegram'у нечего.
      const chat = update.message?.chat.id ?? update.callback_query?.message?.chat.id;
      const lang = langOf(update.message?.from?.language_code ?? update.callback_query?.from.language_code);
      if (chat !== undefined) {
        await deps.tg.send(chat, t(lang, "failed")).catch(() => {});
      }
      if (update.callback_query) await deps.tg.answer(update.callback_query.id).catch(() => {});
    });
  // Ответ Telegram'у сразу; разбор (ИИ до 14 с, речь до 10 с) — в фоне.
  if (typeof EdgeRuntime !== "undefined" && EdgeRuntime?.waitUntil) {
    EdgeRuntime.waitUntil(work);
  } else {
    await work;
  }
  return ok();
});

/** Ошибка ИИ — в лог код и `ai_error` (без base64 и текста запроса), дальше как раньше. */
function logAiError(ai: "text" | "vision", provider?: string) {
  return (e: unknown): never => {
    if (e instanceof AiError) log({ ai, provider, code: e.code, ai_error: e.detail, tried: e.tried });
    throw e;
  };
}

function codeOf(e: unknown): string {
  const c = (e as { code?: unknown })?.code;
  return typeof c === "string" && /^[a-z0-9_]{1,40}$/i.test(c) ? c : "unexpected";
}

function makeDeps(): Deps | null {
  const token = Deno.env.get("TELEGRAM_BOT_TOKEN")?.trim();
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!token || !url || !serviceKey) return null;

  const sb = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
    const { data, error } = await sb.rpc(fn, args);
    if (error) throw Object.assign(new Error(fn), { code: `db_${fn}` });
    return data as T;
  }

  const db: Db = {
    takeUpdate: (id) => rpc<boolean>("tg_take_update", { p_update_id: id }),
    resolve: (chat, group) => rpc<Who>("tg_resolve_chat", { p_chat: chat, p_group: group }),
    linkChat: (code, chat, username, name, lang) =>
      rpc("tg_link_chat", { p_code: code, p_chat: chat, p_username: username, p_name: name, p_lang: lang }),
    guestStart: (token, chat, name, lang) =>
      rpc("tg_guest_start", { p_token: token, p_chat: chat, p_name: name, p_lang: lang }),
    reset: (chat) => rpc<boolean>("tg_reset", { p_chat: chat }),
    connectGroup: (code, chat, title) => rpc("tg_connect_group", { p_code: code, p_chat: chat, p_title: title }),
    context: async (chat, group, objectId) => {
      const c = await rpc<Partial<Ctx>>("tg_context", { p_chat: chat, p_group: group, p_object: objectId ?? null });
      return {
        ...c,
        layers: c.layers ?? [],
        objects: c.objects ?? [],
        places: c.places ?? [],
        assets: c.assets ?? [],
      };
    },
    setObject: (chat, objectId) => rpc("tg_set_object", { p_chat: chat, p_object: objectId }),
    nearest: (chat, lat, lng) => rpc("tg_nearest_object", { p_chat: chat, p_lat: lat, p_lng: lng }),
    createOrder: (chat, group, id, order) =>
      rpc("tg_create_order", { p_chat: chat, p_group: group, p_id: id, p_order: order }),
    sessionGet: (chat) => rpc<Session | null>("tg_session_get", { p_chat: chat }),
    sessionPut: async (chat, state) => {
      await rpc("tg_session_put", { p_chat: chat, p_state: state });
    },
    notifyOptout: async (chat, off) => {
      await rpc("tg_notify_optout", { p_chat: chat, p_off: off });
    },
    notifyClaim: (orderId, status) => rpc("tg_notify_claim", { p_order: orderId, p_status: status }),
    // Шаг 28 (0025). Без 0025 — функции нет: «Новая заявка» молча не уходит,
    // «Взять в работу» отвечает «недоступна».
    assignClaim: (orderId, actor) =>
      rpc<AssignInfo | null>("tg_notify_assign_claim", { p_order: orderId, p_actor: actor }),
    assignRelease: async (orderId, contractorId, profileId) => {
      await rpc("tg_notify_assign_release", { p_order: orderId, p_contractor: contractorId, p_profile: profileId });
    },
    takeOrder: (chat, orderId) =>
      rpc<Record<string, unknown>>("tg_take_order", { p_chat: chat, p_order: orderId }).catch(() => ({ error: "unavailable" })),
    // Заявка на демо с сайта (шаг 29, 0026). Без 0026 — ошибка, бот отвечает «не получилось»
    // (или только пересылает владельцу, если задан TELEGRAM_LEADS_CHAT_ID).
    leadSave: (chat, username, name, lang, text) =>
      rpc<Record<string, unknown>>("tg_lead_save", { p_chat: chat, p_username: username, p_name: name, p_lang: lang, p_text: text }),
  };

  const storage: Storage = {
    async upload(path, bytes) {
      const { error } = await sb.storage.from(PHOTO_BUCKET).upload(path, bytes, {
        contentType: "image/jpeg",
        upsert: false,
      });
      if (error) throw Object.assign(new Error("upload"), { code: "storage_upload" });
    },
    async remove(path) {
      await sb.storage.from(PHOTO_BUCKET).remove([path]);
    },
  };

  // Поставщики ИИ и распознавания речи — по секретам (шаг 33): AI_* или YANDEX_*.
  const env = (k: string) => Deno.env.get(k);
  const textCfg = aiFromEnv(env, "text");
  const visionCfg = aiFromEnv(env, "vision", visionModels(env));
  const speech = sttFromEnv(env);

  const ai: Ai = {
    async text(text, lang, catalog) {
      if (!textCfg) return null;
      const r = await complete(textCfg, buildMessages({ text, locale: lang }, catalog))
        .catch(logAiError("text", textCfg.provider));
      const raw = parseModelJson(r.content);
      return raw ? { result: normalize(raw, catalog, text), model: r.model } : null;
    },
    async vision(image, lang, layers) {
      if (!visionCfg) return null;
      const r = await callVision(
        visionCfg,
        buildVisionMessages({ image, mime: "image/jpeg", locale: lang }, layers),
      ).catch(logAiError("vision", visionCfg.provider));
      const raw = parseModelJson(stripThinking(r.content));
      return raw ? { vision: normalizeVision(raw, layers), model: r.model === "pro" ? "main" : "lite" } : null;
    },
    stt(audio, lang) {
      if (!speech) return Promise.reject(Object.assign(new Error("stt"), { code: "not_configured" }));
      return speech.recognize(audio, lang);
    },
  };

  return {
    tg: telegramApi(token),
    db,
    storage,
    ai,
    log,
    uuid: () => crypto.randomUUID(),
    appUrl: APP_URL,
    leadsChat: leadsChatId(Deno.env.get("TELEGRAM_LEADS_CHAT_ID")),
  };
}
