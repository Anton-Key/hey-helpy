// Edge Function telegram-notify (шаг 24): после смены статуса заявки
// приложение (менеджер или исполнитель) вызывает её со своим JWT:
//   POST { orderId } → 200 { result: sent | sent_photo | skip | no_status | send_failed }
//   400 bad_request · 401 unauthorized · 404 not_visible · 500 not_configured
//
// Кто что делает:
// • JWT пользователя (verify_jwt = true + проверка getUser): заявка, её
//   статус и фото «после» читаются ПОД RLS пользователя — видит ли он заявку
//   и что сейчас в базе, решает база, а не приложение.
// • service_role (Supabase передаёт сам) — ТОЛЬКО функции tg_notify_claim /
//   tg_notify_release (0022): чат автора из telegram.orders и отметка
//   «по этому статусу уже отправлено» (повторный вызов ничего не шлёт).
// • Ошибка Telegram не мешает смене статуса: статус уже сохранён, отметка
//   снимается, следующий вызов попробует снова.
//
// Секреты: TELEGRAM_BOT_TOKEN. В лог — результат, время, код ошибки;
// текст заявки, chat_id и фото — нет.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { corsHeaders, logFn } from "../_shared/http.ts";
import { sendPhotoBytes, telegramApi } from "../telegram-bot/telegram.ts";
import { notifyOrder, parseNotifyInput, type Target } from "./notify.ts";

const log = logFn("telegram-notify");
const APP_URL = "https://anton-key.github.io/hey-helpy/";
const PHOTO_BUCKET = "work-photos";
const PHOTO_MAX = 10 * 1024 * 1024;

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

  // Без токена — 401 раньше всего остального (так проверяет «Deploy functions»).
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return reply(401, { error: "unauthorized" }, { code: "no_token" });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const token = Deno.env.get("TELEGRAM_BOT_TOKEN")?.trim();
  if (!url || !anonKey || !serviceKey || !token) {
    return reply(500, { error: "not_configured" }, { code: "not_configured" });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "bad_request" }, { code: "bad_json" });
  }
  const input = parseNotifyInput(body);
  if (!input.ok) return reply(400, { error: "bad_request" }, { code: "bad_input" });

  const user = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: u, error: ue } = await user.auth.getUser(jwt);
  if (ue || !u?.user) return reply(401, { error: "unauthorized" }, { code: "no_user" });

  const service = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const tg = telegramApi(token);

  try {
    const result = await notifyOrder(input.orderId, {
      async readOrder(id) {
        const { data, error } = await user.from("work_orders").select("status").eq("id", id).maybeSingle();
        if (error) throw Object.assign(new Error("read"), { code: "db_read" });
        return data as { status: string } | null;
      },
      async claim(id, status) {
        const { data, error } = await service.rpc("tg_notify_claim", { p_order: id, p_status: status });
        if (error) throw Object.assign(new Error("claim"), { code: "db_claim" });
        return (data ?? null) as Target | null;
      },
      async release(id, status) {
        await service.rpc("tg_notify_release", { p_order: id, p_status: status });
      },
      async afterPhoto(id) {
        const { data } = await user.from("attachments").select("storage_path")
          .eq("work_order_id", id).eq("kind", "photo").eq("stage", "after")
          .order("created_at", { ascending: false }).limit(1);
        const path = (data?.[0] as { storage_path?: string } | undefined)?.storage_path;
        if (!path || path.startsWith("demo/")) return null;
        const f = await user.storage.from(PHOTO_BUCKET).download(path);
        if (f.error || !f.data || f.data.size > PHOTO_MAX) return null;
        return new Uint8Array(await f.data.arrayBuffer());
      },
      send: (chat, html, markup) => tg.send(chat, html, markup),
      sendPhoto: (chat, photo, caption, markup) => sendPhotoBytes(token, chat, photo, caption, markup),
      appUrl: APP_URL,
    });
    if (result === "not_visible") return reply(404, { error: "not_visible" }, { result });
    return reply(200, { result }, { result });
  } catch (e) {
    const code = (e as { code?: string })?.code ?? "unexpected";
    return reply(500, { error: "failed" }, { code });
  }
});
