# Шаг 29: сайт продукта «Эй, Helpy» + экран «Готовность к показу»

Ветка `step-29` от свежего `main` (шаг 28 слит — коммит `fc04bf8`). PR #27. Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

Состояние рабочей базы (со слов пользователя, 16.10): применены 0001–0025, выложены 5 функций. 0025 дописана в «Применённые миграции» `CLAUDE.md` первым коммитом (заодно у 0023 / 0024 / 0025 снята пометка «не применена»). **Новая миграция — 0026** (заявки на демо с сайта, блок 5 — добавлен по решению владельца после первой версии PR).

## Чек-лист
- [x] 1. Сайт: содержание и вёрстка (`site/`, RU `/` и EN `/en/`, 7 страниц × 2 языка, своя 404)
- [x] 2. Индексация, разметка, публикация (`robots.txt`, `sitemap.xml`, `llms.txt`, `llms-full.txt`, JSON-LD, OG, выкладка, инструкция по домену)
- [x] 4. Проверка и отчёт AI readiness — **85 / 100** (было 83 до контактов), Lighthouse мобильный **100 / 100 / 100 / 100** (RU и EN)
- [x] 3. Экран «Готовность к показу» (администратор)
- [x] 5. Контакты — Telegram-бот: кнопки «Запросить демо» → `t.me/HeyHelpy_bot?start=demo`, режим «заявка на демо» в боте, миграция 0026 `sales.site_leads`
- [x] Итог: `/check`, документация, PR готов к проверке

## Журнал
| Время | Что сделано | Коммит |
|---|---|---|
| 16.10 | Ветка, отчёт, 0025 в «Применённые» | `0e8659e` |
| 16.10 | Блок 1: генератор `tools/site/`, тексты RU / EN, стиль, картинки, шрифты; черновой PR #27 | `464bd08` |
| 16.10 | Блок 2: публикация вместе с приложением, «Deploy site», проверка сайта в «PR check», `docs/site/README.md` | `635c049` |
| 16.10 | Блок 4: Lighthouse 100 (убран сдвиг вёрстки), html-validate 0 ошибок, `ai-readiness-2026-10-16.md` | `617c5cf` |
| 16.10 | Блок 3: «Готовность к показу», проверка вебхука в `telegram-notify` | `82327eb` |
| 16.10 | `/check`, CLAUDE.md, итоговый отчёт, PR → ready | (предпоследний) |
| 16.10 вечер | Блок 5: контакт — Telegram-бот на сайте, режим «заявка на демо» в боте, миграция 0026, тесты | (последний) |

## Где остановился
Всё сделано. Дальше — шаги владельца (раздел «Что сделать вам»).

---

## Что сделано

