// Логика бота: обновление Telegram → ответы и заявка. Без сети и окружения:
// база, Telegram, хранилище и модели приходят зависимостями (Deps) — их
// подменяют тесты (bot_test.ts).
//
// Личность чата определяет база (tg_resolve_chat) по chat_id: аккаунт,
// гость ссылки объекта / компании, группа объекта или никто. Без ссылки бот
// не показывает ни компаний, ни объектов и не создаёт заявок.
//
// Разговор: сообщение (текст / голос / фото) → черновик → карточка с
// кнопками («Создать», «Изменить место», «Срочность», «Отмена») → заявка.
// Черновик живёт в базе 30 минут (tg_session_*).

import {
  type Catalog,
  clip,
  type IntakeResult,
  type LayerRef,
  type PlaceRef,
  type Priority,
  PRIORITIES,
  stripWakePhrase,
  TEXT_MAX,
  TITLE_MAX,
} from "../_shared/intake.ts";
import { type AssetRef, buildResult, type Vision } from "../_shared/identify.ts";
import { kindLabel } from "../_shared/kinds.ts";
import {
  BOT_USERNAME,
  groupAddressed,
  type InlineButton,
  parseCommand,
  pickPhoto,
  type ReplyMarkup,
  reporterName,
  stripMention,
  type TelegramApi,
  type TgCallback,
  TgError,
  type TgMessage,
  type TgUpdate,
  type TgUser,
  VOICE_MAX_BYTES,
  VOICE_MAX_SECONDS,
} from "./telegram.ts";
import { type Lang, langOf, t, type TextKey } from "./texts.ts";

// ---------------------------------------------------------------------------
// Зависимости
// ---------------------------------------------------------------------------

export type J = Record<string, unknown>;

export interface ObjectRef {
  id: string;
  name: string;
  city?: string | null;
}

/** Ответ tg_resolve_chat. */
export interface Who {
  kind: "user" | "guest" | "guest_off" | "group" | "none";
  company_id?: string;
  company_name?: string;
  profile_id?: string;
  name?: string | null;
  role?: string;
  link_id?: string;
  link_object_id?: string | null;
  object?: ObjectRef | null;
}

/** Ответ tg_context: что видит чат. */
export interface Ctx {
  kind?: string;
  error?: string;
  layers: LayerRef[];
  objects: (ObjectRef & { lat?: number | null; lng?: number | null })[];
  places: PlaceRef[];
  assets: AssetRef[];
}

export interface Db {
  takeUpdate(updateId: number): Promise<boolean>;
  resolve(chat: number, group: boolean): Promise<Who>;
  linkChat(code: string, chat: number, username: string | null, name: string | null, lang: Lang): Promise<J>;
  guestStart(token: string, chat: number, name: string | null, lang: Lang): Promise<J>;
  reset(chat: number): Promise<boolean>;
  connectGroup(code: string, chat: number, title: string | null): Promise<J>;
  context(chat: number, group: boolean, objectId?: string | null): Promise<Ctx>;
  setObject(chat: number, objectId: string): Promise<J>;
  nearest(chat: number, lat: number, lng: number): Promise<J>;
  createOrder(chat: number, group: boolean, id: string, order: J): Promise<J>;
  sessionGet(chat: number): Promise<Session | null>;
  sessionPut(chat: number, state: Session | null): Promise<void>;
}

export interface Storage {
  upload(path: string, bytes: Uint8Array): Promise<void>;
  remove(path: string): Promise<void>;
}

export interface Ai {
  /** Разбор текста; null — модель недоступна (тогда текст как есть). */
  text(text: string, lang: Lang, catalog: Catalog): Promise<{ result: IntakeResult; model: string } | null>;
  /** Снимок → вид, система, шильдик, неисправность; null — не получилось. */
  vision(imageB64: string, lang: Lang, layers: LayerRef[]): Promise<{ vision: Vision; model: string } | null>;
  /** Голос → текст. Ошибка — исключение с кодом. */
  stt(audio: Uint8Array, lang: Lang): Promise<string>;
}

export interface Deps {
  tg: TelegramApi;
  db: Db;
  storage: Storage;
  ai: Ai;
  log: (fields: J) => void;
  uuid: () => string;
  /** Адрес веб-приложения (ссылка на заявку для привязанного пользователя). */
  appUrl: string;
  bot?: string;
}

// ---------------------------------------------------------------------------
// Черновик
// ---------------------------------------------------------------------------

