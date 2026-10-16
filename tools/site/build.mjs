// Генератор сайта «Эй, Helpy» — без зависимостей, только Node ≥ 18.
//
//   node tools/site/build.mjs              → перезаписывает HTML и служебные файлы в site/
//   node tools/site/build.mjs --out DIR    → ещё и собирает готовый к публикации сайт в DIR
//                                            (site/ + картинки assets/site/ + значки + демо-видео)
//
// Тексты — content.ru.mjs / content.en.mjs, настройки (адрес сайта, контакты) — config.mjs,
// стиль — site.css (встраивается в каждую страницу). Руками site/*.html не править: перезапишется.
// Картинки лежат в assets/site/ (хук block_secrets пропускает картинки только из разрешённых папок)
// и копируются в img/ только при --out.
import { readFileSync, writeFileSync, mkdirSync, cpSync, copyFileSync, existsSync, rmSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { SITE_URL, APP_URL, UPDATED, CONTACT, VIDEO, BRAND } from './config.mjs';
import * as ru from './content.ru.mjs';
import * as en from './content.en.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '../..');
const siteDir = join(root, 'site');
const sizes = JSON.parse(readFileSync(join(root, 'assets/site/sizes.json'), 'utf8'));
const LANGS = { ru, en };
const KEYS = ['home', 'features', 'industries', 'security', 'faq', 'contact', 'privacy'];
const NAV = ['features', 'industries', 'security', 'faq', 'contact'];

/** Порядок ИИ-ботов и поисковиков в robots.txt — требования владельца (шаг 29). */
export const BOTS = [
  'GPTBot', 'OAI-SearchBot', 'ChatGPT-User', 'ClaudeBot', 'Claude-User', 'Claude-SearchBot',
  'PerplexityBot', 'Perplexity-User', 'Google-Extended', 'Applebot-Extended', 'YandexBot',
  'YandexAdditional', 'Bingbot', 'Googlebot',
];

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const abs = (path) => SITE_URL + path;
const depth = (slug) => (slug.match(/\//g) || []).length;
const json = (o) => JSON.stringify(o, null, 1).replace(/</g, '\\u003c');

function css(rel) {
  return readFileSync(join(here, 'site.css'), 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\s*\n\s*/g, '')
    .replace('FONT400', `${rel}fonts/onest-400.woff2`)
    .replace('FONT600', `${rel}fonts/onest-600.woff2`);
}

const LOGO = '<svg width="32" height="32" viewBox="0 0 32 32" aria-hidden="true"><rect width="32" height="32" rx="9" fill="#2DB89A"/><path d="M9 9v14M23 9v14M9 16h14" stroke="#062B23" stroke-width="3" stroke-linecap="round"/></svg>';

/** Помощники для текстов страницы: ссылки, картинки, видео, призыв. */
function helpers(lang, slug) {
  const { ui, pages } = LANGS[lang];
  const rel = '../'.repeat(depth(slug));
  const href = (key, hash = '') => rel + pages[key].slug + hash || './';
  const imgTag = (name, alt, eager) => {
    const [w, h] = sizes[`${name}.webp`];
    return `<img src="${rel}img/${name}.webp" width="${w}" height="${h}" alt="${esc(alt)}"${eager ? ' fetchpriority="high"' : ' loading="lazy"'} decoding="async">`;
  };
  return {
    rel,
    link: (key, text, hash = '') => `<a href="${href(key, hash)}">${text}</a>`,
    appLink: (text) => `<a href="${APP_URL}">${text}</a>`,
    img: (name, alt, { eager = false, cls = '' } = {}) => `<figure class="shot ${cls}">${imgTag(name, alt, eager)}</figure>`,
    figure: (name, alt, caption) => `<figure class="big">${imgTag(name, alt)}<figcaption>${caption}. ${ui.shotNote}.</figcaption></figure>`,
    card: (name, title, text, alt) => `<article class="card"><h3>${title}</h3><p>${text}</p>${imgTag(name, alt)}</article>`,
    cta: (kind) => `<a class="btn${kind === 'primary' ? '' : ' ghost'}" href="${href('contact')}">${ui.demo}</a>`,
    video: (label) => `<figure class="video"><video controls preload="none" playsinline width="${VIDEO.width}" height="${VIDEO.height}" poster="${rel}${VIDEO.poster}" aria-label="${esc(label)}"><source src="${rel}${VIDEO.file}" type="video/mp4"><a href="${rel}${VIDEO.file}">${esc(label)}</a></video><figcaption>${ui.videoNote}</figcaption></figure>`,
    ctaBlock: () => lang === 'ru'
      ? `<section class="cta" aria-labelledby="cta"><h2 id="cta">Попробуйте на своих объектах</h2><p>Покажем Эй, Helpy на демо-данных и обсудим пилот: ваши объекты, ваши подрядчики, оплата только за доказанную работу.</p><p class="actions"><a class="btn" href="${href('contact')}">${ui.demo}</a> <a class="btn ghost" href="${APP_URL}">${ui.login}</a></p></section>`
      : `<section class="cta" aria-labelledby="cta"><h2 id="cta">Try it at your sites</h2><p>We will show Hey Helpy on demo data and discuss a pilot: your sites, your contractors, payment only for proven work.</p><p class="actions"><a class="btn" href="${href('contact')}">${ui.demo}</a> <a class="btn ghost" href="${APP_URL}">${ui.login}</a></p></section>`,
    contact: () => contactBlock(lang),
  };
}

function contactBlock(lang) {
  const t = lang === 'ru'
    ? { name: 'Имя', company: 'Компания', msg: 'Объекты и задача', send: 'Написать письмо', subject: 'Демо / пилот Эй, Helpy', or: 'Или напишите напрямую:', tg: 'Telegram:', soon: 'Адрес для запросов демо и пилота появится здесь в ближайшие дни.', hint: 'Кнопка откроет вашу почтовую программу с готовым письмом — сайт ничего не отправляет сам.' }
    : { name: 'Name', company: 'Company', msg: 'Sites and task', send: 'Write an e-mail', subject: 'Hey Helpy demo / pilot', or: 'Or write directly:', tg: 'Telegram:', soon: 'The contact address for demo and pilot requests will appear here shortly.', hint: 'The button opens your e-mail program with a pre-filled message — the website sends nothing itself.' };
  if (!CONTACT.email && !CONTACT.telegram) {
    // TODO (владелец): контакты — tools/site/config.mjs → CONTACT, затем node tools/site/build.mjs
    return `<div class="notice"><p>${t.soon}</p></div>\n<!-- TODO: контакты владельца — tools/site/config.mjs (CONTACT) -->`;
  }
  let html = '';
  if (CONTACT.email) {
    const mail = esc(CONTACT.email);
    html += `<form class="form" action="mailto:${mail}?subject=${encodeURIComponent(t.subject)}" method="post" enctype="text/plain">
  <label>${t.name}<input name="name" autocomplete="name"></label>
  <label>${t.company}<input name="company" autocomplete="organization"></label>
  <label>${t.msg}<textarea name="message"></textarea></label>
  <button class="btn" type="submit">${t.send}</button>
  <p class="note">${t.hint}</p>
</form>
<p>${t.or} <a href="mailto:${mail}">${mail}</a></p>`;
  }
  if (CONTACT.telegram) html += `<p>${t.tg} <a href="https://t.me/${esc(CONTACT.telegram)}">@${esc(CONTACT.telegram)}</a></p>`;
  return html;
}

function org(lang) {
  const o = {
    '@type': 'Organization',
    '@id': abs('#organization'),
    name: BRAND[lang],
    alternateName: BRAND[lang === 'ru' ? 'en' : 'ru'],
    url: SITE_URL,
    logo: { '@type': 'ImageObject', url: abs('img/icon-512.png'), width: 512, height: 512 },
  };
  if (CONTACT.email) o.contactPoint = { '@type': 'ContactPoint', contactType: 'sales', email: CONTACT.email, availableLanguage: ['ru', 'en'] };
  return o;
}

function softwareApp(lang) {
  const isRu = lang === 'ru';
  return {
    '@type': 'SoftwareApplication',
    '@id': abs('#software'),
    name: BRAND[lang],
    alternateName: BRAND[isRu ? 'en' : 'ru'],
    url: abs(LANGS[lang].pages.home.slug),
    description: LANGS[lang].llmsIntro,
    applicationCategory: 'BusinessApplication',
    applicationSubCategory: isRu
      ? 'SaaS для эксплуатации недвижимости: CMMS, facility management'
      : 'SaaS for property maintenance: CMMS, facility management',
    operatingSystem: 'Web, Android',
    inLanguage: ['ru', 'en'],
    featureList: isRu
      ? ['Заявки голосом (YandexGPT)', 'Распознавание оборудования по фото', 'Заявки и уведомления в Telegram, гости по QR-коду', 'Автоназначение подрядчика по системе и объекту', 'Фото «после» только живой камерой со штампом', 'Отметка визита по геозоне', 'Акт подрядчику: к оплате только доказанная работа', 'Разделение обязанностей на уровне базы данных', 'Работа без интернета (Android)', 'Плановое ТО', 'Планы этажей и реестр оборудования', 'Отчёты PDF и Excel', 'Регионы и зоны доступа']
      : ['Voice work orders (YandexGPT)', 'Equipment recognition from photos', 'Work orders and notifications in Telegram, guests via QR code', 'Automatic contractor assignment by system and site', 'Live-camera-only “after” photos with a stamp', 'Geofenced visit check-in', 'Contractor act: only proven work is payable', 'Segregation of duties enforced by the database', 'Offline work (Android)', 'Preventive maintenance', 'Floor plans and asset register', 'PDF and Excel reports', 'Regions and access zones'],
    screenshot: ['voice', 'camera', 'act'].map((n) => abs(`img/${n}.webp`)),
    offers: {
      '@type': 'Offer',
      url: abs(LANGS[lang].pages.contact.slug),
      description: isRu ? 'Цена по запросу; доступен пилот' : 'Pricing on request; pilot available',
    },
    publisher: { '@id': abs('#organization') },
  };
}

function videoObject(lang) {
  return {
    '@type': 'VideoObject',
    name: lang === 'ru' ? 'Демо «Эй, Helpy» за две минуты' : 'Hey Helpy two-minute demo',
    description: lang === 'ru'
      ? 'Сквозная история одной поломки: голосовая заявка, ИИ разбирает её, камера-помощник узнаёт оборудование, фото «после» и акт подрядчику, в котором к оплате только доказанная работа.'
      : 'The full story of one fault: a voice work order parsed by AI, the camera assistant recognising the equipment, the “after” photo and a contractor act where only proven work is payable. Video in Russian.',
    thumbnailUrl: abs(VIDEO.poster),
    uploadDate: VIDEO.uploadDate,
    duration: VIDEO.duration,
    contentUrl: abs(VIDEO.file),
    inLanguage: 'ru',
    publisher: { '@id': abs('#organization') },
  };
}

function jsonLd(lang, key, page) {
  const { pages, ui } = LANGS[lang];
  const graph = [org(lang)];
  const url = abs(page.slug);
  graph.push({
    '@type': 'WebPage', '@id': url, url, name: page.title, description: page.description,
    inLanguage: lang, dateModified: UPDATED, isPartOf: { '@id': abs('#website') },
  });
  if (key === 'home') {
    graph.push({ '@type': 'WebSite', '@id': abs('#website'), url: SITE_URL, name: BRAND[lang], inLanguage: ['ru', 'en'], publisher: { '@id': abs('#organization') } });
    graph.push(softwareApp(lang), videoObject(lang));
  } else {
    graph.push({
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: ui.home, item: abs(pages.home.slug) },
        { '@type': 'ListItem', position: 2, name: page.h1, item: url },
      ],
    });
  }
  if (key === 'features') graph.push(softwareApp(lang));
  if (page.faq) {
    graph.push({
      '@type': 'FAQPage',
      mainEntity: page.faq.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })),
    });
  }
  return { '@context': 'https://schema.org', '@graph': graph };
}

