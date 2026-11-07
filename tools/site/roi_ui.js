// Калькулятор окупаемости — интерактивная форма в браузере (шаг 35).
// Не модуль: build.mjs встраивает этот файл в страницу roi/ ПОСЛЕ текста tools/site/roi.mjs
// (без слова export), поэтому calc, fmtMoney, REGIONS и т. д. здесь уже определены.
// Без сети, без cookies и localStorage, без счётчиков — только расчёт на странице.
/* global calc, fmtMoney, fmtRoi, fmtPct, fmtInt, defaultContractorSpend, sqftToM2, SQFT_PER_M2, REGIONS, COMMON */
function roiInit(T, CFG) {
  var form = document.getElementById('roi-form');
  var out = document.getElementById('roi-out');
  if (!form || !out) return;
  var lang = T.lang;
  var $ = function (id) { return document.getElementById(id); };
  var f = {
    region: $('roi-region'), sites: $('roi-sites'), area: $('roi-area'), unit: $('roi-unit'),
    spend: $('roi-spend'), over: $('roi-over'), annual: $('roi-annual'),
    hoursCoord: $('roi-hc'), hoursFm: $('roi-hf'), payouts: $('roi-payouts'), payoutsPerSite: $('roi-k'),
  };
  // Поле ввода → ключ ошибки в calc().
  var errField = {
    sites: f.sites, areaM2: f.area, contractorSpend: f.spend, hoursCoord: f.hoursCoord,
    hoursFm: f.hoursFm, overbilling: f.over, payoutsPerSite: f.payoutsPerSite,
  };
  var unit = 'm2';

  function set(id, text) { var e = $(id); if (e) e.textContent = text; }
  function show(id, on) { var e = $(id); if (e) e.hidden = !on; }
  function fmt(tpl, vars) { return tpl.replace(/\{(\w+)\}/g, function (m, k) { return k in vars ? vars[k] : m; }); }
  function money(x, region) { return fmtMoney(x, region, lang); }

  function areaM2() {
    var v = f.area.value;
    if (unit !== 'sqft') return v;
    var n = parseNum(v);
    return n === undefined || !isFinite(n) ? v : sqftToM2(n);
  }

  function showErrors(errors) {
    Object.keys(errField).forEach(function (k) {
      var input = errField[k];
      var msg = $(input.id + '-err');
      var code = errors[k];
      if (code) {
        input.setAttribute('aria-invalid', 'true');
        msg.textContent = (T.err[k] && (T.err[k][code] || T.err[k].any)) || T.err.any;
        msg.hidden = false;
      } else {
        input.removeAttribute('aria-invalid');
        msg.textContent = '';
        msg.hidden = true;
      }
    });
  }

  function update() {
    var region = f.region.value;
    var cur = REGIONS[region].currency;
    // Кв. футы — только для США (бриф 8.2).
    show('roi-unit-wrap', region === 'US');
    if (region !== 'US' && unit === 'sqft') switchUnit('m2');
    set('roi-spend-cur', cur);
    set('roi-over-out', fmtPct(Number(f.over.value) / 100, lang));
    show('roi-k-wrap', f.payouts.checked);

    var input = {
      region: region, sites: f.sites.value, areaM2: areaM2(), contractorSpend: f.spend.value,
      hoursCoord: f.hoursCoord.value, hoursFm: f.hoursFm.value, overbilling: Number(f.over.value) / 100,
      annual: f.annual.checked, payouts: f.payouts.checked, payoutsPerSite: f.payoutsPerSite.value,
    };
    var r = calc(input, { showPrices: CFG.showPrices });
    showErrors(r.ok ? {} : r.errors);

    // Подсказка «рассчитано по площади» — если площадь в порядке.
    var a = parseNum(input.areaM2);
    if (typeof a === 'number' && isFinite(a) && a > 0) {
      var def = defaultContractorSpend(region, a);
      set('roi-spend-hint', fmt(T.spendHint, { v: money(def, region) }));
      f.spend.placeholder = fmtInt(def, lang);
    } else {
      set('roi-spend-hint', T.spendHintEmpty);
      f.spend.placeholder = '';
    }

    show('roi-o-err', !r.ok);
    show('roi-o-custom', r.ok && r.custom);
    show('roi-o-calc', r.ok && !r.custom);
    if (!r.ok || r.custom) return;

    var b = r.base;
    var p = fmtPct(b.overbilling, lang);
    show('roi-o-roi-wrap', CFG.showPrices);
    show('roi-o-net-wrap', CFG.showPrices);
    show('roi-o-value-big', !CFG.showPrices);
    if (CFG.showPrices) {
      set('roi-o-roi', fmtRoi(b.roi, lang));
      set('roi-o-net-m', money(b.netMonth, region));
      set('roi-o-net-y', money(b.netYear, region));
      set('roi-o-cost', fmt(T.costValue, { m: money(b.costMonth, region), tier: r.tier, site: money(r.pricePerSite, region) }));
      set('roi-o-range', fmt(T.range, {
        low: money(r.low.netMonth, region), high: money(r.high.netMonth, region),
        roiLow: fmtRoi(r.low.roi, lang), roiHigh: fmtRoi(r.high.roi, lang),
      }));
    } else {
      set('roi-o-value-m', money(b.valueMonth, region));
      set('roi-o-value-y', money(b.valueYear, region));
      set('roi-o-cost', T.priceOnRequest);
      set('roi-o-range', fmt(T.rangeNoPrice, { low: money(r.low.valueMonth, region), high: money(r.high.valueMonth, region) }));
    }
    set('roi-o-value', fmt(T.perMonthYear, { m: money(b.valueMonth, region), y: money(b.valueYear, region) }));
    set('roi-o-time', money(b.timeValue, region));
    set('roi-o-over-lbl', fmt(T.overLabel, { p: p }));
    set('roi-o-over', money(b.overbillingValue, region));
    show('roi-o-gulf', r.gulfHint);
  }

  function switchUnit(to) {
    if (to === unit) return;
    var n = parseNum(f.area.value);
    if (typeof n === 'number' && isFinite(n)) {
      var v = to === 'sqft' ? n * SQFT_PER_M2 : n / SQFT_PER_M2;
      f.area.value = String(Math.round(v));
    }
    unit = to;
    f.unit.value = to;
  }

  f.unit.addEventListener('change', function () { switchUnit(f.unit.value === 'sqft' ? 'sqft' : 'm2'); update(); });
  form.addEventListener('input', update);
  form.addEventListener('change', update);
  form.addEventListener('submit', function (e) { e.preventDefault(); update(); });
  form.hidden = false;
  out.hidden = false;
  update();
}
