// Вызов ИИ-моделей через OpenAI-совместимый API — общий для voice-intake
// (текст), photo-identify (картинка) и бота. Поставщик выбирается секретами
// (шаг 33, [aiFromEnv]):
//   * заданы AI_BASE_URL + AI_API_KEY + AI_MODEL_TEXT / AI_MODEL_VISION — любой
//     OpenAI-совместимый поставщик (для клиентов в США и ЕС);
//   * не заданы — как раньше: Yandex AI Studio (YANDEX_API_KEY, YANDEX_FOLDER_ID).
// Ключи приходят из переменных окружения функции; ни ключи, ни текст заявки,
// ни фото, ни ответ модели сюда не логируются. В лог — только `provider`.

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
  /**
   * Лестница попыток на 400 (мультимодальная модель): json_schema →
   * json_object → только `model` и `messages`, как в официальном примере.
   * Без неё (YandexGPT, текст) — как раньше: json_schema → без response_format.
   */
  ladder?: boolean;
}

/**
 * На какой ступени ответила модель: строгая схема, просто JSON, без формата.
 * "bare" — текстовый откат (без response_format, но с max_tokens и temperature).
 */
export type FormatStep = "schema" | "object" | "plain" | "bare";

const LADDER: FormatStep[] = ["schema", "object", "plain"];
const TEXT_STEPS: FormatStep[] = ["schema", "bare"];

/** Формат ответа voice-intake (по умолчанию — как до шага 22). */
export const INTAKE_FORMAT: ReplyFormat = {
  name: "work_order",
  schema: RESPONSE_SCHEMA,
  maxTokens: 400,
};

export const YANDEX_URL = "https://ai.api.cloud.yandex.net/v1/chat/completions";

/** Кто отвечает: Yandex AI Studio (по умолчанию) или OpenAI-совместимый API по AI_BASE_URL. */
export type AiProvider = "yandex" | "openai";
export const DEFAULT_MODEL = "yandexgpt/latest";
/** Запасная модель: быстрее, отвечает, когда основная не успела. */
export const LITE_MODEL = "yandexgpt-lite/latest";
/** Всё время на ИИ (обе попытки). Приложение ждёт функцию 16 с. */
export const TIMEOUT_MS = 14000;
/** Сколько ждём основную модель, прежде чем спросить запасную. */
export const PRIMARY_MS = 7000;
/** Меньше этого на запасную модель не остаётся — не пробуем. */
const MIN_RETRY_MS = 1000;

export interface AiConfig {
  /** Не задан — "yandex" (как до шага 33). */
  provider?: AiProvider;
  apiKey: string;
  /** Только Yandex: каталог AI Studio. */
  folderId?: string;
  /** Только openai: адрес API, например https://api.openai.com/v1. */
  baseUrl?: string;
  /** Yandex — без каталога (yandexgpt/latest); openai — как у поставщика. */
  model: string;
  /** Запасная модель (по умолчанию [LITE_MODEL] у Yandex); "" — без повтора. */
  liteModel?: string;
}

/** Прежнее имя (до шага 33). */
export type YandexConfig = AiConfig;

/** "-" или пусто в запасной модели — без повтора. */
function liteFrom(v: string | undefined, fallback: string): string {
  const t = v?.trim();
  return t === "-" ? "" : (t || fallback);
}

/**
 * Настройки модели из секретов функции. [kind] — текст (разбор заявки) или
 * картинка (узнавание оборудования). null — ИИ не настроен (функция отвечает
 * 500 not_configured, бот — без ИИ).
 *
 * 1) AI_BASE_URL и AI_API_KEY заданы → OpenAI-совместимый поставщик; модели —
 *    AI_MODEL_TEXT / AI_MODEL_TEXT_LITE или AI_MODEL_VISION /
 *    AI_MODEL_VISION_LITE (основная обязательна, запасная — нет, "-" — без).
 * 2) Иначе — Yandex AI Studio, как было: YANDEX_API_KEY, YANDEX_FOLDER_ID,
 *    модели YANDEX_MODEL(_LITE) или [vision] (YANDEX_VISION_MODEL(_LITE)).
 */