function header(lang, key, h) {
  const { ui, pages } = LANGS[lang];
  const other = lang === 'ru' ? 'en' : 'ru';
  const otherHref = h.rel + LANGS[other].pages[key].slug || './';
  const navItems = NAV.map((k) => `<li><a href="${h.rel + pages[k].slug}"${k === key ? ' aria-current="page"' : ''}>${pages[k].nav}</a></li>`).join('');
  return `<a class="skip" href="#main">${ui.skip}</a>
<header class="top"><div class="wrap">
<a class="logo" href="${h.rel + pages.home.slug || './'}"${key === 'home' ? ' aria-current="page"' : ''}>${LOGO}<span>${BRAND[lang]}</span></a>
<nav aria-label="${lang === 'ru' ? 'Основное меню' : 'Main menu'}"><ul class="nav-d">${navItems}</ul></nav>
<a class="lang" href="${otherHref}" hreflang="${other}" lang="${other}" title="${LANGS[lang].ui.otherLang}">${ui.otherLangShort}</a>
<a class="btn ghost small" href="${APP_URL}">${ui.login}</a>
<details class="menu"><summary>${ui.menu}</summary><ul>${navItems}<li><a href="${APP_URL}">${ui.login}</a></li></ul></details>
</div></header>`;
}

function footer(lang, h) {
  const { ui, pages } = LANGS[lang];
  const links = [...NAV, 'privacy'].map((k) => `<li><a href="${h.rel + pages[k].slug}">${pages[k].nav}</a></li>`).join('');
  return `<footer class="foot"><div class="wrap">
<ul>${links}<li><a href="${APP_URL}">${ui.login}</a></li><li><a href="${h.rel}llms.txt">${ui.footerAi}: llms.txt</a></li></ul>
<p>${ui.footerNote}</p>
<p>© 2026 ${BRAND[lang]}</p>
</div></footer>`;
}