### Блок 1. Сайт
- **Без фреймворков и без JavaScript**: статический HTML + CSS. ⚠️ **Решение: крошечный генератор на Node** (`tools/site/build.mjs`, без зависимостей) — шапка, подвал, JSON-LD, hreflang и canonical одинаковы на 15 страницах, руками так не удержать. Тексты — `tools/site/content.ru.mjs` / `content.en.mjs` (HTML-фрагменты, не Markdown — проще и без парсера). Сгенерированный HTML лежит в `site/` и коммитится; «PR check» проверяет, что он совпадает с генератором.
- Меню на телефоне — элемент `<details>` (работает без JS). На сайте нет ни одного исполняемого скрипта — весь текст виден ботам.
- Стиль продукта (вариант A): Onest 400 / 600 — только эти 2 начертания, только латиница + кириллица, WOFF2 по ~17 КБ (`tools/site/fonts.mjs`), `font-display: swap`, предзагрузка; акцент `#2DB89A`, тёмный `#0F1A17`, фон `#F2F4F3`. Стиль встроен в страницу (без отдельного запроса).
- **Страницы (RU / EN):** главная (одна фраза + «Платим подрядчику только за доказанную работу», «Сколько нужно человек, чтобы повесить один замок?» — текстом, без фото людей, как это работает в 5 шагов, главное с кадрами, демо-видео, для кого, призыв), возможности (11 разделов фактами), для кого (4 сегмента), безопасность и развёртывание, FAQ (11 вопросов), контакты, политика конфиденциальности, 404.
- Кадры: 8 из `docs/screens/pitch/` → WebP 480 / 1200 px, 23–34 КБ (`tools/site/images.mjs`): голос (04), камера (21), Telegram (28, обрезан пустой фон), фото до / после (24), акт (20), план (06), отчёт (10), ТО (13). ⚠️ Кадр 25 (без сети) не взят: на нём служебный переключатель «Сеть (тест)» и заявка «E2E-17». Подписи — «экран приложения, демо-данные».
- Видео `docs/demo/hey-helpy-demo-v2.mp4` (2:09, без звука, подписи на русском) — `preload="none"`, постер 13 КБ, без автозапуска.
- «Войти» → https://anton-key.github.io/hey-helpy/ (приложение не переносилось).
- ⚠️ **Картинки сайта — в `assets/site/`, а не в `site/`**: хук `block_secrets.sh` пропускает картинки только из `assets/`, `docs/screens/` и т. п. Хук не трогал; генератор копирует их в `img/` при сборке (`--out`). Во Flutter-сборку они не попадают (в `pubspec.yaml` подключена только `assets/demo_photos/`).
- **Контакты — Telegram-бот** (решение владельца, блок 5): все кнопки «Запросить демо» и страница «Контакты» ведут на `https://t.me/HeyHelpy_bot?start=demo`. E-mail и телефон на сайте не указываются. (В первой версии PR здесь была заглушка.)
- ⚠️ **Безопасность и развёртывание — только то, что есть**: «работает сейчас» — облако (Supabase / PostgreSQL, серверы в ЕС, ИИ — YandexGPT); «в планах» — размещение в РФ в Yandex Cloud; «обсуждается в пилоте» — выделенное облако / on-premise / изолированный контур (готовой поставки нет). Документа дорожной карты с вариантами развёртывания в репозитории нет — написал по `CLAUDE.md` и `docs/security/review-2026-10.md`. Для госзаказчиков прямо сказано: сертификации для ГИС сейчас нет.
- Названия — «Эй, Helpy» / «Hey Helpy»; кодового названия, реальных планов, фото людей, клиентов, отзывов и цифр нет (цифры только из демо-кадров с подписью «демо-данные»).

