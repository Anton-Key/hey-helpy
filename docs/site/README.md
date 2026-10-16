# Сайт продукта «Эй, Helpy»

Отдельно от приложения: статический HTML + CSS, **без JavaScript** (меню на телефоне — элемент `<details>`), RU по умолчанию, EN — `/en/`. Поисковики и ИИ-боты видят весь текст без выполнения скриптов.

- Сейчас: **https://anton-key.github.io/hey-helpy/site/** (рядом с приложением https://anton-key.github.io/hey-helpy/).
- Оценка готовности для поисковиков и ИИ-агентов — [`ai-readiness-2026-10-16.md`](ai-readiness-2026-10-16.md).

## Страницы

| Адрес (RU / EN) | Что |
|---|---|
| `/` · `/en/` | Главная: одна фраза о продукте, проблема, как работает, главное с кадрами, демо-видео, для кого, «Запросить демо» |
| `features/` | Возможности: голос, фото и «Камера-помощник», Telegram, оплата по доказательству, роли, без интернета, плановое ТО, планы этажей, документы, отчёты, зоны доступа |
| `industries/` | Для кого: БЦ и ТЦ, сети и ритейл, УК и FM, госзаказчики |
| `security/` | Безопасность и развёртывание (только то, что есть; планы помечены «в планах») |
| `faq/` | 11 вопросов (разметка FAQPage) |
| `contact/` | Запросить демо / пилот — кнопка открывает Telegram-бота `https://t.me/HeyHelpy_bot?start=demo` (все кнопки «Запросить демо» ведут туда же) |
| `privacy/` | Политика конфиденциальности сайта |
| `404.html` | Своя страница «не найдено» (RU + EN, `noindex`) |
| `robots.txt`, `sitemap.xml`, `llms.txt`, `llms-full.txt`, `humans.txt`, `site.webmanifest` | Для поисковиков и ИИ |

## Как устроено

```
tools/site/
  config.mjs        адрес сайта (SITE_URL), вход в приложение, контакт (CONTACT — Telegram-бот), дата обновления
  content.ru.mjs    все тексты RU      content.en.mjs  все тексты EN
  site.css          стиль (встраивается в каждую страницу)
  build.mjs         генератор: site/*.html, robots, sitemap, llms*.txt;  --out DIR — готовый сайт с картинками
  check.mjs         проверка собранного сайта (её же делает «PR check»)
  serve.mjs         локальный просмотр
  images.mjs        кадры docs/screens/pitch → WebP в assets/site/ (разово, нужен ffmpeg)
  og.mjs            картинки для соцсетей 1200×630 → assets/site/og-ru.png, og-en.png (Playwright)
  fonts.mjs         Onest 400 / 600 → WOFF2 в site/fonts/ (разово, npm install в tools/site)
site/               сгенерированный HTML и служебные файлы — руками не править
assets/site/        картинки сайта (хук block_secrets пропускает картинки только из assets/, docs/screens/…)
```

Демо-видео берётся из `docs/demo/hey-helpy-demo-v2.mp4`, значки — из `web/icons/`; в `site/` они не копируются, только при сборке (`--out`).

**Поправить текст:** `tools/site/content.ru.mjs` / `content.en.mjs` → `node tools/site/build.mjs` → закоммитить `site/`. «PR check» остановится, если `site/` не пересобран или проверка не прошла.

**Посмотреть у себя:**
```bash
node tools/site/build.mjs --out build/site && node tools/site/check.mjs build/site
node tools/site/serve.mjs build/site 8090   # http://localhost:8090/
```

## Публикация сейчас (GitHub Pages, подпапка)

GitHub Pages при каждой выкладке **заменяет сайт целиком**. Поэтому приложение и сайт выкладываются **одной** выкладкой: «Deploy web» после сборки Flutter собирает сайт в `build/web/site/`. Отдельная выкладка только сайта стёрла бы приложение (и наоборот).

- При каждом слиянии в `main` «Deploy web» выкладывает приложение **и** сайт (если включена переменная `WEB_PUBLISH_ENABLED = true`, см. `CLAUDE.md`, «Веб-ссылка»).
- Обновить без нового коммита: GitHub → Actions → **Deploy site** → Run workflow (ветка `main`). Это тот же «Deploy web».
- Несуществующий адрес внутри `/hey-helpy/site/` ведёт на 404 сайта, а не на приложение.

⚠️ **Ограничение подпапки.** `robots.txt`, `llms.txt` и `sitemap.xml` поисковики и ИИ-боты ищут **только в корне домена** (`https://anton-key.github.io/robots.txt`), а корень `anton-key.github.io` — это другой репозиторий. Пока сайт в подпапке, эти файлы лежат «не там»: боты пускаются по умолчанию (запрета нет), страницы найдутся по ссылкам, но правила из нашего `robots.txt` и `llms.txt` боты не прочитают. Полноценно — только на своём домене.

## Свой домен (рекомендуется)

