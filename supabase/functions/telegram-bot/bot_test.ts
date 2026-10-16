// deno test supabase/functions — бот без сети: Telegram, база, хранилище,
// модели и SpeechKit — заглушки в памяти.
import { assert, assertEquals, assertFalse, assertStringIncludes } from "jsr:@std/assert@1.0.13";
import {
  cardText,
  type Ctx,
  type Db,
  type Deps,
  handleUpdate,
  type J,
  objectFromText,
  plainDraft,
  type Session,
  settleObject,
  toBase64,
  type Who,
  leadsChatId,
  leadWho,
} from "./bot.ts";
import {
  groupAddressed,
  parseCommand,
  parseUpdate,
  pickPhoto,
  reporterName,
  secretMatches,
  stripMention,
  type TelegramApi,
  telegramApi,
  TgError,
  type TgMessage,
  type TgUpdate,
} from "./telegram.ts";
import { recognize, SttError } from "./stt.ts";
import { COMMANDS, langOf, t, TEXTS } from "./texts.ts";
import type { IntakeResult } from "../_shared/intake.ts";
import type { Vision } from "../_shared/identify.ts";
import { type AssignInfo, assignNotice, notifyAssigned, parseTake, takeData, takeReply } from "./assign.ts";
import type { Target } from "../telegram-notify/notify.ts";

const CO = "c0000000-0000-4000-8000-000000000001";
const OBJ = "o0000000-0000-4000-8000-000000000010";
const OBJ2 = "o0000000-0000-4000-8000-000000000011";
const ROOM = "r0000000-0000-4000-8000-000000000021";
const HVAC = "l0000000-0000-4000-8000-000000000001";
const AC = "a0000000-0000-4000-8000-000000000708";

const CHAT = 5001;
const GROUP = -1009;
const USER = 777;

const baseCtx = (): Ctx => ({
  layers: [{ id: HVAC, name: "Климат", name_i18n: { ru: "Климат", en: "HVAC" } }],
  objects: [
    { id: OBJ, name: "БЦ «Демо»", city: "Белград" },
    { id: OBJ2, name: "Офис 1", city: "Москва" },
  ],
  places: [{ id: ROOM, object_id: OBJ, name: "Переговорная", code: "301", object_name: "БЦ «Демо»" }],
  assets: [{
    id: AC,
    name: "Кондиционер КД-301",
    kind: "ac",
    layer_id: HVAC,
    location_id: ROOM,
    location_name: "Переговорная",
    location_code: "301",
    object_id: OBJ,
  }],
});

interface Sent {
  chat: number;
  html: string;
  markup?: unknown;
  replyTo?: number;
}

/** Мир заглушек: что бот отправил, что записал в базу. */
function world(opts: {
  who?: Who;
  ctx?: Ctx;
  ai?: IntakeResult | null | "throw";
  vision?: Vision | null;
  stt?: string | Error;
  create?: J;
  download?: Uint8Array | Error;
  take?: J;
  assign?: AssignInfo | null;
  author?: Target | null;
  /** Шаг 29: есть 0026 — ответ tg_lead_save (или "throw" — сбой базы). */
  lead?: J | "throw";
  leadsChat?: number | null;
} = {}) {
  const sent: Sent[] = [];
  const edits: Sent[] = [];
  const answers: (string | undefined)[] = [];
  const sessions = new Map<number, Session | null>();
  const seen = new Set<number>();
  const orders: J[] = [];
  const uploads: string[] = [];
  const removed: string[] = [];
  const logs: J[] = [];
  const calls: string[] = [];
  const leads: J[] = [];
  let msgId = 100;
  let who: Who = opts.who ?? {
    kind: "guest",
    company_id: CO,
    link_id: "lnk",
    link_object_id: OBJ,
    object: { id: OBJ, name: "БЦ «Демо»", city: "Белград" },
  };
  const ctx = opts.ctx ?? baseCtx();

  const tg: TelegramApi = {
    send(chat, html, markup, replyTo) {
      sent.push({ chat, html, markup, replyTo });
      return Promise.resolve(++msgId);
    },
    edit(chat, _id, html, markup) {
      edits.push({ chat, html, markup });
      return Promise.resolve();
    },
    answer(_id, text) {
      answers.push(text);
      return Promise.resolve();
    },
    download() {
      const d = opts.download ?? new Uint8Array([0xff, 0xd8, 0xff, 1, 2, 3]);
      return d instanceof Error ? Promise.reject(d) : Promise.resolve(d);
    },
  };
  const db: Db = {
    takeUpdate(id) {
      if (seen.has(id)) return Promise.resolve(false);
      seen.add(id);
      return Promise.resolve(true);
    },
    resolve() {
      calls.push("resolve");
      return Promise.resolve(who);
    },
    linkChat(code) {
      calls.push("link");
      return Promise.resolve(code === "123456" ? { ok: true, name: "Мария Ковалёва" } : { ok: false });
    },
    guestStart(token) {
      calls.push("guest");
      if (token === "obj") return Promise.resolve({ ok: true, scope: "object", object: ctx.objects[0] });
      if (token === "co") return Promise.resolve({ ok: true, scope: "company", company_name: "Демо БЦ" });
      if (token === "other") return Promise.resolve({ ok: false, error: "other_company" });
      return Promise.resolve({ ok: false, error: "bad_link" });
    },
    reset() {
      const had = who.kind !== "none";
      who = { kind: "none" };
      return Promise.resolve(had);
    },
    connectGroup(code) {
      return Promise.resolve(code === "ABC" ? { ok: true, object_name: "БЦ «Демо»" } : { ok: false });
    },
    context() {
      calls.push("context");
      return Promise.resolve(ctx);
    },
    setObject(_chat, id) {
      const o = ctx.objects.find((x) => x.id === id);
      return Promise.resolve(o ? { ok: true, object: o } : { ok: false });
    },
    nearest(_c, lat) {
      return Promise.resolve(lat > 44 ? { ok: true, object: ctx.objects[0] } : { ok: false });
    },
    createOrder(_c, _g, id, order) {
      orders.push({ id, ...order });
      return Promise.resolve(opts.create ?? { ok: true, number: 42, photo: !!order.photo_path });
    },
    sessionGet(chat) {
      return Promise.resolve(structuredClone(sessions.get(chat) ?? null));
    },
    sessionPut(chat, s) {
      sessions.set(chat, s ? structuredClone(s) : null);
      return Promise.resolve();
    },
    notifyOptout(_chat, off) {
      calls.push(off ? "notify_off" : "notify_on");
      return Promise.resolve();
    },
    notifyClaim(_o, status) {
      calls.push(`claim_${status}`);
      return Promise.resolve(opts.author ?? null);
    },
    assignClaim(_o, actor) {
      calls.push(`assign_${actor ?? "-"}`);
      return Promise.resolve(opts.assign ?? null);
    },
    assignRelease() {
      calls.push("assign_release");
      return Promise.resolve();
    },
    takeOrder(chat, orderId) {
      calls.push(`take_${chat}_${orderId}`);
      return Promise.resolve(opts.take ?? { error: "not_found" });
    },
    ...(opts.lead === undefined ? {} : {
      leadSave(chat: number, username: string | null, name: string | null, lang: string, text: string) {
        calls.push("lead");
        if (opts.lead === "throw") return Promise.reject(new Error("db"));
        leads.push({ chat, username, name, lang, text });
        return Promise.resolve(opts.lead as J);
      },
    }),
  };
  let n = 0;
  const deps: Deps = {
    tg,
    db,
    storage: {
      upload(p) {
        uploads.push(p);
        return Promise.resolve();
      },
      remove(p) {
        removed.push(p);
        return Promise.resolve();
      },
    },
    ai: {
      text() {
        if (opts.ai === "throw") return Promise.reject(new Error("down"));
        if (!opts.ai) return Promise.resolve(null);
        return Promise.resolve({ result: opts.ai, model: "pro" });
      },
      vision() {
        return Promise.resolve(opts.vision ? { vision: opts.vision, model: "main" } : null);
      },
      stt() {
        const s = opts.stt ?? "";
        return s instanceof Error ? Promise.reject(s) : Promise.resolve(s);
      },
    },
    log: (f) => logs.push(f),
    uuid: () => `00000000-0000-4000-8000-${String(++n).padStart(12, "0")}`,
    appUrl: "https://app.example/",
    leadsChat: opts.leadsChat ?? null,
  };
  return { leads, deps, sent, edits, answers, sessions, orders, uploads, removed, logs, calls, setWho: (w: Who) => (who = w) };
}

