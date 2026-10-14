// Уведомление автору заявки в Telegram (шаг 24) — логика без сети.
// HTTP-обёртка — index.ts; тесты — notify_test.ts.
import { type InlineButton, NOTIFY_OFF, type ReplyMarkup } from "../telegram-bot/telegram.ts";
import { type Lang, t } from "../telegram-bot/texts.ts";

/** Ответ tg_notify_claim (0022): кому и что отправить. */
export interface Target {
  chat_id: number;
  kind: "user" | "guest" | "group";
  lang: Lang;
  number: string;
  title: string;
  status: "in_progress" | "done" | "returned" | "cancelled";
  return_reason?: string | null;
}

export interface NotifyDeps {
  /** Заявка под RLS пользователя; null — не видна. */
  readOrder(id: string): Promise<{ status: string } | null>;
  /** service_role: tg_notify_claim. */
  claim(id: string, status: string): Promise<Target | null>;
  release(id: string, status: string): Promise<void>;
  /** Последнее фото «после» под RLS пользователя; null — нет. */
  afterPhoto(id: string): Promise<Uint8Array | null>;
  send(chat: number, html: string, markup?: ReplyMarkup): Promise<unknown>;
  sendPhoto(chat: number, photo: Uint8Array, caption: string, markup?: ReplyMarkup): Promise<unknown>;
  appUrl: string;
}

export const NOTIFY_STATUSES = ["in_progress", "done", "returned", "cancelled"] as const;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function parseNotifyInput(body: unknown): { ok: true; orderId: string } | { ok: false } {
  const id = (body as { orderId?: unknown } | null)?.orderId;
  return typeof id === "string" && UUID.test(id) ? { ok: true, orderId: id.toLowerCase() } : { ok: false };
}

export function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/** Текст и кнопки уведомления. */
export function notice(tg: Target, orderId: string, appUrl: string): { html: string; markup?: ReplyMarkup } {
  const key = ({
    in_progress: "notifyInProgress",
    done: "notifyDone",
    returned: "notifyReturned",
    cancelled: "notifyCancelled",
  } as const)[tg.status];
  const title = tg.title.length > 80 ? tg.title.slice(0, 79) + "…" : tg.title;
  const lines = [esc(t(tg.lang, key, { number: tg.number, title }))];
  if (tg.status === "returned" && tg.return_reason?.trim()) {
    lines.push(esc(t(tg.lang, "notifyReason", { reason: tg.return_reason.trim() })));
  }
  const row: InlineButton[] = tg.kind === "user"
    ? [{ text: t(tg.lang, "openInApp"), url: `${appUrl}#/orders/${orderId}` }]
    : tg.kind === "guest"
    ? [{ text: t(tg.lang, "bNotifyOff"), callback_data: NOTIFY_OFF }]
    : [];
  return { html: lines.join("\n"), markup: row.length ? { inline_keyboard: [row] } : undefined };
}

export type NotifyResult =
  | "not_visible"
  | "no_status"
  | "skip"
  | "sent"
  | "sent_photo"
  | "send_failed";

/**
 * 1) заявка видна пользователю (RLS) — иначе not_visible;
 * 2) её статус в базе — из уведомляемых;
 * 3) tg_notify_claim: чат автора и отметка «уже отправлено» (повтор → skip);
 * 4) отправка; ошибка — отметка снимается (send_failed), статус не страдает.
 */
export async function notifyOrder(orderId: string, d: NotifyDeps): Promise<NotifyResult> {
  const o = await d.readOrder(orderId);
  if (!o) return "not_visible";
  if (!(NOTIFY_STATUSES as readonly string[]).includes(o.status)) return "no_status";
  const target = await d.claim(orderId, o.status);
  if (!target) return "skip";
  const { html, markup } = notice(target, orderId, d.appUrl);
  try {
    if (target.status === "done") {
      const photo = await d.afterPhoto(orderId).catch(() => null);
      if (photo) {
        await d.sendPhoto(target.chat_id, photo, html, markup);
        return "sent_photo";
      }
    }
    await d.send(target.chat_id, html, markup);
    return "sent";
  } catch {
    await d.release(orderId, o.status).catch(() => {});
    return "send_failed";
  }
}
