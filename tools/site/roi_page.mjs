// Страница калькулятора окупаемости roi/ (шаг 35): разметка и встроенный скрипт.
// Формулы и цифры — только из roi.mjs; тексты — `roi` в content.en.mjs / content.ru.mjs (из брифа
// docs/site/roi-calculator-brief.md). Без JS страница показывает таблицу контрольных примеров,
// цены и «Как мы считаем», посчитанные здесь же при сборке; с JS поверх — форма (hidden до запуска скрипта).
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  calc, hourCost, repairRateM2, fmtMoney, fmtRoi, fmtPct, fmtInt, fmtDec, REGIONS, REGION_KEYS, COMMON, FX,
  US_REPAIR_PER_SQFT, SQFT_PER_M2,
} from './roi.mjs';
import { ROI_SHOW_PRICES, CONTACT } from './config.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const fmt = (tpl, vars) => tpl.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? vars[k] : m));

/** Текст roi.mjs для браузера: без export и без комментариев. */
export function roiSource() {
  return readFileSync(join(here, 'roi.mjs'), 'utf8')
    .replace(/\/\*\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/,\s*\/\/.*$/gm, ',')
    .replace(/^export /gm, '')
    .replace(/\n\s*\n+/g, '\n');
}

function uiSource() {
  return readFileSync(join(here, 'roi_ui.js'), 'utf8')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/^\/\* global[^\n]*\*\/$/m, '')
    .replace(/\n\s*\n+/g, '\n');
}

/** Встроенный скрипт страницы: формулы + форма. Только на этой странице, без сети и хранилищ. */
export function roiScript(T, lang) {
  const t = { lang, ...T.js };
  const cfg = { showPrices: ROI_SHOW_PRICES };
  const code = `(function(){\n'use strict';\n${roiSource()}\n${uiSource()}\nroiInit(${JSON.stringify(t)},${JSON.stringify(cfg)});\n})();`;
  if (/<\/script/i.test(code)) throw new Error('roi: «</script» в коде скрипта');
  return `<script>\n${code}\n</script>`;
}

const money = (x, r, lang) => fmtMoney(x, r, lang);

/** ROI контрольного примера (1 объект, 5 000 м², 3 %) — для текстов FAQ: «×2.6». */
export function exampleRoi(region, lang) {
  return fmtRoi(calc({ region, sites: 1, areaM2: COMMON.areaM2 }).base.roi, lang);
}
/** Дробь как есть, с запятой для RU: 10.7639 → «10,7639». */
const dec = (x, lang) => String(x).replace('.', lang === 'ru' ? ',' : '.');

/** Таблица контрольных примеров: 1 объект M (5 000 м²), 3 % и 10 %, три региона (бриф, раздел 7). */
function examplesTable(T, lang) {
  const xs = REGION_KEYS.map((r) => calc({ region: r, sites: 1, areaM2: COMMON.areaM2 }, { showPrices: ROI_SHOW_PRICES }));
  const row = (label, f) => `<tr><th scope="row">${label}</th>${xs.map((x) => `<td>${f(x)}</td>`).join('')}</tr>`;
  const rows = [
    row(T.ex.spend, (x) => money(x.contractorSpend, x.region, lang)),
    row(T.ex.time, (x) => money(x.base.timeValue, x.region, lang)),
    row(fmt(T.ex.over, { p: fmtPct(0.03, lang) }), (x) => money(x.low.overbillingValue, x.region, lang)),
    row(fmt(T.ex.value, { p: fmtPct(0.03, lang) }), (x) => money(x.low.valueMonth, x.region, lang)),
  ];
  if (ROI_SHOW_PRICES) {
    rows.push(
      row(T.ex.price, (x) => money(x.base.costMonth, x.region, lang)),
      row(fmt(T.ex.net, { p: fmtPct(0.03, lang) }), (x) => money(x.low.netMonth, x.region, lang)),
      row(fmt(T.ex.roi, { p: fmtPct(0.03, lang) }), (x) => `<strong>${fmtRoi(x.low.roi, lang)}</strong>`),
      row(fmt(T.ex.net, { p: fmtPct(0.1, lang) }), (x) => money(x.high.netMonth, x.region, lang)),
      row(fmt(T.ex.roi, { p: fmtPct(0.1, lang) }), (x) => `<strong>${fmtRoi(x.high.roi, lang)}</strong>`),
    );
  } else {
    rows.push(
      row(fmt(T.ex.value, { p: fmtPct(0.1, lang) }), (x) => money(x.high.valueMonth, x.region, lang)),
      row(T.ex.price, () => T.priceOnRequest),
    );
  }
  return `<div class="table-wrap"><table>
<caption>${T.ex.caption}</caption>
<thead><tr><th scope="col">${T.ex.metric}</th>${REGION_KEYS.map((r) => `<th scope="col">${T.regionShort[r]}</th>`).join('')}</tr></thead>
<tbody>
${rows.join('\n')}
</tbody>
</table></div>`;
}

