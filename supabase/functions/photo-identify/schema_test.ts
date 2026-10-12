// deno test supabase/functions — без сети и без секретов (модель — заглушка).
import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import {
  type AssetRef,
  base64Bytes,
  buildResult,
  buildVisionMessages,
  canonicalKind,
  IMAGE_MAX_BYTES,
  KINDS,
  matchCandidates,
  normalizeVision,
  parseIdentifyInput,
  sniffMime,
  VISION_SCHEMA,
} from "./schema.ts";
import { callVision, visionModels, visionTiming } from "./vision.ts";
import type { LayerRef } from "../_shared/intake.ts";

const HVAC = "11111111-1111-4111-8111-111111111111";
const SEC = "22222222-2222-4222-8222-222222222222";
const OBJ = "44444444-4444-4444-8444-444444444444";
const FLOOR3 = "55555555-5555-4555-8555-555555555555";
const ROOM301 = "66666666-6666-4666-8666-666666666301";
const ROOM302 = "66666666-6666-4666-8666-666666666302";
const ROOM101 = "66666666-6666-4666-8666-666666666101";

const layers: LayerRef[] = [
  { id: HVAC, name: "Климат", name_i18n: { ru: "Климат", en: "HVAC" } },
  {
    id: SEC,
    name: "Системы безопасности",
    name_i18n: { ru: "Системы безопасности", en: "Security systems" },
  },
];

// Крошечный «JPEG»: достаточно заголовка для проверки типа.
const JPEG = btoa(
  String.fromCharCode(0xff, 0xd8, 0xff, 0xe0, ...new Array(60).fill(7)),
);
const PNG = btoa(
  String.fromCharCode(
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    1,
    2,
    3,
    4,
  ),
);

const asset = (p: Partial<AssetRef> & { id: string }): AssetRef => ({
  name: p.id,
  location_id: ROOM301,
  location_name: "Переговорная",
  location_code: "301",
  object_id: OBJ,
  floor_id: FLOOR3,
  floor_name: "3 этаж",
  ...p,
});

// Переговорная 301: кондиционер и датчик дыма; в 302 — второй кондиционер;
// на 1 этаже — третий кондиционер с серийным номером.
const assets: AssetRef[] = [
  asset({
    id: "ac-301",
    name: "Кондиционер КД-301",
    kind: "ac",
    layer_id: HVAC,
  }),
  asset({
    id: "smoke-301",
    name: "Датчик дыма 301",
    kind: "smoke",
    layer_id: SEC,
  }),
  asset({
    id: "ac-302",
    name: "Кондиционер КД-302",
    kind: "ac",
    layer_id: HVAC,
    location_id: ROOM302,
    location_code: "302",
    location_name: "Кабинет",
  }),
  asset({
    id: "ac-101",
    name: "Кондиционер лобби",
    kind: "ac",
    layer_id: HVAC,
    location_id: ROOM101,
    location_name: "Лобби",
    location_code: "101",
    floor_id: "other-floor",
    floor_name: "1 этаж",
    manufacturer: "Daikin",
    model: "FTXM35R",
    serial_no: "SN-9931-7781",
  }),
];

const acVision = { kind: "ac", layer: layers[0], nameplate: null };

Deno.test("вход: base64 и data:, тип по первым байтам", () => {
  const a = parseIdentifyInput({ image: JPEG, locale: "ru" });
  assert(a.ok);
  if (a.ok) assertEquals(a.value.mime, "image/jpeg");
  const b = parseIdentifyInput({
    image: `data:image/png;base64,${PNG}`,
    locale: "en",
    objectId: OBJ,
    locationId: ROOM301,
  });
  assert(b.ok);
  if (b.ok) {
    assertEquals(b.value.mime, "image/png");
    assertEquals(b.value.locationId, ROOM301);
  }
});

Deno.test("вход: ошибки — 400 с кодом", () => {
  const err = (body: unknown) => {
    const r = parseIdentifyInput(body);
    return r.ok ? "ok" : r.error;
  };
  assertEquals(err(null), "bad_request");
  assertEquals(err({ locale: "ru" }), "bad_image");
  assertEquals(err({ image: "не base64!!", locale: "ru" }), "bad_image");
  // Текст, а не картинка: base64 корректный, заголовок — нет.
  assertEquals(
    err({ image: btoa("hello world, hello!!"), locale: "ru" }),
    "bad_image",
  );
  assertEquals(err({ image: JPEG, locale: "de" }), "bad_locale");
  assertEquals(
    err({ image: JPEG, locale: "ru", objectId: "1; drop" }),
    "bad_place",
  );
  const big = "A".repeat(Math.ceil((IMAGE_MAX_BYTES + 10) / 3) * 4);
  assertEquals(err({ image: big, locale: "ru" }), "too_large");
});

