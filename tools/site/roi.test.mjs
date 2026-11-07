// Тесты калькулятора окупаемости (шаг 35): node --test tools/site/roi.test.mjs
// Контрольные примеры — docs/site/roi-calculator-brief.md, раздел 7: совпадение до единицы валюты и до 0,1 по ROI.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  calc, tierFor, defaultContractorSpend, hourCost, repairRateM2, sqftToM2, parseNum, validate,
  fmtMoney, fmtRoi, fmtInt, fmtPct, roundMoney, roundRoi, REGIONS, COMMON,
} from './roi.mjs';

const base = (region, extra = {}) => ({ region, sites: 1, areaM2: 5000, ...extra });
const r = (x) => roundMoney(x);

// Бриф, раздел 7.
const CONTROL = {
  US: { spend: 6750, time: 986, over3: 202, value: 1188, price: 450, roi: [2.6, 2.9, 3.7], net3: 738, net10: 1211 },
  EU: { spend: 4824, time: 446, over3: 145, value: 591, price: 349, roi: [1.7, 2.0, 2.7], net3: 242, net10: 579 },
  GCC: { spend: 17352, time: 607, over3: 521, value: 1127, price: 1100, roi: [1.0, 1.3, 2.1], net3: 27, net10: 1242 },
};

for (const [region, c] of Object.entries(CONTROL)) {
  test(`контрольный пример ${region}: 1 объект M, 5 000 м²`, () => {
    const x = calc(base(region));
    assert.equal(x.ok, true);
    assert.equal(x.tier, 'M');
    assert.equal(r(x.contractorSpend), c.spend);
    assert.equal(r(x.base.timeValue), c.time);
    assert.equal(r(x.base.overbillingValue), c.over3);
    assert.equal(r(x.base.valueMonth), c.value);
    assert.equal(r(x.base.costMonth), c.price);
    assert.equal(roundRoi(x.base.roi), c.roi[0]);
    assert.equal(r(x.base.netMonth), c.net3);
    assert.equal(r(x.base.netYear), r(x.base.netMonth * 12));
    assert.equal(roundRoi(calc(base(region, { overbilling: 0.05 })).base.roi), c.roi[1]);
    const x10 = calc(base(region, { overbilling: 0.1 }));
    assert.equal(roundRoi(x10.base.roi), c.roi[2]);
    assert.equal(r(x10.base.netMonth), c.net10);
    // Диапазон 3–10 % — те же числа при любом выбранном p.
    assert.equal(r(x.low.netMonth), c.net3);
    assert.equal(r(x.high.netMonth), c.net10);
    assert.equal(roundRoi(x.high.roi), c.roi[2]);
  });
}

test('стоимость часа и ставки — как в таблице брифа (раздел 5)', () => {
  const h = (reg, who) => Math.round(hourCost(reg, who) * 100) / 100;
  assert.deepEqual([h('US', 'coord'), h('US', 'fm')], [44.35, 64.1]);
  assert.deepEqual([h('EU', 'coord'), h('EU', 'fm')], [20.22, 28.55]);
  assert.deepEqual([h('GCC', 'coord'), h('GCC', 'fm')], [20.19, 60.78]);
  const m = (reg) => Math.round(repairRateM2(reg) * 100) / 100;
  assert.deepEqual([m('US'), m('EU'), m('GCC')], [23.14, 16.54, 59.49]);
});

test('ступени: границы 3 000 / 10 000 / 30 000 м² включительно', () => {
  assert.equal(tierFor(1), 'S');
  assert.equal(tierFor(3000), 'S');
  assert.equal(tierFor(3000.01), 'M');
  assert.equal(tierFor(10000), 'M');
  assert.equal(tierFor(10001), 'L');
  assert.equal(tierFor(30000), 'L');
  assert.equal(tierFor(30000.5), 'custom');
  assert.equal(calc(base('US', { areaM2: 3000 })).base.costMonth, 250);
  assert.equal(calc(base('EU', { areaM2: 30000 })).base.costMonth, 579);
});