export interface Draft {
  title: string;
  description: string | null;
  object_id: string | null;
  object_label: string | null;
  location_id: string | null;
  location_label: string | null;
  asset_id: string | null;
  asset_label: string | null;
  layer_id: string | null;
  layer_label: string | null;
  priority: Priority;
  photo_file_id: string | null;
  heard: string | null;
  photo_note: string | null;
  ai: boolean;
}

export interface Session {
  /** confirm — карточка; object — ждём объект; need_text — фото без текста. */
  step: "confirm" | "object" | "need_text";
  draft: Draft | null;
  /** id сообщения-карточки: кнопки старых карточек не срабатывают. */
  card: number | null;
  /** Автор черновика (Telegram user id): в группе жмёт кнопки только он. */
  author: number | null;
  photo_file_id?: string | null;
}

// ---------------------------------------------------------------------------
// Вспомогательное
// ---------------------------------------------------------------------------

export function esc(s: string | null | undefined): string {
  return (s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function cap(s: string): string {
  return s ? s[0].toUpperCase() + s.slice(1) : s;
}

function norm(s: string): string {
  return s.toLowerCase().replaceAll("ё", "е").replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

export function objectLabel(o: ObjectRef | null | undefined): string | null {
  if (!o) return null;
  return o.city && o.city.trim() && !o.name.startsWith(o.city) ? `${o.city} · ${o.name}` : o.name;
}

export function placeLabel(p: PlaceRef): string {
  const code = p.code?.trim();
  return code && !p.name.startsWith(code) ? `${code} · ${p.name}` : p.name;
}

function layerLabel(l: LayerRef | undefined, lang: Lang): string | null {
  if (!l) return null;
  const v = (l.name_i18n ?? {})[lang] ?? (l.name_i18n ?? {})["ru"];
  return typeof v === "string" && v.trim() ? v.trim() : l.name;
}

/** Объект, названный в тексте («в БЦ Демо», «Москва офис 3»): ровно один. */
export function objectFromText(text: string, objects: ObjectRef[]): ObjectRef | null {
  const t = ` ${norm(text)} `;
  const hits = objects.filter((o) => {
    const name = norm(o.name);
    if (name.length < 3) return false;
    if (!t.includes(` ${name} `)) return false;
    // «Офис 1» есть в нескольких городах — тогда нужен и город.
    const twins = objects.filter((x) => norm(x.name) === name);
    return twins.length === 1 || (!!o.city && t.includes(` ${norm(o.city)} `));
  });
  return hits.length === 1 ? hits[0] : null;
}

/** Черновик без ИИ: текст как есть. */
export function plainDraft(text: string): Draft {
  const clean = stripWakePhrase(text.replace(/\s+/g, " ").trim()) || text.trim();
  return {
    title: clip(cap(clean), TITLE_MAX),
    description: clean.length > TITLE_MAX ? clip(clean, 2000) : null,
    object_id: null,
    object_label: null,
    location_id: null,
    location_label: null,
    asset_id: null,
    asset_label: null,
    layer_id: null,
    layer_label: null,
    priority: "normal",
    photo_file_id: null,
    heard: null,
    photo_note: null,
    ai: false,
  };
}

/** Разбор ИИ → черновик (только значения справочников — их проверила normalize). */
export function aiDraft(text: string, r: IntakeResult, ctx: Ctx, lang: Lang): Draft {
  const d = plainDraft(text);
  d.title = r.title ?? d.title;
  d.description = r.description ?? d.description;
  d.priority = r.priority ?? "normal";
  d.ai = true;
  if (r.layer_id) {
    d.layer_id = r.layer_id;
    d.layer_label = layerLabel(ctx.layers.find((l) => l.id === r.layer_id), lang);
  }
  const place = r.location_id ? ctx.places.find((p) => p.id === r.location_id) : undefined;
  if (place) setPlace(d, place, ctx);
  return d;
}

function setObject(d: Draft, o: ObjectRef | null) {
  if ((o?.id ?? null) !== d.object_id) {
    d.location_id = null;
    d.location_label = null;
    d.asset_id = null;
    d.asset_label = null;
  }
  d.object_id = o?.id ?? null;
  d.object_label = objectLabel(o);
}

function setPlace(d: Draft, p: PlaceRef, ctx: Ctx) {
  const o = ctx.objects.find((x) => x.id === p.object_id) ??
    { id: p.object_id, name: p.object_name ?? "", city: p.object_city ?? null };
  setObject(d, o);
  d.location_id = p.id;
  d.location_label = placeLabel(p);
}

/** Объект черновика: из помещения → из текста → последний объект чата → единственный. */
export function settleObject(d: Draft, text: string, who: Who, ctx: Ctx): boolean {
  if (d.object_id) return true;
  const named = objectFromText(text, ctx.objects);
  const known = named ?? (who.object && ctx.objects.find((o) => o.id === who.object!.id)) ??
    (ctx.objects.length === 1 ? ctx.objects[0] : null);
  if (known) {
    setObject(d, known);
    return true;
  }
  // Пользователь без доступных объектов — «уточнит менеджер».
  return ctx.objects.length === 0;
}

// ---------------------------------------------------------------------------
// Карточка и меню
// ---------------------------------------------------------------------------

function prLabel(lang: Lang, p: Priority): string {
  return t(lang, `pr_${p}` as TextKey);
}

export function cardText(d: Draft, lang: Lang): string {
  const lines: string[] = [];
  if (d.heard) lines.push(`<i>${esc(t(lang, "heard", { text: d.heard }))}</i>`, "");
  if (d.photo_note) lines.push(`<i>${esc(d.photo_note)}</i>`, "");
  lines.push(esc(t(lang, "understood")), `<b>${esc(d.title)}</b>`);
  if (d.description && d.description !== d.title) lines.push(esc(clip(d.description, 300)));
  lines.push("");
  const where = d.object_label
    ? [d.object_label, d.location_label ?? t(lang, "wholeObject")].join(" · ")
    : t(lang, "managerWillClarify");
  lines.push(`📍 ${esc(where)}`);
  if (d.layer_label) lines.push(`🔧 ${esc(t(lang, "system"))}: ${esc(d.layer_label)}`);
  if (d.asset_label) lines.push(`🧰 ${esc(t(lang, "equipment"))}: ${esc(d.asset_label)}`);
  lines.push(`⚡ ${esc(t(lang, "priority"))}: ${esc(prLabel(lang, d.priority))}`);
  if (d.photo_file_id) lines.push(`📷 ${esc(t(lang, "photo"))}: ${esc(t(lang, "photoAttached"))}`);
  if (!d.ai) lines.push("", `<i>${esc(t(lang, "aiOff"))}</i>`);
  lines.push("", esc(t(lang, "createQ")));
  return lines.join("\n");
}

export function cardButtons(lang: Lang): ReplyMarkup {
  return {
    inline_keyboard: [
      [{ text: t(lang, "bCreate"), callback_data: "c" }],
      [
        { text: t(lang, "bPlace"), callback_data: "pl" },
        { text: t(lang, "bPriority"), callback_data: "pr" },
      ],
      [{ text: t(lang, "bCancel"), callback_data: "x" }],
    ],
  };
}

function rows(buttons: InlineButton[], perRow: number): InlineButton[][] {
  const out: InlineButton[][] = [];
  for (let i = 0; i < buttons.length; i += perRow) out.push(buttons.slice(i, i + perRow));
  return out;
}

/** Объекты кнопками, по городам («Москва · Офис 1»), не больше 30. */
export function objectButtons(objects: ObjectRef[], lang: Lang, back: boolean): ReplyMarkup {
  const sorted = [...objects].sort((a, b) =>
    (a.city ?? "").localeCompare(b.city ?? "") || a.name.localeCompare(b.name)
  ).slice(0, 30);
  const kb = rows(sorted.map((o) => ({ text: objectLabel(o) ?? o.name, callback_data: `o:${o.id}` })), 2);
  if (back) kb.push([{ text: t(lang, "bBack"), callback_data: "bk" }]);
  return { inline_keyboard: kb };
}

export function placeButtons(places: PlaceRef[], lang: Lang, otherObject: boolean): ReplyMarkup {
  const kb = rows(places.slice(0, 24).map((p) => ({ text: placeLabel(p), callback_data: `p:${p.id}` })), 2);
  kb.push([{ text: t(lang, "bWhole"), callback_data: "p:-" }]);
  if (otherObject) kb.push([{ text: t(lang, "bOtherObject"), callback_data: "ob" }]);
  kb.push([{ text: t(lang, "bBack"), callback_data: "bk" }]);
  return { inline_keyboard: kb };
}

export function priorityButtons(lang: Lang): ReplyMarkup {
  return {
    inline_keyboard: [
      ...rows(PRIORITIES.map((p) => ({ text: cap(prLabel(lang, p)), callback_data: `r:${p}` })), 2),
      [{ text: t(lang, "bBack"), callback_data: "bk" }],
    ],
  };
}

const LOCATION_KB = (lang: Lang): ReplyMarkup => ({
  keyboard: [[{ text: t(lang, "bLocation"), request_location: true }]],
  resize_keyboard: true,
  one_time_keyboard: true,
});

// ---------------------------------------------------------------------------
// Обработка обновления
// ---------------------------------------------------------------------------

interface Turn {
  deps: Deps;
  chat: number;
  group: boolean;
  lang: Lang;
  from?: TgUser;
  replyTo?: number;
  log: J;
}

async function say(turn: Turn, key: TextKey, vars: Record<string, string> = {}, markup?: ReplyMarkup) {
  const escaped = Object.fromEntries(Object.entries(vars).map(([k, v]) => [k, esc(v)]));
  return await turn.deps.tg.send(turn.chat, esc(t(turn.lang, key, {})).replace(
    /\{(\w+)\}/g,
    (m, k) => (k in escaped ? escaped[k] : m),
  ), markup, turn.group ? turn.replyTo : undefined);
}

/** Главная точка: одно обновление Telegram. Ошибки — наружу (index.ts отвечает 200). */
export async function handleUpdate(update: TgUpdate, deps: Deps): Promise<J> {
  const log: J = {};
  if (!(await deps.db.takeUpdate(update.update_id))) {
    return { type: "repeat" };
  }
  const bot = deps.bot ?? BOT_USERNAME;
  if (update.callback_query) {
    log.type = "callback";
    await handleCallback(update.callback_query, deps, log);
    return log;
  }
  const m = update.message;
  if (!m || m.chat.type === "channel") return { type: "skip" };
  const group = m.chat.type !== "private";
  if (group && !groupAddressed(m, bot)) return { type: "group_skip" };
  const turn: Turn = {
    deps,
    chat: m.chat.id,
    group,
    lang: langOf(m.from?.language_code),
    from: m.from,
    replyTo: m.message_id,
    log,
  };
  log.chat = group ? "group" : "private";
  await handleMessage(m, turn, bot);
  return log;
}

async function handleMessage(m: TgMessage, turn: Turn, bot: string) {
  const { deps, chat, group } = turn;
  const cmd = parseCommand(m.text, bot);
  if (cmd) {
    turn.log.type = `cmd_${cmd.name}`;
    await handleCommand(cmd.name, cmd.arg, m, turn, bot);
    return;
  }
  const who = await deps.db.resolve(chat, group);
  turn.log.who = who.kind;
  if (who.kind === "none") {
    turn.log.type = "unlinked";
    await say(turn, group ? "groupNotConnected" : "startUnknown");
    return;
  }
  if (who.kind === "guest_off") {
    turn.log.type = "link_off";
    await say(turn, "linkOff");
    return;
  }
  if (m.location) {
    turn.log.type = "location";
    if (group) return void await say(turn, "locationOnlyPrivate");
    await onLocation(m.location.latitude, m.location.longitude, who, turn);
    return;
  }
  if (m.voice) {
    turn.log.type = "voice";
    await onVoice(m, who, turn);
    return;
  }
  if (m.photo) {
    turn.log.type = "photo";
    await onPhoto(m, who, turn, bot);
    return;
  }
  const raw = group ? stripMention(m.text ?? "", bot) : (m.text ?? "").trim();
  if (!raw) {
    turn.log.type = m.text !== undefined ? "empty" : "unsupported";
    await say(turn, m.text !== undefined && group ? "helpGroup" : "unsupported", { bot });
    return;
  }
  turn.log.type = "text";
  await intake(raw, who, turn, {});
}

// --- Команды ---------------------------------------------------------------

async function handleCommand(name: string, arg: string, m: TgMessage, turn: Turn, bot: string) {
  const { deps, chat, group, lang } = turn;
  const from = m.from;
  switch (name) {
    case "start": {
      if (!group && arg.startsWith("link_")) {
        const r = await deps.db.linkChat(arg.slice(5), chat, from?.username ?? null, reporterName(from), lang);
        turn.log.result = r.ok ? "linked" : "bad_code";
        if (!r.ok) return void await say(turn, "badCode");
        const nm = typeof r.name === "string" && r.name.trim() ? r.name.trim().split(/\s+/)[0] : "";
        return void await say(turn, nm ? "linked" : "linkedNoName", { name: nm });
      }
      if (!group && (arg.startsWith("obj_") || arg.startsWith("co_"))) {
        const token = arg.slice(arg.indexOf("_") + 1);
        const r = await deps.db.guestStart(token, chat, reporterName(from), lang);
        turn.log.result = r.ok ? `start_${r.scope}` : String(r.error);
        if (!r.ok) return void await say(turn, r.error === "other_company" ? "otherCompany" : "badLink");
        const obj = r.object as ObjectRef | null;
        if (obj) {
          return void await say(turn, r.kind === "user" ? "userObject" : "guestObject", {
            object: objectLabel(obj) ?? obj.name,
          });
        }
        return void await say(turn, "guestCompany", { company: String(r.company_name ?? "") });
      }
      const who = await deps.db.resolve(chat, group);
      turn.log.who = who.kind;
      if (who.kind === "none") return void await say(turn, group ? "groupNotConnected" : "startUnknown");
      if (who.kind === "guest_off") return void await say(turn, "linkOff");
      return void await say(turn, group ? "helpGroup" : "help", { bot });
    }
    case "help": {
      const who = await deps.db.resolve(chat, group);
      if (who.kind === "none") return void await say(turn, group ? "groupNotConnected" : "startUnknown");
      return void await say(turn, group ? "helpGroup" : "help", { bot });
    }
    case "cancel": {
      const s = await deps.db.sessionGet(chat);
      await deps.db.sessionPut(chat, null);
      return void await say(turn, s ? "cancelled" : "nothingToCancel");
    }
    case "reset": {
      if (group) return void await say(turn, "helpGroup", { bot });
      const ok = await deps.db.reset(chat);
      return void await say(turn, ok ? "reset" : "resetNothing");
    }
    case "connect": {
      if (!group) return void await say(turn, "connectInPrivate");
      const r = await deps.db.connectGroup(arg, chat, m.chat.title ?? null);
      turn.log.result = r.ok ? "group_connected" : "bad_code";
      if (!r.ok) return void await say(turn, "badCode");
      return void await say(turn, "groupConnected", { object: String(r.object_name ?? ""), bot });
    }
    case "where": {
      const who = await deps.db.resolve(chat, group);
      if (who.kind === "none") return void await say(turn, group ? "groupNotConnected" : "startUnknown");
      if (who.kind === "guest_off") return void await say(turn, "linkOff");
      if (group || (who.kind === "guest" && who.link_object_id)) {
        return void await say(turn, "objectChosen", { object: objectLabel(who.object) ?? "—" });
      }
      const ctx = await deps.db.context(chat, group);
      if (!ctx.objects.length) return void await say(turn, "noObjects");
      await deps.db.sessionPut(chat, { step: "object", draft: null, card: null, author: turn.from?.id ?? null });
      await say(turn, "askObject", {}, objectButtons(ctx.objects, lang, false));
      await say(turn, "bLocation", {}, LOCATION_KB(lang)).catch(() => null);
      return;
    }
    default:
      await say(turn, group ? "helpGroup" : "help", { bot });
  }
}

// --- Сообщения -------------------------------------------------------------

/** Текст (набранный или распознанный) → черновик → карточка или выбор объекта. */
async function intake(
  text: string,
  who: Who,
  turn: Turn,
  extra: { heard?: string; photo?: { fileId: string; vision: Vision | null } },
) {
  const { deps, chat, group, lang } = turn;
  const ctx = await deps.db.context(chat, group);
  if (ctx.error) {
    turn.log.code = ctx.error;
    return void await say(turn, "failed");
  }
  const input = text.slice(0, TEXT_MAX);
  let draft: Draft;
  if (input.trim()) {
    const started = Date.now();
    const ai = await deps.ai.text(input, lang, { layers: ctx.layers, places: ctx.places }).catch(() => null);
    turn.log.ai_ms = Date.now() - started;
    turn.log.model = ai?.model ?? null;
    draft = ai ? aiDraft(input, ai.result, ctx, lang) : plainDraft(input);
  } else {
    draft = plainDraft("");
  }
  draft.heard = extra.heard ?? null;

  // Фото: вид, неисправность, кандидат из реестра.
  const prev = await deps.db.sessionGet(chat);
  const photoId = extra.photo?.fileId ?? (prev?.step === "need_text" ? prev.photo_file_id ?? null : null);
  draft.photo_file_id = photoId;
  const v = extra.photo?.vision ?? null;
  if (v) {
    const kind = kindLabel(v.kind, lang);
    draft.photo_note = [
      t(lang, "photoSeen", { kind }),
      v.defect ? t(lang, "photoDefect", { defect: v.defect }) : "",
    ].filter(Boolean).join(". ");
    if (!input.trim()) {
      draft.title = clip(v.defect ?? kind, TITLE_MAX);
      draft.description = draft.photo_note;
      draft.ai = true;
    }
    if (!draft.layer_id && v.layer) {
      draft.layer_id = v.layer.id;
      draft.layer_label = layerLabel(ctx.layers.find((l) => l.id === v.layer!.id) ?? v.layer, lang);
    }
  }

  const known = settleObject(draft, input, who, ctx);
  if (v) {
    const res = buildResult(v, ctx.assets, {
      objectId: draft.object_id,
      locationId: draft.location_id,
      floorId: null,
    }, lang);
    const top = res.candidates[0];
    turn.log.candidates = res.candidates.length;
    if (top && top.score >= 0.5) {
      const a = ctx.assets.find((x) => x.id === top.asset_id);
      const place = ctx.places.find((p) => p.id === top.location_id);
      if (a && (!draft.object_id || a.object_id === draft.object_id)) {
        if (place && !draft.location_id) setPlace(draft, place, ctx);
        if (!draft.object_id) {
          setObject(draft, ctx.objects.find((o) => o.id === a.object_id) ?? null);
        }
        if (!draft.location_id) {
          draft.location_id = a.location_id;
          draft.location_label = top.location_label;
        }
        draft.asset_id = a.id;
        draft.asset_label = a.name;
      }
    }
  }
  turn.log.ai = draft.ai;
  turn.log.object = !!draft.object_id;
  turn.log.place = !!draft.location_id;

  const session: Session = {
    step: known || draft.object_id ? "confirm" : "object",
    draft,
    card: null,
    author: turn.from?.id ?? null,
  };
  if (session.step === "object") {
    await deps.db.sessionPut(chat, session);
    await say(turn, "askObject", {}, objectButtons(ctx.objects, lang, false));
    if (!group) await say(turn, "bLocation", {}, LOCATION_KB(lang)).catch(() => null);
    return;
  }
  session.card = await deps.tg.send(chat, cardText(draft, lang), cardButtons(lang), group ? turn.replyTo : undefined);
  await deps.db.sessionPut(chat, session);
}

async function onVoice(m: TgMessage, who: Who, turn: Turn) {
  const v = m.voice!;
  turn.log.sec = v.duration;
  if (v.duration > VOICE_MAX_SECONDS || (v.file_size ?? 0) > VOICE_MAX_BYTES) {
    turn.log.code = "voice_too_long";
    return void await say(turn, "voiceTooLong");
  }
  let audio: Uint8Array;
  try {
    audio = await turn.deps.tg.download(v.file_id, VOICE_MAX_BYTES);
  } catch (e) {
    turn.log.code = e instanceof TgError ? e.code : "download";
    return void await say(turn, e instanceof TgError && e.code === "too_large" ? "voiceTooLong" : "failed");
  }
  const started = Date.now();
  let text: string;
  try {
    text = await turn.deps.ai.stt(audio, turn.lang);
  } catch (e) {
    turn.log.stage = "stt";
    turn.log.code = (e as { code?: string })?.code ?? "stt_failed";
    return void await say(turn, "voiceEmpty");
  } finally {
    turn.log.stt_ms = Date.now() - started;
  }
  if (!text.trim()) {
    turn.log.code = "stt_empty";
    return void await say(turn, "voiceEmpty");
  }
  const clean = turn.group ? stripMention(text, turn.deps.bot) : text;
  await intake(clean, who, turn, { heard: clean });
}

async function onPhoto(m: TgMessage, who: Who, turn: Turn, bot: string) {
  const { deps, lang } = turn;
  const size = pickPhoto(m.photo);
  if (!size) return void await say(turn, "photoTooBig");
  const caption = turn.group ? stripMention(m.caption ?? "", bot) : (m.caption ?? "").trim();
  let vision: Vision | null = null;
  try {
    const bytes = await deps.tg.download(size.file_id, 1536 * 1024);
    const ctx = await deps.db.context(turn.chat, turn.group);
    const started = Date.now();
    const r = await deps.ai.vision(toBase64(bytes), lang, ctx.layers).catch(() => null);
    turn.log.vision_ms = Date.now() - started;
    turn.log.vision_model = r?.model ?? null;
    vision = r?.vision ?? null;
  } catch (e) {
    turn.log.code = e instanceof TgError ? e.code : "photo";
  }
  if (!vision && !caption) {
    // Фото сохраним в черновике: следующее сообщение — текст к нему.
    await deps.db.sessionPut(turn.chat, {
      step: "need_text",
      draft: null,
      card: null,
      author: turn.from?.id ?? null,
      photo_file_id: size.file_id,
    });
    return void await say(turn, "photoNoAi");
  }
  await intake(caption, who, turn, { photo: { fileId: size.file_id, vision } });
}

async function onLocation(lat: number, lng: number, who: Who, turn: Turn) {
  const { deps, chat, lang } = turn;
  if (who.kind === "guest" && who.link_object_id) {
    return void await say(turn, "objectChosen", { object: objectLabel(who.object) ?? "—" });
  }
  const r = await deps.db.nearest(chat, lat, lng);
  if (!r.ok) {
    turn.log.result = "not_found";
    const ctx = await deps.db.context(chat, false);
    return void await say(turn, "nearestNotFound", {}, objectButtons(ctx.objects, lang, false));
  }
  const obj = r.object as ObjectRef;
  await deps.db.setObject(chat, obj.id);
  turn.log.result = "nearest";
  await afterObject(obj, turn, null);
}

/** Объект выбран: черновик есть — карточка, нет — «Объект: …». */
async function afterObject(obj: ObjectRef, turn: Turn, editMessage: number | null) {
  const { deps, chat, lang } = turn;
  const s = await deps.db.sessionGet(chat);
  if (s?.draft) {
    setObject(s.draft, obj);
    s.step = "confirm";
    const html = cardText(s.draft, lang);
    if (editMessage) {
      await deps.tg.edit(chat, editMessage, html, cardButtons(lang));
      s.card = editMessage;
    } else {
      s.card = await deps.tg.send(chat, html, cardButtons(lang));
    }
    await deps.db.sessionPut(chat, s);
    return;
  }
  if (s) await deps.db.sessionPut(chat, null);
  const text = esc(t(lang, "objectChosen", { object: objectLabel(obj) ?? obj.name }));
  if (editMessage) await deps.tg.edit(chat, editMessage, text);
  else await deps.tg.send(chat, text, { remove_keyboard: true });
}

// --- Кнопки ----------------------------------------------------------------

async function handleCallback(cb: TgCallback, deps: Deps, log: J) {
  const msg = cb.message;
  if (!msg) return void await deps.tg.answer(cb.id);
  const chat = msg.chat.id;
  const group = msg.chat.type !== "private";
  const lang = langOf(cb.from.language_code);
  const turn: Turn = { deps, chat, group, lang, from: cb.from, log };
  const data = cb.data ?? "";
  log.action = data.split(":")[0];
  const who = await deps.db.resolve(chat, group);
  log.who = who.kind;
  if (who.kind === "none" || who.kind === "guest_off") {
    await deps.tg.answer(cb.id);
    return void await say(turn, who.kind === "none" ? (group ? "groupNotConnected" : "startUnknown") : "linkOff");
  }
  const s = await deps.db.sessionGet(chat);
  if (group && s?.author && s.author !== cb.from.id) {
    return void await deps.tg.answer(cb.id, t(lang, "stale"));
  }

  // Выбор объекта: и в черновике, и из /where.
  if (data.startsWith("o:")) {
    const id = data.slice(2);
    const r = await deps.db.setObject(chat, id);
    await deps.tg.answer(cb.id);
    if (!r.ok) return void await say(turn, "notAllowed");
    return void await afterObject(r.object as ObjectRef, turn, msg.message_id);
  }
  if (!s?.draft || (s.card !== null && s.card !== msg.message_id)) {
    await deps.tg.answer(cb.id, t(lang, "stale"));
    if (!s?.draft) await deps.tg.edit(chat, msg.message_id, esc(t(lang, "stale")));
    return;
  }
  const d = s.draft;
  const card = () => deps.tg.edit(chat, msg.message_id, cardText(d, lang), cardButtons(lang));

  if (data === "x") {
    await deps.db.sessionPut(chat, null);
    await deps.tg.answer(cb.id);
    return void await deps.tg.edit(chat, msg.message_id, esc(t(lang, "cancelled")));
  }
  if (data === "bk") {
    await deps.tg.answer(cb.id);
    return void await card();
  }
  if (data === "pr") {
    await deps.tg.answer(cb.id);
    return void await deps.tg.edit(chat, msg.message_id, esc(t(lang, "askPriority")), priorityButtons(lang));
  }
  if (data.startsWith("r:")) {
    const p = data.slice(2) as Priority;
    if ((PRIORITIES as readonly string[]).includes(p)) d.priority = p;
    await deps.db.sessionPut(chat, s);
    await deps.tg.answer(cb.id);
    return void await card();
  }
  if (data === "pl" || data === "ob") {
    await deps.tg.answer(cb.id);
    const ctx = await deps.db.context(chat, group);
    const many = ctx.objects.length > 1 && who.kind !== "group" && !(who.kind === "guest" && who.link_object_id);
    if (data === "ob" || !d.object_id) {
      return void await deps.tg.edit(chat, msg.message_id, esc(t(lang, "askObject")), objectButtons(ctx.objects, lang, true));
    }
    const places = ctx.places.filter((p) => p.object_id === d.object_id);
    return void await deps.tg.edit(chat, msg.message_id, esc(t(lang, "askPlace")), placeButtons(places, lang, many));
  }
  if (data.startsWith("p:")) {
    const id = data.slice(2);
    if (id === "-") {
      d.location_id = null;
      d.location_label = null;
      d.asset_id = null;
      d.asset_label = null;
    } else {
      const ctx = await deps.db.context(chat, group, d.object_id);
      const p = ctx.places.find((x) => x.id === id);
      if (p) {
        setPlace(d, p, ctx);
        d.asset_id = null;
        d.asset_label = null;
      }
    }
    await deps.db.sessionPut(chat, s);
    await deps.tg.answer(cb.id);
    return void await card();
  }
  if (data === "c") {
    await deps.tg.answer(cb.id);
    return void await create(s, who, turn, msg.message_id);
  }
  await deps.tg.answer(cb.id);
}

async function create(s: Session, who: Who, turn: Turn, cardId: number) {
  const { deps, chat, group, lang } = turn;
  const d = s.draft!;
  const id = deps.uuid();
  let photoPath: string | null = null;
  if (d.photo_file_id && who.company_id) {
    try {
      const bytes = await deps.tg.download(d.photo_file_id, 1536 * 1024);
      photoPath = `${who.company_id}/${id}/tg_${deps.uuid().slice(0, 8)}.jpg`;
      await deps.storage.upload(photoPath, bytes);
    } catch (e) {
      turn.log.code = e instanceof TgError ? e.code : "photo_upload";
      photoPath = null;
    }
  }
  const r = await deps.db.createOrder(chat, group, id, {
    title: d.title,
    description: d.description,
    object_id: d.object_id,
    location_id: d.location_id,
    asset_id: d.asset_id,
    layer_id: d.layer_id,
    priority: d.priority,
    photo_path: photoPath,
    reporter: { name: reporterName(turn.from), username: turn.from?.username ?? null },
  });
  if (!r.ok) {
    if (photoPath) await deps.storage.remove(photoPath).catch(() => {});
    turn.log.result = String(r.error ?? "failed");
    const key: TextKey = r.error === "rate_limited"
      ? "rateLimited"
      : r.error === "rate_limited_link"
      ? "rateLimitedLink"
      : r.error === "link_disabled"
      ? "linkOff"
      : r.error === "object_not_allowed"
      ? "notAllowed"
      : "failed";
    await deps.db.sessionPut(chat, null);
    return void await deps.tg.edit(chat, cardId, esc(t(lang, key)));
  }
  turn.log.result = "created";
  turn.log.photo = !!r.photo;
  const html = [
    `✅ <b>${esc(t(lang, "created", { number: String(r.number) }))}</b>`,
    "",
    esc(d.title),
    `📍 ${esc(d.object_label ? [d.object_label, d.location_label ?? t(lang, "wholeObject")].join(" · ") : t(lang, "managerWillClarify"))}`,
  ].join("\n");
  const markup: ReplyMarkup | undefined = who.kind === "user"
    ? { inline_keyboard: [[{ text: t(lang, "openInApp"), url: `${deps.appUrl}#/orders/${id}` }]] }
    : undefined;
  await deps.tg.edit(chat, cardId, html, markup);
}

export function toBase64(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(s);
}