/** Прейскурант S / M / L / больше 30 000 м² (бриф 4.1). */
function pricesTable(T, lang) {
  const area = (k) => fmt(T.tierArea[k], {
    s: fmtInt(COMMON.tiers.S, lang), m: fmtInt(COMMON.tiers.M, lang), l: fmtInt(COMMON.tiers.L, lang),
  });
  const row = (k) => `<tr><th scope="row">${T.tierName[k]}</th><td>${area(k)}</td>${REGION_KEYS.map((r) => `<td>${k === 'custom' ? T.custom : money(REGIONS[r].prices[k], r, lang)}</td>`).join('')}</tr>`;
  return `<div class="table-wrap"><table>
<caption>${T.prices.caption}</caption>
<thead><tr><th scope="col">${T.prices.tier}</th><th scope="col">${T.prices.area}</th>${REGION_KEYS.map((r) => `<th scope="col">${T.regionShort[r]}</th>`).join('')}</tr></thead>
<tbody>
${['S', 'M', 'L', 'custom'].map(row).join('\n')}
</tbody>
</table></div>`;
}

/** Таблица допущений (бриф, раздел 5). */
function assumptionsTable(T, lang) {
  const sal = (r, who) => money(who === 'fm' ? REGIONS[r].fmSalary : REGIONS[r].coordSalary, r, lang);
  const per = (r, x) => `${REGIONS[r].symbol}${fmtDec(x, lang)}`;
  const row = (label, f, kind) => `<tr><th scope="row">${label}</th>${REGION_KEYS.map((r) => `<td>${f(r)}</td>`).join('')}<td>${T.kind[kind]}</td></tr>`;
  const same = (v) => () => v;
  return `<div class="table-wrap"><table>
<caption>${T.how.tableCaption}</caption>
<thead><tr><th scope="col">${T.how.param}</th>${REGION_KEYS.map((r) => `<th scope="col">${T.regionShort[r]}</th>`).join('')}<th scope="col">${T.how.type}</th></tr></thead>
<tbody>
${row(T.how.coordSalary, (r) => sal(r, 'coord'), 'fact')}
${row(T.how.fmSalary, (r) => sal(r, 'fm'), 'fact')}
${row(T.how.burden, same(dec(COMMON.burden, lang)), 'assumption')}
${row(T.how.hoursYear, same(fmtInt(COMMON.hoursYear, lang)), 'assumption')}
${row(T.how.coordHour, (r) => per(r, hourCost(r, 'coord')), 'calc')}
${row(T.how.fmHour, (r) => per(r, hourCost(r, 'fm')), 'calc')}
${row(T.how.repair, (r) => per(r, repairRateM2(r)), 'estimate')}
${row(T.how.share, same(fmtPct(COMMON.contractorShare, lang)), 'assumption')}
${row(T.how.hours, same(fmt(T.how.hoursValue, { c: COMMON.hoursCoord, f: COMMON.hoursFm })), 'assumption')}
${row(T.how.overbilling, same(fmt(T.how.overbillingValue, { p: fmtPct(COMMON.overbilling, lang), min: fmtPct(COMMON.overbillingMin, lang), max: fmtPct(COMMON.overbillingMax, lang) })), 'assumption')}
</tbody>
</table></div>`;
}

const field = (id, label, input, hint = '') => `<div class="roi-field">
<label for="${id}">${label}</label>
${input}
${hint ? `<p class="note" id="${id}-hint">${hint}</p>` : ''}<p class="roi-err" id="${id}-err" hidden></p>
</div>`;

