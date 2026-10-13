// Вызов мультимодальной модели Yandex AI Studio (картинка на входе) через
// общий клиент _shared/yandex.ts — тот же OpenAI-совместимый API и те же
// секреты YANDEX_API_KEY / YANDEX_FOLDER_ID, что у voice-intake.
//
// Модель по умолчанию — qwen3.6-35b-a3b: на 12.10.2026 единственная модель
// AI Studio, которая принимает изображения (base64, image_url с data:) —
// https://aistudio.yandex.ru/docs/ru/ai-studio/concepts/generation/models.html
// https://aistudio.yandex.ru/docs/en/ai-studio/operations/generation/multimodels-request
// Заменить — секрет YANDEX_VISION_MODEL; запасная — YANDEX_VISION_MODEL_LITE
// (по умолчанию нет: второй мультимодальной модели в каталоге нет).

import {
  complete,
  type ModelMessage,
  PRIMARY_MS,
  type ReplyFormat,
  TIMEOUT_MS,
} from "./yandex.ts";
import { VISION_SCHEMA } from "./identify.ts";

export const DEFAULT_VISION_MODEL = "qwen3.6-35b-a3b";
export const DEFAULT_VISION_LITE = "";

export const VISION_FORMAT: ReplyFormat = {
  name: "equipment_photo",
  schema: VISION_SCHEMA,
  // С запасом: рассуждающая модель может потратить часть ответа на <think>.
  maxTokens: 1000,
  // 12.10.2026 рабочий запрос отклонялся (400) и с response_format, и без
  // него — пробуем json_object и запрос как в официальном примере.
  ladder: true,
};

/** Модели из окружения: "-" в запасной — без повтора. */
export function visionModels(
  env: (k: string) => string | undefined,
): { model: string; liteModel: string } {
  const model = env("YANDEX_VISION_MODEL")?.trim() || DEFAULT_VISION_MODEL;
  const liteEnv = env("YANDEX_VISION_MODEL_LITE")?.trim();
  const liteModel = liteEnv === "-" ? "" : (liteEnv || DEFAULT_VISION_LITE);
  return { model, liteModel };
}

/**
 * Как в шаге 20: основная ждёт ≤ 7 с, затем один повтор на запасной, всего
 * ≤ 14 с. Без запасной модели основной отдаём все 14 с — повторять некому.
 */
export function visionTiming(liteModel: string, model: string) {
  const retry = !!liteModel && liteModel !== model;
  return { totalMs: TIMEOUT_MS, primaryMs: retry ? PRIMARY_MS : TIMEOUT_MS };
}

export function callVision(
  cfg: { apiKey: string; folderId: string; model: string; liteModel: string },
  messages: ModelMessage[],
  fetchFn: typeof fetch = fetch,
) {
  return complete(
    cfg,
    messages,
    fetchFn,
    visionTiming(cfg.liteModel, cfg.model),
    VISION_FORMAT,
  );
}
