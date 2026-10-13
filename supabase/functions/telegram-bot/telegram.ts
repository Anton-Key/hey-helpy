// Telegram Bot API: нужные поля обновлений, разбор команд и упоминаний,
// проверка секрета вебхука и тонкий клиент API. Токен бота — только в
// адресе запроса к api.telegram.org, в лог не попадает.

/** Имя бота — одно место (в приложении — kTelegramBot в lib/core/app_links.dart). */
export const BOT_USERNAME = "HeyHelpy_bot";

export const API = "https://api.telegram.org";

/** Голосовое: SpeechKit принимает до 1 МБ и 30 с. */
export const VOICE_MAX_BYTES = 1024 * 1024;
export const VOICE_MAX_SECONDS = 30;
/** Фото для модели: Telegram отдаёт до 1280 px — это ~100–300 КБ. */
export const PHOTO_MAX_BYTES = 1536 * 1024;

export interface TgUser {
  id: number;
  is_bot?: boolean;
  first_name?: string;
  last_name?: string;
  username?: string;
  language_code?: string;
}

export interface TgChat {
  id: number;
  type: "private" | "group" | "supergroup" | "channel";
  title?: string;
}

export interface TgPhotoSize {
  file_id: string;
  width: number;
  height: number;
  file_size?: number;
}

export interface TgEntity {
  type: string;
  offset: number;
  length: number;
}

export interface TgMessage {
  message_id: number;
  from?: TgUser;
  chat: TgChat;
  text?: string;
  caption?: string;
  entities?: TgEntity[];
  caption_entities?: TgEntity[];
  voice?: { file_id: string; duration: number; file_size?: number };
  photo?: TgPhotoSize[];
  location?: { latitude: number; longitude: number };
  reply_to_message?: { from?: TgUser };
}

export interface TgCallback {
  id: string;
  from: TgUser;
  message?: { message_id: number; chat: TgChat };
  data?: string;
}

export interface TgUpdate {
  update_id: number;
  message?: TgMessage;
  callback_query?: TgCallback;
}

export interface InlineButton {
  text: string;
  callback_data?: string;
  url?: string;
}

export type ReplyMarkup =
  | { inline_keyboard: InlineButton[][] }
  | {
    keyboard: { text: string; request_location?: boolean }[][];
    resize_keyboard?: boolean;
    one_time_keyboard?: boolean;
  }
  | { remove_keyboard: true };

/** Тело запроса → обновление Telegram или null (мусор не обрабатываем). */
export function parseUpdate(body: unknown): TgUpdate | null {
  if (typeof body !== "object" || body === null) return null;
  const u = body as Record<string, unknown>;
  if (typeof u.update_id !== "number" || !Number.isSafeInteger(u.update_id)) {
    return null;
  }
  const ok = (v: unknown) => typeof v === "object" && v !== null;
  const msg = u.message as TgMessage | undefined;
  if (msg !== undefined && !(ok(msg) && ok(msg.chat) && typeof msg.chat.id === "number")) {
    return null;
  }
  const cb = u.callback_query as TgCallback | undefined;
  if (cb !== undefined && !(ok(cb) && ok(cb.from) && typeof cb.id === "string")) {
    return null;
  }
  return body as TgUpdate;
}

/** Сравнение секрета за постоянное время (не выдаёт длину совпавшего начала). */
export function secretMatches(given: string | null, expected: string): boolean {
  if (!expected) return false;
  const a = new TextEncoder().encode(given ?? "");
  const b = new TextEncoder().encode(expected);
  const n = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < n; i++) diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return diff === 0;
}

export interface Command {
  name: string;
  arg: string;
}

/**
 * «/start obj_x» → {name: "start", arg: "obj_x"}. Команда другому боту
 * («/help@OtherBot») — null. Регистр имени бота не важен.
 */
export function parseCommand(
  text: string | undefined,
  bot = BOT_USERNAME,
): Command | null {
  const m = /^\/([a-z_]{1,32})(?:@([A-Za-z0-9_]{3,64}))?(?:\s+([\s\S]*))?$/i
    .exec((text ?? "").trim());
  if (!m) return null;
  if (m[2] && m[2].toLowerCase() !== bot.toLowerCase()) return null;
  return { name: m[1].toLowerCase(), arg: (m[3] ?? "").trim() };
}

/** Есть ли в тексте упоминание @бота (по разметке Telegram или по тексту). */
export function mentionsBot(text: string | undefined, bot = BOT_USERNAME): boolean {
  if (!text) return false;
  return new RegExp(`(^|[^A-Za-z0-9_])@${bot}(?![A-Za-z0-9_])`, "i").test(text);
}

/** Текст без упоминания бота: «@HeyHelpy_bot течёт кран» → «течёт кран». */
export function stripMention(text: string, bot = BOT_USERNAME): string {
  return text.replace(new RegExp(`@${bot}(?![A-Za-z0-9_])`, "gi"), " ")
    .replace(/\s+/g, " ").trim();
}

