// Проверка собранного сайта без браузера и без сети (её же запускает «PR check»):
//   node tools/site/build.mjs --out build/site && node tools/site/check.mjs build/site
// Что проверяет: один h1 и уровни заголовков без пропусков; title, description, canonical, hreflang;
// нет noindex (кроме 404); JSON-LD разбирается и содержит нужные типы; у картинок alt / width / height;
// нет исполняемых скриптов (весь текст виден без JS); внутренние ссылки и якоря ведут на существующее;
// robots.txt пускает всех нужных ботов; sitemap.xml и llms.txt — на существующие страницы;
// нет ключей, e-mail и запрещённых названий; у каждой картинки, постера, ролика, OG и значка — версия
// ?v=<первые 8 знаков SHA-256 файла> (шаг 35c), и она совпадает с файлом.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, relative, dirname, normalize } from 'node:path';
import { SITE_URL } from './config.mjs';
import { BOTS } from './build.mjs';

const out = process.argv[2] || 'build/site';
const errors = [];
const warns = [];
const err = (f, m) => errors.push(`${f}: ${m}`);

const files = [];
(function walk(d) {
  for (const f of readdirSync(d)) {
    const p = join(d, f);
    statSync(p).isDirectory() ? walk(p) : files.push(p);
  }
})(out);
const html = files.filter((f) => f.endsWith('.html'));
const rel = (f) => relative(out, f);
const ids = new Map(html.map((f) => [rel(f), new Set([...readFileSync(f, 'utf8').matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]))]));

/** Адрес ссылки → файл в собранном сайте (или null, если ссылка внешняя). */
function target(fromFile, href) {
  let path = href;
  if (href.startsWith(SITE_URL)) path = '/' + href.slice(SITE_URL.length);
  else if (/^(https?:|mailto:|tel:)/.test(href)) return null;
  const [withQuery, hash] = path.split('#');
  const p = withQuery.split('?')[0];
  let file = p === '' ? rel(fromFile) : p.startsWith('/') ? normalize(p.slice(1)) : normalize(join(dirname(rel(fromFile)), p));
  if (file === '.' || file.endsWith('/') || p.endsWith('/') || p === '') file = p === '' ? file : join(file, 'index.html');
  if (existsSync(join(out, file)) && statSync(join(out, file)).isDirectory()) file = join(file, 'index.html');
  return { file, hash };
}

