// deno test supabase/functions — уведомления без сети: база и Telegram — заглушки.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.13";
import { notice, notifyOrder, type NotifyDeps, parseNotifyInput, type Target } from "./notify.ts";

const ID = "11111111-2222-4333-8444-555555555555";

function deps(o: {
  status?: string | null;
  target?: Partial<Target> | null;
  photo?: Uint8Array | null;
  fail?: boolean;
}) {
  const sent: { chat: number; html: string; markup?: unknown; photo?: boolean }[] = [];
  const released: string[] = [];
  const claimed = new Set<string>();
  const d: NotifyDeps = {
    readOrder: () => Promise.resolve(o.status === null ? null : { status: o.status ?? "done" }),
    claim(id, status) {
      if (o.target === null) return Promise.resolve(null);
      const k = `${id}:${status}`;
      if (claimed.has(k)) return Promise.resolve(null); // как on conflict do nothing
      claimed.add(k);
      return Promise.resolve({
        chat_id: 777, kind: "guest", lang: "ru", number: "111111", title: "Не работает освещение",
        status: status as Target["status"], ...o.target,
      });
    },
    release(id, status) {
      released.push(`${id}:${status}`);
      claimed.delete(`${id}:${status}`);
      return Promise.resolve();
    },
    afterPhoto: () => Promise.resolve(o.photo ?? null),
    send(chat, html, markup) {
      if (o.fail) return Promise.reject(new Error("tg down"));
      sent.push({ chat, html, markup });
      return Promise.resolve();
    },
    sendPhoto(chat, _p, html, markup) {
      if (o.fail) return Promise.reject(new Error("tg down"));
      sent.push({ chat, html, markup, photo: true });
      return Promise.resolve();
    },
    appUrl: "https://app.example/",
  };
  return { d, sent, released };
}

Deno.test("вход: только uuid заявки", () => {
  assert(parseNotifyInput({ orderId: ID }).ok);
  assert(!parseNotifyInput({ orderId: "1; drop" }).ok);
  assert(!parseNotifyInput(null).ok);
});

Deno.test("выполнена с фото «после» — фото Telegram с подписью и кнопкой отписки", async () => {
  const { d, sent } = deps({ status: "done", photo: new Uint8Array([0xff, 0xd8]) });
  assertEquals(await notifyOrder(ID, d), "sent_photo");
  assert(sent[0].photo);
  assertStringIncludes(sent[0].html, "Заявка № 111111 «Не работает освещение»: выполнена ✅");
  assertStringIncludes(JSON.stringify(sent[0].markup), "nf:off");
});

Deno.test("повторный вызов на тот же статус не шлёт второе сообщение", async () => {
  const { d, sent } = deps({ status: "in_progress" });
  assertEquals(await notifyOrder(ID, d), "sent");
  assertEquals(await notifyOrder(ID, d), "skip");
  assertEquals(sent.length, 1);
  assertStringIncludes(sent[0].html, "взята в работу");
});

Deno.test("заявка не видна пользователю — ничего не отправляется", async () => {
  const { d, sent } = deps({ status: null });
  assertEquals(await notifyOrder(ID, d), "not_visible");
  assertEquals(sent.length, 0);
});

Deno.test("статус без уведомления (на проверке) — ничего", async () => {
  const { d, sent } = deps({ status: "on_review" });
  assertEquals(await notifyOrder(ID, d), "no_status");
  assertEquals(sent.length, 0);
});

Deno.test("не из Telegram или отписался — skip", async () => {
  const { d, sent } = deps({ status: "done", target: null });
  assertEquals(await notifyOrder(ID, d), "skip");
  assertEquals(sent.length, 0);
});

Deno.test("ошибка Telegram — отметка снимается, можно повторить", async () => {
  const { d, released } = deps({ status: "returned", fail: true });
  assertEquals(await notifyOrder(ID, d), "send_failed");
  assertEquals(released, [`${ID}:returned`]);
});

Deno.test("привязанный пользователь — кнопка «Открыть», группа — без кнопок; причина возврата", () => {
  const base: Target = { chat_id: 1, kind: "user", lang: "en", number: "ABCDEF", title: "Leak <b>", status: "returned", return_reason: "No photo" };
  const u = notice(base, ID, "https://app/");
  assertStringIncludes(u.html, "Work order #ABCDEF “Leak &lt;b&gt;”: returned");
  assertStringIncludes(u.html, "Reason: No photo");
  assertStringIncludes(JSON.stringify(u.markup), `https://app/#/orders/${ID}`);
  const g = notice({ ...base, kind: "group", lang: "ru", status: "cancelled" }, ID, "https://app/");
  assertStringIncludes(g.html, "отклонена");
  assertEquals(g.markup, undefined);
});
