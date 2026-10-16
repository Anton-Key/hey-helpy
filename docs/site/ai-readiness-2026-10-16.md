# Готовность сайта «Эй, Helpy» для поисковиков и ИИ-агентов — 16 октября 2026

Сайт: `site/` (генератор `tools/site/`), адрес после слияния PR — **https://anton-key.github.io/hey-helpy/site/**. Оценивал Claude Code на локальной сборке (`node tools/site/build.mjs --out build/site`, сервер `tools/site/serve.mjs` с gzip, как у GitHub Pages) и по опубликованному `anton-key.github.io`.

## Итог: **85 из 100**, после своего домена — **≈ 97**

> Обновлено 16.10 (вечер): контакт — Telegram-бот `?start=demo` на всех кнопках «Запросить демо» и в JSON-LD (`contactPoint`, `sameAs`): доверие 3 → 5.

| Раздел | Баллы | Чего не хватает |
|---|---|---|
| Доступ ботов | **20 / 30** | `robots.txt` и `llms.txt` лежат в подпапке, боты их там не ищут (нужен свой домен) |
| Техника | **33 / 35** | Срок кэша задаёт GitHub Pages (10 мин); замеры только лабораторные (полевых данных пока нет) |
| Структура и разметка | **32 / 35** | Нет юридического названия, страницы «О компании» и внешних профилей компании (доверие, E-E-A-T) |

## 1. Доступ ботов — 20 / 30

| Что | Баллы | Как проверено |
|---|---|---|
| Сайт отвечает всем ботам одинаково, без блокировок | 10 / 10 | `curl -A` под 14 ботами (GPTBot, OAI-SearchBot, ChatGPT-User, ClaudeBot, Claude-User, Claude-SearchBot, PerplexityBot, Perplexity-User, Google-Extended, Applebot-Extended, YandexBot, YandexAdditional, bingbot, Googlebot): у всех `200 text/html` и одинаковый ответ. GitHub Pages по User-Agent не фильтрует |
| `robots.txt` явно разрешает всех 14 ботов, нет `Disallow: /`, есть `Sitemap:` | 3 / 8 | Файл правильный (проверяет `tools/site/check.mjs`), но действует **только в корне домена**. Сейчас корень — `anton-key.github.io/robots.txt` → **404** (другой репозиторий). Запретов нет — боты пускаются по умолчанию, но наш файл они не прочитают |
| `llms.txt` и `llms-full.txt` (RU + EN, формат llmstxt.org) | 2 / 7 | Есть и проходят проверку, но ИИ-агенты ищут `/llms.txt` в корне домена; сейчас найдут только по ссылке «llms.txt» в подвале каждой страницы |
| Нет `noindex` и `X-Robots-Tag` | 5 / 5 | `noindex` только на 404 (так и нужно). Заголовков `X-Robots-Tag` GitHub Pages не ставит |

## 2. Техника — 33 / 35

**Lighthouse 12, мобильный профиль** (Moto G Power, «медленный 4G», замедление процессора ×4), локально с gzip:

| Страница | Производительность | Доступность | Практики | SEO | LCP | CLS | TBT | FCP |
|---|---|---|---|---|---|---|---|---|
| Главная RU `/` | **100** | **100** | **100** | **100** | 1,6 с | 0 | 0 мс | 0,9 с |
| Главная EN `/en/` | **100** | **100** | **100** | **100** | 1,6 с | 0 | 0 мс | 0,9 с |

INP: JavaScript на сайте нет вообще (меню на телефоне — `<details>`), обработчиков ввода нет — задержке взаимодействия неоткуда взяться (TBT = 0).

| Что | Баллы | Как проверено |
|---|---|---|
| Core Web Vitals (LCP < 2,5 с, CLS < 0,1, INP < 200 мс) | 9 / 10 | Лабораторные: LCP 1,6 с, CLS 0, TBT 0. −1: полевых данных (CrUX) у нового сайта нет — смотреть в PageSpeed Insights через 4–6 недель после запуска |
| Lighthouse ≥ 90 по всем четырём категориям | 8 / 8 | 100 / 100 / 100 / 100 на обеих главных |
| Весь текст виден без JavaScript | 7 / 7 | Playwright с выключенным JS: ключевые фразы на месте на `/`, `features/`, `faq/`, `en/`, `en/faq/`, `en/security/`; `check.mjs` — ни одного исполняемого `<script>` (только JSON-LD) |
| `sitemap.xml` с `lastmod` и `hreflang` | 3 / 3 | 14 адресов (7 × RU / EN), у каждого `lastmod` и `xhtml:link` ru / en / x-default |
| `rel=canonical`, `hreflang` RU / EN / x-default | 3 / 3 | На всех 14 страницах, абсолютные адреса |
| Своя 404, нет битых ссылок, валидный HTML | 2 / 2 | `check.mjs`: все ссылки, картинки, видео и якоря ведут на существующее; `html-validate` (набор recommended) — 0 ошибок на 15 страницах; адрес внутри `/hey-helpy/site/`, которого нет, → 404 сайта |
| HTTPS, кэш | 1 / 2 | HTTPS — да (GitHub Pages). −1: `cache-control: max-age=600` задаёт GitHub, изменить нельзя (на Cloudflare Pages — можно) |