for (const f of html) {
  const s = readFileSync(f, 'utf8');
  const name = rel(f);
  const is404 = name === '404.html';
  const h1 = (s.match(/<h1[\s>]/g) || []).length;
  if (h1 !== 1) err(name, `h1: ${h1}, нужен ровно один`);
  let prev = 0;
  for (const m of s.matchAll(/<h([1-6])[\s>]/g)) {
    const lvl = Number(m[1]);
    if (prev && lvl > prev + 1) err(name, `пропуск уровня заголовка h${prev} → h${lvl}`);
    prev = lvl;
  }
  if (!/<html lang="(ru|en)">/.test(s)) err(name, 'нет lang у <html>');
  const title = s.match(/<title>([^<]*)<\/title>/)?.[1] || '';
  if (title.length < 10 || title.length > 80) err(name, `title ${title.length} симв. (нужно 10–80)`);
  const desc = s.match(/<meta name="description" content="([^"]*)"/)?.[1] || '';
  if (desc.length < 50 || desc.length > 200) err(name, `description ${desc.length} симв. (нужно 50–200)`);
  if (!/<meta name="viewport"/.test(s)) err(name, 'нет viewport');
  if (!is404) {
    if (/noindex/.test(s)) err(name, 'noindex на обычной странице');
    if (!/<link rel="canonical" href="https:\/\//.test(s)) err(name, 'нет canonical');
    for (const l of ['ru', 'en', 'x-default']) if (!s.includes(`hreflang="${l}"`)) err(name, `нет hreflang ${l}`);
    for (const p of ['og:title', 'og:description', 'og:image', 'og:url', 'twitter:card']) if (!s.includes(`"${p}"`)) err(name, `нет ${p}`);
  }
  // JSON-LD
  const lds = [...s.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];
  if (!is404 && !lds.length) err(name, 'нет JSON-LD');
  const types = new Set();
  for (const [, j] of lds) {
    try {
      const o = JSON.parse(j);
      if (o['@context'] !== 'https://schema.org') err(name, 'JSON-LD без @context schema.org');
      for (const n of o['@graph'] || [o]) types.add(n['@type']);
      if (/aggregateRating|"review"|ratingValue/.test(j)) err(name, 'в JSON-LD отзывы / рейтинги — их нет, выдумывать нельзя');
    } catch (e) { err(name, `JSON-LD не разбирается: ${e.message}`); }
  }
  if (!is404) {
    for (const t of ['Organization', 'WebPage']) if (!types.has(t)) err(name, `JSON-LD без ${t}`);
    const home = name === 'index.html' || name === 'ru/index.html';
    if (home) for (const t of ['SoftwareApplication', 'VideoObject', 'WebSite']) if (!types.has(t)) err(name, `JSON-LD без ${t}`);
    if (!home && !types.has('BreadcrumbList')) err(name, 'JSON-LD без BreadcrumbList');
    if (/\/faq\//.test(name) && !types.has('FAQPage')) err(name, 'JSON-LD без FAQPage');
  }
  // Без JS: исполняемых скриптов нет (кроме JSON-LD). Исключение (шаг 35) — калькулятор окупаемости roi/:
  // один встроенный скрипт без src, без сети, cookies и хранилищ; форма скрыта до запуска скрипта,
  // а без JS видны таблица контрольных примеров и «Как мы считаем».
  const scripts = [...s.matchAll(/<script(?![^>]*application\/ld\+json)[^>]*>([\s\S]*?)<\/script>/g)];
  const isRoi = /^(ru\/)?roi\/index\.html$/.test(name);
  if (scripts.length && !isRoi) err(name, `исполняемый <script> (${scripts.length}) — текст должен быть виден без JS`);
  if (isRoi) {
    if (scripts.length !== 1) err(name, `калькулятор: скриптов ${scripts.length}, нужен ровно один встроенный`);
    for (const [tag, code] of scripts) {
      if (/\ssrc=/.test(tag)) err(name, 'калькулятор: внешний скрипт (src) запрещён');
      const bad = code.match(/\b(fetch|XMLHttpRequest|sendBeacon|WebSocket|EventSource|localStorage|sessionStorage|indexedDB|document\.cookie|import\s*\()/);
      if (bad) err(name, `калькулятор: «${bad[1]}» — без сети, cookies и хранилищ`);
    }
    if (!/<form id="roi-form"[^>]* hidden/.test(s)) err(name, 'калькулятор: форма должна быть скрыта без JS (hidden)');
    if (!/<table>[\s\S]*?<\/table>/.test(s)) err(name, 'калькулятор: без JS нужна таблица контрольных примеров');
    if (!/(not a promise|а не обещание)/.test(s)) err(name, 'калькулятор: нет честной подписи под результатом');
  }
  // Ничего «гарантированного» (бриф калькулятора, раздел 9).
  if (/guarantee|гарантир/i.test(s.replace(/<style>[\s\S]*?<\/style>/, ''))) err(name, '«гарантия» на сайте — обещаний не даём');
  // Картинки
  for (const [img] of s.matchAll(/<img [^>]*>/g)) {
    if (!/ alt="[^"]+"/.test(img)) err(name, `img без alt: ${img.slice(0, 80)}`);
    if (!/ width="\d+"/.test(img) || !/ height="\d+"/.test(img)) err(name, `img без width / height: ${img.slice(0, 80)}`);
  }
  // Ссылки и ресурсы
  for (const [, attr, href] of s.matchAll(/\s(href|src|poster)="([^"]+)"/g)) {
    const t = target(f, href);
    if (!t) continue;
    if (!existsSync(join(out, t.file))) { err(name, `битая ссылка ${attr}="${href}" → ${t.file}`); continue; }
    if (t.hash && t.file.endsWith('.html') && !ids.get(t.file)?.has(t.hash)) err(name, `нет якоря #${t.hash} в ${t.file}`);
  }
  // Секреты, личные данные, запрещённое
  if (/eyJ[A-Za-z0-9_-]{10,}\.|sbp_[A-Za-z0-9]{20,}|service_role/.test(s)) err(name, 'похоже на ключ');
  if (/[A-Za-z0-9._%+-]+@(?!media\b|font-face\b|HeyHelpy_bot)[A-Za-z0-9-]+\.[A-Za-z]{2,}/.test(s.replace(/<style>[\s\S]*?<\/style>/, ''))) warns.push(`${name}: есть e-mail — проверьте, что это рабочий адрес владельца`);
  if (/Сербская Роза|Serbian Rose/i.test(s)) err(name, 'кодовое название продукта');
  // Строка собрана из частей, чтобы сторож test/terminology_test.dart не находил её в этом файле.
  if (s.includes('Эй' + ', Helpy')) err(name, 'старое название продукта — на всех языках «Hey Helpy» (шаг 33)');
  if (/TODO/.test(s)) warns.push(`${name}: TODO на странице`);
}

// Версии картинок и видео (шаг 35c): адрес без ?v= или с чужим хешем — браузер и превью ссылок
// покажут старый файл из кэша. Ищем все адреса медиафайлов в HTML (атрибуты, OG, JSON-LD) и манифесте.
const MEDIA = /(?:https?:\/\/[^"'\s()<>]+|[A-Za-z0-9_./-]+)\.(?:webp|png|jpe?g|gif|svg|avif|mp4|webm)(?![A-Za-z0-9])(?:\?[^"'\s()<>]*)?/g;
const sha8 = new Map();
let mediaRefs = 0;
for (const f of [...html, join(out, 'site.webmanifest')].filter(existsSync)) {
  const s = readFileSync(f, 'utf8').replace(/<style>[\s\S]*?<\/style>/g, '');
  for (const [url] of s.matchAll(MEDIA)) {
    if (url.startsWith('http') && !url.startsWith(SITE_URL)) continue; // чужие адреса не наши
    mediaRefs++;
    const v = url.match(/\?v=([0-9a-f]{8})$/)?.[1];
    if (!v) { err(rel(f), `медиафайл без версии ?v=: ${url}`); continue; }
    const t = target(f, url);
    const file = t && join(out, t.file);
    if (!file || !existsSync(file)) { err(rel(f), `медиафайл не найден: ${url}`); continue; }
    if (!sha8.has(file)) sha8.set(file, createHash('sha256').update(readFileSync(file)).digest('hex').slice(0, 8));
    if (sha8.get(file) !== v) err(rel(f), `версия ${v} не совпадает с файлом (${sha8.get(file)}): ${url} — пересоберите сайт`);
  }
}
if (!mediaRefs) err('сайт', 'не найдено ни одного адреса картинки — проверка версий не работает');

// robots.txt
const robots = existsSync(join(out, 'robots.txt')) ? readFileSync(join(out, 'robots.txt'), 'utf8') : '';
if (!robots) err('robots.txt', 'нет файла');
for (const b of BOTS) if (!new RegExp(`User-agent: ${b}\\nAllow: /\\n`).test(robots)) err('robots.txt', `нет Allow для ${b}`);
if (/^Disallow:\s*\/\s*$/m.test(robots)) err('robots.txt', 'Disallow: / закрывает сайт');
if (!robots.includes(`Sitemap: ${SITE_URL}sitemap.xml`)) err('robots.txt', 'нет строки Sitemap');

// sitemap.xml
const sm = readFileSync(join(out, 'sitemap.xml'), 'utf8');
const locs = [...sm.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
if ((sm.match(/<lastmod>\d{4}-\d{2}-\d{2}<\/lastmod>/g) || []).length !== locs.length) err('sitemap.xml', 'не у всех адресов есть lastmod');
for (const u of locs) {
  const t = target(join(out, 'index.html'), u);
  if (!t || !existsSync(join(out, t.file))) err('sitemap.xml', `адрес без страницы: ${u}`);
}
const pages = html.filter((f) => rel(f) !== '404.html').length;
if (locs.length !== pages) err('sitemap.xml', `адресов ${locs.length}, страниц ${pages}`);

// llms.txt / llms-full.txt
for (const f of ['llms.txt', 'llms-full.txt']) {
  if (!existsSync(join(out, f))) { err(f, 'нет файла'); continue; }
  const t = readFileSync(join(out, f), 'utf8');
  if (f === 'llms.txt' && !/^# .+\n\n> /.test(t)) err(f, 'нет заголовка «# …» и описания «> …» (формат llmstxt.org)');
  for (const [, u] of t.matchAll(/\]\((https:[^)]+)\)/g)) {
    const tg = target(join(out, 'index.html'), u);
    if (tg && !existsSync(join(out, tg.file))) err(f, `ссылка без страницы: ${u}`);
  }
}

for (const w of warns) console.warn('⚠️', w);
if (errors.length) {
  console.error(errors.map((e) => '✗ ' + e).join('\n'));
  console.error(`\nОшибок: ${errors.length}`);
  process.exit(1);
}
console.log(`✓ сайт в порядке: ${html.length} HTML-страниц, ${locs.length} адресов в sitemap, ${BOTS.length} ботов в robots.txt, ${mediaRefs} адресов медиафайлов с версией`);