test('больше 30 000 м² — индивидуальная цена, без чисел', () => {
  const x = calc(base('US', { areaM2: 30001 }));
  assert.deepEqual(x, { ok: true, region: 'US', currency: 'USD', tier: 'custom', custom: true });
});

test('скидка 15 % за год', () => {
  const x = calc(base('US', { annual: true }));
  assert.equal(x.pricePerSite, 382.5);
  assert.equal(r(x.base.costMonth), 383);
  assert.equal(roundRoi(x.base.roi), 3.1);
});

test('плата за выплаты: $2 / €2 / AED 7 × выплат, по умолчанию выключена', () => {
  assert.equal(calc(base('US')).pricePerSite, 450);
  assert.equal(calc(base('US', { payouts: true })).pricePerSite, 470);
  assert.equal(calc(base('EU', { payouts: true, payoutsPerSite: 25 })).pricePerSite, 399);
  assert.equal(calc(base('GCC', { payouts: true })).pricePerSite, 1170);
  // год + выплаты: скидка только на подписку
  assert.equal(calc(base('US', { payouts: true, annual: true })).pricePerSite, 402.5);
});

test('несколько объектов: всё умножается на N', () => {
  const one = calc(base('US'));
  const ten = calc(base('US', { sites: 10 }));
  assert.equal(r(ten.base.valueMonth), r(one.base.valueMonth * 10));
  assert.equal(ten.base.costMonth, 4500);
  assert.equal(roundRoi(ten.base.roi), roundRoi(one.base.roi));
});

test('свои расходы на подрядчиков вместо рассчитанных', () => {
  const x = calc(base('US', { contractorSpend: '10 000' }));
  assert.equal(x.contractorSpendDefault, false);
  assert.equal(r(x.base.overbillingValue), 300);
  assert.equal(calc(base('US', { contractorSpend: '' })).contractorSpendDefault, true);
});

test('кв. футы → м²: 1 м² = 10,7639 кв. фута', () => {
  assert.equal(sqftToM2(10.7639), 1);
  assert.equal(Math.round(sqftToM2(53819.5)), 5000);
  assert.equal(tierFor(sqftToM2(32291.7)), 'S'); // 3 000 м²
  assert.equal(r(defaultContractorSpend('US', sqftToM2(53819.5))), 6750);
});

test('ROI_SHOW_PRICES = false: только выгода, без цены и ROI', () => {
  const x = calc(base('US'), { showPrices: false });
  assert.equal(r(x.base.valueMonth), 1188);
  assert.equal(x.base.costMonth, null);
  assert.equal(x.base.netMonth, null);
  assert.equal(x.base.roi, null);
  assert.equal(x.pricePerSite, null);
  assert.equal(x.listPrice, null);
  // подсказка Залива не зависит от показа цен
  assert.equal(calc(base('GCC'), { showPrices: false }).gulfHint, true);
});

test('подсказка Залива — только Залив и ROI при 3 % < ×1,3', () => {
  assert.equal(calc(base('GCC')).gulfHint, true);
  assert.equal(calc(base('US')).gulfHint, false);
  assert.equal(calc(base('EU')).gulfHint, false);
  assert.equal(calc(base('GCC', { contractorSpend: 100000 })).gulfHint, false);
  // подсказка по 3 %, даже если ползунок на 10 %
  assert.equal(calc(base('GCC', { overbilling: 0.1 })).gulfHint, true);
});