### Блок 2. Индексация, разметка, публикация
- `robots.txt` — явно `Allow: /` для 14 ботов (GPTBot, OAI-SearchBot, ChatGPT-User, ClaudeBot, Claude-User, Claude-SearchBot, PerplexityBot, Perplexity-User, Google-Extended, Applebot-Extended, YandexBot, YandexAdditional, Bingbot, Googlebot) и `*`, строка `Sitemap:`. `noindex` — только на 404.
- `sitemap.xml` — 14 адресов, `lastmod`, `hreflang` ru / en / x-default. На каждой странице `rel=canonical` и `hreflang`.
- `llms.txt` (формат llmstxt.org, RU + EN, ссылки на все страницы, короткие факты) и `llms-full.txt` (полный текст всех страниц на двух языках, собирается из тех же текстов). Плюс `humans.txt`, `site.webmanifest`, значки (из `web/icons/`).
- **JSON-LD**: на всех страницах `Organization`, `WebPage`; на главной `WebSite`, `SoftwareApplication` (BusinessApplication, «SaaS для эксплуатации недвижимости: CMMS, facility management», Web + Android, `offers` «цена по запросу; доступен пилот», `featureList`, скриншоты), `VideoObject`; на внутренних — `BreadcrumbList`; на «Возможностях» — `SoftwareApplication`; на FAQ — `FAQPage`. Проверено офлайн по словарю schema.org (все 414 свойств существуют и относятся к своим типам). Отзывов и рейтингов нет — ⚠️ поэтому Google не покажет «приложение со звёздами»; это нормально.
- Open Graph / Twitter Card + картинки 1200×630 RU и EN (`tools/site/og.mjs`, из кадров, без людей).
- **Публикация.** ⚠️ Главное: GitHub Pages при каждой выкладке **заменяет весь сайт**. Отдельный workflow для сайта стёр бы приложение. Поэтому сайт собирается **внутри «Deploy web»** в `build/web/site/` → `https://anton-key.github.io/hey-helpy/site/`. «Deploy site» (`deploy-site.yml`) — ручной запуск того же файла (через `workflow_call`). Несуществующий адрес в `/hey-helpy/site/…` ведёт на 404 сайта (в 404 приложения добавлена одна строка-переадресация только для этих адресов; для приложения ничего не меняется).
- Проверено: приложение сейчас опубликовано (`/hey-helpy/` → 200), значит после слияния PR сайт появится сам.
- ⚠️ `robots.txt` и `llms.txt` в подпапке боты не читают (корень `anton-key.github.io` → 404, другой репозиторий). Запретов нет, боты пускаются по умолчанию — но полный балл только на своём домене. Инструкция — `docs/site/README.md`: ⚠️ **рекомендую Cloudflare Pages из этого же репозитория** (сайт в корне своего домена, команда сборки `node tools/site/build.mjs --out dist`, переменная `SITE_URL`), запасной вариант — отдельный репозиторий `hey-helpy-site` (сам не создавал). `site/CNAME` — шаблон `www.example.com` (в выкладку не попадает).

### Блок 4. Проверка
| Проверка | Результат |
|---|---|
| Lighthouse 12, мобильный профиль, главная RU | **100 / 100 / 100 / 100**, LCP 1,6 с, CLS 0, TBT 0 мс, FCP 0,9 с |
| То же, главная EN | **100 / 100 / 100 / 100**, LCP 1,6 с, CLS 0, TBT 0 мс |
| Без JavaScript (Playwright, JS выключен) | ✓ текст на `/`, `features/`, `faq/`, `en/`, `en/faq/`, `en/security/` |
| User-Agent 14 ботов (локально) | у всех `200 text/html`, одинаковый ответ |
| `html-validate` (recommended) | 0 ошибок на 15 страницах (правило `doctype-style` выключено: `<!doctype html>` допустим) |
| `tools/site/check.mjs` (то же в «PR check») | ✓ один h1, уровни заголовков, title / description, canonical, hreflang, OG, JSON-LD, alt и размеры картинок, ссылки и якоря, robots, sitemap, llms. Проверено, что ловит битую ссылку, якорь и пропуск уровня |
| Телефон 412 px | без горизонтальной прокрутки, снимки глазами |

Первый замер дал 86 / 90 (CLS 0,16–0,21: место под первую картинку и полужирный шрифт появлялись позже) — исправлено (ширина у рамки картинки, предзагрузка начертания 600).

Отчёт с баллами и рекомендациями — **[`docs/site/ai-readiness-2026-10-16.md`](../site/ai-readiness-2026-10-16.md)**: **85 / 100** после блока 5 (доступ ботов 20 / 30, техника 33 / 35, структура 32 / 35); после своего домена — ≈ 97.

### Блок 3. «Готовность к показу»
Профиль → «Моя компания» → **«Готовность к показу»** (только администратор). Зелёные / жёлтые / красные / серые строки, сверху общий итог, внизу «Проверить ещё раз» (и потянуть вниз).