/**
 * Читает ли бот это сообщение группы: упоминание, ответ на сообщение бота
 * или команда. Остальную переписку группы бот не обрабатывает и не хранит.
 */
export function groupAddressed(m: TgMessage, bot = BOT_USERNAME): boolean {
  const text = m.text ?? m.caption ?? "";
  if (parseCommand(m.text, bot)) return true;
  if (mentionsBot(text, bot)) return true;
  const r = m.reply_to_message?.from;
  return !!(r?.is_bot && r.username?.toLowerCase() === bot.toLowerCase());
}

/** Самый крупный вариант фото не больше [max] байт. */
export function pickPhoto(
  sizes: TgPhotoSize[] | undefined,
  max = PHOTO_MAX_BYTES,
): TgPhotoSize | null {
  const ok = (sizes ?? []).filter((s) => (s.file_size ?? 0) <= max);
  if (!ok.length) return null;
  return ok.reduce((a, b) => (b.width * b.height > a.width * a.height ? b : a));
}

/** Имя для заявки: «Мария К.» — без телефона и без chat_id. */
export function reporterName(u: TgUser | undefined): string | null {
  if (!u) return null;
  const first = (u.first_name ?? "").trim();
  const last = (u.last_name ?? "").trim();
  const name = [first, last ? `${last[0]}.` : ""].filter(Boolean).join(" ");
  return name || null;
}

// ---------------------------------------------------------------------------
// Клиент API
// ---------------------------------------------------------------------------

export class TgError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

export interface TelegramApi {
  send(
    chatId: number,
    html: string,
    markup?: ReplyMarkup,
    replyTo?: number,
  ): Promise<number | null>;
  edit(chatId: number, messageId: number, html: string, markup?: ReplyMarkup): Promise<void>;
  answer(callbackId: string, text?: string): Promise<void>;
  /** Скачать файл по file_id: не больше [maxBytes]. */
  download(fileId: string, maxBytes: number): Promise<Uint8Array>;
}

export function telegramApi(
  token: string,
  fetchFn: typeof fetch = fetch,
  timeoutMs = 8000,
): TelegramApi {
  async function call(method: string, body: unknown): Promise<unknown> {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      const res = await fetchFn(`${API}/bot${token}/${method}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: ctrl.signal,
      });
      const data = await res.json().catch(() => null) as
        | { ok?: boolean; result?: unknown }
        | null;
      if (!res.ok || !data?.ok) throw new TgError(`tg_${method}_${res.status}`);
      return data.result;
    } catch (e) {
      if (e instanceof TgError) throw e;
      throw new TgError(ctrl.signal.aborted ? `tg_${method}_timeout` : `tg_${method}_network`);
    } finally {
      clearTimeout(timer);
    }
  }

  return {
    async send(chatId, html, markup, replyTo) {
      const r = await call("sendMessage", {
        chat_id: chatId,
        text: html,
        parse_mode: "HTML",
        link_preview_options: { is_disabled: true },
        ...(markup ? { reply_markup: markup } : {}),
        ...(replyTo
          ? { reply_parameters: { message_id: replyTo, allow_sending_without_reply: true } }
          : {}),
      }) as { message_id?: number } | null;
      return r?.message_id ?? null;
    },
    async edit(chatId, messageId, html, markup) {
      try {
        await call("editMessageText", {
          chat_id: chatId,
          message_id: messageId,
          text: html,
          parse_mode: "HTML",
          link_preview_options: { is_disabled: true },
          ...(markup ? { reply_markup: markup } : {}),
        });
      } catch (e) {
        // «message is not modified» и подобное — не ошибка для человека.
        if (!(e instanceof TgError && e.code.endsWith("_400"))) throw e;
      }
    },
    async answer(callbackId, text) {
      await call("answerCallbackQuery", {
        callback_query_id: callbackId,
        ...(text ? { text } : {}),
      }).catch(() => {});
    },
    async download(fileId, maxBytes) {
      const f = await call("getFile", { file_id: fileId }) as
        | { file_path?: string; file_size?: number }
        | null;
      if (!f?.file_path) throw new TgError("tg_no_file");
      if ((f.file_size ?? 0) > maxBytes) throw new TgError("too_large");
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), timeoutMs);
      try {
        const res = await fetchFn(`${API}/file/bot${token}/${f.file_path}`, {
          signal: ctrl.signal,
        });
        if (!res.ok) throw new TgError(`tg_file_${res.status}`);
        const buf = new Uint8Array(await res.arrayBuffer());
        if (buf.length > maxBytes) throw new TgError("too_large");
        return buf;
      } catch (e) {
        if (e instanceof TgError) throw e;
        throw new TgError(ctrl.signal.aborted ? "tg_file_timeout" : "tg_file_network");
      } finally {
        clearTimeout(timer);
      }
    },
  };
}