const numInput = (id, value) =>
  `<input id="${id}" name="${id}" type="text" inputmode="decimal" autocomplete="off" value="${value}" aria-describedby="${id}-hint ${id}-err">`;

function formHtml(T, lang) {
  const regions = REGION_KEYS.map((r) => `<option value="${r}">${T.regionLong[r]}</option>`).join('');
  return `<form id="roi-form" class="roi-form" hidden novalidate aria-labelledby="roi-form-h">
<h2 id="roi-form-h">${T.form.title}</h2>
${field('roi-region', T.form.region, `<select id="roi-region" name="roi-region">${regions}</select>`)}
${field('roi-sites', T.form.sites, numInput('roi-sites', 1), fmt(T.form.sitesHint, { max: COMMON.maxSites }))}
<div class="roi-field">
<label for="roi-area">${T.form.area}</label>
<div class="roi-row">${numInput('roi-area', COMMON.areaM2)}<span id="roi-unit-wrap" class="roi-unit"><label class="sr" for="roi-unit">${T.form.unit}</label><select id="roi-unit" name="roi-unit"><option value="m2">${T.form.m2}</option><option value="sqft">${T.form.sqft}</option></select></span></div>
<p class="note" id="roi-area-hint">${fmt(T.form.areaHint, { s: fmtInt(COMMON.tiers.S, lang), m: fmtInt(COMMON.tiers.M, lang), l: fmtInt(COMMON.tiers.L, lang) })}</p><p class="roi-err" id="roi-area-err" hidden></p>
</div>
${field('roi-spend', `${T.form.spend} (<span id="roi-spend-cur">USD</span>)`, numInput('roi-spend', ''), T.js.spendHintEmpty)}
<div class="roi-field">
<label for="roi-over">${T.form.over}</label>
<div class="roi-row"><input id="roi-over" name="roi-over" type="range" min="${COMMON.overbillingMin * 100}" max="${COMMON.overbillingMax * 100}" step="0.5" value="${COMMON.overbilling * 100}" aria-describedby="roi-over-hint"><output id="roi-over-out" for="roi-over">${fmtPct(COMMON.overbilling, lang)}</output></div>
<p class="note" id="roi-over-hint">${T.form.overHint}</p><p class="roi-err" id="roi-over-err" hidden></p>
</div>
<div class="roi-check"><input id="roi-annual" name="roi-annual" type="checkbox"><label for="roi-annual">${fmt(T.form.annual, { d: fmtPct(COMMON.annualDiscount, lang) })}</label></div>
<details class="roi-more">
<summary>${T.form.more}</summary>
${field('roi-hc', T.form.hc, numInput('roi-hc', COMMON.hoursCoord), T.form.hoursHint)}
${field('roi-hf', T.form.hf, numInput('roi-hf', COMMON.hoursFm), T.form.hoursHint)}
<div class="roi-check"><input id="roi-payouts" name="roi-payouts" type="checkbox" aria-describedby="roi-payouts-hint"><label for="roi-payouts">${T.form.payouts}</label></div>
<p class="note" id="roi-payouts-hint">${fmt(T.form.payoutsHint, { us: money(REGIONS.US.payoutFee, 'US', lang), eu: money(REGIONS.EU.payoutFee, 'EU', lang), gcc: money(REGIONS.GCC.payoutFee, 'GCC', lang) })}</p>
<div id="roi-k-wrap" hidden>${field('roi-k', T.form.k, numInput('roi-k', COMMON.payoutsPerSite), T.form.kHint)}</div>
</details>
<p class="actions"><button class="btn ghost" type="submit">${T.form.submit}</button></p>
</form>`;
}

