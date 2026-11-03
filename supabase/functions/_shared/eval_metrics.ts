// Тест точности распознавания (шаг 34): метрики прогона — чистые функции, без
// сети (тесты — recognition-eval/metrics_test.ts).
//
// Определения (их же печатает отчёт):
// * Top-1 — на фото единица из реестра, и ИИ первой назвал именно её.
//   Ошибка функции или модели по фото — НЕ верно (честно: так увидит человек).
// * Top-3 — правильная единица среди (до) трёх кандидатов.
// * Вид — вид, названный ИИ, совпал с видом единицы (снимок при разметке).
// * Ложное «узнавание» — на фото оборудование, которого нет в реестре, а ИИ
//   первой назвал единицу из реестра.
// * Порог X: ИИ «отвечает», если уверенность (балл первого кандидата, 0..1)
//   ≥ X и первый кандидат не делит балл со вторым (при ничьей — спросить
//   человека). При X = 0 — первый кандидат как есть, без этих условий.
// * 95 % доверительный интервал — интервал Уилсона.

import { canonicalKind } from "./kinds.ts";

export interface EvalSample {
  id: string;
  site_id: string;
  room_id: string;
  true_equipment_id: string | null;
  true_is_unregistered: boolean;
  true_kind: string | null;
  similar_in_room: number;
  light: string;
  distance: string;
  angle: string;
  occlusion: boolean;
}

export interface EvalCandidate {
  asset_id: string;
  score: number;
}

export interface EvalResult {
  sample_id: string;
  predicted_equipment_id: string | null;
  candidates: EvalCandidate[];
  confidence: number | null;
  predicted_kind: string | null;
  no_equipment: boolean;
  abstained: boolean;
  ms: number | null;
  tokens: number | null;
  cost_usd: number | null;
  error: string | null;
}

export interface Rate {
  k: number;
  n: number;
  /** k / n; null при n = 0. */
  p: number | null;
  lo: number | null;
  hi: number | null;
}

/** Интервал Уилсона для доли k из n (по умолчанию 95 %, z = 1,96). */
export function wilson(k: number, n: number, z = 1.959964): Rate {
  if (n <= 0) return { k, n, p: null, lo: null, hi: null };
  const p = k / n;
  const z2 = z * z;
  const denom = 1 + z2 / n;
  const centre = (p + z2 / (2 * n)) / denom;
  const half = (z / denom) * Math.sqrt(p * (1 - p) / n + z2 / (4 * n * n));
  return {
    k,
    n,
    p,
    lo: Math.max(0, centre - half),
    hi: Math.min(1, centre + half),
  };
}

/** Перцентиль «ближайший ранг»; null — нет данных. */
export function percentile(values: number[], q: number): number | null {
  if (!values.length) return null;
  const s = [...values].sort((a, b) => a - b);
  const rank = Math.ceil(q * s.length);
  return s[Math.min(s.length, Math.max(1, rank)) - 1];
}

export const THRESHOLDS = [0, 0.5, 0.7, 0.9];

export interface ThresholdRow {
  threshold: number;
  /** Доля фото с единицей из реестра, где ИИ ответил. */
  coverage: Rate;
  /** Точность среди ответов (Top-1). */
  accuracy: Rate;
  /** Доля фото «нет в реестре», где ИИ всё же ответил единицей. */
  false_recognition: Rate;
}

export interface Group {
  key: string;
  top1: Rate;
  top3: Rate;
}

export interface Metrics {
  photos: number;
  registered: number;
  unregistered: number;
  units: number;
  rooms: number;
  sites: number;
  kinds: Record<string, number>;
  conditions: Record<string, Record<string, number>>;
  results: number;
  missing: number;
  errors: number;
  top1: Rate;
  top3: Rate;
  kind: Rate;
  false_recognition: Rate;
  thresholds: ThresholdRow[];
  by_kind: Group[];
  by_light: Group[];
  by_distance: Group[];
  by_angle: Group[];
  by_occlusion: Group[];
  by_similar: Group[];
  latency_ms: { median: number | null; p95: number | null; n: number };
  tokens_median: number | null;
  cost_per_photo_usd: number | null;
  /** До 6 фото, где ИИ ошибся: сначала неверный Top-1, затем ложные «узнавания». */
  error_examples: {
    sample_id: string;
    type: "wrong_unit" | "false_recognition" | "error";
  }[];
}

function topIds(r: EvalResult | undefined): string[] {
  if (!r || r.error) return [];
  return r.candidates.map((c) => c.asset_id).slice(0, 3);
}

function top1Of(r: EvalResult | undefined): string | null {
  if (!r || r.error || r.abstained) return null;
  return r.predicted_equipment_id ?? r.candidates[0]?.asset_id ?? null;
}

/** Ответил ли ИИ при пороге [t] (см. определения выше). */
export function answersAt(r: EvalResult | undefined, t: number): boolean {
  if (!top1Of(r)) return false;
  if (t <= 0) return true;
  const c = r!.confidence ?? r!.candidates[0]?.score ?? 0;
  const second = r!.candidates[1]?.score;
  return c >= t && (second === undefined || second < c);
}

function count(k: number, n: number): Rate {
  return wilson(k, n);
}

function groupBy(
  regs: EvalSample[],
  key: (s: EvalSample) => string,
  ok1: (s: EvalSample) => boolean,
  ok3: (s: EvalSample) => boolean,
): Group[] {
  const m = new Map<string, EvalSample[]>();
  for (const s of regs) {
    const k = key(s);
    m.set(k, [...(m.get(k) ?? []), s]);
  }
  return [...m.entries()]
    .sort((a, b) => b[1].length - a[1].length || a[0].localeCompare(b[0]))
    .map(([k, list]) => ({
      key: k,
      top1: count(list.filter(ok1).length, list.length),
      top3: count(list.filter(ok3).length, list.length),
    }));
}

