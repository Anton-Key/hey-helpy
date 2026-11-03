// Тесты метрик теста распознавания (шаг 34): интервал Уилсона, Top-1/Top-3,
// вид, ложные «узнавания», пороги, разбивки, время. Без сети.

import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import {
  answersAt,
  computeMetrics,
  type EvalResult,
  type EvalSample,
  headline,
  percentile,
  wilson,
} from "../_shared/eval_metrics.ts";

Deno.test("wilson: известные значения", () => {
  const a = wilson(0, 10);
  assertEquals(a.p, 0);
  assertAlmostEquals(a.lo!, 0, 1e-9);
  assertAlmostEquals(a.hi!, 0.2775, 1e-4);
  const b = wilson(10, 10);
  assertAlmostEquals(b.lo!, 0.7225, 1e-4);
  assertAlmostEquals(b.hi!, 1, 1e-9);
  const c = wilson(50, 100);
  assertAlmostEquals(c.lo!, 0.4038, 1e-4);
  assertAlmostEquals(c.hi!, 0.5962, 1e-4);
  // 93.4 % на 352 фото — пример подписи из задания.
  const d = wilson(329, 352);
  assert(d.lo! > 0.90 && d.lo! < 0.91, `lo ${d.lo}`);
  assert(d.hi! > 0.955 && d.hi! < 0.96, `hi ${d.hi}`);
  assertEquals(wilson(0, 0).p, null);
});

Deno.test("percentile: ближайший ранг", () => {
  assertEquals(percentile([], 0.5), null);
  assertEquals(percentile([5], 0.95), 5);
  assertEquals(percentile([1, 2, 3, 4], 0.5), 2);
  const xs = Array.from({ length: 100 }, (_, i) => i + 1);
  assertEquals(percentile(xs, 0.95), 95);
  assertEquals(percentile(xs, 0.5), 50);
});

const base = {
  site_id: "S1",
  light: "good",
  distance: "close",
  angle: "front",
  occlusion: false,
  true_is_unregistered: false,
};

function sample(
  id: string,
  unit: string | null,
  extra: Partial<EvalSample> = {},
): EvalSample {
  return {
    ...base,
    id,
    room_id: "R1",
    true_equipment_id: unit,
    true_is_unregistered: unit === null,
    true_kind: unit ? "ac" : null,
    similar_in_room: unit ? 2 : 0,
    ...extra,
  };
}

function result(
  id: string,
  cands: [string, number][],
  extra: Partial<EvalResult> = {},
): EvalResult {
  return {
    sample_id: id,
    predicted_equipment_id: cands[0]?.[0] ?? null,
    candidates: cands.map(([asset_id, score]) => ({ asset_id, score })),
    confidence: cands[0]?.[1] ?? null,
    predicted_kind: "ac",
    no_equipment: false,
    abstained: cands.length === 0,
    ms: 1000,
    tokens: 900,
    cost_usd: null,
    error: null,
    ...extra,
  };
}

