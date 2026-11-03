// Вызов мультимодальной модели (картинка на входе) через общий клиент
// _shared/ai.ts — тот же OpenAI-совместимый API и тот же выбор поставщика
// (шаг 33: AI_* или YANDEX_*), что у voice-intake. Ниже — модели Yandex по
// умолчанию; у другого поставщика модели задают AI_MODEL_VISION(_LITE).
//
// Модель по умолчанию — qwen3.6-35b-a3b: на 12.10.2026 единственная модель
// AI Studio, которая принимает изображения (base64, image_url с data:) —
// https://aistudio.yandex.ru/docs/ru/ai-studio/concepts/generation/models.html
// https://aistudio.yandex.ru/docs/en/ai-studio/operations/generation/multimodels-request
// Заменить — секрет YANDEX_VISION_MODEL; запасная — YANDEX_VISION_MODEL_LITE
// (по умолчанию нет: второй мультимодальной модели в каталоге нет).

import {
  type AiConfig,
  complete,
  type ModelMessage,
  PRIMARY_MS,
  type ReplyFormat,
  TIMEOUT_MS,
} from "./ai.ts";
import { VISION_SCHEMA, VISION_SCHEMA_BOX } from "./identify.ts";

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

/** Шаг 31: то же, плюс рамка оборудования («AR-метки», `box: true`). */
export const VISION_FORMAT_BOX: ReplyFormat = {
  ...VISION_FORMAT,
  name: "equipment_photo_box",
  schema: VISION_SCHEMA_BOX,
};

/**
 * Рамка от ИИ включена по умолчанию (её просит только экран «AR-метки»).
 * Выключить без выкладки кода — секрет YANDEX_VISION_BOX = off: функция не
 * просит рамку, экран ставит метку в точке прицела.
 */
export const BOX_DEFAULT = true;

export function boxEnabled(env: (k: string) => string | undefined): boolean {
  const v = env("YANDEX_VISION_BOX")?.trim().toLowerCase();
  if (v === "off" || v === "0" || v === "false" || v === "-") return false;
  if (v === "on" || v === "1" || v === "true") return true;
  return BOX_DEFAULT;
}

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
  cfg: AiConfig,
  messages: ModelMessage[],
  fetchFn: typeof fetch = fetch,
  format: ReplyFormat = VISION_FORMAT,
) {
  return complete(
    cfg,
    messages,
    fetchFn,
    visionTiming(cfg.liteModel ?? "", cfg.model),
    format,
  );
}