| Строка | Как проверяется |
|---|---|
| База отвечает | одна строка своей компании, время в мс |
| Миграции 0017–0025 | по таблице или столбцу каждой миграции под RLS (`photo_identifications`, `report_links`, `attachments.file_name`, `layers.archived_at`, `contractor_rates`, `work_orders.submitted_by`, `act_proof_decisions`, `vps_sites`); «нет таблицы / столбца» → красное с номерами. ⚠️ 0022 — закрытая схема `telegram`, её не видно; 0025 требует 0022, отдельно не проверяется |
| 5 функций | проверочные запросы с JWT: `telegram-bot` без секрета вебхука → 401, `offline-sync` пустой → 400, `telegram-notify` → проверка вебхука, `voice-intake` и `photo-identify` — настоящий разбор (ниже). Ответ 2xx / 400 / 401 / 403 / 404 — функция жива; 5xx или тишина 20 с — красное |
| Telegram-бот: вебхук | ⚠️ **Решение: проверочный режим в `telegram-notify`** — `POST {kind: "webhook"}`, только администратор (роль читается под RLS), функция сама вызывает `getWebhookInfo` и возвращает **только** `configured` (вебхук указывает на нашу `telegram-bot`), `pending`, `last_error_age_s`. Токен, адрес и текст ошибки Telegram наружу не выходят. **Заработает после «Deploy functions»**; до этого старая функция отвечает 400 → серая строка «Проверка появится после Deploy functions (шаг 29)». Логика — `health.ts`, тесты `health_test.ts` |
| Голос: ответ ИИ | настоящий вызов `voice-intake` с фразой «Эй, Хелпи, проверка связи: в переговорной жарко» — время и модель (pro / lite). Ничего не создаёт |
| По фото: ответ ИИ | настоящий вызов `photo-identify` с нарисованным `assets/demo_photos/ac_indoor.jpg`. Функция снимок не хранит, журнал 0017 пишет только приложение — проверка его не трогает |
| По фото за 24 часа | журнал 0017: число узнаваний и среднее время |
| Последний Refresh demo | ⚠️ даты прямо в базе нет — берётся самая новая демо-заявка (`…101…299`): Refresh ставит даты от дня запуска. До 2 суток — зелёное, до 7 — жёлтое, старше — красное «запустите Refresh demo». Подписано «≈ … (по датам демо-заявок)» |

⚠️ Время ответа голоса «за 24 часа» из журнала взять нельзя — журнала разборов голоса в базе нет (только логи Supabase). Вместо этого — живой замер одним вызовом (стоит копейки, ~2–8 с). Каждое «Проверить ещё раз» — по одному вызову YandexGPT и мультимодальной модели.

Пороги: ИИ ≤ 8 с — зелёное, ≤ 16 с — жёлтое (приложение ещё дождётся), дольше — красное. Вебхук: ошибка доставки за последний час или очередь > 10 — жёлтое.

Остальное приложение не менялось (только одна строка меню). RU / EN — 44 новые строки в `.arb` (дописаны в конец, остальное не тронуто).

### Блок 5. Контакты через Telegram-бота (по решению владельца)
**Сайт.** Кнопки «Запросить демо» (главная, призыв внизу каждой страницы — RU и EN) и кнопка на «Контактах» → `https://t.me/HeyHelpy_bot?start=demo`. В JSON-LD `Organization` — `contactPoint` (sales, ссылка на бота, ru / en) и `sameAs` (`https://t.me/HeyHelpy_bot`); `SoftwareApplication.offers.url` — та же ссылка. Заглушка и TODO из `tools/site/config.mjs` убраны. Политика конфиденциальности (RU / EN) переписана честно: что бот сохраняет (текст, имя и ник, язык, номер чата), зачем и кто видит. `llms.txt` и `llms-full.txt` пересобраны (строка «Запросить демо … (Telegram)»). Проверки: `check.mjs` ✓, html-validate 0 ошибок, JSON-LD — 484 свойства по словарю schema.org ✓, Lighthouse мобильный — 100 / 100 / 100 / 100 на главных RU и EN и на «Контактах». Оценка AI readiness: **83 → 85** (доверие 3 → 5).

