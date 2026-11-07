// Калькулятор окупаемости Hey Helpy (шаг 35) — ЕДИНСТВЕННЫЙ источник формул, допущений и цен.
// Источник цифр — docs/site/roi-calculator-brief.md (разделы 4–7). Цифры из головы не брать.
//
// Модуль без зависимостей и без import: build.mjs встраивает его текст в страницу roi/
// (убирая слово «export»), поэтому в браузере считает ровно тот же код, что и в тестах.
// Тесты: node --test tools/site/roi.test.mjs
//
// Поменять цену, зарплату, курс или долю — только здесь, затем `node tools/site/build.mjs`.

/** Фиксированные курсы (бриф, раздел 5). */
export const FX = { EUR_USD: 1.1193, USD_AED: 3.6725 };

/** 1 м² = 10,7639 кв. фута. */
export const SQFT_PER_M2 = 10.7639;

/** Затраты на ремонт и ТО в США: $2,15 за кв. фут в год (медиана IFMA 2025 / BOMA 2024 через Oxmaint). */
export const US_REPAIR_PER_SQFT = 2.15;

/** Общие допущения (бриф, разделы 3–5). */
export const COMMON = {
  burden: 1.25, //            множитель налогов и соц. взносов
  hoursYear: 2080, //         40 ч × 52 нед.
  contractorShare: 0.7, //    доля затрат на ремонт и ТО, уходящая подрядчикам
  hoursCoord: 15, //          часы координатора, сэкономленные на объект в месяц
  hoursFm: 5, //              часы FM-менеджера
  overbilling: 0.03, //       переплаты по умолчанию — осторожно
  overbillingMin: 0.03,
  overbillingMax: 0.1,
  annualDiscount: 0.15, //    скидка за оплату года вперёд
  payoutsPerSite: 10, //      выплат подрядчикам на объект в месяц (опция с 2028)
  areaM2: 5000, //            площадь по умолчанию
  maxSites: 500,
  maxAreaM2: 1000000,
  maxHours: 744, //           часов в месяце не больше, чем 31 × 24
  maxPayouts: 1000,
  tiers: { S: 3000, M: 10000, L: 30000 }, // верхние границы ступеней, м² (включительно)
};

/**
 * Регионы: валюта, зарплаты (факт, бриф раздел 5), затраты на ремонт на м² (оценка),
 * прейскурант за объект в месяц S / M / L (бриф 4.1), плата за выплату (бриф 4.3).
 * repairShare — затраты на м² относительно США (ЕС = 80 %, Залив = 70 % — допущения),
 * usdPerUnit — сколько долларов в единице валюты (для перевода оценки США).
 */
export const REGIONS = {
  US: {
    currency: 'USD', symbol: '$', coordSalary: 73792, fmSalary: 106660,
    repairShare: 1, usdPerUnit: 1,
    prices: { S: 250, M: 450, L: 750 }, payoutFee: 2,
  },
  EU: {
    currency: 'EUR', symbol: '€', coordSalary: 33644, fmSalary: 47500,
    repairShare: 0.8, usdPerUnit: FX.EUR_USD,
    prices: { S: 199, M: 349, L: 579 }, payoutFee: 2,
  },
  GCC: {
    currency: 'AED', symbol: 'AED ', coordSalary: 33600, fmSalary: 101130,
    repairShare: 0.7, usdPerUnit: 1 / FX.USD_AED,
    prices: { S: 650, M: 1100, L: 2000 }, payoutFee: 7,
  },
};

export const REGION_KEYS = ['US', 'EU', 'GCC'];

/** Стоимость часа: зарплата × 1,25 / 2 080. */
export function hourCost(region, who) {
  const r = REGIONS[region];
  return ((who === 'fm' ? r.fmSalary : r.coordSalary) * COMMON.burden) / COMMON.hoursYear;
}

/** Затраты на ремонт и ТО за год на м² в валюте региона. */
export function repairRateM2(region) {
  const r = REGIONS[region];
  return (US_REPAIR_PER_SQFT * SQFT_PER_M2 * r.repairShare) / r.usdPerUnit;
}