let upd = 1;
function msg(p: Partial<TgMessage> & { lang?: string; chatType?: "private" | "group" | "supergroup" } = {}): TgUpdate {
  const chatType = p.chatType ?? "private";
  return {
    update_id: upd++,
    message: {
      message_id: 10 + upd,
      from: { id: USER, first_name: "Мария", last_name: "Ковалёва", language_code: p.lang ?? "ru" },
      chat: { id: chatType === "private" ? CHAT : GROUP, type: chatType, title: "Демо" },
      ...p,
    },
  };
}

function press(data: string, card: number, opts: { chat?: number; from?: number; group?: boolean } = {}): TgUpdate {
  return {
    update_id: upd++,
    callback_query: {
      id: `cb${upd}`,
      from: { id: opts.from ?? USER, first_name: "Мария", last_name: "Ковалёва", language_code: "ru" },
      message: {
        message_id: card,
        chat: { id: opts.chat ?? CHAT, type: opts.group ? "supergroup" : "private" },
      },
      data,
    },
  };
}

const aiLeak: IntakeResult = {
  source: "ai",
  title: "Течёт кондиционер",
  description: "В переговорной 301 капает вода с кондиционера",
  layer_id: HVAC,
  layer: "Климат",
  location_id: ROOM,
  location_hint: null,
  priority: "high",
  confidence: 0.9,
  transcript: "",
};

// ---------------------------------------------------------------------------
// telegram.ts
// ---------------------------------------------------------------------------

Deno.test("secretMatches: только точное совпадение, пустой секрет — отказ", () => {
  assert(secretMatches("abc", "abc"));
  assertFalse(secretMatches("abd", "abc"));
  assertFalse(secretMatches("abcd", "abc"));
  assertFalse(secretMatches(null, "abc"));
  assertFalse(secretMatches("", ""));
});

Deno.test("parseUpdate отбрасывает мусор", () => {
  assertEquals(parseUpdate(null), null);
  assertEquals(parseUpdate({ update_id: "1" }), null);
  assertEquals(parseUpdate({ update_id: 1, message: { chat: {} } }), null);
  assertEquals(parseUpdate({ update_id: 1, callback_query: { id: "x" } }), null);
  assert(parseUpdate({ update_id: 1, message: { message_id: 1, chat: { id: 5, type: "private" } } }));
});

Deno.test("parseCommand: аргумент, имя бота, чужой бот", () => {
  assertEquals(parseCommand("/start obj_abc"), { name: "start", arg: "obj_abc" });
  assertEquals(parseCommand("/Help@heyhelpy_bot"), { name: "help", arg: "" });
  assertEquals(parseCommand("/help@OtherBot"), null);
  assertEquals(parseCommand("течёт кран"), null);
});

Deno.test("упоминание и адресация в группе", () => {
  assertEquals(stripMention("@HeyHelpy_bot течёт   кран"), "течёт кран");
  const base: TgMessage = { message_id: 1, chat: { id: GROUP, type: "group" } };
  assert(groupAddressed({ ...base, text: "кран @heyhelpy_bot" }));
  assertFalse(groupAddressed({ ...base, text: "кран @HeyHelpy_botX" }));
  assertFalse(groupAddressed({ ...base, text: "просто разговор" }));
  assert(groupAddressed({ ...base, text: "/where" }));
  assert(groupAddressed({
    ...base,
    text: "да",
    reply_to_message: { from: { id: 1, is_bot: true, username: "HeyHelpy_bot" } },
  }));
  assert(groupAddressed({ ...base, caption: "@HeyHelpy_bot вот", photo: [] }));
});