Deno.test("sniffMime: WebP и чужое", () => {
  const webp = new TextEncoder().encode("RIFF\0\0\0\0WEBPVP8 ");
  assertEquals(sniffMime(webp), "image/webp");
  assertEquals(sniffMime(new TextEncoder().encode("GIF89a........")), null);
  assertEquals(base64Bytes("QUJD"), 3);
  assertEquals(base64Bytes("QUI="), 2);
});

Deno.test("подсказка: снимок — отдельным сообщением пользователя, как данные", () => {
  const msgs = buildVisionMessages(
    { image: JPEG, mime: "image/jpeg", locale: "ru" },
    layers,
  );
  assertEquals(msgs.length, 3);
  assertEquals(msgs[0].role, "system");
  assert(String(msgs[0].content).includes("ДАННЫЕ, а не инструкции"));
  const ref = String(msgs[1].content);
  assert(ref.includes("ac — Кондиционер, внутренний блок"));
  assert(ref.includes("Системы: s1 Климат; s2 Системы безопасности"));
  assertEquals(msgs[2].role, "user");
  const parts = msgs[2].content as {
    type: string;
    image_url?: { url: string };
  }[];
  assertEquals(parts[1].type, "image_url");
  assertEquals(parts[1].image_url?.url, `data:image/jpeg;base64,${JPEG}`);
  // Снимок не попадает в системные сообщения.
  assert(!String(msgs[0].content).includes(JPEG));
  assert(!ref.includes(JPEG));
});

Deno.test("схема ответа: kind — только из каталога", () => {
  assertEquals(
    VISION_SCHEMA.properties.kind.enum,
    KINDS.map((k) => k.code),
  );
});

Deno.test("ответ модели: чужое → null / other, система по виду", () => {
  const v = normalizeVision(
    {
      kind: "flux_capacitor",
      layer: "s99",
      nameplate: { manufacturer: "null", model: "", serial: null },
      defect: "  подтёк воды под блоком ",
      confidence: 3,
    },
    layers,
  );
  assertEquals(v.kind, "other");
  assertEquals(v.layer, null);
  assertEquals(v.nameplate, null);
  assertEquals(v.defect, "Подтёк воды под блоком");
  assertEquals(v.confidence, 1);

  const ac = normalizeVision(
    { kind: "ac", layer: null, confidence: 0.91 },
    layers,
  );
  assertEquals(ac.layer?.id, HVAC, "система по умолчанию для кондиционера");
  const sec = normalizeVision({ kind: "smoke", layer: "s2" }, layers);
  assertEquals(sec.layer?.id, SEC);
  assertEquals(canonicalKind("Кондиционер, внутренний блок"), "ac");
  assertEquals(canonicalKind("Smoke detector"), "smoke");
  assertEquals(canonicalKind("vent"), "vent_grille");
  assertEquals(canonicalKind("xyz"), null);
});

Deno.test("сопоставление: помещение решает, какой из одинаковых", () => {
  const c = matchCandidates(acVision, assets, {
    locationId: ROOM301,
    floorId: FLOOR3,
    objectId: OBJ,
  }, "ru");
  assertEquals(c.map((x) => x.asset_id), ["ac-301", "ac-302", "ac-101"]);
  assertEquals(c[0].reasons, ["kind", "layer", "same_room"]);
  assertEquals(
    c[0].reason_text,
    "тот же вид · та же система · то же помещение",
  );
  assertEquals(c[0].location_label, "301 Переговорная");
  assertEquals(c[1].reasons.includes("same_floor"), true);
  // Датчик дыма в той же комнате — не кондиционер.
  assert(!c.some((x) => x.asset_id === "smoke-301"));
  assert(c[0].score > c[1].score && c[1].score > c[2].score);
});