Deno.test("computeMetrics: Top-1, Top-3, вид, ложные узнавания, ошибки", () => {
  const samples = [
    sample("p1", "A"),
    sample("p2", "A", { light: "dim" }),
    sample("p3", "B", { room_id: "R2", similar_in_room: 1 }),
    sample("p4", "B", { room_id: "R2", similar_in_room: 1, distance: "far" }),
    sample("p5", null, { site_id: "S2", room_id: "R3" }),
    sample("p6", null, { site_id: "S2", room_id: "R3" }),
    sample("p7", "C", { true_kind: "light", similar_in_room: 1 }),
  ];
  const results = [
    result("p1", [["A", 0.75], ["B", 0.45]]), // верно
    result("p2", [["B", 0.75], ["A", 0.75]]), // неверно, в top-3, ничья
    result("p3", [["B", 0.8]]), // верно
    result("p4", [], { predicted_kind: "fancoil" }), // «не знаю», вид не тот
    result("p5", [["A", 0.45]]), // ложное узнавание
    result("p6", [], { no_equipment: true, predicted_kind: null }), // правильно промолчал
    result("p7", [], { error: "timeout", ms: 14000 }), // ошибка — неверно
  ];
  const m = computeMetrics(samples, results);
  assertEquals(m.photos, 7);
  assertEquals(m.registered, 5);
  assertEquals(m.unregistered, 2);
  assertEquals(m.units, 3);
  assertEquals(m.rooms, 3);
  assertEquals(m.sites, 2);
  assertEquals(m.errors, 1);
  assertEquals(m.missing, 0);
  assertEquals([m.top1.k, m.top1.n], [2, 5]);
  assertEquals([m.top3.k, m.top3.n], [3, 5]);
  // Вид: p1, p2, p3 верно; p4 — fancoil, p7 — ошибка → 3 из 5.
  assertEquals([m.kind.k, m.kind.n], [3, 5]);
  assertEquals([m.false_recognition.k, m.false_recognition.n], [1, 2]);
  // Порог 0 — ответ на 3 из 5 (p1, p2, p3), верно 2.
  const t0 = m.thresholds.find((t) => t.threshold === 0)!;
  assertEquals([t0.coverage.k, t0.coverage.n], [3, 5]);
  assertEquals([t0.accuracy.k, t0.accuracy.n], [2, 3]);
  // Порог 0,7: p2 — ничья, не отвечает; p1 и p3 — верно.
  const t7 = m.thresholds.find((t) => t.threshold === 0.7)!;
  assertEquals([t7.coverage.k, t7.accuracy.k, t7.accuracy.n], [2, 2, 2]);
  assertEquals(t7.false_recognition.k, 0);
  const t9 = m.thresholds.find((t) => t.threshold === 0.9)!;
  assertEquals(t9.coverage.k, 0);
  assertEquals(t9.accuracy.p, null);
  // Разбивки.
  const similar = m.by_similar.find((g) => g.key === "several_similar")!;
  assertEquals([similar.top1.k, similar.top1.n], [1, 2]);
  const dim = m.by_light.find((g) => g.key === "dim")!;
  assertEquals([dim.top1.k, dim.top1.n], [0, 1]);
  assertEquals(m.by_kind.find((g) => g.key === "light")!.top1.k, 0);
  // Время — без ошибок.
  assertEquals(m.latency_ms.n, 6);
  assertEquals(m.latency_ms.median, 1000);
  assertEquals(m.cost_per_photo_usd, null);
  // Примеры ошибок: неверная единица (p2, p4), ложное узнавание (p5), ошибка (p7).
  assertEquals(m.error_examples.map((e) => [e.sample_id, e.type]), [
    ["p2", "wrong_unit"],
    ["p4", "wrong_unit"],
    ["p5", "false_recognition"],
    ["p7", "error"],
  ]);
  assertEquals(m.conditions.light, { good: 6, dim: 1 });
});

Deno.test("computeMetrics: фото без ответа считается неверным", () => {
  const m = computeMetrics([sample("p1", "A"), sample("p2", "A")], [
    result("p1", [["A", 0.75]]),
  ]);
  assertEquals(m.missing, 1);
  assertEquals([m.top1.k, m.top1.n], [1, 2]);
});

Deno.test("answersAt: порог и ничья", () => {
  const r = result("x", [["A", 0.75], ["B", 0.75]]);
  assert(answersAt(r, 0));
  assert(!answersAt(r, 0.5));
  assert(answersAt(result("x", [["A", 0.75], ["B", 0.45]]), 0.7));
  assert(!answersAt(result("x", [["A", 0.65]]), 0.7));
  assert(!answersAt(result("x", []), 0));
  assert(!answersAt(undefined, 0));
});

Deno.test("headline: подпись главной цифры", () => {
  const samples = Array.from(
    { length: 10 },
    (_, i) => sample(`p${i}`, i < 5 ? "A" : "B"),
  );
  const results = samples.map((s, i) =>
    result(s.id, [[i < 9 ? s.true_equipment_id! : "Z", 0.75]])
  );
  const h = headline(computeMetrics(samples, results));
  assertEquals(
    h,
    "Top-1: 90.0% (95% CI 59.6–98.2%), n = 10 photos, 2 units, 1 rooms, 1 sites",
  );
});