Вес главной: HTML 26 КБ (≈ 8 КБ gzip, стиль встроен), шрифт Onest — 2 начертания по 17–18 КБ (WOFF2, только латиница + кириллица, `font-display: swap`, предзагрузка), первая картинка 31 КБ WebP; остальные картинки — `loading="lazy"`, видео — `preload="none"` с постером 13 КБ.

## 3. Структура и разметка — 32 / 35

| Что | Баллы | Как проверено |
|---|---|---|
| Один `h1`, `h2` / `h3` без пропусков, семантика (`header`, `nav`, `main`, `section`, `article`, `footer`, `figure`, таблицы с `caption` и `th scope`), «хлебные крошки» | 8 / 8 | `check.mjs` (один h1, без пропусков уровней) на всех 15 страницах; Lighthouse «Доступность» 100 |
| JSON-LD: `Organization`, `WebSite`, `WebPage`, `SoftwareApplication` (BusinessApplication, «SaaS для эксплуатации недвижимости: CMMS, facility management», Web + Android, `offers` — «цена по запросу; доступен пилот»), `FAQPage` (11 вопросов RU / EN), `BreadcrumbList`, `VideoObject` (демо 2:09, постер, дата) | 10 / 10 | `JSON.parse` на каждой странице; сверка со словарём schema.org (`schemaorg-current-https.jsonld`): все 414 свойств существуют и относятся к своим типам. Отзывов, рейтингов, клиентов и цифр нет — проверяет `check.mjs` |
| FAQ, понятный ИИ-ассистентам (вопрос → прямой ответ) | 5 / 5 | 11 вопросов, которые реально задают: связь в подвале, отличие от Excel / мессенджера, без приложения, где данные, сколько стоит… |
| Open Graph и Twitter Card | 4 / 4 | `og:title / description / url / image (1200×630) / locale`, `twitter:card = summary_large_image`; картинки RU и EN нарисованы из кадров приложения, без людей |
| Доверие (E-E-A-T): кто стоит за продуктом, как связаться | 5 / 8 | Контакт есть — Telegram-бот (`contactPoint`, `sameAs`). −3: нет юридического названия, страницы «О компании» и профилей компании (сайт, соцсети) |

## Рекомендации

| Приоритет | Что | Кто | Что изменится |
|---|---|---|---|
| **Критично** | Свой домен — сайт в корне домена (`docs/site/README.md`, вариант A — Cloudflare Pages из этого же репозитория) | Владелец покупает и подключает; Claude Code меняет `SITE_URL` | `robots.txt` и `llms.txt` заработают: доступ ботов 20 → 30 |
| **Важно** | Google Search Console и Яндекс Вебмастер, отправить `sitemap.xml` | Владелец | Быстрая индексация, отчёты о покрытии и Core Web Vitals. Google можно уже сейчас: ресурс «Префикс URL» `https://anton-key.github.io/hey-helpy/site/` с подтверждением мета-тегом (Claude Code добавит тег в генератор) |
| **Важно** | Юридическое название, страница «О компании», ссылки на профили компании (Telegram-канал, LinkedIn, vc.ru…) — когда появятся | Владелец даёт данные; Claude Code добавляет в `Organization` (`legalName`, `sameAs`) и на сайт | +3 к доверию; ИИ-ассистенты увереннее ссылаются |
| Важно | Проверить разметку в Rich Results Test и Schema Markup Validator на опубликованном адресе | Владелец (2 минуты, `docs/site/README.md`) | Подтверждение «без ошибок» от Google |
| Желательно | Адаптивные картинки (`srcset` 320 / 480 px для кадров телефона) | Claude Code | −20–40 КБ на телефоне (Lighthouse подсказка «Image delivery») |
| Желательно | Английская версия демо-ролика (подписи на английском) | Claude Code (перезапись `tools/e2e/record_demo.sh` с языком EN) | VideoObject для `/en/` на языке страницы |
| Желательно | Отдельные Markdown-версии страниц (`/features/index.md`) и ссылки на них из `llms.txt` | Claude Code | Агентам проще брать одну страницу, а не весь `llms-full.txt` |
| Желательно | IndexNow (Bing, Яндекс) — ключ-файл и пинг при выкладке, после своего домена | Claude Code | Новые страницы индексируются за часы |
| Желательно | Полевые Core Web Vitals через 4–6 недель | Владелец (PageSpeed Insights) | Подтверждение реальными пользователями |

## Что изменится после своего домена

- `robots.txt`, `llms.txt`, `llms-full.txt`, `sitemap.xml` окажутся в корне — боты и ИИ-агенты найдут их сами: **доступ ботов 20 → 30**.
- Можно подтвердить сайт в Яндекс Вебмастере (он работает с доменами, не с подпапками) и в Search Console ресурсом «Домен».
- На Cloudflare Pages — свои заголовки кэша (`_headers`), +1 в технике.
- С юр. названием и профилями компании: **≈ 97 / 100**.

## Как повторить проверку

```bash
node tools/site/build.mjs --out build/site && node tools/site/check.mjs build/site     # то же делает «PR check»
node tools/site/serve.mjs build/site 8090 &
CHROME_PATH=/opt/pw-browsers/chromium-1248/chrome-linux64/chrome npx lighthouse@12 http://localhost:8090/ \
  --chrome-flags="--headless=new --no-sandbox" --view            # мобильный профиль по умолчанию
npx html-validate@9 build/site/**/*.html                          # правило doctype-style выключить (<!doctype html> — допустимо)
```
Ответы под User-Agent ботов на опубликованном адресе — `docs/site/README.md`, «Проверить доступ ботов».