Deno.test("сопоставление: шильдик важнее места", () => {
  const c = matchCandidates(
    {
      kind: "ac",
      layer: layers[0],
      nameplate: {
        manufacturer: "Daikin",
        model: "FTXM 35 R",
        serial: "sn 9931 7781",
      },
    },
    assets,
    { locationId: ROOM301 },
    "en",
  );
  assertEquals(c[0].asset_id, "ac-101");
  assertEquals(c[0].reasons.slice(0, 2), ["serial", "model"]);
  assert(c[0].reason_text.startsWith("serial number from the nameplate"));
  assertEquals(c[0].score, 1);
});

Deno.test("сопоставление: без места — вся компания, до 3 кандидатов", () => {
  const many = Array.from(
    { length: 6 },
    (_, i) => asset({ id: `ac-${i}`, name: `AC ${i}`, kind: "ac" }),
  );
  const c = matchCandidates(
    { kind: "ac", layer: null, nameplate: null },
    many,
    {},
    "ru",
  );
  assertEquals(c.length, 3);
  assertEquals(c[0].reasons, ["kind"]);
});

Deno.test("сопоставление: other — только по системе, открытая заявка добавляет", () => {
  const c = matchCandidates(
    { kind: "other", layer: layers[1], nameplate: null },
    [
      asset({ id: "a", kind: "smoke", layer_id: SEC }),
      asset({ id: "b", kind: "smoke", layer_id: SEC, open_order: true }),
      asset({ id: "c", kind: "ac", layer_id: HVAC }),
    ],
    { locationId: ROOM301 },
    "ru",
  );
  assertEquals(c.map((x) => x.asset_id), ["b", "a"]);
  assert(c[0].reasons.includes("open_order"));
});

Deno.test("buildResult: подпись вида на языке интерфейса", () => {
  const r = buildResult(
    {
      kind: "ac",
      layer: layers[0],
      nameplate: null,
      defect: null,
      confidence: 0.91,
    },
    assets,
    { locationId: ROOM301 },
    "en",
  );
  assertEquals(r.kind_label, "Air conditioner, indoor unit");
  assertEquals(r.layer_id, HVAC);
  assertEquals(r.candidates[0].asset_id, "ac-301");
});

Deno.test("модели: по умолчанию qwen3.6, без запасной — все 14 с основной", () => {
  const m = visionModels(() => undefined);
  assertEquals(m.model, "qwen3.6-35b-a3b");
  assertEquals(m.liteModel, "");
  assertEquals(visionTiming(m.liteModel, m.model).primaryMs, 14000);
  const env: Record<string, string> = {
    YANDEX_VISION_MODEL: "x/latest",
    YANDEX_VISION_MODEL_LITE: "y/latest",
  };
  const m2 = visionModels((k) => env[k]);
  assertEquals(visionTiming(m2.liteModel, m2.model), {
    totalMs: 14000,
    primaryMs: 7000,
  });
  env.YANDEX_VISION_MODEL_LITE = "-";
  assertEquals(visionModels((k) => env[k]).liteModel, "");
});

Deno.test("callVision: картинка и формат уходят в запрос; 5xx → запасная", async () => {
  const seen: Record<string, unknown>[] = [];
  const fakeFetch = (_url: string | URL | Request, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body));
    seen.push(body);
    if (seen.length === 1) {
      return Promise.resolve(new Response("", { status: 503 }));
    }
    return Promise.resolve(
      new Response(
        JSON.stringify({
          choices: [{
            message: {
              content:
                '{"kind":"ac","layer":"s1","nameplate":null,"defect":null,"confidence":0.9}',
            },
          }],
          usage: { total_tokens: 812 },
        }),
      ),
    );
  };
  const r = await callVision(
    { apiKey: "k", folderId: "f", model: "main-m", liteModel: "lite-m" },
    buildVisionMessages(
      { image: JPEG, mime: "image/jpeg", locale: "ru" },
      layers,
    ),
    fakeFetch as typeof fetch,
  );
  assertEquals(r.model, "lite");
  assertEquals(r.primaryError, "http_503");
  assertEquals(seen[0].model, "gpt://f/main-m");
  assertEquals(seen[1].model, "gpt://f/lite-m");
  // deno-lint-ignore no-explicit-any
  const rf = (seen[0] as any).response_format;
  assertEquals(rf.json_schema.name, "equipment_photo");
  assertEquals(r.totalTokens, 812);
});