### Вариант A — Cloudflare Pages из этого же репозитория (проще всего, бесплатно)
Сайт будет в **корне** своего домена, приложение останется где было.
1. Купить домен (например, у reg.ru, Cloudflare Registrar, Namecheap). Название — на ваш выбор.
2. Cloudflare → Workers & Pages → Create → Pages → **Connect to Git** → репозиторий `hey-helpy`, ветка `main`.
3. Настройки сборки: Framework — None; Build command — `node tools/site/build.mjs --out dist`; Build output directory — `dist`; переменная окружения `SITE_URL` = `https://ваш-домен/` (со слэшем в конце).
4. Custom domains → добавить домен (и `www`). Если домен куплен не в Cloudflare — перенести DNS в Cloudflare или прописать CNAME, как подскажет мастер. HTTPS включится сам.
5. Сказать Claude Code: «домен такой-то» — он поменяет `SITE_URL` в `tools/site/config.mjs`, пересоберёт `site/` и сделает PR (после этого canonical, sitemap и hreflang в git совпадут с доменом).

### Вариант B — отдельный репозиторий `hey-helpy-site` на GitHub Pages
Если хочется остаться на GitHub: создать **вами** публичный репозиторий `hey-helpy-site`, копировать туда собранный сайт (`node tools/site/build.mjs --out …`), в Settings → Pages включить публикацию, указать Custom domain (файл `CNAME` с доменом — шаблон `site/CNAME`), у регистратора — записи:
- `A` для корня: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`;
- `AAAA` для корня: `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`;
- `CNAME` для `www` → `anton-key.github.io`.
Затем Settings → Pages → **Enforce HTTPS**. Репозиторий Claude Code сам не создаёт.

> Почему не «свой домен на этом репозитории»: тогда в корне домена окажется **приложение** (Flutter), а не сайт, и `robots.txt` / `llms.txt` пришлось бы класть в сборку приложения.

`site/CNAME` — шаблон с `www.example.com`: в выкладку в подпапку он не попадает; при варианте B вписать в него свой домен.

### После переезда — поисковики
1. **Google Search Console** (search.google.com/search-console) → Добавить ресурс → «Домен» → подтвердить TXT-записью у регистратора / в Cloudflare → Файлы Sitemap → `https://ваш-домен/sitemap.xml`.
2. **Яндекс Вебмастер** (webmaster.yandex.ru) → Добавить сайт → подтвердить (DNS / мета-тег / файл — для мета-тега и файла попросите Claude Code добавить их в генератор) → Индексирование → Файлы Sitemap → тот же адрес.
3. **Bing Webmaster Tools** — можно импортировать из Search Console одной кнопкой.
4. Проверить разметку: **Rich Results Test** (search.google.com/test/rich-results) и **Schema Markup Validator** (validator.schema.org) — вставить адрес главной и `faq/`. Ожидаемо: Organization, WebSite, SoftwareApplication, VideoObject, FAQPage, BreadcrumbList — без ошибок. ⚠️ Расширенный сниппет «приложение со звёздами» Google показывает только при рейтинге или отзывах — их нет и выдумывать нельзя, поэтому предупреждение «нет aggregateRating / review» — нормально.
5. Проверить Core Web Vitals: **PageSpeed Insights** (pagespeed.web.dev) → адрес главной → вкладка «Мобильные».

## Проверить доступ ботов (после выкладки)

```bash
URL=https://anton-key.github.io/hey-helpy/site/
for ua in GPTBot OAI-SearchBot ChatGPT-User ClaudeBot Claude-User Claude-SearchBot PerplexityBot Perplexity-User \
          Google-Extended Applebot-Extended YandexBot YandexAdditional bingbot Googlebot; do
  printf '%-18s ' "$ua"; curl -s -o /dev/null -w '%{http_code} %{content_type} %{size_download}\n' -A "Mozilla/5.0 (compatible; $ua)" "$URL"
done
curl -s "${URL}robots.txt" | head; curl -s "${URL}llms.txt" | head -5
```
Ожидаемо: у всех `200 text/html`, размер одинаковый (сайт никого не блокирует и не отдаёт ботам другое).

## Заявки на демо (Telegram-бот)

Кнопка «Запросить демо» → `https://t.me/HeyHelpy_bot?start=demo` → бот просит одно сообщение и сохраняет его в `sales.site_leads` (миграция 0026). E-mail и телефон на сайте не публикуются.

- **Посмотреть заявки:** Supabase → Table Editor → схема `sales` → `site_leads` (или SQL Editor: `select created_at, tg_username, tg_name, language, text, status from sales.site_leads order by created_at desc;`). Отметить: `update sales.site_leads set status = 'contacted' where id = '…';` (потом `closed`).
- **Получать заявки в Telegram сразу** (необязательно): секрет `TELEGRAM_LEADS_CHAT_ID` = номер вашего чата с ботом.
  Как узнать номер, не показывая никому токен бота: после применения 0026 откройте ссылку «Запросить демо» сами, отправьте боту «проверка» → Supabase → Table Editor → `sales.site_leads` → столбец `chat_id` вашей строки (это и есть номер; у личного чата он положительный). Затем Supabase → Edge Functions → **Secrets** → Add new secret: имя `TELEGRAM_LEADS_CHAT_ID`, значение — это число → Save. Функция подхватит секрет при следующем запуске; если заявки не приходят — Actions → Deploy functions. Тестовую строку можно удалить: `delete from sales.site_leads where text = 'проверка';`
- Лимиты: 3 заявки в сутки с одного чата, 300 в сутки всего.