**Бот (`telegram-bot`), остальная логика не менялась:**
- `/start demo` в личном чате → «Здравствуйте! Это Эй, Helpy. Расскажите в одном сообщении: компания, сколько объектов и в каких городах, что хотите посмотреть. Мы свяжемся с вами здесь, в Telegram.» (EN — по языку Telegram). Ни компаний, ни объектов, привязки чата не меняются. В группе `start=demo` игнорируется.
- Следующее сообщение этого чата (черновик `step: "lead"`, живёт 30 минут, как обычный черновик): текст до 2000 символов → лид → «Спасибо! Мы получили заявку и напишем вам здесь.»; голос / фото / прочее → «Напишите, пожалуйста, текстом…» (черновик остаётся); длиннее 2000 — просьба сократить; `/cancel` отменяет. После лида чат возвращается к обычному поведению (гость — к своему объекту, незнакомец — к подсказке про ссылку).
- Лимит — 3 лида в сутки с чата (и 300 в сутки всего — защита от наплыва): «Мы уже получили ваши заявки сегодня…».
- **Уведомление владельцу:** если задан необязательный секрет `TELEGRAM_LEADS_CHAT_ID`, бот присылает туда «🆕 Заявка на демо: @ник · имя» и текст (HTML экранирован; всегда на русском). Не задан — только запись в таблицу. ⚠️ Если 0026 ещё не применена, но секрет задан — заявка не теряется: уходит владельцу, человеку — «Спасибо»; без обоих — «Не получилось сохранить заявку, попробуйте позже» (черновик остаётся).
- В лог — только `type: lead` и результат (`lead_saved`, `lead_limited`, `lead_voice`…); текст, имя, ник и chat_id не пишутся (проверяет тест).
- Тесты `bot_test.ts` (8 новых, `demo: …`): незнакомец, EN, голос и длинный текст, лимит, сообщение владельцу с экранированием, без 0026 с секретом и без, гость и группа без изменений, разбор `TELEGRAM_LEADS_CHAT_ID`. Все **107** тестов Deno прошли, `deno check` чистый.

**⚠️ Кто видит лиды — решение.** Лид — это заявка **владельцу продукта**, а не данные компании-клиента, поэтому администраторы компаний в приложении (в том числе «Демо БЦ») видеть их не должны. Сделал так:
- таблица в отдельной схеме **`sales`**, которую API Supabase не отдаёт (как схема `telegram`): `sales.site_leads`;
- RLS включён, политик нет, у `anon` / `authenticated` нет прав ни на схему, ни на таблицу — из приложения не прочитать даже администратору;
- пишет только бот через `public.tg_lead_save` (service_role);
- **смотрит и меняет статус только владелец проекта Supabase**: Table Editor (схема `sales`) или SQL Editor. Отдельного экрана в приложении нет — до питча приложение не трогаем; если нужен — отдельный флаг «владелец продукта» и экран позже.
- Почему не `public`: тест изоляции требует, чтобы каждая таблица `public` принадлежала компании и имела политики, — у лидов компании нет.

**Миграция 0026** — `supabase/migrations/0026_site_leads.sql`. Зачем: хранить заявки на демо с сайта. Что меняет: новая схема `sales`, таблица `sales.site_leads`, функция `public.tg_lead_save`; существующие таблицы и функции не трогает. Повторный запуск безопасен (`if not exists`, `create or replace`; проверено: `tools/db_test/run.sh` запускает её дважды). Тесты `tools/db_test/tg_leads.sql` — 19 проверок: приложение под менеджером, администратором, исполнителем, заявителем и аноним не читают таблицу и не вызывают функцию; пустой и длинный текст; 3 лида в сутки, 4-й — отказ; другой чат — свой лимит; язык и длина ника; статусы только new / contacted / closed. Весь набор: **15 наборов, 0 ошибок** (изоляция компаний — 962 проверки).