test('защита от мусора на входе', () => {
  const e = (input) => calc({ region: 'US', sites: 1, areaM2: 5000, ...input }).errors;
  assert.deepEqual(e({ sites: 0 }), { sites: 'min' });
  assert.deepEqual(e({ sites: -3 }), { sites: 'min' });
  assert.deepEqual(e({ sites: 501 }), { sites: 'max' });
  assert.deepEqual(e({ sites: 2.5 }), { sites: 'integer' });
  assert.deepEqual(e({ sites: '' }), { sites: 'required' });
  assert.deepEqual(e({ sites: 'abc' }), { sites: 'number' });
  assert.deepEqual(e({ areaM2: 0 }), { areaM2: 'min' });
  assert.deepEqual(e({ areaM2: -100 }), { areaM2: 'min' });
  assert.deepEqual(e({ areaM2: '   ' }), { areaM2: 'required' });
  assert.deepEqual(e({ areaM2: 2e6 }), { areaM2: 'max' });
  assert.deepEqual(e({ contractorSpend: -1 }), { contractorSpend: 'min' });
  assert.deepEqual(e({ hoursCoord: -1, hoursFm: 'x' }), { hoursCoord: 'min', hoursFm: 'number' });
  assert.deepEqual(e({ hoursCoord: 1000 }), { hoursCoord: 'max' });
  assert.deepEqual(e({ overbilling: 0.02 }), { overbilling: 'min' });
  assert.deepEqual(e({ overbilling: 0.15 }), { overbilling: 'max' });
  assert.deepEqual(e({ payoutsPerSite: -1 }), { payoutsPerSite: 'min' });
  assert.deepEqual(e({ payoutsPerSite: 1.5 }), { payoutsPerSite: 'integer' });
  assert.deepEqual(e({ sites: Infinity }), { sites: 'number' });
  assert.deepEqual(e({ sites: NaN }), { sites: 'number' });
  // 500 — можно, нули часов — можно (выгода только от переплат)
  assert.equal(calc(base('US', { sites: 500 })).ok, true);
  const zero = calc(base('US', { hoursCoord: 0, hoursFm: '0' }));
  assert.equal(r(zero.base.timeValue), 0);
  // неизвестный регион → США
  assert.equal(calc(base('XX')).region, 'US');
  assert.equal(validate({}).errors.sites, 'required');
});

test('разбор чисел: пробелы, запятые, неразрывный пробел', () => {
  assert.equal(parseNum('1 188'), 1188);
  assert.equal(parseNum('1 188'), 1188);
  assert.equal(parseNum('1,188'), 1188);
  assert.equal(parseNum('1,188.5'), 1188.5);
  assert.equal(parseNum('2,5'), 2.5);
  assert.equal(parseNum(''), undefined);
  assert.ok(Number.isNaN(parseNum('5k')));
  assert.ok(Number.isNaN(parseNum('1.2.3')));
});

test('форматирование EN / RU', () => {
  assert.equal(fmtInt(1188.19, 'en'), '1,188');
  assert.equal(fmtInt(1188.19, 'ru'), '1 188');
  assert.equal(fmtInt(1234567, 'en'), '1,234,567');
  assert.equal(fmtInt(999, 'ru'), '999');
  assert.equal(fmtMoney(6749.87, 'US', 'en'), '$6,750');
  assert.equal(fmtMoney(4824.3, 'EU', 'ru'), '€4 824');
  assert.equal(fmtMoney(17352.4, 'GCC', 'en'), 'AED 17,352');
  assert.equal(fmtMoney(-250.4, 'US', 'en'), '−$250');
  assert.equal(fmtRoi(2.64, 'en'), '×2.6');
  assert.equal(fmtRoi(2.64, 'ru'), '×2,6');
  assert.equal(fmtRoi(1.025, 'en'), '×1.0');
  assert.equal(fmtPct(0.03, 'en'), '3%');
  assert.equal(fmtPct(0.035, 'ru'), '3,5 %');
});

test('прейскурант и плата за выплаты — как в брифе (раздел 4)', () => {
  assert.deepEqual(REGIONS.US.prices, { S: 250, M: 450, L: 750 });
  assert.deepEqual(REGIONS.EU.prices, { S: 199, M: 349, L: 579 });
  assert.deepEqual(REGIONS.GCC.prices, { S: 650, M: 1100, L: 2000 });
  assert.deepEqual([REGIONS.US.payoutFee, REGIONS.EU.payoutFee, REGIONS.GCC.payoutFee], [2, 2, 7]);
  assert.equal(COMMON.overbilling, 0.03);
  assert.equal(COMMON.contractorShare, 0.7);
});