function head({ lang, title, description, canonical, alternates, rel, ld, noindex = false, ogImage }) {
  const alt = alternates
    ? Object.entries(alternates).map(([l, u]) => `<link rel="alternate" hreflang="${l}" href="${u}">`).join('\n')
    : '';
  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
${noindex ? '<meta name="robots" content="noindex">' : '<meta name="robots" content="index, follow, max-image-preview:large">'}
${canonical ? `<link rel="canonical" href="${canonical}">` : ''}
${alt}
<meta property="og:type" content="website">
<meta property="og:site_name" content="${BRAND[lang]}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
${canonical ? `<meta property="og:url" content="${canonical}">` : ''}
<meta property="og:image" content="${ogImage}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="${BRAND[lang]}">
<meta property="og:locale" content="${LANGS[lang].ui.locale}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(description)}">
<meta name="twitter:image" content="${ogImage}">
<meta name="theme-color" content="#2DB89A">
<link rel="icon" href="${rel}favicon.png" type="image/png">
<link rel="apple-touch-icon" href="${rel}img/icon-192.png">
<link rel="manifest" href="${rel}site.webmanifest">
<link rel="preload" href="${rel}fonts/onest-400.woff2" as="font" type="font/woff2" crossorigin>
<style>${css(rel)}</style>
${ld ? `<script type="application/ld+json">\n${json(ld)}\n</script>` : ''}
</head>`;
}

function renderPage(lang, key) {
  const { pages, ui } = LANGS[lang];
  const page = pages[key];
  const h = helpers(lang, page.slug);
  const alternates = { ru: abs(ru.pages[key].slug), en: abs(en.pages[key].slug), 'x-default': abs(ru.pages[key].slug) };
  const crumbs = key === 'home' ? '' : `<nav class="crumbs" aria-label="${lang === 'ru' ? 'Навигационная цепочка' : 'Breadcrumb'}"><ol><li><a href="${h.rel + pages.home.slug || './'}">${ui.home}</a></li><li aria-current="page">${page.h1}</li></ol></nav>\n`;
  return `${head({
    lang, title: page.title, description: page.description, canonical: abs(page.slug), alternates,
    rel: h.rel, ld: jsonLd(lang, key, page), ogImage: abs(`img/og-${lang}.png`),
  })}
<body>
${header(lang, key, h)}
<main id="main"><div class="wrap">
${crumbs}${page.body(h, page).trim()}
</div></main>
${footer(lang, h)}
</body>
</html>
`;
}

/** 404 отдаётся по любому адресу — поэтому все ссылки абсолютные. */
function render404() {
  const h = { rel: SITE_URL };
  return `${head({
    lang: 'ru', title: `${ru.notFound.title}`, description: ru.notFound.text, rel: SITE_URL,
    noindex: true, ogImage: abs('img/og-ru.png'),
  })}
<body>
${header('ru', 'home', h).replace(' aria-current="page"', '')}
<main id="main"><div class="wrap err">
<h1>${ru.notFound.h1} · <span lang="en">${en.notFound.h1}</span></h1>
<p>${ru.notFound.text} <span lang="en">${en.notFound.text}</span></p>
<p class="actions" style="justify-content:center"><a class="btn" href="${SITE_URL}">Главная</a> <a class="btn ghost" href="${abs('en/')}" lang="en">Home (English)</a></p>
</div></main>
${footer('ru', h)}
</body>
</html>
`;
}

// ---------- Текстовые версии для ИИ ----------

/** HTML → простой Markdown для llms-full.txt (только наши шаблоны, не общий парсер). */
export function htmlToText(html) {
  return html
    .replace(/<nav class="toc"[\s\S]*?<\/nav>/g, '')
    .replace(/<figure class="video">[\s\S]*?<\/figure>/g, '')
    .replace(/<figcaption>([\s\S]*?)<\/figcaption>/g, '\n_$1_\n')
    .replace(/<img [^>]*alt="([^"]*)"[^>]*>/g, (_, a) => `\n[${lang_img}: ${a}]\n`)
    .replace(/<h1[^>]*>([\s\S]*?)<\/h1>/g, '\n## $1\n')
    .replace(/<h2[^>]*>([\s\S]*?)<\/h2>/g, '\n### $1\n')
    .replace(/<h3[^>]*>([\s\S]*?)<\/h3>/g, '\n#### $1\n')
    .replace(/<tr>([\s\S]*?)<\/tr>/g, (_, r) => `\n| ${r.replace(/<\/t[hd]>\s*<t[hd][^>]*>/g, ' | ').replace(/<[^>]+>/g, '').trim()} |`)
    .replace(/<caption>([\s\S]*?)<\/caption>/g, '\n$1\n')
    .replace(/<li[^>]*>/g, '\n- ')
    .replace(/<\/p>|<\/li>|<\/section>|<\/article>/g, '\n')
    .replace(/<strong>([\s\S]*?)<\/strong>/g, '**$1**')
    .replace(/<a [^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/g, '$2')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/[ \t]+\n/g, '\n').replace(/\n[ \t]+/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
}
let lang_img = 'Кадр';

function llmsTxt() {
  const L = (lang, key) => `- [${LANGS[lang].pages[key].h1}](${abs(LANGS[lang].pages[key].slug)}): ${LANGS[lang].pages[key].description}`;
  return `# Эй, Helpy (Hey Helpy)

> ${ru.llmsIntro}
>
> ${en.llmsIntro}

Полное описание продукта одним файлом (RU и EN): ${abs('llms-full.txt')}
Full product description in one file (RU and EN): ${abs('llms-full.txt')}
Вход в приложение / App sign-in: ${APP_URL}

## Страницы (русский)

${KEYS.map((k) => L('ru', k)).join('\n')}

## Pages (English)

${KEYS.map((k) => L('en', k)).join('\n')}

## Факты / Facts

- Категория / Category: CMMS, facility management, контроль подрядчиков / contractor control (SaaS)
- Платформы / Platforms: веб (браузер) и Android / web (browser) and Android; iPhone app — нет / not available
- Языки интерфейса / UI languages: русский, English
- ИИ / AI: YandexGPT (разбор заявки / work order parsing), мультимодальная модель Yandex AI Studio (распознавание оборудования по фото / equipment recognition)
- Данные / Data: PostgreSQL (Supabase), ЕС / EU; размещение в РФ (Yandex Cloud) — в планах / hosting in Russia planned
- Цена / Pricing: по запросу, пилот / on request, pilot
- Стадия / Stage: MVP (октябрь 2026 / October 2026)
- Отзывов, рейтингов и публичных клиентов на сайте нет / No reviews, ratings or public customer references are published

## Optional

- [Политика конфиденциальности сайта](${abs(ru.pages.privacy.slug)})
- [Website privacy policy](${abs(en.pages.privacy.slug)})
`;
}

function llmsFullTxt() {
  const part = (lang) => {
    lang_img = lang === 'ru' ? 'Кадр' : 'Screenshot';
    return KEYS.filter((k) => k !== 'privacy').map((k) => {
      const p = LANGS[lang].pages[k];
      const h = helpers(lang, p.slug);
      return `URL: ${abs(p.slug)}\n${htmlToText(p.body(h, p).replace(/<section class="cta"[\s\S]*?<\/section>/g, ''))}`;
    }).join('\n\n---\n\n');
  };
  return `# Эй, Helpy (Hey Helpy) — полное описание / full description

Обновлено / Updated: ${UPDATED}. Источник / Source: ${SITE_URL}
Вход в приложение / App: ${APP_URL}

# Русский

${ru.llmsIntro}

${part('ru')}

# English

${en.llmsIntro}

${part('en')}
`;
}

function robotsTxt() {
  return `# ${BRAND.ru} / ${BRAND.en}: сайт открыт для поисковиков и ИИ-ассистентов.
# The site is open to search engines and AI assistants.
${BOTS.map((b) => `\nUser-agent: ${b}\nAllow: /`).join('\n')}

User-agent: *
Allow: /

Sitemap: ${abs('sitemap.xml')}
`;
}

function sitemapXml() {
  const urls = KEYS.flatMap((k) => ['ru', 'en'].map((lang) => {
    const alt = ['ru', 'en'].map((l) => `    <xhtml:link rel="alternate" hreflang="${l}" href="${abs(LANGS[l].pages[k].slug)}"/>`).join('\n');
    return `  <url>
    <loc>${abs(LANGS[lang].pages[k].slug)}</loc>
    <lastmod>${UPDATED}</lastmod>
${alt}
    <xhtml:link rel="alternate" hreflang="x-default" href="${abs(ru.pages[k].slug)}"/>
  </url>`;
  }));
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${urls.join('\n')}
</urlset>
`;
}