<details><summary>Полный текст 0026</summary>

```sql
-- 0026 — заявки на демо с сайта через Telegram-бота (шаг 29).
--
-- Кнопка «Запросить демо» на сайте ведёт на https://t.me/HeyHelpy_bot?start=demo.
-- Бот просит одно сообщение (компания, объекты, города, что показать) и
-- сохраняет его как «лид» — заявку на демо ВЛАДЕЛЬЦУ продукта, а не заявку
-- компании-клиента. Поэтому:
--
-- 1) Таблица в отдельной схеме sales (через API не видна, как схема telegram):
--    sales.site_leads (id, chat_id, tg_username, tg_name, language, text,
--    created_at, status new | contacted | closed). RLS включён, политик нет,
--    у anon / authenticated прав нет — приложение (в том числе администраторы
--    компаний-клиентов) лиды не видит. Смотрит и меняет статус только
--    владелец проекта: Supabase → Table Editor (схема sales) или SQL Editor.
-- 2) public.tg_lead_save(чат, username, имя, язык, текст) — только
--    service_role (бот). Лимиты: 3 лида в сутки с одного чата, 300 в сутки
--    всего. Текст 1–2000 символов.
--
-- Повторный запуск безопасен: if not exists, create or replace, drop … if exists.
-- Других таблиц и функций не меняет.

create schema if not exists sales;
revoke all on schema sales from public, anon, authenticated;

create table if not exists sales.site_leads (
  id          uuid primary key default gen_random_uuid(),
  chat_id     bigint not null,
  tg_username text check (tg_username is null or char_length(tg_username) <= 64),
  tg_name     text check (tg_name is null or char_length(tg_name) <= 128),
  language    text not null default 'ru' check (language in ('ru', 'en')),
  text        text not null check (char_length(btrim(text)) between 1 and 2000),
  created_at  timestamptz not null default now(),
  status      text not null default 'new' check (status in ('new', 'contacted', 'closed'))
);

create index if not exists site_leads_chat_created_idx on sales.site_leads (chat_id, created_at desc);
create index if not exists site_leads_created_idx on sales.site_leads (created_at desc);

alter table sales.site_leads enable row level security;
revoke all on table sales.site_leads from public, anon, authenticated;

comment on table sales.site_leads is
  'Шаг 29: заявки на демо с сайта (бот, /start demo). Только владелец: Table Editor / SQL Editor. Статус: new → contacted → closed.';

create or replace function public.tg_lead_save(
  p_chat bigint, p_username text, p_name text, p_lang text, p_text text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_text text := btrim(coalesce(p_text, ''));
  v_id uuid;
begin
  if p_chat is null then
    return jsonb_build_object('ok', false, 'error', 'bad_chat');
  end if;
  if char_length(v_text) = 0 or char_length(v_text) > 2000 then
    return jsonb_build_object('ok', false, 'error', 'bad_text');
  end if;
  -- Лимиты: защита от спама в таблицу и в чат владельца.
  if (select count(*) from sales.site_leads
       where chat_id = p_chat and created_at > now() - interval '24 hours') >= 3 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  if (select count(*) from sales.site_leads where created_at > now() - interval '24 hours') >= 300 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into sales.site_leads (chat_id, tg_username, tg_name, language, text)
  values (
    p_chat,
    nullif(left(btrim(coalesce(p_username, '')), 64), ''),
    nullif(left(btrim(coalesce(p_name, '')), 128), ''),
    case when p_lang = 'en' then 'en' else 'ru' end,
    v_text)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- Только бот (service_role), как остальные tg_* (0018).
revoke all on function public.tg_lead_save(bigint, text, text, text, text) from public, anon, authenticated;
grant execute on function public.tg_lead_save(bigint, text, text, text, text) to service_role;
grant usage on schema sales to service_role;
grant select, insert, update on sales.site_leads to service_role;
```
</details>

