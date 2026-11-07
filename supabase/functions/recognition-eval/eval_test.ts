// Тесты recognition-eval (шаг 34): запрос, поставщики, строка результата,
// хеш подсказки. Без сети.

import { assert, assertEquals, assertMatch } from "jsr:@std/assert@1";
import {
  errorRow,
  parseEvalRequest,
  pickConfig,
  providerList,
  toBase64,
  toResultRow,
} from "./eval.ts";
import { promptHash } from "../_shared/identify_run.ts";
import type { IdentifyResult } from "../_shared/identify.ts";

const ID = "de300000-0000-4000-8000-000000000708";

Deno.test("parseEvalRequest", () => {
  assertEquals(parseEvalRequest({ action: "providers" }), {
    ok: true,
    value: { action: "providers" },
  });
  assert(parseEvalRequest({ action: "run", runId: ID, sampleId: ID }).ok);
  assert(!parseEvalRequest({ action: "run", runId: ID }).ok);
  assert(!parseEvalRequest({ action: "run", runId: "x", sampleId: ID }).ok);
  assert(parseEvalRequest({ action: "report", runId: ID }).ok);
  assert(!parseEvalRequest({ action: "drop" }).ok);
  assert(!parseEvalRequest(null).ok);
  assert(!parseEvalRequest([]).ok);
});

const yandexOnly: Record<string, string> = {
  YANDEX_API_KEY: "k",
  YANDEX_FOLDER_ID: "f",
};
const both: Record<string, string> = {
  ...yandexOnly,
  AI_BASE_URL: "https://api.example.com/v1",
  AI_API_KEY: "k2",
  AI_MODEL_VISION: "vision-1",
};

Deno.test("поставщики: только Yandex", () => {
  const env = (k: string) => yandexOnly[k];
  const list = providerList(env);
  assertEquals(list.map((p) => [p.id, p.provider]), [["default", "yandex"]]);
  assertEquals(pickConfig(env, "default")?.provider, "yandex");
  assertEquals(pickConfig(env, "openai"), null);
  // Ключи в список не попадают.
  assert(!JSON.stringify(list).includes('"k"'));
});

Deno.test("поставщики: оба — можно сравнить", () => {
  const env = (k: string) => both[k];
  const list = providerList(env);
  assertEquals(list.map((p) => [p.id, p.provider, p.model]), [
    ["default", "openai", "vision-1"],
    ["yandex", "yandex", "qwen3.6-35b-a3b"],
  ]);
  assertEquals(pickConfig(env, "default")?.provider, "openai");
  assertEquals(pickConfig(env, "yandex")?.provider, "yandex");
  assertEquals(pickConfig(env, "openai")?.model, "vision-1");
  assert(!JSON.stringify(list).includes("k2"));
});

Deno.test("поставщики: ничего не настроено", () => {
  assertEquals(providerList(() => undefined), []);
  assertEquals(pickConfig(() => undefined, "default"), null);
});

function identify(
  cands: [string, number][],
  extra: Partial<IdentifyResult> = {},
): IdentifyResult {
  return {
    source: "ai",
    kind: "ac",
    kind_label: "Air conditioner",
    layer_id: null,
    layer: null,
    nameplate: null,
    defect: null,
    confidence: 0.9,
    no_equipment: false,
    candidates: cands.map(([asset_id, score]) => ({
      asset_id,
      name: asset_id,
      location_id: "L",
      location_label: "L",
      floor_label: null,
      score,
      reasons: [],
      reason_text: "",
    })),
    ...extra,
  };
}

Deno.test("toResultRow: первый кандидат, уверенность — его балл", () => {
  const r = toResultRow(identify([["A", 0.75], ["B", 0.45], ["C", 0.35]]), {
    ms: 3200,
    tokens: 1100,
    model: "main",
  });
  assertEquals(r.predicted_equipment_id, "A");
  assertEquals(r.confidence, 0.75);
  assertEquals(r.model_confidence, 0.9);
  assertEquals(r.candidates.length, 3);
  assertEquals(r.abstained, false);
  assertEquals(r.error, null);
  assertEquals(r.cost_usd, null);
});

Deno.test("toResultRow: «не знаю» и «нет оборудования»", () => {
  const none = toResultRow(identify([]), {
    ms: 1,
    tokens: null,
    model: "lite",
  });
  assertEquals(none.abstained, true);
  assertEquals(none.predicted_equipment_id, null);
  const noEq = toResultRow(
    identify([], { no_equipment: true, kind: "other" }),
    {
      ms: 1,
      tokens: null,
      model: "main",
    },
  );
  assertEquals(noEq.no_equipment, true);
  assertEquals(noEq.predicted_kind, null);
});

Deno.test("errorRow: только безопасный код", () => {
  assertEquals(errorRow("timeout", 14000).error, "timeout");
  assertEquals(errorRow("http 500 <html>", 1).error, "unexpected");
});

Deno.test("toBase64: большой снимок без переполнения стека", () => {
  const bytes = new Uint8Array(300_000).map((_, i) => i % 256);
  const b64 = toBase64(bytes);
  assertEquals(atob(b64).length, 300_000);
});

Deno.test("promptHash: SHA-256, зависит от языка, стабилен", async () => {
  const en = await promptHash("en");
  assertMatch(en, /^[0-9a-f]{64}$/);
  assertEquals(en, await promptHash("en"));
  assert(en !== await promptHash("ru"));
});
