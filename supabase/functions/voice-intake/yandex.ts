// Вызов YandexGPT через OpenAI-совместимый API Yandex AI Studio.
// Ключи приходят из переменных окружения функции; ни ключи, ни текст заявки,
// ни ответ модели сюда не логируются.

import { type ChatMessage, RESPONSE_SCHEMA } from "./schema.ts";

export const YANDEX_URL = "https://ai.api.cloud.yandex.net/v1/chat/completions";
export const DEFAULT_MODEL = "yandexgpt/latest";
export const TIMEOUT_MS = 8000;

export interface YandexConfig {
  apiKey: string;
  folderId: string;
  /** Модель без каталога, например yandexgpt/latest. */
  model: string;
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
}

/**
 * Отправляет сообщения модели и возвращает текст ответа. Сначала — со
 * структурированным ответом (response_format: json_schema); если API его не
 * принял (400) — ещё раз без него, в пределах тех же [TIMEOUT_MS].
 */
export async function complete(
  cfg: YandexConfig,
  messages: ChatMessage[],
  fetchFn: typeof fetch = fetch,
): Promise<AiReply> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    let res = await send(cfg, messages, true, ctrl.signal, fetchFn);
    if (res.status === 400) {
      await res.body?.cancel();
      res = await send(cfg, messages, false, ctrl.signal, fetchFn);
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
  messages: ChatMessage[],
  structured: boolean,
  signal: AbortSignal,
  fetchFn: typeof fetch,
): Promise<Response> {
  const body: Record<string, unknown> = {
    model: `gpt://${cfg.folderId}/${cfg.model}`,
    messages,
    temperature: 0.1,
    max_tokens: 400,
    stream: false,
  };
  if (structured) {
    body.response_format = {
      type: "json_schema",
      json_schema: {
        name: "work_order",
        schema: RESPONSE_SCHEMA,
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
