// Проверка вебхука бота для экрана «Готовность к показу» (шаг 29).
//   POST { kind: "webhook" } → 200 { webhook: { configured, pending, last_error_age_s } }
// Только администратор компании (роль читается под RLS). Наружу — только эти три поля:
// без токена, без адреса вебхука и без текста ошибки Telegram.

export interface WebhookInfo {
  url?: string;
  pending_update_count?: number;
  last_error_date?: number;
}

export interface WebhookSummary {
  /** Вебхук указывает на нашу функцию telegram-bot этого проекта. */
  configured: boolean;
  /** Сколько обновлений Telegram ждут доставки. */
  pending: number;
  /** Сколько секунд назад была последняя ошибка доставки (null — ошибок не было). */
  last_error_age_s: number | null;
}

export function isWebhookCheck(body: unknown): boolean {
  return (body as { kind?: unknown } | null)?.kind === "webhook";
}

export function webhookSummary(info: WebhookInfo, supabaseUrl: string, nowSec: number): WebhookSummary {
  const expected = `${supabaseUrl.replace(/\/+$/, "")}/functions/v1/telegram-bot`;
  const age = info.last_error_date ? Math.max(0, nowSec - info.last_error_date) : null;
  return {
    configured: (info.url ?? "") === expected,
    pending: Math.max(0, Number(info.pending_update_count ?? 0) || 0),
    last_error_age_s: age,
  };
}

/** getWebhookInfo — токен только в адресе запроса к Telegram, наружу не отдаётся. */
export async function getWebhookInfo(
  token: string,
  fetchFn: typeof fetch = fetch,
  timeoutMs = 8000,
): Promise<WebhookInfo> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetchFn(`https://api.telegram.org/bot${token}/getWebhookInfo`, { signal: ctrl.signal });
    const data = await res.json().catch(() => null) as { ok?: boolean; result?: WebhookInfo } | null;
    if (!res.ok || !data?.ok || !data.result) throw new Error(`tg_getWebhookInfo_${res.status}`);
    return data.result;
  } finally {
    clearTimeout(timer);
  }
}