export const sqftToM2 = (sqft) => sqft / SQFT_PER_M2;

/** Ступень по площади: ≤ 3 000 → S; ≤ 10 000 → M; ≤ 30 000 → L; больше — custom (индивидуальная цена). */
export function tierFor(areaM2) {
  const t = COMMON.tiers;
  if (areaM2 <= t.S) return 'S';
  if (areaM2 <= t.M) return 'M';
  if (areaM2 <= t.L) return 'L';
  return 'custom';
}

/** Расходы на подрядчиков на объект в месяц по умолчанию: A × ставка_м² × 0,70 / 12. */
export function defaultContractorSpend(region, areaM2) {
  return (areaM2 * repairRateM2(region) * COMMON.contractorShare) / 12;
}

/** Пустое поле → undefined; иначе число (или NaN — ошибка ввода). Принимает «1 188», «1,188.5», «2,5». */
export function parseNum(v) {
  if (v === undefined || v === null) return undefined;
  if (typeof v === 'number') return v;
  let s = String(v).trim().replace(/[\s  ]/g, '');
  if (s === '') return undefined;
  if (/^-?\d{1,3}(,\d{3})+(\.\d+)?$/.test(s)) s = s.replace(/,/g, '');
  else s = s.replace(',', '.');
  return /^-?\d+(\.\d+)?$/.test(s) ? Number(s) : NaN;
}

/**
 * Проверка ввода. Возвращает { values, errors }: errors — { поле: код }.
 * Коды: required, number, integer, min, max.
 */
export function validate(input) {
  const errors = {};
  const values = {};
  const num = (key, { required = false, def, min, max, integer = false, minExclusive = false }) => {
    let v = parseNum(input[key]);
    if (v === undefined) {
      if (required) errors[key] = 'required';
      v = def;
    } else if (!Number.isFinite(v)) errors[key] = 'number';
    else if (integer && !Number.isInteger(v)) errors[key] = 'integer';
    else if (minExclusive ? v <= min : v < min) errors[key] = 'min';
    else if (max !== undefined && v > max) errors[key] = 'max';
    values[key] = v;
  };
  values.region = REGIONS[input.region] ? input.region : 'US';
  num('sites', { required: true, min: 1, max: COMMON.maxSites, integer: true });
  num('areaM2', { required: true, min: 0, minExclusive: true, max: COMMON.maxAreaM2 });
  num('contractorSpend', { min: 0 });
  num('hoursCoord', { def: COMMON.hoursCoord, min: 0, max: COMMON.maxHours });
  num('hoursFm', { def: COMMON.hoursFm, min: 0, max: COMMON.maxHours });
  num('overbilling', { def: COMMON.overbilling, min: COMMON.overbillingMin - 1e-9, max: COMMON.overbillingMax + 1e-9 });
  num('payoutsPerSite', { def: COMMON.payoutsPerSite, min: 0, max: COMMON.maxPayouts, integer: true });
  values.annual = !!input.annual;
  values.payouts = !!input.payouts;
  return { values, errors };
}

/** Один сценарий при заданной доле переплат p. Деньги — без округления. */
function scenario(v, price, spend, p) {
  const timeValue = v.hoursCoord * hourCost(v.region, 'coord') + v.hoursFm * hourCost(v.region, 'fm');
  const overbillingValue = p * spend;
  const value = timeValue + overbillingValue;
  const valueTotal = v.sites * value;
  const costTotal = price === null ? null : v.sites * price;
  const net = costTotal === null ? null : valueTotal - costTotal;
  return {
    overbilling: p,
    timeValue: v.sites * timeValue,
    overbillingValue: v.sites * overbillingValue,
    valueMonth: valueTotal,
    valueYear: valueTotal * 12,
    costMonth: costTotal,
    costYear: costTotal === null ? null : costTotal * 12,
    netMonth: net,
    netYear: net === null ? null : net * 12,
    roi: costTotal ? valueTotal / costTotal : null,
  };
}

