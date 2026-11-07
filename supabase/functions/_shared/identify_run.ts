// Один проход «снимок → ответ» — общий для photo-identify (пользователь) и
// recognition-eval (тест точности, шаг 34). Тест обязан идти тем же путём:
// те же подсказка, модель, справочники под RLS пользователя и сопоставление с
// реестром. Разница только в том, куда пишется результат.

import {
  buildResult,
  buildVisionMessages,
  CANDIDATES_MAX,
  type IdentifyInput,
  type IdentifyResult,
  normalizeVision,
  POINTS,
  stripThinking,
  VISION_PROMPT,
  VISION_SCHEMA,
} from "./identify.ts";
import { parseModelJson } from "./intake.ts";
import { KINDS } from "./kinds.ts";
import { loadAssets, loadLayers, resolveHere } from "./registry.ts";
import { callVision, VISION_FORMAT, VISION_FORMAT_BOX } from "./vision.ts";
import { type AiConfig, AiError } from "./ai.ts";

// deno-lint-ignore no-explicit-any
type Db = any;
type Log = (fields: Record<string, unknown>) => void;

export type IdentifyOutcome =
  | {
    ok: true;
    result: IdentifyResult;
    /** "main" | "lite" — какая модель ответила. */
    model: "main" | "lite";
    log: Record<string, unknown>;
  }
  | {
    ok: false;
    /** Код для ответа 502 и журнала: invalid_json, timeout, http_5xx… */
    code: string;
    log: Record<string, unknown>;
  };

/** Снимок → вид, система, шильдик и кандидаты из реестра (под RLS [db]). */
export async function identifyPhoto(
  db: Db,
  aiCfg: AiConfig,
  input: IdentifyInput,
  opts: { box: boolean; log: Log; fetchFn?: typeof fetch },
): Promise<IdentifyOutcome> {
  const { box, log } = opts;
  // Справочники читаем, пока модель смотрит на снимок.
  const layers = await loadLayers(db, log);
  const registry = (async () => {
    const here = await resolveHere(db, input);
    return { here, assets: await loadAssets(db, here, log) };
  })().catch(() => {
    log({ code: "registry_failed" });
    return { here: {}, assets: [] };
  });

  try {
    const aiStarted = Date.now();
    const ai = await callVision(
      aiCfg,
      buildVisionMessages(input, layers, { box }),
      opts.fetchFn ?? fetch,
      box ? VISION_FORMAT_BOX : VISION_FORMAT,
    );
    const aiMs = Date.now() - aiStarted;
    const model: "main" | "lite" = ai.model === "pro" ? "main" : "lite";
    const which = {
      provider: aiCfg.provider,
      model,
      first: ai.primaryError,
      first_error: ai.primaryDetail,
      format: ai.format,
    };
    const raw = parseModelJson(stripThinking(ai.content));
    if (!raw) {
      return {
        ok: false,
        code: "invalid_json",
        log: {
          bytes: input.bytes,
          tokens: ai.totalTokens,
          ai_ms: aiMs,
          ...which,
        },
      };
    }
    const { here, assets } = await registry;
    const result = buildResult(
      normalizeVision(raw, layers, { box }),
      assets,
      here,
      input.locale,
    );
    return {
      ok: true,
      result,
      model,
      log: {
        ...which,
        bytes: input.bytes,
        mime: input.mime,
        tokens: ai.totalTokens,
        ai_ms: aiMs,
        assets: assets.length,
        candidates: result.candidates.length,
        kind: result.kind,
        plate: result.nameplate !== null,
        // Шаг 31: только есть ли рамка (без координат).
        box: box ? (result.box ? "yes" : "no") : undefined,
      },
    };
  } catch (e) {
    const code = e instanceof AiError ? e.code : "unexpected";
    return {
      ok: false,
      code,
      log: {
        code,
        provider: aiCfg.provider,
        bytes: input.bytes,
        // Только error.code / error.message ответа API, без base64 (≤ 300).
        ai_error: e instanceof AiError ? e.detail : undefined,
        tried: e instanceof AiError ? e.tried : undefined,
      },
    };
  }
}

/**
 * Версия «правил распознавания» для отчёта: SHA-256 от подсказки, схемы
 * ответа, каталога видов, баллов сопоставления и языка. Справочники компании
 * (системы, оборудование) — данные, в хеш не входят.
 */
export async function promptHash(locale: string): Promise<string> {
  const source = JSON.stringify({
    prompt: VISION_PROMPT,
    schema: VISION_SCHEMA,
    kinds: KINDS.map((k) => k.code),
    points: POINTS,
    candidates: CANDIDATES_MAX,
    locale,
  });
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(source),
  );
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
