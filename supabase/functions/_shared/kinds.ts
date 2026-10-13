// Каталог видов оборудования (assets.meta.kind) — один для приложения и
// функций. Та же таблица — в lib/features/equipment/equipment_kinds.dart и
// подписи в lib/l10n/app_*.arb (ключи eqKind_<код>); совпадение проверяет
// тест test/equipment_kinds_test.dart (читает этот файл).
//
// layer — система по умолчанию: английское название слоя (layers.name_i18n.en,
// как в seed_default_layers), null — система не очевидна.

export interface KindDef {
  code: string;
  ru: string;
  en: string;
  layer: string | null;
}

export const KINDS: readonly KindDef[] = [
  {
    code: "ac",
    ru: "Кондиционер, внутренний блок",
    en: "Air conditioner, indoor unit",
    layer: "HVAC",
  },
  {
    code: "ac_outdoor",
    ru: "Кондиционер, наружный блок",
    en: "Air conditioner, outdoor unit",
    layer: "HVAC",
  },
  { code: "fancoil", ru: "Фанкойл", en: "Fan coil unit", layer: "HVAC" },
  {
    code: "vent_grille",
    ru: "Вентиляционная решётка",
    en: "Ventilation grille",
    layer: "HVAC",
  },
  { code: "radiator", ru: "Радиатор отопления", en: "Radiator", layer: "HVAC" },
  {
    code: "sensor",
    ru: "Датчик температуры",
    en: "Temperature sensor",
    layer: "HVAC",
  },
  {
    code: "panel",
    ru: "Щит электрический",
    en: "Electrical panel",
    layer: "Electrical",
  },
  { code: "light", ru: "Светильник", en: "Light fixture", layer: "Electrical" },
  {
    code: "socket",
    ru: "Розетка / выключатель",
    en: "Socket / switch",
    layer: "Electrical",
  },
  { code: "ups", ru: "ИБП", en: "UPS", layer: "Electrical" },
  {
    code: "server",
    ru: "Серверная стойка",
    en: "Server rack",
    layer: "Electrical",
  },
  {
    code: "smoke",
    ru: "Датчик дыма",
    en: "Smoke detector",
    layer: "Security systems",
  },
  {
    code: "extinguisher",
    ru: "Огнетушитель",
    en: "Fire extinguisher",
    layer: "Security systems",
  },
  {
    code: "camera",
    ru: "Камера видеонаблюдения",
    en: "CCTV camera",
    layer: "Security systems",
  },
  {
    code: "access_reader",
    ru: "Считыватель СКУД",
    en: "Access control reader",
    layer: "Security systems",
  },
  {
    code: "door_lock",
    ru: "Замок / доводчик",
    en: "Lock / door closer",
    layer: "Security systems",
  },
  {
    code: "faucet",
    ru: "Кран / смеситель",
    en: "Faucet / mixer",
    layer: "Plumbing",
  },
  {
    code: "toilet",
    ru: "Унитаз / раковина",
    en: "Toilet / sink",
    layer: "Plumbing",
  },
  {
    code: "water_heater",
    ru: "Водонагреватель",
    en: "Water heater",
    layer: "Plumbing",
  },
  {
    code: "water",
    ru: "Датчик протечки",
    en: "Leak sensor",
    layer: "Plumbing",
  },
  {
    code: "lift_panel",
    ru: "Панель лифта",
    en: "Elevator panel",
    layer: "Other",
  },
  { code: "other", ru: "Другое", en: "Other", layer: null },
];

/** Старые коды из данных до шага 22 → код каталога. */
export const KIND_ALIASES: Readonly<Record<string, string>> = {
  vent: "vent_grille",
  lift: "lift_panel",
  generator: "panel",
};

/** Код или подпись (RU/EN, без учёта регистра) → код каталога, иначе null. */
export function canonicalKind(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const t = v.trim().toLowerCase().replaceAll("ё", "е");
  if (!t) return null;
  const alias = KIND_ALIASES[t];
  if (alias) return alias;
  const k = KINDS.find((k) =>
    k.code === t || k.ru.toLowerCase().replaceAll("ё", "е") === t ||
    k.en.toLowerCase() === t
  );
  return k?.code ?? null;
}

export function kindDef(code: string | null | undefined): KindDef | null {
  const c = canonicalKind(code);
  return c ? KINDS.find((k) => k.code === c) ?? null : null;
}

export function kindLabel(code: string, locale: "ru" | "en"): string {
  const k = kindDef(code) ?? KINDS[KINDS.length - 1];
  return locale === "en" ? k.en : k.ru;
}
