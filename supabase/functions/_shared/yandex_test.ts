// Вызов модели: лестница форматов на 400 (мультимодальная модель), разбор
// ответа без строгого формата, диагностика `ai_error` без base64 и текста
// запроса. Без сети: fetch подменён.

import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { parseModelJson } from "./intake.ts";
import { stripThinking } from "./identify.ts";
import { VISION_FORMAT } from "./vision.ts";
import {
  AiError,
  aiErrorDetail,
  complete,
  INTAKE_FORMAT,
  type ModelMessage,
} from "./yandex.ts";

const cfg = { apiKey: "k", folderId: "f", model: "m", liteModel: "" };
const timing = { totalMs: 2000, primaryMs: 2000 };
const B64 = "QUJD".repeat(200); // «снимок» 800 знаков без пробелов
const USER_TEXT = "Секретный текст заявки: протечка в 305";
const vision: ModelMessage[] = [
  { role: "system", content: "правила" },
  {
    role: "user",
    content: [
      { type: "text", text: USER_TEXT },
      {
        type: "image_url",
        image_url: { url: `data:image/jpeg;base64,${B64}` },
      },
    ],
  },
];

const ok = (content: string) =>
  new Response(
    JSON.stringify({
      choices: [{ message: { content } }],
      usage: { total_tokens: 5 },
    }),
  );
/** 400 с телом как у AI Studio; в сообщении — эхо запроса и base64. */
const bad400 = () =>
  new Response(
    JSON.stringify({
      error: {
        code: "invalid_argument",
        message: `unsupported field; got ${B64} near "${USER_TEXT}"`,
      },
    }),
    { status: 400 },
  );

/** fetch: отвечает 400 первым [fails] запросам, затем ok; тела — в [bodies]. */
function ladderFetch(fails: number, bodies: Record<string, unknown>[]) {
  return ((_u: string, init?: RequestInit) => {
    bodies.push(JSON.parse(String(init?.body)));
    return Promise.resolve(
      bodies.length <= fails ? bad400() : ok('{"kind":"ac"}'),
    );
  }) as unknown as typeof fetch;
}

Deno.test("лестница: 1-я ступень — json_schema, ответ сразу", async () => {
  const bodies: Record<string, unknown>[] = [];
  const r = await complete(
    cfg,
    vision,
    ladderFetch(0, bodies),
    timing,
    VISION_FORMAT,
  );
  assertEquals(r.format, "schema");
  assertEquals(bodies.length, 1);
  // deno-lint-ignore no-explicit-any
  assertEquals((bodies[0] as any).response_format.type, "json_schema");
  assertEquals(bodies[0].max_tokens, 1000);
});

Deno.test("лестница: 400 → json_object", async () => {
  const bodies: Record<string, unknown>[] = [];
  const r = await complete(
    cfg,
    vision,
    ladderFetch(1, bodies),
    timing,
    VISION_FORMAT,
  );
  assertEquals(r.format, "object");
  assertEquals(bodies.length, 2);
  assertEquals(bodies[1].response_format, { type: "json_object" });
});

Deno.test("лестница: 400, 400 → только model и messages, как в примере", async () => {
  const bodies: Record<string, unknown>[] = [];
  const r = await complete(
    cfg,
    vision,
    ladderFetch(2, bodies),
    timing,
    VISION_FORMAT,
  );
  assertEquals(r.format, "plain");
  assertEquals(r.content, '{"kind":"ac"}');
  assertEquals(Object.keys(bodies[2]).sort(), ["messages", "model"]);
  assertEquals(bodies[2].model, "gpt://f/m");
});

Deno.test("лестница: все ступени 400 → AiError http_400 с ai_error и tried", async () => {
  const bodies: Record<string, unknown>[] = [];
  try {
    await complete(cfg, vision, ladderFetch(9, bodies), timing, VISION_FORMAT);
    throw new Error("ожидалась ошибка");
  } catch (e) {
    assert(e instanceof AiError);
    assertEquals(e.code, "http_400");
    assertEquals(e.tried, ["schema:400", "object:400", "plain:400"]);
    assert(e.detail?.startsWith("invalid_argument: unsupported field"));
    assertEquals(bodies.length, 3);
  }
});

Deno.test("текст (voice-intake): как раньше — json_schema → без формата, без json_object", async () => {
  const bodies: Record<string, unknown>[] = [];
  const r = await complete(
    cfg,
    [],
    ladderFetch(1, bodies),
    timing,
    INTAKE_FORMAT,
  );
  assertEquals(r.format, "bare");
  assertEquals(bodies.length, 2);
  assert(!("response_format" in bodies[1]));
  assertEquals(bodies[1].max_tokens, INTAKE_FORMAT.maxTokens);
  // Вторая 400 у текста — ошибка, третьей ступени нет.
  const b2: Record<string, unknown>[] = [];
  try {
    await complete(cfg, [], ladderFetch(9, b2), timing, INTAKE_FORMAT);
    throw new Error("ожидалась ошибка");
  } catch (e) {
    assert(e instanceof AiError);
    assertEquals(e.tried, ["schema:400", "bare:400"]);
    assertEquals(b2.length, 2);
  }
});

Deno.test("ai_error: без base64 и текста запроса, не длиннее 300", async () => {
  const lines: string[] = [];
  const orig = console.log;
  try {
    await complete(cfg, vision, ladderFetch(9, []), timing, VISION_FORMAT);
  } catch (e) {
    assert(e instanceof AiError);
    // Как пишут функции: log({ code, ai_error, tried }).
    console.log = (s: string) => lines.push(s);
    console.log(
      JSON.stringify({ code: e.code, ai_error: e.detail, tried: e.tried }),
    );
  } finally {
    console.log = orig;
  }
  const line = lines.join("\n");
  assert(line.includes("invalid_argument"));
  assert(!line.includes(B64.slice(0, 120)), "base64 в логе");
  assert(!/\S{101,}/.test(JSON.parse(line).ai_error));
  assert(JSON.parse(line).ai_error.length <= 300);
  // Текст запроса не попадает: в detail только error.code / error.message
  // ответа, тело запроса не читается вовсе.
  assert(!line.includes("data:image"));
});

Deno.test("ai_error: только error.code / message, обрезка, не JSON", () => {
  assertEquals(
    aiErrorDetail('{"error":{"code":"bad","message":"no","extra":"x"}}'),
    "bad: no",
  );
  assertEquals(aiErrorDetail('{"message":"Unauthorized"}'), "Unauthorized");
  assertEquals(
    aiErrorDetail('{"error":{"grpcCode":3,"message":"bad"}}'),
    "3: bad",
  );
  assertEquals(aiErrorDetail("<html>gateway</html>"), "non_json");
  assertEquals(aiErrorDetail(""), undefined);
  assertEquals(aiErrorDetail('{"other":1}'), undefined);
  const long = aiErrorDetail(
    JSON.stringify({ error: { message: "слово ".repeat(200) } }),
  )!;
  assertEquals(long.length, 300);
});

Deno.test("ответ без строгого формата: <think>, текст вокруг, блок ```json", () => {
  const cases = [
    '<think>это {ac}?</think>\n{"kind":"ac"}',
    'Вот результат:\n```json\n{"kind":"ac"}\n```\nГотово.',
    '```\n{"kind":"ac"}\n```',
    'Ответ: {"kind":"ac"} — уверен.',
  ];
  for (const c of cases) {
    assertEquals(parseModelJson(stripThinking(c)), { kind: "ac" }, c);
  }
  assertEquals(parseModelJson("нет JSON"), null);
});
