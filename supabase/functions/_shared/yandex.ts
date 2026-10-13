// Вызов моделей Yandex AI Studio через OpenAI-совместимый API — общий для
// voice-intake (YandexGPT, текст) и photo-identify (мультимодальная модель,
// картинка). Ключи приходят из переменных окружения функции; ни ключи, ни
// текст заявки, ни фото, ни ответ модели сюда не логируются.

import { RESPONSE_SCHEMA } from "./intake.ts";

/** Часть сообщения: текст или картинка (мультимодальная модель, OpenAI-формат). */
export type ContentPart =
  | { type: "text"; text: string }
  | { type: "image_url"; image_url: { url: string } };

/** Сообщение модели: текст (YandexGPT) или части с картинкой. */
export interface ModelMessage {
  role: "system" | "user";
  content: string | ContentPart[];
}

/** Структурированный ответ: имя и JSON Schema (response_format), лимит токенов. */
export interface ReplyFormat {
  name: string;
  schema: unknown;
  maxTokens: number;
}

/** Формат ответа voice-intake (по умолчанию — как до шага 22). */
export const INTAKE_FORMAT: ReplyFormat = {
  name: "work_order",
  schema: RESPONSE_SCHEMA,
  maxTokens: 400,
};

export const YANDEX_URL = "https://ai.api.cloud.yandex.net/v1/chat/completions";
export const DEFAULT_MODEL = "yandexgpt/latest";
/** Запасная модель: быстрее, отвечает, когда основная не успела. */
export const LITE_MODEL = "yandexgpt-lite/latest";
/** Всё время на ИИ (обе попытки). Приложение ждёт функцию 16 с. */
export const TIMEOUT_MS = 14000;
/** Сколько ждём основную модель, прежде чем спросить запасную. */
export const PRIMARY_MS = 7000;
/** Меньше этого на запасную модель не остаётся — не пробуем. */
const MIN_RETRY_MS = 1000;

export interface YandexConfig {
  apiKey: string;
  folderId: string;
  /** Модель без каталога, например yandexgpt/latest. */
  model: string;
  /** Запасная модель (по умолчанию [LITE_MODEL]); "" — без повтора. */
  liteModel?: string;
}

/** Какая модель ответила — в ответ функции и в лог (без текста заявки). */
export type ModelTag = "pro" | "lite";

export interface Timing {
  totalMs: number;
  primaryMs: number;
}

/** Ошибка вызова модели: код для логов, без деталей ответа и ключей. */
export class AiError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

export interface AiReply {
  content: string;
  totalTokens: number | null;
  model: ModelTag;
  /** Код ошибки основной модели, если ответила запасная. */
  primaryError?: string;
}

/** Ошибки, после которых есть смысл спросить запасную модель. */
function retryable(code: string): boolean {
  return code === "timeout" || code === "network" ||
    code === "empty_reply" || /^http_5\d\d$/.test(code);
}

/**
 * Основная модель ждёт до [Timing.primaryMs]; не ответила, вернула 5xx,
 * пустой ответ или нет сети — один повтор на запасной модели с оставшимся до
 * [Timing.totalMs] временем. 4xx (ключ, каталог) не повторяем — запасная
 * упадёт так же. Обе не ответили — [AiError] запасной (обычно "timeout").
 */
export async function complete(
  cfg: YandexConfig,
  messages: ModelMessage[],
  fetchFn: typeof fetch = fetch,
  timing: Timing = { totalMs: TIMEOUT_MS, primaryMs: PRIMARY_MS },
  format: ReplyFormat = INTAKE_FORMAT,
): Promise<AiReply> {
  const started = Date.now();
  const lite = cfg.liteModel ?? LITE_MODEL;
  try {
    const r = await completeOne(
      cfg,
      cfg.model,
      messages,
      fetchFn,
      Math.min(timing.primaryMs, timing.totalMs),
      format,
    );
    return { ...r, model: "pro" };
  } catch (e) {
    const code = e instanceof AiError ? e.code : "unexpected";
    const left = timing.totalMs - (Date.now() - started);
    if (
      !lite || lite === cfg.model || !retryable(code) || left < MIN_RETRY_MS
    ) {
      throw e;
    }
    const r = await completeOne(cfg, lite, messages, fetchFn, left, format);
    return { ...r, model: "lite", primaryError: code };
  }
}

/**
 * Один запрос к модели [model] с ограничением [timeoutMs]. Сначала — со
 * структурированным ответом (response_format: json_schema); если API его не
 * принял (400) — ещё раз без него, в пределах того же времени.
 */
async function completeOne(
  cfg: YandexConfig,
  model: string,
  messages: ModelMessage[],
  fetchFn: typeof fetch,
  timeoutMs: number,
  format: ReplyFormat,
): Promise<{ content: string; totalTokens: number | null }> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    let res = await send(
      cfg,
      model,
      messages,
      format,
      true,
      ctrl.signal,
      fetchFn,
    );
    if (res.status === 400) {
      await res.body?.cancel();
      res = await send(
        cfg,
        model,
        messages,
        format,
        false,
        ctrl.signal,
        fetchFn,
      );
    }
    if (!res.ok) {
      await res.body?.cancel();
      throw new AiError(`http_${res.status}`);
    }
    const data = await res.json().catch(() => null);
    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) {
      throw new AiError("empty_reply");
    }
    const total = data?.usage?.total_tokens;
    return {
      content,
      totalTokens: typeof total === "number" ? total : null,
    };
  } catch (e) {
    if (e instanceof AiError) throw e;
    throw new AiError(ctrl.signal.aborted ? "timeout" : "network");
  } finally {
    clearTimeout(timer);
  }
}

function send(
  cfg: YandexConfig,
  model: string,
  messages: ModelMessage[],
  format: ReplyFormat,
  structured: boolean,
  signal: AbortSignal,
  fetchFn: typeof fetch,
): Promise<Response> {
  const body: Record<string, unknown> = {
    model: `gpt://${cfg.folderId}/${model}`,
    messages,
    temperature: 0.1,
    max_tokens: format.maxTokens,
    stream: false,
  };
  if (structured) {
    body.response_format = {
      type: "json_schema",
      json_schema: {
        name: format.name,
        schema: format.schema,
        strict: true,
      },
    };
  }
  return fetchFn(YANDEX_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Api-Key ${cfg.apiKey}`,
      "OpenAI-Project": cfg.folderId,
    },
    body: JSON.stringify(body),
    signal,
  });
}