const manifest = () => json({
  name: BRAND.ru, short_name: BRAND.ru, lang: 'ru', start_url: './', display: 'browser',
  background_color: '#F2F4F3', theme_color: '#2DB89A',
  icons: [
    { src: 'img/icon-192.png', sizes: '192x192', type: 'image/png' },
    { src: 'img/icon-512.png', sizes: '512x512', type: 'image/png' },
  ],
}) + '\n';

const humansTxt = () => `/* TEAM */
Product: ${BRAND.ru} / ${BRAND.en}
Built with: Claude Code

/* SITE */
Last update: ${UPDATED}
Language: Русский, English
Standards: HTML5, CSS3, Schema.org JSON-LD
Software: Node.js (static generator, tools/site/build.mjs)
`;

// ---------- Запись ----------

function write(rel, text) {
  const f = join(siteDir, rel);
  mkdirSync(dirname(f), { recursive: true });
  writeFileSync(f, text);
}

export function build() {
  for (const lang of ['ru', 'en']) for (const k of KEYS) write(`${LANGS[lang].pages[k].slug}index.html`, renderPage(lang, k));
  write('404.html', render404());
  write('robots.txt', robotsTxt());
  write('sitemap.xml', sitemapXml());
  write('llms.txt', llmsTxt());
  write('llms-full.txt', llmsFullTxt());
  write('site.webmanifest', manifest());
  write('humans.txt', humansTxt());
}