function resultHtml(T) {
  return `<section id="roi-out" class="roi-out" hidden aria-labelledby="roi-out-h">
<h2 id="roi-out-h">${T.out.title}</h2>
<div aria-live="polite">
<p id="roi-o-err" class="roi-err" hidden>${T.out.fix}</p>
<div id="roi-o-custom" class="notice" hidden><p>${T.out.custom}</p></div>
<div id="roi-o-calc">
<div class="roi-big">
<p id="roi-o-roi-wrap"><span class="lbl">${T.out.roi}</span><strong id="roi-o-roi">—</strong></p>
<p id="roi-o-net-wrap"><span class="lbl">${T.out.net}</span><strong id="roi-o-net-m">—</strong><span class="per">${T.out.perMonth}</span><span class="sub"><span id="roi-o-net-y">—</span> ${T.out.perYear}</span></p>
<p id="roi-o-value-big" hidden><span class="lbl">${T.out.value}</span><strong id="roi-o-value-m">—</strong><span class="per">${T.out.perMonth}</span><span class="sub"><span id="roi-o-value-y">—</span> ${T.out.perYear}</span></p>
</div>
<dl class="roi-dl">
<div><dt>${T.out.value}</dt><dd id="roi-o-value">—</dd></div>
<div><dt>${T.out.cost}</dt><dd><span id="roi-o-cost">—</span><span class="note">${T.out.free}</span></dd></div>
<div><dt>${T.out.time}</dt><dd id="roi-o-time">—</dd></div>
<div><dt id="roi-o-over-lbl">${T.out.over}</dt><dd id="roi-o-over">—</dd></div>
</dl>
<p id="roi-o-range" class="roi-range">—</p>
<p id="roi-o-gulf" class="notice" hidden>${T.out.gulf}</p>
</div>
</div>
<p class="roi-honest">${T.honest}</p>
<p class="actions"><a class="btn" href="${CONTACT.roiUrl}">${T.demo}</a></p>
</section>`;
}

/** Тело страницы. h — помощники build.mjs (ссылки), T — тексты языка. */
export function roiBody(h, T, lang) {
  const sources = T.how.sources.map(([name, url]) => `<li><a href="${url}" rel="noopener">${name}</a></li>`).join('');
  return `
<h1>${T.h1}</h1>
<p class="lead">${T.lead}</p>
<noscript><p class="notice">${T.noJs}</p></noscript>
<div class="roi">
${formHtml(T, lang)}
${resultHtml(T)}
</div>

<section aria-labelledby="roi-ex">
<h2 id="roi-ex">${T.ex.title}</h2>
<p>${T.ex.text}</p>
${examplesTable(T, lang)}
<p class="roi-honest">${T.honest}</p>
<p class="note">${fmt(T.ex.gulfNote, {})}</p>
</section>

<section aria-labelledby="roi-price">
<h2 id="roi-price">${T.prices.title}</h2>
${ROI_SHOW_PRICES ? `${pricesTable(T, lang)}
<ul class="ticks">${T.prices.notes.map((n) => `<li>${fmt(n, {
    d: fmtPct(COMMON.annualDiscount, lang),
    us: money(REGIONS.US.payoutFee, 'US', lang), eu: money(REGIONS.EU.payoutFee, 'EU', lang), gcc: money(REGIONS.GCC.payoutFee, 'GCC', lang),
  })}</li>`).join('')}</ul>` : `<p><strong>${T.priceOnRequest}.</strong> ${T.prices.free}</p>`}
</section>

<section aria-labelledby="roi-how">
<h2 id="roi-how">${T.how.title}</h2>
<ol>${T.how.steps.map((s) => `<li>${s}</li>`).join('')}</ol>
${assumptionsTable(T, lang)}
<p class="note">${fmt(T.how.notes, {
    sqft: dec(US_REPAIR_PER_SQFT, lang), m2: dec(SQFT_PER_M2, lang), eur: dec(FX.EUR_USD, lang), aed: dec(FX.USD_AED, lang),
    eu: fmtPct(REGIONS.EU.repairShare, lang), gcc: fmtPct(REGIONS.GCC.repairShare, lang),
  })}</p>
<h3>${T.how.sourcesTitle}</h3>
<ul>${sources}</ul>
<p class="note">${T.how.vendorNote}</p>
</section>

<section class="cta" aria-labelledby="cta">
<h2 id="cta">${T.cta.title}</h2>
<p>${T.cta.text}</p>
<p class="actions"><a class="btn" href="${CONTACT.roiUrl}">${T.demo}</a> ${h.link('faq', T.cta.faq).replace('<a ', '<a class="btn ghost" ')}</p>
</section>
${roiScript(T, lang)}
`;
}

export { esc };