function tally(xs: string[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const x of xs) out[x] = (out[x] ?? 0) + 1;
  return out;
}

export function computeMetrics(
  samples: EvalSample[],
  results: EvalResult[],
  thresholds: number[] = THRESHOLDS,
): Metrics {
  const byId = new Map(results.map((r) => [r.sample_id, r]));
  const regs = samples.filter((s) => !!s.true_equipment_id);
  const unregs = samples.filter((s) => !s.true_equipment_id);
  const res = (s: EvalSample) => byId.get(s.id);
  const ok1 = (s: EvalSample) => top1Of(res(s)) === s.true_equipment_id;
  const ok3 = (s: EvalSample) =>
    topIds(res(s)).includes(s.true_equipment_id ?? "");
  const falseRec = (s: EvalSample) => top1Of(res(s)) !== null;

  const withKind = samples.filter((s) => canonicalKind(s.true_kind));
  const kindOk = withKind.filter((s) => {
    const r = res(s);
    if (!r || r.error || r.no_equipment) return false;
    return canonicalKind(r.predicted_kind) === canonicalKind(s.true_kind);
  }).length;

  const thresholdRows = thresholds.map((t) => {
    const answered = regs.filter((s) => answersAt(res(s), t));
    return {
      threshold: t,
      coverage: count(answered.length, regs.length),
      accuracy: count(answered.filter(ok1).length, answered.length),
      false_recognition: count(
        unregs.filter((s) => answersAt(res(s), t)).length,
        unregs.length,
      ),
    };
  });

  const done = samples.map(res).filter((r): r is EvalResult => !!r);
  const ms = done.filter((r) => !r.error && typeof r.ms === "number").map((
    r,
  ) => r.ms as number);
  const tokens = done.filter((r) => typeof r.tokens === "number").map((r) =>
    r.tokens as number
  );
  const costs = done.filter((r) => typeof r.cost_usd === "number").map((r) =>
    r.cost_usd as number
  );

  const examples: Metrics["error_examples"] = [];
  for (const s of regs) {
    if (examples.length >= 6) break;
    const r = res(s);
    if (r?.error) continue;
    if (r && !ok1(s)) examples.push({ sample_id: s.id, type: "wrong_unit" });
  }
  for (const s of unregs) {
    if (examples.length >= 6) break;
    if (falseRec(s)) {
      examples.push({ sample_id: s.id, type: "false_recognition" });
    }
  }
  for (const s of samples) {
    if (examples.length >= 6) break;
    if (res(s)?.error) examples.push({ sample_id: s.id, type: "error" });
  }

  return {
    photos: samples.length,
    registered: regs.length,
    unregistered: unregs.length,
    units: new Set(regs.map((s) => s.true_equipment_id)).size,
    rooms: new Set(samples.map((s) => s.room_id)).size,
    sites: new Set(samples.map((s) => s.site_id)).size,
    kinds: tally(
      samples.map((s) =>
        canonicalKind(s.true_kind) ?? (s.true_kind ? s.true_kind : "unknown")
      ),
    ),
    conditions: {
      light: tally(samples.map((s) => s.light)),
      distance: tally(samples.map((s) => s.distance)),
      angle: tally(samples.map((s) => s.angle)),
      occlusion: tally(samples.map((s) => s.occlusion ? "yes" : "no")),
    },
    results: done.length,
    missing: samples.length - done.length,
    errors: done.filter((r) => !!r.error).length,
    top1: count(regs.filter(ok1).length, regs.length),
    top3: count(regs.filter(ok3).length, regs.length),
    kind: count(kindOk, withKind.length),
    false_recognition: count(unregs.filter(falseRec).length, unregs.length),
    thresholds: thresholdRows,
    by_kind: groupBy(
      regs,
      (s) => canonicalKind(s.true_kind) ?? "unknown",
      ok1,
      ok3,
    ),
    by_light: groupBy(regs, (s) => s.light, ok1, ok3),
    by_distance: groupBy(regs, (s) => s.distance, ok1, ok3),
    by_angle: groupBy(regs, (s) => s.angle, ok1, ok3),
    by_occlusion: groupBy(regs, (s) => s.occlusion ? "yes" : "no", ok1, ok3),
    by_similar: groupBy(
      regs,
      (s) => s.similar_in_room >= 2 ? "several_similar" : "single",
      ok1,
      ok3,
    ),
    latency_ms: {
      median: percentile(ms, 0.5),
      p95: percentile(ms, 0.95),
      n: ms.length,
    },
    tokens_median: percentile(tokens, 0.5),
    cost_per_photo_usd: costs.length && costs.length === done.length
      ? costs.reduce((a, b) => a + b, 0) / costs.length
      : null,
    error_examples: examples,
  };
}

function pct(v: number | null): string {
  return v === null ? "—" : `${(v * 100).toFixed(1)}%`;
}

/** «Top-1: 93.4% (95% CI 90.1–95.7%), n = 352 photos, 41 units, 12 rooms, 3 sites». */
export function headline(m: Metrics): string {
  const r = m.top1;
  return `Top-1: ${pct(r.p)} (95% CI ${pct(r.lo).replace("%", "")}–${
    pct(r.hi)
  }), n = ${r.n} photos, ${m.units} units, ${m.rooms} rooms, ${m.sites} sites`;
}