## Новые и изменённые файлы
| Файл | Что |
|---|---|
| `tools/site/build.mjs` | генератор сайта, JSON-LD, robots, sitemap, llms, сборка `--out` |
| `tools/site/config.mjs` | адрес сайта, вход в приложение, контакт — Telegram-бот `?start=demo`, дата обновления, видео |
| `tools/site/content.ru.mjs`, `content.en.mjs` | все тексты сайта |
| `tools/site/site.css` | стиль (встраивается) |
| `tools/site/check.mjs` | проверка собранного сайта (в «PR check») |
| `tools/site/serve.mjs` | локальный просмотр с gzip |
| `tools/site/images.mjs`, `og.mjs`, `fonts.mjs`, `package.json`, `package-lock.json` | разовая подготовка картинок, OG и шрифтов |
| `site/**` | сгенерированные 15 HTML, robots, sitemap, llms, humans, manifest, шрифты, `CNAME` (шаблон) |
| `assets/site/*.webp`, `og-ru.png`, `og-en.png`, `sizes.json` | картинки сайта |
| `.github/workflows/deploy-web.yml` | + сборка сайта в `build/web/site/`, 404 сайта, `workflow_call` |
| `.github/workflows/deploy-site.yml` | новый: ручной запуск той же выкладки |
| `.github/workflows/pr-check.yml` | + шаг «Сайт продукта» (актуален и проходит проверку) |
| `docs/site/README.md` | как устроен сайт, публикация, свой домен, Search Console, Вебмастер, проверка ботов |
| `docs/site/ai-readiness-2026-10-16.md` | оценка 85 / 100 и рекомендации |
| `lib/features/readiness/readiness_logic.dart` | цвета проверок (чистые функции) |
| `lib/features/readiness/readiness_repository.dart` | запросы проверок |
| `lib/features/readiness/readiness_screen.dart` | экран |
| `lib/features/profile/company_screen.dart` | строка меню «Готовность к показу» (администратор) |
| `lib/l10n/app_ru.arb`, `app_en.arb` (+ сгенерированные) | 44 строки `ready…` |
| `test/readiness_test.dart` | 10 тестов: логика и экран (RU / EN) |
| `supabase/functions/telegram-notify/health.ts`, `health_test.ts`, `index.ts` | проверка вебхука `{kind: "webhook"}` |
| `CLAUDE.md` | 0025 в «Применённые», разделы про сайт и «Готовность к показу», 0026 и режим «заявка на демо» |
| `supabase/migrations/0026_site_leads.sql` | **новая миграция**: `sales.site_leads`, `tg_lead_save` |
| `tools/db_test/tg_leads.sql` | тесты 0026 |
| `supabase/functions/telegram-bot/bot.ts`, `texts.ts`, `index.ts`, `bot_test.ts` | режим «заявка на демо», секрет `TELEGRAM_LEADS_CHAT_ID`, тесты |
| `.gitignore` | `/tools/site/node_modules/` |

## Проверки
- `/check`: ✅ анализ `lib` и `test` — без ошибок; ✅ тесты — **518 прошли, 0 упали**; ✅ веб-сборка собирается; ⚠️ строки вне переводов — 1 место «проверить»: `readiness_repository.dart:64` — проверочная фраза для ИИ (уходит в `voice-intake`, на экран не выводится), это данные, не интерфейс — оставил; ✅ название продукта — нарушений нет.
- `deno check` + `deno test supabase/functions/telegram-notify` — 12 прошли.
- Сайт — таблица в блоке 4.
- ⚠️ `/screens` не запускал: в приложении изменился один экран администратора, и он делает настоящие вызовы ИИ; экран покрыт виджет-тестами. На рабочей базе экран не проверялся (у Claude Code нет входа в приложение) — см. «Как проверить руками».

