// recognition-eval (шаг 34): чистые функции — разбор запроса, выбор
// поставщика, ответ распознавания → строка результата. Без сети и окружения
// (тесты — eval_test.ts).

import type { IdentifyResult } from "../_shared/identify.ts";
import { type AiConfig, aiFromEnv, type AiProvider } from "../_shared/ai.ts";
import { visionModels } from "../_shared/vision.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Язык подсказки в тесте — всегда английский (входит в хеш подсказки). */
export const EVAL_LOCALE = "en" as const;

export type EvalRequest =
  | { action: "providers" }
  | { action: "run"; runId: string; sampleId: string }
  | { action: "report"; runId: string };

export function parseEvalRequest(
  body: unknown,
): { ok: true; value: EvalRequest } | { ok: false; error: string } {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return { ok: false, error: "bad_request" };
  }
  const b = body as Record<string, unknown>;
  const id = (v: unknown) => typeof v === "string" && UUID.test(v);
  switch (b.action) {
    case "providers":
      return { ok: true, value: { action: "providers" } };
    case "run":
      if (!id(b.runId) || !id(b.sampleId)) {
        return { ok: false, error: "bad_request" };
      }
      return {
        ok: true,
        value: {
          action: "run",
          runId: b.runId as string,
          sampleId: b.sampleId as string,
        },
      };
    case "report":
      if (!id(b.runId)) return { ok: false, error: "bad_request" };
      return {
        ok: true,
        value: { action: "report", runId: b.runId as string },
      };
    default:
      return { ok: false, error: "bad_request" };
  }
}

type Env = (k: string) => string | undefined;

/**
 * Настроенные поставщики для картинок. "default" — тот же, что у
 * пользователей photo-identify (AI_*, если заданы, иначе Yandex). Если заданы
 * оба — можно сравнить их на одном наборе.
 */
export function visionConfigs(env: Env): {
  default: AiConfig | null;
  yandex: AiConfig | null;
  openai: AiConfig | null;
} {
  const models = visionModels(env);
  const def = aiFromEnv(env, "vision", models);
  const onlyYandex: Env = (k) => k.startsWith("AI_") ? undefined : env(k);
  const yandex = aiFromEnv(onlyYandex, "vision", models);
  const openai = def?.provider === "openai" ? def : null;
  return { default: def, yandex, openai };
}

export function pickConfig(
  env: Env,
  requested: string,
): AiConfig | null {
  const all = visionConfigs(env);
  if (requested === "yandex") return all.yandex;
  if (requested === "openai") return all.openai;
  return all.default;
}

/** Список для приложения: только имена поставщиков и моделей, без ключей. */
export function providerList(env: Env): {
  id: "default" | AiProvider;
  provider: AiProvider;
  model: string;
}[] {
  const all = visionConfigs(env);
  const out: {
    id: "default" | AiProvider;
    provider: AiProvider;
    model: string;
  }[] = [];
  if (all.default) {
    out.push({
      id: "default",
      provider: all.default.provider ?? "yandex",
      model: all.default.model,
    });
  }
  if (all.openai && all.default?.provider !== "openai") {
    out.push({ id: "openai", provider: "openai", model: all.openai.model });
  }
  if (all.yandex && (all.default?.provider ?? "yandex") !== "yandex") {
    out.push({ id: "yandex", provider: "yandex", model: all.yandex.model });
  }
  return out;
}

/** Строка результата (p_result функции recognition_eval_put_result). */
export interface ResultRow {
  predicted_equipment_id: string | null;
  candidates: { asset_id: string; score: number }[];
  confidence: number | null;
  model_confidence: number | null;
  predicted_kind: string | null;
  no_equipment: boolean;
  abstained: boolean;
  ms: number;
  tokens: number | null;
  cost_usd: null;
  model_tag: "main" | "lite" | null;
  error: string | null;
}

/**
 * Ответ распознавания → строка результата. «Не знаю» — кандидатов нет (в
 * кадре нет оборудования или в реестре ничего не подошло). Уверенность —
 * балл первого кандидата (как его видит человек на экране «Скорее всего»).
 * Стоимость поставщики в ответе не сообщают — null (токены пишем).
 */
export function toResultRow(
  r: IdentifyResult,
  meta: { ms: number; tokens: number | null; model: "main" | "lite" },
): ResultRow {
  const cands = r.candidates.slice(0, 3).map((c) => ({
    asset_id: c.asset_id,
    score: c.score,
  }));
  return {
    predicted_equipment_id: cands[0]?.asset_id ?? null,
    candidates: cands,
    confidence: cands[0]?.score ?? null,
    model_confidence: r.confidence,
    predicted_kind: r.no_equipment ? null : r.kind,
    no_equipment: r.no_equipment,
    abstained: cands.length === 0,
    ms: meta.ms,
    tokens: meta.tokens,
    cost_usd: null,
    model_tag: meta.model,
    error: null,
  };
}

export function errorRow(code: string, ms: number): ResultRow {
  const safe = /^[a-z_]{1,40}$/.test(code) ? code : "unexpected";
  return {
    predicted_equipment_id: null,
    candidates: [],
    confidence: null,
    model_confidence: null,
    predicted_kind: null,
    no_equipment: false,
    abstained: false,
    ms,
    tokens: null,
    cost_usd: null,
    model_tag: null,
    error: safe,
  };
}

/** Base64 без переполнения стека на больших снимках. */
export function toBase64(bytes: Uint8Array): string {
  let s = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    s += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(s);
}
