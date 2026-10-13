// Yandex SpeechKit, синхронное распознавание (API v1): голосовое из Telegram
// (OGG/Opus) → текст. До 1 МБ и 30 с, один канал.
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