## Что сделать вам
1. **Проверить и слить PR #27.**
2. **Apply migration 0026**: GitHub → Actions → **Apply migration** → Run workflow → `file`: `0026_site_leads.sql` → прочитать текст в первой задаче → Review deployments → `production-db` → **Approve and deploy**. Потом написать Claude Code «применена 0026».
3. *(по желанию)* **Секрет `TELEGRAM_LEADS_CHAT_ID`** — чтобы заявки на демо сразу приходили вам в Telegram. Номер чата — без токена бота и без сторонних ботов:
   1. откройте на телефоне https://t.me/HeyHelpy_bot?start=demo и отправьте «проверка»;
   2. Supabase → **Table Editor** → схема `sales` → `site_leads` → в вашей строке столбец **`chat_id`** — это нужное число;
   3. Supabase → **Edge Functions → Secrets** → Add new secret: имя `TELEGRAM_LEADS_CHAT_ID`, значение — это число → Save;
   4. тестовую строку можно удалить в SQL Editor: `delete from sales.site_leads where text = 'проверка';`
   (Подробно — `docs/site/README.md`, «Заявки на демо».)
4. **Deploy functions** (Actions → Deploy functions → ветка `main` → одобрить): новый режим бота и проверка вебхука для «Готовности к показу». ⚠️ Меняется бот — если перед питчем 19.10 ничего трогать не хочется, сделайте это после показа; до выкладки ссылка «Запросить демо» откроет бота, но он ответит старым текстом «нужна ссылка от работодателя».
5. **Deploy site** — после слияния сайт выкладывается сам вместе с приложением («Deploy web»); вручную (Actions → **Deploy site** → `main` → одобрить) — только если нужно обновить без нового коммита. Открыть https://anton-key.github.io/hey-helpy/site/ и полистать на телефоне.
6. По желанию — **свой домен**, потом **Google Search Console** и **Яндекс Вебмастер**: `docs/site/README.md`.
7. Смотреть заявки на демо: Supabase → Table Editor → `sales.site_leads` (отметить `status`: `contacted`, `closed`).

## Как проверить руками
- **Сайт:** главная → «Возможности» → «Вопросы» → переключатель EN / RU → «Войти» (открывает приложение) → несуществующий адрес `…/site/abc` → своя 404. На телефоне — кнопка «Меню».
- **Заявка на демо** (после 0026 и Deploy functions): на сайте «Запросить демо» → Telegram → бот просит одно сообщение → написать «проверка» → «Спасибо!…»; строка в `sales.site_leads`; с секретом — сообщение «🆕 Заявка на демо…» в вашем чате. Голосовое вместо текста → «напишите текстом». Четвёртая заявка за сутки → «уже получили». Гостевой QR объекта и группа работают как раньше.
- **Боты:** команда из `docs/site/README.md`, «Проверить доступ ботов» — у всех `200`.
- **Готовность к показу:** войти демо-менеджером (он администратор «Демо БЦ») → Профиль → «Моя компания» → «Готовность к показу». Ожидаемо: база, миграции, 5 функций — зелёные; «вебхук» — серая до Deploy functions; голос ~2–5 с, «По фото» ~5–10 с; Refresh demo — зелёное, если запускали в последние 2 дня. Под менеджером без роли администратора строки меню нет.

## Ограничения и что не сделано
- Пока сайт в подпапке, `robots.txt` / `llms.txt` боты сами не найдут (честно учтено в оценке: доступ ботов 20 / 30).
- Лиды смотрятся только в Supabase (Table Editor / SQL Editor); экрана в приложении нет.
- Видео только на русском (в EN-версии так и подписано).
- Полевых Core Web Vitals нет — у нового сайта их не бывает; через 4–6 недель — PageSpeed Insights.
- Вебхук в «Готовности» — после Deploy functions.
- Дата Refresh demo — приблизительная (по демо-заявкам), отдельной отметки в базе нет (для неё нужна была бы миграция — не стал).