export function aiFromEnv(
  env: (k: string) => string | undefined,
  kind: "text" | "vision",
  vision?: { model: string; liteModel: string },
): AiConfig | null {
  const baseUrl = env("AI_BASE_URL")?.trim();
  const key = env("AI_API_KEY")?.trim();
  if (baseUrl && key) {
    const name = kind === "text" ? "AI_MODEL_TEXT" : "AI_MODEL_VISION";
    const model = env(name)?.trim();
    if (!model) return null;
    return {
      provider: "openai",
      apiKey: key,
      baseUrl,
      model,
      liteModel: liteFrom(env(`${name}_LITE`), ""),
    };
  }
  const apiKey = env("YANDEX_API_KEY")?.trim();
  const folderId = env("YANDEX_FOLDER_ID")?.trim();
  if (!apiKey || !folderId) return null;
  if (kind === "vision" && vision) {
    return { provider: "yandex", apiKey, folderId, ...vision };
  }
  return {
    provider: "yandex",
    apiKey,
    folderId,
    model: env("YANDEX_MODEL")?.trim() || DEFAULT_MODEL,
    liteModel: liteFrom(env("YANDEX_MODEL_LITE"), LITE_MODEL),
  };
}

/** Адрес запроса: у openai — `<AI_BASE_URL>/chat/completions` (если не указан целиком). */
export function chatUrl(cfg: AiConfig): string {
  if (cfg.provider !== "openai") return YANDEX_URL;
  const base = (cfg.baseUrl ?? "").replace(/\/+$/, "");
  return base.endsWith("/chat/completions") ? base : `${base}/chat/completions`;
}

/** Какая модель ответила — в ответ функции и в лог (без текста заявки). */
export type ModelTag = "pro" | "lite";

export interface Timing {
  totalMs: number;
  primaryMs: number;
}

/**
 * Ошибка вызова модели: код для логов. [detail] — для поля лога `ai_error`:
 * только `error.code` / `error.message` из ответа API (см. [aiErrorDetail]).
 * [tried] — ступени формата с HTTP-кодом каждой («schema:400»).
 */
export class AiError extends Error {
  constructor(
    readonly code: string,
    readonly detail?: string,
    readonly tried: string[] = [],
  ) {
    super(code);
  }
}

/** Всё без пробелов длиннее 100 знаков (base64 снимка, токены) — вырезаем. */
const LONG_RUN = /\S{101,}/g;
const MAX_DETAIL = 300;

/**
 * Из тела ответа не 2xx — только `error.code` и `error.message` (или
 * `message`), без base64 и не длиннее 300 знаков. Тело запроса сюда не
 * попадает. Не JSON или нет полей — "non_json" / undefined.
 */
export function aiErrorDetail(bodyText: string): string | undefined {
  if (!bodyText.trim()) return undefined;
  let data: unknown;
  try {
    data = JSON.parse(bodyText);
  } catch {
    return "non_json";
  }
  if (typeof data !== "object" || data === null) return "non_json";
  // deno-lint-ignore no-explicit-any
  const d = data as any;
  const err = typeof d.error === "object" && d.error !== null ? d.error : {};
  const pick = (v: unknown) =>
    typeof v === "string" || typeof v === "number" ? String(v) : "";
  const code = pick(err.code ?? err.grpcCode ?? err.type);
  const message = pick(
    err.message ?? d.message ??
      (typeof d.error === "string" ? d.error : undefined),
  );
  const text = [code, message].filter(Boolean).join(": ");
  if (!text) return undefined;
  return sanitizeDetail(text);
}

export function sanitizeDetail(text: string): string {
  // deno-lint-ignore no-control-regex
  const t = text.replace(LONG_RUN, "[…]").replace(/[\u0000-\u001f]+/g, " ")
    .trim();
  return t.length > MAX_DETAIL ? t.slice(0, MAX_DETAIL - 1) + "…" : t;
}