/** Готовый к публикации сайт: site/ + картинки + значки + видео. */
export function assemble(out) {
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });
  cpSync(siteDir, out, { recursive: true, filter: (src) => !src.endsWith('/CNAME') });
  mkdirSync(join(out, 'img'), { recursive: true });
  for (const f of readdirSync(join(root, 'assets/site'))) {
    if (/\.(webp|png)$/.test(f)) copyFileSync(join(root, 'assets/site', f), join(out, 'img', f));
  }
  copyFileSync(join(root, 'web/icons/Icon-192.png'), join(out, 'img/icon-192.png'));
  copyFileSync(join(root, 'web/icons/Icon-512.png'), join(out, 'img/icon-512.png'));
  copyFileSync(join(root, 'web/favicon.png'), join(out, 'favicon.png'));
  mkdirSync(join(out, 'media'), { recursive: true });
  copyFileSync(join(root, VIDEO.src), join(out, VIDEO.file));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  build();
  const i = process.argv.indexOf('--out');
  if (i > 0) {
    const out = process.argv[i + 1];
    if (!out) throw new Error('--out: нужен путь');
    assemble(out);
    for (const lang of ['ru', 'en']) {
      if (!existsSync(join(out, `img/og-${lang}.png`))) console.warn(`⚠️ нет img/og-${lang}.png — node tools/site/og.mjs`);
    }
    console.log('сайт собран:', out);
  }
  if (!CONTACT.email && !CONTACT.telegram) console.warn('⚠️ контакты не заполнены (tools/site/config.mjs → CONTACT) — на странице «Контакты» заглушка');
  console.log('site/ обновлён, адрес:', SITE_URL);
}
