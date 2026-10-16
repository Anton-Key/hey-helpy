// Исполнителю в Telegram: «Новая заявка» и «Взять в работу» (шаг 28, 0025).
// Логика без сети: вызывают telegram-notify (приложение назначило подрядчика)
// и бот (заявка создана в Telegram и сразу назначена). Тесты — assign_test.ts.
import { type InlineButton, NOTIFY_OFF, type ReplyMarkup } from "./telegram.ts";
import { type Lang, t, type TextKey } from "./texts.ts";

/** Кнопка «Взять в работу»: tk:<uuid заявки> (39 байт < 64). */
export const TAKE_PREFIX = "tk:";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function takeData(orderId: string): string {
  return TAKE_PREFIX + orderId;
}

/** id заявки из кнопки; null — не наша кнопка или испорчена. */
export function parseTake(data: string): string | null {
  if (!data.startsWith(TAKE_PREFIX)) return null;
  const id = data.slice(TAKE_PREFIX.length);
  return UUID.test(id) ? id.toLowerCase() : null;
}

/** Ответ tg_notify_assign_claim (0025). */
export interface AssignInfo {
  number: string;
  title: string;
  object: string | null;
  place: string | null;
  priority: string | null;
  contractor_id: string;
  targets: { chat_id: number; lang: Lang; profile_id: string }[];
}

function htmlEsc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

const PR_KEYS: Record<string, TextKey> = {
  low: "pr_low",
  normal: "pr_normal",
  high: "pr_high",
  critical: "pr_critical",
};

/**
 * «🆕 Новая заявка № 3F2A1C: Капает вода с кондиционера
 *  📍 БЦ «Демо» · 301 Переговорная · срочность высокая»
 * + кнопки «▶️ Взять в работу» / «Открыть» и «🔕 Не присылать заявки».
 */
export function assignNotice(
  info: AssignInfo,
  lang: Lang,
  orderId: string,
  appUrl: string,
): { html: string; markup: { inline_keyboard: InlineButton[][] } } {
  const title = info.title.length > 80 ? info.title.slice(0, 79) + "…" : info.title;
  const where = [info.object, info.place].filter((x): x is string => !!x && x.trim() !== "");
  const pr = info.priority && info.priority !== "normal" && PR_KEYS[info.priority]
    ? t(lang, "assignPriority", { priority: t(lang, PR_KEYS[info.priority]) })
    : null;
  const second = [...where, ...(pr ? [pr] : [])].join(" · ");
  const lines = [`<b>${htmlEsc(t(lang, "assignNew", { number: info.number, title }))}</b>`];
  if (second) lines.push(`📍 ${htmlEsc(second)}`);
  const row: InlineButton[] = [
    { text: t(lang, "bTake"), callback_data: takeData(orderId) },
    { text: t(lang, "bOpen"), url: `${appUrl}#/orders/${orderId}` },
  ];
  return {
    html: lines.join("\n"),
    markup: { inline_keyboard: [row, [{ text: t(lang, "bAssignOff"), callback_data: NOTIFY_OFF }]] },
  };
}

export interface AssignDeps {
  /** service_role: tg_notify_assign_claim; null — некому / уже отправлено. */
  claim(orderId: string, actor: string | null): Promise<AssignInfo | null>;
  release(orderId: string, contractorId: string, profileId: string): Promise<void>;
  send(chat: number, html: string, markup?: ReplyMarkup): Promise<unknown>;
  appUrl: string;
}

export interface AssignResult {
  sent: number;
  failed: number;
}

/** Разослать «Новая заявка»; ошибка одному — отметка снимается, остальным шлём. */
export async function notifyAssigned(
  orderId: string,
  actor: string | null,
  d: AssignDeps,
): Promise<AssignResult> {
  const info = await d.claim(orderId, actor);
  const res = { sent: 0, failed: 0 };
  if (!info) return res;
  for (const target of info.targets) {
    const lang: Lang = target.lang === "en" ? "en" : "ru";
    const { html, markup } = assignNotice(info, lang, orderId, d.appUrl);
    try {
      await d.send(target.chat_id, html, markup);
      res.sent++;
    } catch {
      res.failed++;
      await d.release(orderId, info.contractor_id, target.profile_id).catch(() => {});
    }
  }
  return res;
}

/** Ответ tg_take_order → ключ текста для чата. */
export function takeReply(r: { ok?: boolean; error?: string }): TextKey {
  if (r.ok) return "takeOk";
  switch (r.error) {
    case "already":
      return "takeAlready";
    case "not_linked":
      return "takeNotLinked";
    case "not_executor":
      return "takeNotExecutor";
    default:
      return "takeGone";
  }
}