export interface AiReply {
  content: string;
  totalTokens: number | null;
  model: ModelTag;
  /** Код ошибки основной модели, если ответила запасная. */
  primaryError?: string;
  /** Подробность ошибки основной модели (как `ai_error`). */
  primaryDetail?: string;
  /** На какой ступени формата ответили — в лог (`format`). */
  format: FormatStep;
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
  cfg: AiConfig,
  messages: ModelMessage[],
  fetchFn: typeof fetch = fetch,
  timing: Timing = { totalMs: TIMEOUT_MS, primaryMs: PRIMARY_MS },
  format: ReplyFormat = INTAKE_FORMAT,
): Promise<AiReply> {
  const started = Date.now();
  const lite = cfg.liteModel ??
    (cfg.provider === "openai" ? "" : LITE_MODEL);
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
    return {
      ...r,
      model: "lite",
      primaryError: code,
      primaryDetail: e instanceof AiError ? e.detail : undefined,
    };
  }
}

/**
 * Один запрос к модели [model] с ограничением [timeoutMs]. Сначала — со
 * структурированным ответом (response_format: json_schema); если API его не
 * принял (400) — следующая ступень ([LADDER] или [TEXT_STEPS]) в пределах
 * того же времени.
 */
async function completeOne(
  cfg: AiConfig,
  model: string,
  messages: ModelMessage[],
  fetchFn: typeof fetch,
  timeoutMs: number,
  format: ReplyFormat,
): Promise<
  { content: string; totalTokens: number | null; format: FormatStep }
> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  const steps = format.ladder ? LADDER : TEXT_STEPS;
  const tried: string[] = [];
  let detail: string | undefined;
  try {
    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      const res = await send(
        cfg,
        model,
        messages,
        format,
        step,
        ctrl.signal,
        fetchFn,
      );
      if (!res.ok) {
        tried.push(`${step}:${res.status}`);
        detail = aiErrorDetail(await res.text().catch(() => ""));
        if (res.status === 400 && i < steps.length - 1) continue;
        throw new AiError(`http_${res.status}`, detail, tried);
      }
      const data = await res.json().catch(() => null);
      const content = data?.choices?.[0]?.message?.content;
      if (typeof content !== "string" || !content.trim()) {
        throw new AiError("empty_reply", detail, [...tried, `${step}:200`]);
      }
      const total = data?.usage?.total_tokens;
      return {
        content,
        totalTokens: typeof total === "number" ? total : null,
        format: step,
      };
    }
    throw new AiError("unexpected", detail, tried);
  } catch (e) {
    if (e instanceof AiError) throw e;
    throw new AiError(
      ctrl.signal.aborted ? "timeout" : "network",
      detail,
      tried,
    );
  } finally {
    clearTimeout(timer);
  }
}

function send(
  cfg: AiConfig,
  model: string,
  messages: ModelMessage[],
  format: ReplyFormat,
  step: FormatStep,
  signal: AbortSignal,
  fetchFn: typeof fetch,
): Promise<Response> {
  const openai = cfg.provider === "openai";
  const body: Record<string, unknown> = {
    model: openai ? model : `gpt://${cfg.folderId}/${model}`,
    messages,
  };
  if (step !== "plain") {
    body.temperature = 0.1;
    body.max_tokens = format.maxTokens;
    body.stream = false;
  }
  if (step === "object") {
    body.response_format = { type: "json_object" };
  } else if (step === "schema") {
    body.response_format = {
      type: "json_schema",
      json_schema: {
        name: format.name,
        schema: format.schema,
        strict: true,
      },
    };
  }
  const headers: Record<string, string> = openai
    ? { "Content-Type": "application/json", "Authorization": `Bearer ${cfg.apiKey}` }
    : {
      "Content-Type": "application/json",
      "Authorization": `Api-Key ${cfg.apiKey}`,
      "OpenAI-Project": cfg.folderId ?? "",
    };
  return fetchFn(chatUrl(cfg), {
    method: "POST",
    headers,
    body: JSON.stringify(body),
    signal,
  });
}