Deno.test("pickPhoto: самый крупный, не больше предела", () => {
  const p = pickPhoto([
    { file_id: "s", width: 90, height: 90, file_size: 1000 },
    { file_id: "m", width: 800, height: 600, file_size: 90_000 },
    { file_id: "xl", width: 4000, height: 3000, file_size: 5_000_000 },
  ]);
  assertEquals(p?.file_id, "m");
  assertEquals(pickPhoto([{ file_id: "xl", width: 1, height: 1, file_size: 9e9 }]), null);
  assertEquals(pickPhoto(undefined), null);
});

Deno.test("reporterName: имя и первая буква фамилии", () => {
  assertEquals(reporterName({ id: 1, first_name: "Мария", last_name: "Ковалёва" }), "Мария К.");
  assertEquals(reporterName({ id: 1 }), null);
});

Deno.test("telegramApi: токен только в адресе, ошибки — коды", async () => {
  const urls: string[] = [];
  const ok = telegramApi("TOKEN", (u, init) => {
    urls.push(String(u));
    assertFalse(String(init?.body).includes("TOKEN"));
    return Promise.resolve(new Response(JSON.stringify({ ok: true, result: { message_id: 9 } })));
  });
  assertEquals(await ok.send(1, "hi"), 9);
  assertStringIncludes(urls[0], "/botTOKEN/sendMessage");

  const bad = telegramApi("T", () => Promise.resolve(new Response('{"ok":false}', { status: 403 })));
  const e = await bad.send(1, "hi").catch((x) => x);
  assert(e instanceof TgError);
  assertEquals(e.code, "tg_sendMessage_403");
  // «message is not modified» (400) при правке — молча.
  const b400 = telegramApi("T", () => Promise.resolve(new Response('{"ok":false}', { status: 400 })));
  await b400.edit(1, 2, "x");

  const big = telegramApi("T", (u) =>
    Promise.resolve(
      String(u).includes("getFile")
        ? new Response(JSON.stringify({ ok: true, result: { file_path: "f", file_size: 2_000_000 } }))
        : new Response("x"),
    ));
  const e2 = await big.download("id", 1024 * 1024).catch((x) => x);
  assertEquals(e2.code, "too_large");
});

// ---------------------------------------------------------------------------
// stt.ts
// ---------------------------------------------------------------------------

Deno.test("recognize: язык, ключ в заголовке, ошибки", async () => {
  let url = "";
  let auth = "";
  const text = await recognize(new Uint8Array([1]), "en", "KEY", (u, init) => {
    url = String(u);
    auth = new Headers(init?.headers).get("Authorization") ?? "";
    return Promise.resolve(new Response(JSON.stringify({ result: " leaking tap " })));
  });
  assertEquals(text, "leaking tap");
  assertStringIncludes(url, "lang=en-US");
  assertStringIncludes(url, "format=oggopus");
  assertEquals(auth, "Api-Key KEY");

  const e = await recognize(new Uint8Array([1]), "ru", "K", () => Promise.resolve(new Response("no", { status: 401 })))
    .catch((x) => x);
  assert(e instanceof SttError);
  assertEquals(e.code, "http_401");
  const e2 = await recognize(new Uint8Array([1]), "ru", "K", () => Promise.reject(new TypeError("net"))).catch((x) =>
    x
  );
  assertEquals(e2.code, "network");
  const e3 = await recognize(new Uint8Array([1]), "ru", "K", () => Promise.resolve(new Response("{}"))).catch((x) => x);
  assertEquals(e3.code, "bad_reply");
});

// ---------------------------------------------------------------------------
// texts.ts
// ---------------------------------------------------------------------------

