// deno test supabase/functions — проверка вебхука без сети: Telegram — заглушка.
import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.13";
import { getWebhookInfo, isWebhookCheck, webhookSummary } from "./health.ts";

const URL = "https://abc.supabase.co";

Deno.test("isWebhookCheck — только kind: webhook", () => {
  assertEquals(isWebhookCheck({ kind: "webhook" }), true);
  assertEquals(isWebhookCheck({ kind: "assigned" }), false);
  assertEquals(isWebhookCheck(null), false);
  assertEquals(isWebhookCheck("webhook"), false);
});

Deno.test("webhookSummary — наш адрес, без ошибок", () => {
  assertEquals(
    webhookSummary({ url: `${URL}/functions/v1/telegram-bot`, pending_update_count: 2 }, URL + "/", 1000),
    { configured: true, pending: 2, last_error_age_s: null },
  );
});

Deno.test("webhookSummary — чужой или пустой адрес, ошибка 60 с назад", () => {
  assertEquals(
    webhookSummary({ url: "https://evil.example/hook", last_error_date: 940 }, URL, 1000),
    { configured: false, pending: 0, last_error_age_s: 60 },
  );
  assertEquals(webhookSummary({}, URL, 1000).configured, false);
});

Deno.test("getWebhookInfo — ответ Telegram и ошибка", async () => {
  let called = "";
  const ok = ((u: string) => {
    called = u;
    return Promise.resolve(new Response(JSON.stringify({ ok: true, result: { url: "x", pending_update_count: 1 } })));
  }) as unknown as typeof fetch;
  assertEquals(await getWebhookInfo("T0K", ok), { url: "x", pending_update_count: 1 });
  assertEquals(called, "https://api.telegram.org/botT0K/getWebhookInfo");
  const bad = (() => Promise.resolve(new Response('{"ok":false}', { status: 401 }))) as unknown as typeof fetch;
  await assertRejects(() => getWebhookInfo("T0K", bad));
});
