// Шаг 33: выбор поставщика ИИ и распознавания речи по секретам. Без сети:
// fetch подменён, проверяется только куда и с какими заголовками уйдёт запрос.

import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { aiFromEnv, chatUrl, complete, DEFAULT_MODEL, LITE_MODEL, YANDEX_URL } from "./ai.ts";
import { visionModels } from "./vision.ts";
import { sttFromEnv } from "../telegram-bot/stt.ts";

const env = (m: Record<string, string>) => (k: string) => m[k];
const YANDEX = { YANDEX_API_KEY: "yk", YANDEX_FOLDER_ID: "yf" };
const OPENAI = {
  AI_BASE_URL: "https://api.example.com/v1/",
  AI_API_KEY: "ok",
  AI_MODEL_TEXT: "text-model",
  AI_MODEL_TEXT_LITE: "text-mini",
  AI_MODEL_VISION: "vision-model",
};

Deno.test("ai: без AI_* — Yandex, как раньше (модели по умолчанию)", () => {
  const c = aiFromEnv(env(YANDEX), "text")!;
  assertEquals(c.provider, "yandex");
  assertEquals([c.apiKey, c.folderId, c.model, c.liteModel], ["yk", "yf", DEFAULT_MODEL, LITE_MODEL]);
  assertEquals(chatUrl(c), YANDEX_URL);
  const v = aiFromEnv(env(YANDEX), "vision", visionModels(env(YANDEX)))!;
  assertEquals([v.provider, v.model], ["yandex", "qwen3.6-35b-a3b"]);
});

Deno.test("ai: ничего не задано — null (функция ответит not_configured)", () => {
  assertEquals(aiFromEnv(env({}), "text"), null);
  assertEquals(aiFromEnv(env({ YANDEX_API_KEY: "yk" }), "text"), null);
});

Deno.test("ai: AI_BASE_URL + AI_API_KEY — OpenAI-совместимый поставщик, Yandex не трогается", () => {
  const c = aiFromEnv(env({ ...YANDEX, ...OPENAI }), "text")!;
  assertEquals(c.provider, "openai");
  assertEquals([c.apiKey, c.model, c.liteModel], ["ok", "text-model", "text-mini"]);
  assertEquals(chatUrl(c), "https://api.example.com/v1/chat/completions");
  const v = aiFromEnv(env({ ...YANDEX, ...OPENAI }), "vision", visionModels(env(YANDEX)))!;
  assertEquals([v.provider, v.model, v.liteModel], ["openai", "vision-model", ""]);
  assertEquals(chatUrl({ ...c, baseUrl: "https://x.test/v1/chat/completions" }), "https://x.test/v1/chat/completions");
});

Deno.test("ai: openai без модели нужного вида — не настроено; «-» в запасной — без повтора", () => {
  assertEquals(aiFromEnv(env({ AI_BASE_URL: "https://x", AI_API_KEY: "k" }), "vision"), null);
  const c = aiFromEnv(env({ ...OPENAI, AI_MODEL_TEXT_LITE: "-" }), "text")!;
  assertEquals(c.liteModel, "");
});

Deno.test("ai: запрос к openai — Bearer-ключ, имя модели как есть, без каталога", async () => {
  const seen: { url: string; auth: string; model: string; project: string | null }[] = [];
  const fake: typeof fetch = (input, init) => {
    const h = new Headers(init?.headers);
    const body = JSON.parse(String(init?.body));
    seen.push({ url: String(input), auth: h.get("Authorization") ?? "", model: body.model, project: h.get("OpenAI-Project") });
    return Promise.resolve(new Response(JSON.stringify({ choices: [{ message: { content: "{}" } }] })));
  };
  const c = aiFromEnv(env(OPENAI), "text")!;
  await complete(c, [{ role: "user", content: "x" }], fake, { totalMs: 2000, primaryMs: 2000 });
  assertEquals(seen[0], {
    url: "https://api.example.com/v1/chat/completions",
    auth: "Bearer ok",
    model: "text-model",
    project: null,
  });
  const y = aiFromEnv(env(YANDEX), "text")!;
  await complete(y, [{ role: "user", content: "x" }], fake, { totalMs: 2000, primaryMs: 2000 });
  assertEquals([seen[1].url, seen[1].auth, seen[1].model, seen[1].project], [YANDEX_URL, "Api-Key yk", `gpt://yf/${DEFAULT_MODEL}`, "yf"]);
});

Deno.test("stt: по умолчанию прежний (Yandex), с AI_MODEL_STT — OpenAI-совместимый", async () => {
  assertEquals(sttFromEnv(env({})), null);
  assertEquals(sttFromEnv(env(YANDEX))?.provider, "yandex");
  // AI_* без AI_MODEL_STT — распознавание остаётся прежним.
  assertEquals(sttFromEnv(env({ ...YANDEX, ...OPENAI }))?.provider, "yandex");
  let url = "";
  let auth = "";
  const fake: typeof fetch = (input, init) => {
    url = String(input);
    auth = new Headers(init?.headers).get("Authorization") ?? "";
    assert(init?.body instanceof FormData);
    return Promise.resolve(new Response(JSON.stringify({ text: " течёт кран " })));
  };
  const s = sttFromEnv(env({ ...OPENAI, AI_MODEL_STT: "whisper-1" }), fake)!;
  assertEquals(s.provider, "openai");
  assertEquals(await s.recognize(new Uint8Array([1, 2, 3]), "ru"), "течёт кран");
  assertEquals([url, auth], ["https://api.example.com/v1/audio/transcriptions", "Bearer ok"]);
});