Deno.test("тексты: RU и EN — одни и те же ключи и подстановки, название продукта", () => {
  const ru = TEXTS.ru, en = TEXTS.en;
  assertEquals(Object.keys(ru).sort(), Object.keys(en).sort());
  const vars = (s: string) => [...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();
  for (const k of Object.keys(ru) as (keyof typeof ru)[]) {
    assertEquals(vars(ru[k]), vars(en[k]), k);
  }
  assertStringIncludes(ru.startUnknown, "«Эй, Helpy»");
  assertStringIncludes(en.startUnknown, "Hey Helpy");
  assertEquals(langOf("ru-RU"), "ru");
  assertEquals(langOf("de"), "en");
  assertEquals(langOf(undefined), "en");
  assertEquals(COMMANDS.ru.length, COMMANDS.en.length);
  assertEquals(t("en", "created", { number: "7" }), "Work order #7 received. The manager can already see it.");
});

// ---------------------------------------------------------------------------
// Чистые функции разговора
// ---------------------------------------------------------------------------

Deno.test("objectFromText: однозначно или никак", () => {
  const objs = [
    { id: "a", name: "Офис 1", city: "Москва" },
    { id: "b", name: "Офис 1", city: "Дубай" },
    { id: "c", name: "Склад", city: "Белград" },
  ];
  assertEquals(objectFromText("течёт кран в офис 1", objs), null);
  assertEquals(objectFromText("Москва, офис 1 — течёт кран", objs)?.id, "a");
  assertEquals(objectFromText("на складе темно", objs), null);
  assertEquals(objectFromText("склад: темно", objs)?.id, "c");
});

Deno.test("plainDraft: заголовок до 60 символов, длинное — в описании", () => {
  const d = plainDraft("Эй, Хелпи, " + "очень ".repeat(20) + "течёт");
  assert(d.title.length <= 60);
  assert(d.description);
  assertFalse(d.title.startsWith("Эй"));
  assertEquals(d.priority, "normal");
});

Deno.test("settleObject: объект ссылки, иначе единственный, иначе спросить", () => {
  const ctx = baseCtx();
  const guest: Who = { kind: "guest", object: { id: OBJ, name: "x" } };
  const d1 = plainDraft("кран");
  assert(settleObject(d1, "кран", guest, ctx));
  assertEquals(d1.object_id, OBJ);
  const d2 = plainDraft("кран");
  assertFalse(settleObject(d2, "кран", { kind: "user" }, ctx));
  const d3 = plainDraft("кран");
  assert(settleObject(d3, "кран", { kind: "user" }, { ...ctx, objects: [] }));
  assertEquals(d3.object_id, null);
});

Deno.test("cardText экранирует HTML", () => {
  const d = plainDraft("<b>взлом</b> & кран");
  const html = cardText(d, "ru");
  assertStringIncludes(html, "&lt;b&gt;взлом&lt;/b&gt; &amp; кран");
  assertStringIncludes(html, "уточнит менеджер");
  assertStringIncludes(html, TEXTS.ru.aiOff);
});

Deno.test("toBase64 = btoa", () => {
  const b = new Uint8Array(70000).map((_, i) => i % 256);
  let ref = "";
  for (const x of b) ref += String.fromCharCode(x);
  assertEquals(toBase64(b), btoa(ref));
  assertEquals(toBase64(new Uint8Array([104, 105])), "aGk=");
});

// ---------------------------------------------------------------------------
// Разговор целиком
// ---------------------------------------------------------------------------

Deno.test("повтор update_id — ничего не делаем", async () => {
  const w = world();
  const u = msg({ text: "течёт кран" });
  await handleUpdate(u, w.deps);
  const n = w.sent.length;
  assertEquals(await handleUpdate(u, w.deps), { type: "repeat" });
  assertEquals(w.sent.length, n);
});

Deno.test("незнакомый чат: подсказка без компаний и объектов, без заявки", async () => {
  const w = world({ who: { kind: "none" } });
  const r = await handleUpdate(msg({ text: "течёт кран в БЦ Демо" }), w.deps);
  assertEquals(r.type, "unlinked");
  assertEquals(w.sent.length, 1);
  assertEquals(w.sent[0].html, TEXTS.ru.startUnknown);
  assertFalse(w.calls.includes("context"));
  assertFalse(w.sent[0].html.includes("Демо"));
  assertEquals(w.orders.length, 0);
});

Deno.test("незнакомый чат по-английски", async () => {
  const w = world({ who: { kind: "none" } });
  await handleUpdate(msg({ text: "/start", lang: "en" }), w.deps);
  assertStringIncludes(w.sent[0].html, "Hey Helpy");
});

Deno.test("гость по QR объекта: текст → карточка ИИ → «Создать» → заявка", async () => {
  const w = world({ ai: aiLeak });
  await handleUpdate(msg({ text: "/start obj_obj" }), w.deps);
  assertStringIncludes(w.sent[0].html, "Белград · БЦ «Демо»");

  await handleUpdate(msg({ text: "в переговорной капает с кондиционера, срочно" }), w.deps);
  const card = w.sent.at(-1)!;
  assertStringIncludes(card.html, "<b>Течёт кондиционер</b>");
  assertStringIncludes(card.html, "301 · Переговорная");
  assertStringIncludes(card.html, "Климат");
  assertStringIncludes(card.html, "высокая");
  assertFalse(card.html.includes(TEXTS.ru.aiOff));
  const s = w.sessions.get(CHAT)!;
  assertEquals(s.step, "confirm");

  const cardId = s.card!;
  await handleUpdate(press("c", cardId), w.deps);
  assertEquals(w.orders.length, 1);
  const o = w.orders[0];
  assertEquals(o.object_id, OBJ);
  assertEquals(o.location_id, ROOM);
  assertEquals(o.layer_id, HVAC);
  assertEquals(o.priority, "high");
  assertEquals(o.reporter, { name: "Мария К.", username: null });
  const done = w.edits.at(-1)!;
  assertStringIncludes(done.html, "Заявка № 42 принята");
  // Гостю — без ссылки в приложение.
  assertEquals(done.markup, undefined);
});

Deno.test("ИИ недоступен — текст как есть, пометка", async () => {
  const w = world({ ai: "throw" });
  await handleUpdate(msg({ text: "Не работает свет в коридоре" }), w.deps);
  const card = w.sent.at(-1)!;
  assertStringIncludes(card.html, "<b>Не работает свет в коридоре</b>");
  assertStringIncludes(card.html, TEXTS.ru.aiOff);
  assertStringIncludes(card.html, "БЦ «Демо» · весь объект");
});

Deno.test("сотрудник с несколькими объектами: выбор объекта → карточка → ссылка в приложение", async () => {
  const w = world({ who: { kind: "user", company_id: CO, profile_id: "p1", role: "requester" } });
  await handleUpdate(msg({ text: "Мигает лампа" }), w.deps);
  assertEquals(w.sessions.get(CHAT)?.step, "object");
  assertStringIncludes(w.sent.at(-2)!.html, "На каком объекте?");
  const ask = w.sent.at(-2)!;
  await handleUpdate(press(`o:${OBJ2}`, 102), w.deps);
  const s = w.sessions.get(CHAT)!;
  assertEquals(s.step, "confirm");
  assertEquals(s.draft?.object_id, OBJ2);
  assert(ask);
  assertStringIncludes(w.edits.at(-1)!.html, "Москва · Офис 1 · весь объект");
  await handleUpdate(press("c", s.card!), w.deps);
  const markup = w.edits.at(-1)!.markup as { inline_keyboard: { url?: string }[][] };
  assertEquals(markup.inline_keyboard[0][0].url, "https://app.example/#/orders/00000000-0000-4000-8000-000000000001");
});

Deno.test("кнопки: срочность, место, старая карточка, отмена", async () => {
  const w = world();
  await handleUpdate(msg({ text: "Шумит вентилятор" }), w.deps);
  const card = w.sessions.get(CHAT)!.card!;
  await handleUpdate(press("pr", card), w.deps);
  assertStringIncludes(w.edits.at(-1)!.html, "Насколько срочно?");
  await handleUpdate(press("r:critical", card), w.deps);
  assertEquals(w.sessions.get(CHAT)!.draft!.priority, "critical");
  await handleUpdate(press("r:hack", card), w.deps);
  assertEquals(w.sessions.get(CHAT)!.draft!.priority, "critical");
  await handleUpdate(press("pl", card), w.deps);
  const kb = (w.edits.at(-1)!.markup as { inline_keyboard: { callback_data?: string }[][] }).inline_keyboard.flat();
  assert(kb.some((b) => b.callback_data === `p:${ROOM}`));
  // Гость ссылки объекта не меняет объект.
  assertFalse(kb.some((b) => b.callback_data === "ob"));
  await handleUpdate(press(`p:${ROOM}`, card), w.deps);
  assertEquals(w.sessions.get(CHAT)!.draft!.location_id, ROOM);

  await handleUpdate(press("c", card + 50), w.deps);
  assertEquals(w.answers.at(-1), TEXTS.ru.stale);
  assertEquals(w.orders.length, 0);

  await handleUpdate(press("x", card), w.deps);
  assertEquals(w.sessions.get(CHAT), null);
  await handleUpdate(press("c", card), w.deps);
  assertEquals(w.orders.length, 0);
});

Deno.test("лимит заявок — понятный ответ, фото удаляется", async () => {
  const w = world({
    ai: aiLeak,
    vision: null,
    create: { ok: false, error: "rate_limited" },
  });
  await handleUpdate(
    msg({ caption: "капает", photo: [{ file_id: "F", width: 800, height: 600, file_size: 1000 }] }),
    w.deps,
  );
  const card = w.sessions.get(CHAT)!.card!;
  await handleUpdate(press("c", card), w.deps);
  assertEquals(w.uploads.length, 1);
  assertEquals(w.removed, w.uploads);
  assertEquals(w.edits.at(-1)!.html, TEXTS.ru.rateLimited);
  assertEquals(w.sessions.get(CHAT), null);
});

Deno.test("голос: длинный, ошибка распознавания, удачный", async () => {
  const long = world();
  await handleUpdate(msg({ voice: { file_id: "v", duration: 45 } }), long.deps);
  assertEquals(long.sent.at(-1)!.html, TEXTS.ru.voiceTooLong);

  const bad = world({ stt: Object.assign(new Error("x"), { code: "http_403" }) });
  const r = await handleUpdate(msg({ voice: { file_id: "v", duration: 5 } }), bad.deps);
  assertEquals(bad.sent.at(-1)!.html, TEXTS.ru.voiceEmpty);
  assertEquals(r.code, "http_403");

  const good = world({ stt: "течёт кран на кухне" });
  await handleUpdate(msg({ voice: { file_id: "v", duration: 5 } }), good.deps);
  const card = good.sent.at(-1)!.html;
  assertStringIncludes(card, "Услышал: «течёт кран на кухне»");
  assertStringIncludes(card, "<b>Течёт кран на кухне</b>");
});

Deno.test("фото: вид, неисправность, кандидат из реестра, фото в заявку", async () => {
  const v: Vision = {
    kind: "ac",
    layer: { id: HVAC, name: "Климат" },
    nameplate: null,
    defect: "течь конденсата",
    confidence: 0.9,
  };
  const w = world({ vision: v, ai: null });
  await handleUpdate(msg({ photo: [{ file_id: "F", width: 800, height: 600, file_size: 1000 }] }), w.deps);
  const s = w.sessions.get(CHAT)!;
  assertEquals(s.draft!.asset_id, AC);
  assertEquals(s.draft!.location_id, ROOM);
  assertEquals(s.draft!.title, "течь конденсата");
  assertStringIncludes(w.sent.at(-1)!.html, "Кондиционер КД-301");
  await handleUpdate(press("c", s.card!), w.deps);
  assertEquals(w.orders[0].asset_id, AC);
  assert(String(w.orders[0].photo_path).startsWith(`${CO}/${w.orders[0].id}/tg_`));
});

Deno.test("фото без ИИ и без подписи — просим текст, фото остаётся в черновике", async () => {
  const w = world({ vision: null });
  await handleUpdate(msg({ photo: [{ file_id: "F", width: 800, height: 600, file_size: 1000 }] }), w.deps);
  assertEquals(w.sent.at(-1)!.html, TEXTS.ru.photoNoAi);
  await handleUpdate(msg({ text: "сломан замок" }), w.deps);
  assertEquals(w.sessions.get(CHAT)!.draft!.photo_file_id, "F");
});

Deno.test("группа: без упоминания — тишина; с упоминанием — карточка; чужие кнопки", async () => {
  const w = world({ who: { kind: "group", company_id: CO, object: { id: OBJ, name: "БЦ «Демо»" } } });
  const r = await handleUpdate(msg({ chatType: "supergroup", text: "кто пойдёт обедать?" }), w.deps);
  assertEquals(r.type, "group_skip");
  assertEquals(w.sent.length, 0);
  assertFalse(w.calls.includes("resolve"));

  await handleUpdate(msg({ chatType: "supergroup", text: "@HeyHelpy_bot течёт кран" }), w.deps);
  const card = w.sent.at(-1)!;
  assertEquals(card.chat, GROUP);
  assert(card.replyTo);
  assertStringIncludes(card.html, "<b>Течёт кран</b>");
  const id = w.sessions.get(GROUP)!.card!;
  await handleUpdate(press("c", id, { chat: GROUP, group: true, from: 999 }), w.deps);
  assertEquals(w.orders.length, 0);
  assertEquals(w.answers.at(-1), TEXTS.ru.stale);
  await handleUpdate(press("c", id, { chat: GROUP, group: true }), w.deps);
  assertEquals(w.orders.length, 1);
});

Deno.test("команды: привязка кодом, /reset, /connect, /cancel", async () => {
  const w = world({ who: { kind: "none" } });
  await handleUpdate(msg({ text: "/start link_123456" }), w.deps);
  assertEquals(w.sent.at(-1)!.html, "Готово, Мария. Теперь можно писать заявки сюда — текстом, голосом или фото.");
  await handleUpdate(msg({ text: "/start link_000000" }), w.deps);
  assertEquals(w.sent.at(-1)!.html, TEXTS.ru.badCode);
  await handleUpdate(msg({ text: "/start obj_other" }), w.deps);
  assertEquals(w.sent.at(-1)!.html, TEXTS.ru.otherCompany);
  await handleUpdate(msg({ text: "/start co_co" }), w.deps);
  assertStringIncludes(w.sent.at(-1)!.html, "«Демо БЦ»");
  await handleUpdate(msg({ text: "/connect ABC" }), w.deps);
  assertEquals(w.sent.at(-1)!.html, TEXTS.ru.connectInPrivate);
  await handleUpdate(msg({ chatType: "group", text: "/connect ABC" }), w.deps);
  assertStringIncludes(w.sent.at(-1)!.html, "Группа подключена");
  // Ссылка «добавить в группу»: /start grp_<код>.
  await handleUpdate(msg({ chatType: "group", text: "/start@HeyHelpy_bot grp_ABC" }), w.deps);
  assertStringIncludes(w.sent.at(-1)!.html, "Группа подключена");
  await handleUpdate(msg({ chatType: "group", text: "/start grp_XYZ" }), w.deps);
  assertEquals(w.sent.at(-1)!.html, TEXTS.ru.badCode);
  await handleUpdate(msg({ text: "/cancel" }), w.deps);
  assertEquals(w.sent.at(-1)!.html, TEXTS.ru.nothingToCancel);
  w.setWho({ kind: "user", company_id: CO });
  await handleUpdate(msg({ text: "/reset" }), w.deps);
  assertEquals(w.sent.at(-1)!.html, TEXTS.ru.reset);
});

Deno.test("отключённая ссылка — понятный ответ, без заявки", async () => {
  const w = world({ who: { kind: "guest_off" } });
  await handleUpdate(msg({ text: "течёт" }), w.deps);
  assertEquals(w.sent.at(-1)!.html, TEXTS.ru.linkOff);
  assertFalse(w.calls.includes("context"));
});

Deno.test("геопозиция: ближайший объект или список", async () => {
  const w = world({ who: { kind: "user", company_id: CO } });
  await handleUpdate(msg({ location: { latitude: 44.8, longitude: 20.4 } }), w.deps);
  assertStringIncludes(w.sent.at(-1)!.html, "Объект: Белград · БЦ «Демо»");
  await handleUpdate(msg({ location: { latitude: 10, longitude: 10 } }), w.deps);
  assertStringIncludes(w.sent.at(-1)!.html, "300 м");
});

Deno.test("в логе нет текста, имени и chat_id", async () => {
  const w = world({ ai: aiLeak, who: { kind: "user", company_id: CO } });
  const fields: J[] = [];
  fields.push(await handleUpdate(msg({ text: "секретный текст заявки БЦ «Демо»" }), w.deps));
  fields.push(await handleUpdate(msg({ voice: { file_id: "v", duration: 3 } }), w.deps));
  const s = JSON.stringify(fields);
  assertFalse(s.includes("секретный"));
  assertFalse(s.includes("Мария"));
  assertFalse(s.includes(String(CHAT)));
  assertFalse(s.includes(String(USER)));
});

Deno.test("уведомления: /stop и кнопка «Не присылать» выключают, /start — снова включает", async () => {
  const w = world({});
  await handleUpdate(msg({ text: "/stop" }), w.deps);
  assertStringIncludes(w.sent.at(-1)!.html, "уведомления о заявках больше не придут");
  assert(w.calls.includes("notify_off"));
  await handleUpdate(press("nf:off", 999), w.deps);
  assertEquals(w.calls.filter((c) => c === "notify_off").length, 2);
  await handleUpdate(msg({ text: "/start" }), w.deps);
  assert(w.calls.includes("notify_on"));
});

// ---------------------------------------------------------------------------
// Шаг 28: исполнителю — «Новая заявка» и «Взять в работу»
// ---------------------------------------------------------------------------

const WO = "3f2a1c00-0000-4000-8000-000000000277";
const info = (targets: AssignInfo["targets"]): AssignInfo => ({
  number: "3F2A1C",
  title: "Капает вода с кондиционера",
  object: "БЦ «Демо»",
  place: "301 Переговорная",
  priority: "high",
  contractor_id: "k0000000-0000-4000-8000-000000000031",
  targets,
});

Deno.test("кнопка «Взять в работу»: данные ≤ 64 байт, разбор", () => {
  const d = takeData(WO);
  assert(new TextEncoder().encode(d).length <= 64);
  assertEquals(parseTake(d), WO);
  assertEquals(parseTake("tk:не-uuid"), null);
  assertEquals(parseTake("c"), null);
});

Deno.test("текст «Новая заявка»: объект, помещение, срочность, кнопки", () => {
  const ru = assignNotice(info([]), "ru", WO, "https://app.example/");
  assertStringIncludes(ru.html, "Новая заявка № 3F2A1C: Капает вода с кондиционера");
  assertStringIncludes(ru.html, "БЦ «Демо» · 301 Переговорная · срочность высокая");
  const kb = ru.markup.inline_keyboard.flat();
  assertEquals(kb[0].callback_data, takeData(WO));
  assertEquals(kb[1].url, `https://app.example/#/orders/${WO}`);
  assertEquals(kb[2].callback_data, "nf:off");
  const en = assignNotice({ ...info([]), priority: "normal", place: null }, "en", WO, "https://app.example/");
  assertStringIncludes(en.html, "New work order #3F2A1C");
  assertFalse(en.html.includes("priority"));
  // HTML экранируется
  const x = assignNotice({ ...info([]), title: "<b>щит</b>" }, "ru", WO, "u");
  assertStringIncludes(x.html, "&lt;b&gt;щит&lt;/b&gt;");
});

Deno.test("рассылка: ошибка одному — отметка снимается, остальным уходит", async () => {
  const sent: number[] = [];
  const released: string[] = [];
  const r = await notifyAssigned(WO, "actor", {
    claim: () =>
      Promise.resolve(info([
        { chat_id: 1, lang: "ru", profile_id: "p1" },
        { chat_id: 2, lang: "en", profile_id: "p2" },
      ])),
    release: (_o, _c, p) => {
      released.push(p);
      return Promise.resolve();
    },
    send: (chat) => (chat === 2 ? Promise.reject(new Error("blocked")) : Promise.resolve(sent.push(chat))),
    appUrl: "u",
  });
  assertEquals(r, { sent: 1, failed: 1 });
  assertEquals(sent, [1]);
  assertEquals(released, ["p2"]);
  const none = await notifyAssigned(WO, null, {
    claim: () => Promise.resolve(null),
    release: () => Promise.resolve(),
    send: () => Promise.reject(new Error("не должен")),
    appUrl: "u",
  });
  assertEquals(none, { sent: 0, failed: 0 });
});

Deno.test("ответ «Взять в работу» → текст", () => {
  assertEquals(takeReply({ ok: true }), "takeOk");
  assertEquals(takeReply({ error: "already" }), "takeAlready");
  assertEquals(takeReply({ error: "not_executor" }), "takeNotExecutor");
  assertEquals(takeReply({ error: "not_linked" }), "takeNotLinked");
  assertEquals(takeReply({ error: "bad_status" }), "takeGone");
});

Deno.test("бот: «Взять в работу» — статус меняет база, автору уходит «в работе»", async () => {
  const w = world({
    take: { ok: true, number: "3F2A1C", title: "Капает вода" },
    author: { chat_id: 9001, kind: "guest", lang: "ru", number: "3F2A1C", title: "Капает вода", status: "in_progress" },
  });
  await handleUpdate(press(takeData(WO), 555), w.deps);
  assert(w.calls.includes(`take_${CHAT}_${WO}`));
  assertFalse(w.calls.includes("resolve")); // привязку проверяет tg_take_order
  assertStringIncludes(w.edits.at(-1)!.html, "вы взяли её в работу");
  const kb = (w.edits.at(-1)!.markup as { inline_keyboard: { url?: string; callback_data?: string }[][] })
    .inline_keyboard.flat();
  assertEquals(kb.length, 1); // осталась только «Открыть»
  assert(kb[0].url?.endsWith(WO));
  assert(w.calls.includes("claim_in_progress"));
  assertEquals(w.sent.at(-1)!.chat, 9001);
  assertStringIncludes(w.sent.at(-1)!.html, "взята в работу");
});

Deno.test("бот: «Взять в работу» без прав — понятный ответ, статус не меняется", async () => {
  const w = world({ take: { error: "not_executor" } });
  await handleUpdate(press(takeData(WO), 555), w.deps);
  assertEquals(w.answers.at(-1), TEXTS.ru.takeNotExecutor);
  assertEquals(w.sent.at(-1)!.html, TEXTS.ru.takeNotExecutor);
  assertFalse(w.calls.includes("claim_in_progress"));
  const w2 = world({ take: { error: "already", number: "3F2A1C" } });
  await handleUpdate(press(takeData(WO), 555), w2.deps);
  assertEquals(w2.edits.at(-1)!.html, "Заявка № 3F2A1C уже в работе.");
});

Deno.test("бот: заявка создана и назначена — исполнителям «Новая заявка»", async () => {
  const w = world({
    ai: aiLeak,
    who: { kind: "user", company_id: CO, profile_id: "me", object: { id: OBJ, name: "БЦ «Демо»", city: "Белград" } },
    create: { ok: true, number: "3F2A1C", contractor: "КлиматСервис", status: "assigned" },
    assign: info([{ chat_id: 4242, lang: "ru", profile_id: "p1" }]),
  });
  await handleUpdate(msg({ text: "в переговорной 301 капает кондиционер" }), w.deps);
  const card = w.sessions.get(CHAT)!.card!;
  await handleUpdate(press("c", card), w.deps);
  assert(w.calls.includes("assign_me"), "актор — автор заявки (себе не шлём)");
  const toExec = w.sent.find((x) => x.chat === 4242)!;
  assertStringIncludes(toExec.html, "Новая заявка № 3F2A1C");
  // Без подрядчика — не зовём.
  const w2 = world({ ai: aiLeak, create: { ok: true, number: 1 } });
  await handleUpdate(msg({ text: "в переговорной 301 капает кондиционер" }), w2.deps);
  await handleUpdate(press("c", w2.sessions.get(CHAT)!.card!), w2.deps);
  assertFalse(w2.calls.some((c) => c.startsWith("assign_")));
});

Deno.test("тексты шага 28 есть на обоих языках", () => {
  for (const k of ["assignNew", "bTake", "bOpen", "bAssignOff", "takeOk", "takeAlready", "takeNotExecutor", "takeGone"] as const) {
    assert(TEXTS.ru[k] && TEXTS.en[k], k);
  }
});


// --- Шаг 29: заявка на демо с сайта (/start demo) ---------------------------

const OWNER = -100777;

Deno.test("demo: /start demo — просьба написать, без компаний и объектов; текст → лид → «Спасибо»", async () => {
  const w = world({ who: { kind: "none" }, lead: { ok: true, id: "l1" } });
  await handleUpdate(msg({ text: "/start demo" }), w.deps);
  assertStringIncludes(w.sent[0].html, "Расскажите в одном сообщении");
  assertEquals(w.calls.includes("resolve"), false, "незнакомцу не показываем ни компаний, ни объектов");
  assertEquals(w.sessions.get(CHAT)?.step, "lead");

  await handleUpdate(msg({ text: "ООО Ромашка, 5 объектов в Москве и Казани, хотим посмотреть акты" }), w.deps);
  assertEquals(w.leads.length, 1);
  assertEquals(w.leads[0].lang, "ru");
  assertEquals(w.leads[0].name, "Мария Ковалёва");
  assertStringIncludes(w.sent.at(-1)!.html, "Спасибо! Мы получили заявку");
  assertEquals(w.sessions.get(CHAT) ?? null, null, "черновик лида закрыт");
  assertEquals(w.orders.length, 0, "заявка на работу не создаётся");
  assertEquals(JSON.stringify(w.logs).includes("Ромашка"), false, "текст лида не пишется в лог");

  // следующее сообщение — снова обычный путь (незнакомец → подсказка про ссылку)
  await handleUpdate(msg({ text: "ещё вопрос" }), w.deps);
  assertEquals(w.leads.length, 1);
  assertStringIncludes(w.sent.at(-1)!.html, "нужна ссылка от работодателя");
});

Deno.test("demo: английский по языку Telegram", async () => {
  const w = world({ who: { kind: "none" }, lead: { ok: true } });
  await handleUpdate(msg({ text: "/start demo", lang: "en" }), w.deps);
  assertStringIncludes(w.sent[0].html, "In one message, tell us");
  await handleUpdate(msg({ text: "Acme, 3 sites", lang: "en" }), w.deps);
  assertEquals(w.leads[0].lang, "en");
  assertStringIncludes(w.sent.at(-1)!.html, "Thank you!");
});

Deno.test("demo: голос и фото — просим текстом, черновик остаётся; длинный текст — отказ", async () => {
  const w = world({ who: { kind: "none" }, lead: { ok: true } });
  await handleUpdate(msg({ text: "/start demo" }), w.deps);
  await handleUpdate(msg({ voice: { file_id: "v", duration: 5, file_size: 1000 } }), w.deps);
  assertStringIncludes(w.sent.at(-1)!.html, "Напишите, пожалуйста, текстом");
  await handleUpdate(msg({ text: "я".repeat(2001) }), w.deps);
  assertStringIncludes(w.sent.at(-1)!.html, "2000 символов");
  assertEquals(w.leads.length, 0);
  assertEquals(w.sessions.get(CHAT)?.step, "lead");
  await handleUpdate(msg({ text: "/cancel" }), w.deps);
  assertEquals(w.sessions.get(CHAT) ?? null, null, "/cancel работает и тут");
});

Deno.test("demo: лимит — «уже получили», черновик закрыт", async () => {
  const w = world({ who: { kind: "none" }, lead: { ok: false, error: "rate_limited" }, leadsChat: OWNER });
  await handleUpdate(msg({ text: "/start demo" }), w.deps);
  await handleUpdate(msg({ text: "снова я" }), w.deps);
  assertStringIncludes(w.sent.at(-1)!.html, "уже получили ваши заявки");
  assertEquals(w.sent.some((x) => x.chat === OWNER), false, "сверх лимита владельцу не шлём");
});

Deno.test("demo: владельцу — «🆕 Заявка на демо: @ник · имя» с экранированным текстом", async () => {
  const w = world({ who: { kind: "none" }, lead: { ok: true }, leadsChat: OWNER });
  await handleUpdate(msg({ text: "/start demo" }), w.deps);
  const u = msg({ text: "Компания <b>X</b> & Co" });
  u.message!.from = { id: USER, first_name: "Иван", username: "ivan_x", language_code: "ru" };
  await handleUpdate(u, w.deps);
  const n = w.sent.find((x) => x.chat === OWNER)!;
  assertStringIncludes(n.html, "🆕 Заявка на демо: @ivan_x · Иван");
  assertStringIncludes(n.html, "Компания &lt;b&gt;X&lt;/b&gt; &amp; Co");
  assertStringIncludes(w.sent.at(-1)!.html, "Спасибо!");
});

Deno.test("demo: нет 0026 — с чатом владельца всё равно «Спасибо», без него — «не получилось»", async () => {
  const a = world({ who: { kind: "none" }, lead: "throw", leadsChat: OWNER });
  await handleUpdate(msg({ text: "/start demo" }), a.deps);
  await handleUpdate(msg({ text: "Компания" }), a.deps);
  assertEquals(a.sent.some((x) => x.chat === OWNER), true);
  assertStringIncludes(a.sent.at(-1)!.html, "Спасибо!");

  const b = world({ who: { kind: "none" }, lead: "throw" });
  await handleUpdate(msg({ text: "/start demo" }), b.deps);
  await handleUpdate(msg({ text: "Компания" }), b.deps);
  assertStringIncludes(b.sent.at(-1)!.html, "Не получилось сохранить");
  assertEquals(b.sessions.get(CHAT)?.step, "lead", "можно отправить ещё раз");
});

Deno.test("demo: гость и группа не ломаются — без /start demo обычные заявки", async () => {
  const g = world({ lead: { ok: true } }); // гость ссылки объекта
  await handleUpdate(msg({ text: "течёт кран в лобби" }), g.deps);
  assertEquals(g.leads.length, 0);
  assertEquals(g.calls.includes("resolve"), true);

  const gr = world({ who: { kind: "group", company_id: CO, object: { id: OBJ, name: "БЦ «Демо»" } }, lead: { ok: true } });
  await handleUpdate(msg({ text: "/start demo", chatType: "group" }), gr.deps);
  assertEquals(gr.sessions.get(GROUP) ?? null, null, "в группе режим демо не включается");
  assertEquals(gr.leads.length, 0);
});

Deno.test("leadsChatId и leadWho", () => {
  assertEquals(leadsChatId("123456"), 123456);
  assertEquals(leadsChatId(" -1001234567890 "), -1001234567890);
  assertEquals(leadsChatId(""), null);
  assertEquals(leadsChatId(undefined), null);
  assertEquals(leadsChatId("@owner"), null);
  assertEquals(leadWho({ id: 1, username: "a", first_name: "Анна", last_name: "К." }), "@a · Анна К.");
  assertEquals(leadWho({ id: 1 }), "—");
});