/**
 * Расчёт (бриф, раздел 6). Вход — как у validate(); showPrices = false (ROI_SHOW_PRICES в config.mjs)
 * — без цены, чистой выгоды и ROI. Результат:
 *   { ok: false, errors }                       — ошибки ввода;
 *   { ok: true, tier: 'custom', custom: true }  — объект > 30 000 м²: индивидуальная цена, чисел нет;
 *   { ok: true, tier, price, contractorSpend, base, low, high, gulfHint, … } — base при выбранном p,
 *     low / high — при 3 % и 10 % (диапазон).
 */
export function calc(input, { showPrices = true } = {}) {
  const { values: v, errors } = validate(input);
  if (Object.keys(errors).length) return { ok: false, errors };
  const r = REGIONS[v.region];
  const tier = tierFor(v.areaM2);
  if (tier === 'custom') return { ok: true, region: v.region, currency: r.currency, tier, custom: true };
  const spend = v.contractorSpend === undefined ? defaultContractorSpend(v.region, v.areaM2) : v.contractorSpend;
  const listPrice = r.prices[tier];
  const fullPrice = listPrice * (v.annual ? 1 - COMMON.annualDiscount : 1) + (v.payouts ? r.payoutFee * v.payoutsPerSite : 0);
  const price = showPrices ? fullPrice : null;
  const base = scenario(v, price, spend, v.overbilling);
  const low = scenario(v, price, spend, COMMON.overbillingMin);
  const high = scenario(v, price, spend, COMMON.overbillingMax);
  // Подсказка для Залива (бриф 8.6): ROI при 3 % меньше ×1,3. Считается и без показа цен.
  const roiLow = (low.valueMonth) / (v.sites * fullPrice);
  return {
    ok: true,
    region: v.region,
    currency: r.currency,
    tier,
    custom: false,
    showPrices,
    sites: v.sites,
    contractorSpend: spend,
    contractorSpendDefault: v.contractorSpend === undefined,
    listPrice: showPrices ? listPrice : null,
    pricePerSite: price,
    base,
    low,
    high,
    gulfHint: v.region === 'GCC' && roiLow < 1.3,
  };
}

/** Округление денег до целых единиц валюты (половина — вверх по модулю). */
export function roundMoney(x) {
  return Math.sign(x) * Math.round(Math.abs(x));
}

/** ROI с одним знаком после запятой (как число). */
export const roundRoi = (x) => Math.round(x * 10) / 10;

/** Целое с разделителями: EN — «1,188», RU — «1 188» (неразрывный пробел). */
export function fmtInt(n, lang) {
  const s = String(Math.abs(roundMoney(n))).replace(/\B(?=(\d{3})+(?!\d))/g, lang === 'ru' ? ' ' : ',');
  return (roundMoney(n) < 0 ? '−' : '') + s;
}

/** Деньги: «$1,188», «€591», «AED 1,127» (RU — «$1 188»). */
export function fmtMoney(n, region, lang) {
  const neg = roundMoney(n) < 0;
  return (neg ? '−' : '') + REGIONS[region].symbol + fmtInt(Math.abs(n), lang);
}

/** ROI: «×2.6» / «×2,6». */
export function fmtRoi(x, lang) {
  const s = roundRoi(x).toFixed(1);
  return '×' + (lang === 'ru' ? s.replace('.', ',') : s);
}

/** Проценты: «3%» / «3 %» (RU), с половинками — «3.5%» / «3,5 %». */
export function fmtPct(p, lang) {
  const n = Math.round(p * 1000) / 10;
  const s = Number.isInteger(n) ? String(n) : n.toFixed(1);
  return lang === 'ru' ? `${s.replace('.', ',')} %` : `${s}%`;
}

/** Число с двумя знаками (стоимость часа, ставка на м²): «44.35» / «44,35». */
export function fmtDec(x, lang) {
  const [i, d] = x.toFixed(2).split('.');
  return fmtInt(Number(i), lang) + (lang === 'ru' ? ',' : '.') + d;
}
