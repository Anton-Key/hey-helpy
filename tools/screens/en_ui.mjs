// Шаг 33: снимки /screens и кадры питча — только на английском интерфейсе.
// Скрипты съёмки ищут элементы по русским подписям (их сотни). Чтобы не
// переписывать каждый селектор, страница Playwright оборачивается: имена в
// getByRole / getByText / getByLabel / getByPlaceholder переводятся на
// английский по тем же файлам переводов приложения (lib/l10n/app_*.arb).
// Переводятся целые подписи и подписи внутри регулярных выражений (по
// границам слов); строки с параметрами ({count}) — частями до и после них.
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '../..');
const arb = (lang) => JSON.parse(readFileSync(join(ROOT, `lib/l10n/app_${lang}.arb`), 'utf8'));
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** Пары «русская подпись → английская», длинные первыми. */
export function buildPairs() {
  const ru = arb('ru');
  const en = arb('en');
  const pairs = new Map();
  for (const [k, v] of Object.entries(ru)) {
    if (k.startsWith('@') || typeof v !== 'string' || typeof en[k] !== 'string') continue;
    if (!/[А-Яа-яЁё]/.test(v) || v.includes('{') && v.includes('plural')) continue;
    if (!v.includes('{')) {
      if (v.length >= 2 && !pairs.has(v)) pairs.set(v, en[k]);
      continue;
    }
    // «Найдено {n} из {m}»: переводим неизменные куски по порядку, если их столько же.
    const rp = v.split(/\{[^}]+\}/);
    const ep = en[k].split(/\{[^}]+\}/);
    if (rp.length !== ep.length) continue;
    rp.forEach((p, i) => { const t = p.trim(); if (t.length >= 3 && /[А-Яа-яЁё]/.test(t) && !pairs.has(t)) pairs.set(t, ep[i].trim()); });
  }
  return [...pairs.entries()].sort((a, b) => b[0].length - a[0].length);
}

const PAIRS = buildPairs();
const L = 'A-Za-zА-Яа-яЁё0-9';

/** Перевести текст или регулярное выражение селектора. */
export function tr(x) {
  if (typeof x === 'string') {
    for (const [r, e] of PAIRS) if (x === r) return e;
    let s = x;
    for (const [r, e] of PAIRS) {
      if (!s.includes(r)) continue;
      s = s.replace(new RegExp(`(?<![${L}])${esc(r)}(?![${L}])`, 'g'), e);
    }
    return s;
  }
  if (x instanceof RegExp) {
    let src = x.source;
    for (const [r, e] of PAIRS) {
      if (!src.includes(r) && !src.includes(esc(r))) continue;
      const pat = new RegExp(`(?<![${L}])(?:${esc(esc(r))}|${esc(r)})(?![${L}])`, 'g');
      src = src.replace(pat, esc(e).replace(/\$/g, '$$$$'));
    }
    return new RegExp(src, x.flags);
  }
  return x;
}

/** Обернуть страницу: селекторы с русскими подписями ищут английские. */
export function englishPage(page) {
  const wrap = (target) => {
    for (const m of ['getByRole']) {
      const orig = target[m].bind(target);
      target[m] = (role, opts) => wrapLoc(orig(role, opts?.name !== undefined ? { ...opts, name: tr(opts.name) } : opts));
    }
    for (const m of ['getByText', 'getByLabel', 'getByPlaceholder']) {
      const orig = target[m].bind(target);
      target[m] = (text, opts) => wrapLoc(orig(tr(text), opts));
    }
    return target;
  };
  // Локаторы тоже: .first().getByRole(…), .or(…), .filter({hasText}).
  const wrapLoc = (loc) => {
    if (!loc || loc.__en) return loc;
    loc.__en = true;
    wrap(loc);
    for (const m of ['first', 'last', 'nth', 'or', 'and', 'locator']) {
      const orig = loc[m]?.bind(loc);
      if (orig) loc[m] = (...a) => wrapLoc(orig(...a));
    }
    const filter = loc.filter?.bind(loc);
    if (filter) loc.filter = (o = {}) => wrapLoc(filter({ ...o, ...(o.hasText ? { hasText: tr(o.hasText) } : {}) }));
    return loc;
  };
  wrap(page);
  return page;
}

/** Init-скрипт контекста: интерфейс на английском (как сохранённый выбор). */
export const EN_INIT = () => {
  try { localStorage.setItem('flutter.locale', JSON.stringify('en')); } catch {}
};
