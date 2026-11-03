// Голосовое из Telegram (OGG/Opus) → текст. Поставщик — за интерфейсом
// [SpeechToText] (шаг 33), выбирает [sttFromEnv]:
//   * AI_BASE_URL + AI_API_KEY + AI_MODEL_STT — OpenAI-совместимый
//     `/audio/transcriptions` (Whisper и аналоги);
//   * иначе, как раньше, Yandex SpeechKit (синхронное API v1, до 1 МБ и 30 с).
// https://aistudio.yandex.ru/docs/ru/speechkit/stt/api/request-api.html
// Ключ — тот же YANDEX_API_KEY (сервисному аккаунту нужна роль
// ai.speechkit-stt.user); folderId с ключом сервисного аккаунта не передаётся.
// Ни звук, ни текст не логируются.

export const STT_URL = "https://stt.api.cloud.yandex.net/speech/v1/stt:recognize";
export const STT_TIMEOUT_MS = 10000;

export class SttError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

/** Звук → текст ("" — ничего не распознано). Ошибка → SttError с кодом для лога. */
export async function recognize(
  audio: Uint8Array,
  lang: "ru" | "en",
  apiKey: string,
  fetchFn: typeof fetch = fetch,
  timeoutMs = STT_TIMEOUT_MS,
): Promise<string> {
  const url = `${STT_URL}?${new URLSearchParams({
    lang: lang === "ru" ? "ru-RU" : "en-US",
    format: "oggopus",
    topic: "general",
  })}`;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetchFn(url, {
      method: "POST",
      headers: {
        "Authorization": `Api-Key ${apiKey}`,
        "Content-Type": "audio/ogg",
      },
      body: audio as Uint8Array<ArrayBuffer>,
      signal: ctrl.signal,
    });
    if (!res.ok) {
      await res.body?.cancel();
      throw new SttError(`http_${res.status}`);
    }
    const data = await res.json().catch(() => null) as { result?: unknown } | null;
    if (!data || typeof data.result !== "string") throw new SttError("bad_reply");
    return data.result.trim();
  } catch (e) {
    if (e instanceof SttError) throw e;
    throw new SttError(ctrl.signal.aborted ? "timeout" : "network");
  } finally {
    clearTimeout(timer);
  }
}

/** Распознавание речи бота: кто отвечает (в лог) и сам вызов. */
export interface SpeechToText {
  provider: "yandex" | "openai";
  recognize(audio: Uint8Array, lang: "ru" | "en"): Promise<string>;
}

/** OpenAI-совместимое распознавание: multipart `file` + `model` + `language`, ответ `{text}`. */
export async function recognizeOpenAi(
  audio: Uint8Array,
  lang: "ru" | "en",
  cfg: { baseUrl: string; apiKey: string; model: string },
  fetchFn: typeof fetch = fetch,
  timeoutMs = STT_TIMEOUT_MS,
): Promise<string> {
  const base = cfg.baseUrl.replace(/\/+$/, "");
  const form = new FormData();
  form.append("file", new Blob([audio as Uint8Array<ArrayBuffer>], { type: "audio/ogg" }), "voice.ogg");
  form.append("model", cfg.model);
  form.append("language", lang);
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetchFn(`${base}/audio/transcriptions`, {
      method: "POST",
      headers: { "Authorization": `Bearer ${cfg.apiKey}` },
      body: form,
      signal: ctrl.signal,
    });
    if (!res.ok) {
      await res.body?.cancel();
      throw new SttError(`http_${res.status}`);
    }
    const data = await res.json().catch(() => null) as { text?: unknown } | null;
    if (!data || typeof data.text !== "string") throw new SttError("bad_reply");
    return data.text.trim();
  } catch (e) {
    if (e instanceof SttError) throw e;
    throw new SttError(ctrl.signal.aborted ? "timeout" : "network");
  } finally {
    clearTimeout(timer);
  }
}

/** Поставщик распознавания из секретов; null — не настроено (бот просит написать текстом). */
export function sttFromEnv(
  env: (k: string) => string | undefined,
  fetchFn: typeof fetch = fetch,
): SpeechToText | null {
  const baseUrl = env("AI_BASE_URL")?.trim();
  const apiKey = env("AI_API_KEY")?.trim();
  const model = env("AI_MODEL_STT")?.trim();
  if (baseUrl && apiKey && model) {
    return {
      provider: "openai",
      recognize: (a, l) => recognizeOpenAi(a, l, { baseUrl, apiKey, model }, fetchFn),
    };
  }
  const yandexKey = env("YANDEX_API_KEY")?.trim();
  if (yandexKey) {
    return { provider: "yandex", recognize: (a, l) => recognize(a, l, yandexKey, fetchFn) };
  }
  return null;
}
