# Шаг 23: Telegram-бот @HeyHelpy_bot — заявки текстом, голосом и фото

Ветка `step-23` от `main` (PR шага 22 слит). Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

## Чек-лист
- [x] 1. Миграция `0018_telegram.sql` (ссылки, гости, группы, привязка, функции `tg_*`, лимиты) + тесты базы
- [x] 2. Edge Function `telegram-bot` (вебхук: текст, подтверждение, ссылки объекта и компании, гости, голос, фото, группы) + `deno test`
- [x] 3. Workflow «Telegram webhook»
- [x] 4. Приложение: Профиль → Telegram, QR объекта и плакат, ссылка компании, группа объекта, пометка «Telegram» в заявках, автообновление
- [x] 5. Демо-данные, `CLAUDE.md`, `docs/DEMO_SCRIPT.md`, `/screens`, кадр питча 19

**Миграция 0018** (Telegram; не применена). **Новая Edge Function `telegram-bot`** (не выложена). **Новый workflow «Telegram webhook»**. **Seed изменён** (блок 5g, нужна 0018) — нужен Refresh demo. **Нужны новые секреты** `TELEGRAM_BOT_TOKEN` и `TELEGRAM_WEBHOOK_SECRET` (см. «Что сделать вам»).

## Что сделано

### Блок 1. Миграция 0018
- У заявки — канал `telegram` и поле `reporter` (`{name, username, guest, group}`): кто написал в Telegram. Телефона и chat_id там нет. Ставит их **только бот**; из приложения — отказ (триггер `trg_wo_reporter_guard`).
- `report_links` — ссылка (QR-код) на объект или на всю компанию: токен 24 знака, одна включённая на объект / компанию. Создаёт / меняет / отключает менеджер с правом на объект (`report_link_rotate`, `report_link_disable`), ссылку компании — только администратор.
- `telegram_links` (чат ↔ аккаунт по одноразовому коду из «Настроек»), `telegram_guests` (чаты гостей ссылки), `telegram_groups` (рабочая группа объекта). Приложение не видит `chat_id` (права на столбцы).
- Служебная схема `telegram` (через API не видна): коды (хранится только хэш, 15 минут), повторы `update_id`, черновики разговоров (30 минут), журнал для лимитов.
- Функции бота `tg_*` — только для `service_role`. Кто пишет, база определяет сама по chat_id: пользователь работает «как будто вошёл» (его зоны 0016, те же триггеры заявок), гость и группа — только объект(ы) своей ссылки.
- Лимиты: гость — 5 заявок в час с чата и 30 в сутки на ссылку; группа и пользователь — 30 в час.
- Тесты базы `tools/db_test/telegram.sql` — **73 ✅**; строки компании 2 добавлены в `10_fixture.sql` (проверка изоляции компаний).

### Блок 2. Edge Function `telegram-bot`
- Вебхук: сверяет секрет `X-Telegram-Bot-Api-Secret-Token` (за постоянное время), иначе 401 и ничего не делает. Telegram получает ответ сразу, разбор идёт в фоне; повтор `update_id` — 200 без действий.
- Разговор: **текст / голос / фото → черновик → карточка** «✅ Создать / 📍 Изменить место / ⚡ Срочность / Отмена» → заявка.
  - Текст — тот же разбор ИИ, что в приложении (`_shared/intake.ts`). ИИ недоступен → текст как есть с пометкой.
  - Голос — Yandex SpeechKit (до 30 с и 1 МБ), потом тот же разбор.
  - Фото — «Узнать по фото» (`_shared/identify.ts`): вид, система, кандидат из реестра. Снимок прикладывается к заявке фото «до».
  - Геопозиция — ближайший объект.
- Команды: `/start link_<код>` (привязать аккаунт), `/start obj_<токен>` / `co_<токен>` (гость по QR объекта / ссылке компании), `/start grp_<код>` и `/connect <код>` (группа), `/where`, `/cancel`, `/reset`, `/help`. Тексты — RU / EN.
- В группе бот читает только упоминания, ответы ему и команды. Кнопки черновика нажимает только его автор.
- `verify_jwt = false` в `supabase/config.toml`; функция добавлена в «Deploy functions».
- В лог — только тип сообщения, время этапов, модель, коды ошибок. Текст, расшифровка, фото, имена и chat_id не пишутся.
- `bot_test.ts` — 30 тестов без сети; всего `deno test supabase/functions` — **67 ✅**.

### Блок 3. Workflow «Telegram webhook»
`.github/workflows/telegram-webhook.yml`: `set` — подключить бота (адрес функции, секрет, команды меню RU / EN, описание), `info` — только проверить, `delete` — отключить. Итог — в Summary. Запускает и одобряет только пользователь (окружение `production-db`).

### Блок 4. Приложение
- **Профиль → Настройки → Telegram**: «Подключить Telegram» → код привязки, QR-код, «Открыть Telegram»; когда подключён — «Отключить Telegram».
- **Карточка объекта → «Заявки через Telegram»** (менеджер): QR-код, «Плакат для печати (PDF)» (загружается отложенно), «Создать новую ссылку», «Отключить», «Группы Telegram» (подключить группу кодом, отключить).
- **«Моя компания» → «Ссылка компании для Telegram»** (администратор).
- Заявки: пометка «Telegram» в строке списка, «Написал в Telegram · гость» в карточке, источник «Telegram» в фильтре. Ссылка «Открыть в приложении» из бота — `#/orders/<id>`. Список заявок перечитывается сам раз в 15 с (только когда вкладка на экране).
- QR-код — новый компонент дизайн-системы `AppQrCode` (пакет `barcode`).
- Все строки — RU / EN; `test/telegram_test.dart` (ссылки бота совпадают с `BOT_USERNAME`, подписи автора и т. п.).
- Без 0018 новые экраны показывают «Нужна миграция 0018», остальное приложение работает как раньше.

### Блок 5. Демо, документы, проверки
- Демо-данные (блок 5g `demo_history.sql`, только если применена 0018): заявка 277 «Капает вода с кондиционера» (гость «Ольга С.» по QR) и 278 «Не работает розетка у стойки ресепшена» (сотрудник с аккаунтом). Демо-данные загружаются дважды без ошибок.
- `CLAUDE.md`, `docs/DEMO_SCRIPT.md` (сцена с Telegram), кадр питча 19 (`docs/screens/pitch/19-telegram-qr-poster.png`), предпросмотр новых экранов `docs/screens/preview23/` (17 снимков, все ✅).
- Подсказка бота «где подключить аккаунт» исправлена на точный путь «Профиль → Настройки → Telegram» (RU / EN).
- По `/check`: название листа шаблона импорта оборудования теперь из файла перевода (`importTemplateSheetName`), а не прямо в коде (мелочь из шага 16).

### ⚠️ Решения (принял сам)
- Таблица ссылок одна — `report_links`: и на объект, и на всю компанию (`object_id = null`). Так проще управлять и проверять права.
- Служебные таблицы бота — в отдельной схеме `telegram`, приложение их не видит вообще.
- Кто пишет боту, база определяет **сама по chat_id**, бот не может «назваться» другим пользователем.
- Фото до нажатия «Создать» хранится только как `file_id` Telegram: во временную папку ничего не кладётся, удалять нечего.
- Заявки гостей создаются сразу, без подтверждения менеджером, но с пометкой «гость». Защита — лимиты и то, что ссылку можно в любой момент заменить или отключить.
- В группе — один черновик на группу, кнопки жмёт только его автор.

## Новые и изменённые файлы
| Файл | Что |
|---|---|
| `supabase/migrations/0018_telegram.sql` | ссылки, привязка, гости, группы, функции `tg_*`, лимиты, RLS |
| `tools/db_test/telegram.sql`, `tools/db_test/10_fixture.sql` | тесты базы (73) и строки компании 2 |
| `supabase/functions/telegram-bot/index.ts` | вебхук: секрет, повторы, фон |
| `supabase/functions/telegram-bot/bot.ts` | разговор, черновик, кнопки, заявка |
| `supabase/functions/telegram-bot/telegram.ts` | обновления, команды, упоминания, клиент API, `BOT_USERNAME` |
| `supabase/functions/telegram-bot/stt.ts` | SpeechKit (голосовые) |
| `supabase/functions/telegram-bot/texts.ts` | тексты RU / EN, команды меню |
| `supabase/functions/telegram-bot/bot_test.ts` | 30 тестов без сети |
| `supabase/config.toml` | `telegram-bot`: `verify_jwt = false` |
| `.github/workflows/deploy-functions.yml` | `telegram-bot` в списке выкладки |
| `.github/workflows/telegram-webhook.yml` | новый: подключение бота |
| `lib/features/telegram/telegram_repository.dart` | ссылки, привязка, группы |
| `lib/features/telegram/telegram_screens.dart` | экраны Telegram в настройках, объекте, компании |
| `lib/features/telegram/telegram_poster.dart` | плакат A4 с QR (отложенно) |
| `lib/core/design/qr_code.dart`, `design.dart`, `icons.dart` | компонент `AppQrCode`, значки |
| `lib/core/app_links.dart` | ссылки на бота |
| `lib/core/router.dart` | маршрут `/orders/:id` |
| `lib/features/requests/order_link_screen.dart` | открытие заявки по ссылке из бота |
| `lib/features/requests/requests.dart`, `requests_tab.dart`, `order_filter.dart`, `order_filter_bar.dart` | автор из Telegram, канал, автообновление 15 с |
| `lib/features/directory/object_card.dart`, `lib/features/profile/company_screen.dart`, `settings_screen.dart` | входы в экраны Telegram |
| `lib/features/equipment/equipment_xlsx.dart`, `equipment_import_screen.dart` | лист шаблона — из перевода |
| `lib/l10n/app_ru.arb`, `app_en.arb` (+ сгенерированные) | строки RU / EN |
| `pubspec.yaml`, `pubspec.lock` | пакет `barcode` |
| `test/telegram_test.dart` | тесты приложения |
| `supabase/seed/demo_history.sql` | блок 5g — заявки 277–278 |
| `tools/screens/local_screens.mjs` | `--step=23` |
| `docs/screens/preview23/`, `docs/screens/pitch/19-…`, `docs/screens/latest/` | снимки |
| `CLAUDE.md`, `docs/DEMO_SCRIPT.md` | описание шага, сцена показа |

## Проверки
- `flutter analyze lib test` — без замечаний.
- `flutter test` — **372 ✅**, 0 ❌.
- `flutter build web --release` — собирается.
- `deno check` + `deno test supabase/functions` — **67 ✅**.
- `bash tools/db_test/run.sh` (миграции 0001–0018, новые — дважды) — **914 ✅**: telegram 73, tenant_isolation 722, access_zones 34, ppr_regions 49, cross_refs 21, photo_identify 15; демо-данные дважды без ошибок.
- `/check`: строки вне переводов и название продукта — нарушений нет.

## `/screens`
SCREENS_PLACEHOLDER

## Миграция 0018 — полный текст
**Зачем:** заявки из Telegram от сотрудников (с аккаунтом), гостей (по QR-коду объекта или ссылке компании) и рабочих групп объекта. **Что меняет:** у `work_orders` — новое поле `reporter` и канал `telegram` (старые заявки не меняются); новые таблицы `report_links`, `telegram_links`, `telegram_guests`, `telegram_groups`; схема `telegram`; функции `tg_*` и `report_link_*`. Старые права не ослабляются. **Повторный запуск безопасен:** `if not exists`, `create or replace`, `drop … if exists` (проверено: локальные тесты применяют её дважды).

```sql
-- 0018 — Telegram-бот @HeyHelpy_bot (шаг 23): заявки от сотрудников и гостей.
--
-- 1) work_orders: канал 'telegram' (прежние значения остаются) и reporter
--    jsonb — кто написал в Telegram: {name, username, guest, group} (без
--    телефона и без chat_id). Ставить канал 'telegram' и reporter может только
--    бот (функции tg_*); из приложения — отказ (триггер trg_wo_reporter_guard).
-- 2) report_links — ссылки для сотрудников без аккаунта: на объект (QR-код на
--    плакате) или на всю компанию (object_id = null). Токен случайный, 24
--    символа. Одна включённая ссылка на объект / компанию. Меняют только
--    функции report_link_rotate / report_link_disable (менеджер с правом на
--    объект; ссылку компании — администратор). Читают менеджеры компании.
-- 3) telegram_links — привязка чата к аккаунту (одноразовый код из «Профиля»),
--    telegram_guests — чаты гостей (вошли по ссылке; запоминаются, пока ссылка
--    включена), telegram_groups — рабочие группы объекта (/connect <код>).
--    chat_id из приложения не читается (права на столбцы).
-- 4) Схема telegram (не видна через API): одноразовые коды (хранится только
--    хэш), защита от повторов update_id, черновики разговоров (30 минут),
--    журнал заявок бота (для лимитов).
-- 5) Функции бота tg_* — security definer, вызывает ТОЛЬКО service_role
--    (Edge Function telegram-bot). Личность — всегда по chat_id из привязки,
--    не от бота: пользователь — как будто вошёл в приложение (auth.uid() на
--    время вызова, can_see из 0016, те же триггеры заявок); гость и группа —
--    только объект(ы) своей ссылки. Лимиты: гость — 5 заявок в час с чата и 30
--    в сутки на ссылку; группа — 30 в час; пользователь — 30 в час.
-- 6) Функции приложения: tg_create_link_code(), tg_create_group_code(объект),
--    report_link_rotate(объект | null), report_link_disable(объект | null).
--
-- Повторный запуск безопасен: if not exists, create or replace, drop … if exists.

create schema if not exists telegram;
revoke all on schema telegram from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 1. Заявки: канал telegram и автор из Telegram
-- ---------------------------------------------------------------------
alter table public.work_orders add column if not exists reporter jsonb;

alter table public.work_orders drop constraint if exists work_orders_input_channel_check;
alter table public.work_orders add constraint work_orders_input_channel_check
  check (input_channel = any (array['button','text','voice','camera','wake_word','ppr','telegram']));

alter table public.work_orders drop constraint if exists work_orders_reporter_check;
alter table public.work_orders add constraint work_orders_reporter_check
  check (reporter is null or (jsonb_typeof(reporter) = 'object' and length(reporter::text) <= 500));

-- Канал telegram и reporter ставит только бот: функции tg_* включают на
-- время вызова настройку hh.telegram. Вошедший пользователь приложения
-- (auth.uid() задан) их не ставит и не меняет; обслуживание (SQL Editor,
-- демо-данные — auth.uid() пуст) — без ограничений.
create or replace function public.trg_wo_reporter_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or coalesce(current_setting('hh.telegram', true), '') = '1' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.input_channel = 'telegram' or new.reporter is not null then
      raise exception 'forbidden: telegram orders are created by the bot only' using errcode = '42501';
    end if;
  elsif new.reporter is distinct from old.reporter
     or (new.input_channel = 'telegram' and old.input_channel is distinct from 'telegram') then
    raise exception 'forbidden: reporter is set by the bot only' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_wo_reporter_guard on public.work_orders;
create trigger trg_wo_reporter_guard
  before insert or update on public.work_orders
  for each row execute function public.trg_wo_reporter_guard();

-- ---------------------------------------------------------------------
-- 2. Ссылки для сотрудников (QR объекта и ссылка компании)
-- ---------------------------------------------------------------------
create table if not exists public.report_links (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  object_id   uuid references public.objects(id) on delete cascade,
  token       text not null unique,
  enabled     boolean not null default true,
  created_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  disabled_at timestamptz
);

alter table public.report_links drop constraint if exists report_links_token_chk;
alter table public.report_links add constraint report_links_token_chk
  check (token ~ '^[A-Za-z0-9_-]{16,64}$');

-- Одна включённая ссылка на объект и одна — на компанию.
create unique index if not exists uq_report_links_object_enabled
  on public.report_links (object_id) where enabled and object_id is not null;
create unique index if not exists uq_report_links_company_enabled
  on public.report_links (company_id) where enabled and object_id is null;
create index if not exists idx_report_links_company on public.report_links (company_id);

-- Объект ссылки — той же компании.
create or replace function public.trg_report_links_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.object_id is not null and not exists (
       select 1 from objects o where o.id = new.object_id and o.company_id = new.company_id) then
    raise exception 'object of another company' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists trg_report_links_check on public.report_links;
create trigger trg_report_links_check
  before insert or update on public.report_links
  for each row execute function public.trg_report_links_check();

alter table public.report_links enable row level security;
drop policy if exists report_links_select on public.report_links;
create policy report_links_select on public.report_links for select using (
  report_links.company_id = (select public.my_company_id()) and (select public.is_manager()));
revoke all on public.report_links from anon, authenticated;
grant select on public.report_links to authenticated;

-- ---------------------------------------------------------------------
-- 3. Чаты: аккаунты, гости, группы объекта
-- ---------------------------------------------------------------------
create table if not exists public.telegram_links (
  profile_id     uuid primary key references public.profiles(id) on delete cascade,
  chat_id        bigint not null unique,
  tg_username    text,
  tg_name        text,
  language       text,
  last_object_id uuid references public.objects(id) on delete set null,
  created_at     timestamptz not null default now()
);

alter table public.telegram_links enable row level security;
drop policy if exists telegram_links_select on public.telegram_links;
create policy telegram_links_select on public.telegram_links for select using (
  telegram_links.profile_id = (select auth.uid())
  or ((select public.is_manager()) and exists (
        select 1 from public.profiles p
         where p.id = telegram_links.profile_id and p.company_id = (select public.my_company_id()))));
drop policy if exists telegram_links_delete on public.telegram_links;
create policy telegram_links_delete on public.telegram_links for delete using (
  telegram_links.profile_id = (select auth.uid()));
revoke all on public.telegram_links from anon, authenticated;
grant select (profile_id, tg_username, tg_name, language, last_object_id, created_at)
  on public.telegram_links to authenticated;
grant delete on public.telegram_links to authenticated;

create table if not exists public.telegram_guests (
  chat_id        bigint primary key,
  link_id        uuid not null references public.report_links(id) on delete cascade,
  company_id     uuid not null references public.companies(id) on delete cascade,
  last_object_id uuid references public.objects(id) on delete set null,
  tg_name        text,
  language       text,
  created_at     timestamptz not null default now(),
  last_seen_at   timestamptz not null default now()
);
create index if not exists idx_telegram_guests_link on public.telegram_guests (link_id);

alter table public.telegram_guests enable row level security;
drop policy if exists telegram_guests_select on public.telegram_guests;
create policy telegram_guests_select on public.telegram_guests for select using (
  telegram_guests.company_id = (select public.my_company_id()) and (select public.is_manager()));
revoke all on public.telegram_guests from anon, authenticated;
grant select (link_id, company_id, last_object_id, tg_name, language, created_at, last_seen_at)
  on public.telegram_guests to authenticated;

create table if not exists public.telegram_groups (
  chat_id      bigint primary key,
  id           uuid not null unique default gen_random_uuid(),
  object_id    uuid not null references public.objects(id) on delete cascade,
  company_id   uuid not null references public.companies(id) on delete cascade,
  title        text,
  connected_by uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index if not exists idx_telegram_groups_object on public.telegram_groups (object_id);

create or replace function public.trg_telegram_groups_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from objects o where o.id = new.object_id and o.company_id = new.company_id) then
    raise exception 'object of another company' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists trg_telegram_groups_check on public.telegram_groups;
create trigger trg_telegram_groups_check
  before insert or update on public.telegram_groups
  for each row execute function public.trg_telegram_groups_check();

alter table public.telegram_groups enable row level security;
drop policy if exists telegram_groups_select on public.telegram_groups;
create policy telegram_groups_select on public.telegram_groups for select using (
  telegram_groups.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_see(telegram_groups.object_id)));
drop policy if exists telegram_groups_delete on public.telegram_groups;
create policy telegram_groups_delete on public.telegram_groups for delete using (
  telegram_groups.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(telegram_groups.object_id)));
revoke all on public.telegram_groups from anon, authenticated;
grant select (id, object_id, company_id, title, connected_by, created_at)
  on public.telegram_groups to authenticated;
grant delete on public.telegram_groups to authenticated;

-- ---------------------------------------------------------------------
-- 4. Служебные таблицы бота (схема telegram, через API не видны)
-- ---------------------------------------------------------------------
create table if not exists telegram.codes (
  code_hash  text primary key,
  purpose    text not null check (purpose in ('account', 'group')),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  object_id  uuid references public.objects(id) on delete cascade,
  expires_at timestamptz not null,
  used_at    timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_tg_codes_profile on telegram.codes (profile_id, purpose);

create table if not exists telegram.updates (
  update_id    bigint primary key,
  processed_at timestamptz not null default now()
);

create table if not exists telegram.sessions (
  chat_id    bigint primary key,
  state      jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists telegram.orders (
  work_order_id uuid primary key references public.work_orders(id) on delete cascade,
  chat_id       bigint not null,
  link_id       uuid references public.report_links(id) on delete set null,
  profile_id    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now()
);
create index if not exists idx_tg_orders_chat on telegram.orders (chat_id, created_at);
create index if not exists idx_tg_orders_link on telegram.orders (link_id, created_at);
create index if not exists idx_tg_orders_profile on telegram.orders (profile_id, created_at);

alter table telegram.codes    enable row level security;
alter table telegram.updates  enable row level security;
alter table telegram.sessions enable row level security;
alter table telegram.orders   enable row level security;
revoke all on all tables in schema telegram from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. Вспомогательные функции (не вызываются извне)
-- ---------------------------------------------------------------------
-- Хэш кода: регистр и пробелы не важны.
create or replace function telegram.code_hash(p_code text)
returns text language sql immutable set search_path = public, extensions as $$
  select encode(digest(upper(regexp_replace(coalesce(p_code, ''), '\s', '', 'g')), 'sha256'), 'hex');
$$;

-- Код из 8 знаков без похожих (0/O, 1/I): 32 знака, байт % 32 — равномерно.
create or replace function telegram.new_code()
returns text language plpgsql volatile set search_path = public, extensions as $$
declare
  abc constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  b bytea := gen_random_bytes(8);
  s text := '';
begin
  for i in 0 .. 7 loop
    s := s || substr(abc, (get_byte(b, i) % 32) + 1, 1);
  end loop;
  return s;
end $$;

-- Токен ссылки: 18 случайных байт → 24 знака base64url.
create or replace function telegram.new_token()
returns text language sql volatile set search_path = public, extensions as $$
  select translate(encode(gen_random_bytes(18), 'base64'), '+/', '-_');
$$;

-- «Войти» пользователем на время вызова: auth.uid(), my_company_id(),
-- can_see() и триггеры заявок видят его. Возвращает прежние настройки.
create or replace function telegram.act_as(p_uid uuid)
returns text[] language plpgsql volatile set search_path = public as $$
declare
  prev text[] := array[coalesce(current_setting('request.jwt.claims', true), ''),
                       coalesce(current_setting('request.jwt.claim.sub', true), '')];
begin
  perform set_config('request.jwt.claims',
    case when p_uid is null then '' else json_build_object('sub', p_uid, 'role', 'authenticated')::text end, true);
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  return prev;
end $$;

create or replace function telegram.restore(p_prev text[])
returns void language plpgsql volatile set search_path = public as $$
begin
  perform set_config('request.jwt.claims', coalesce(p_prev[1], ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(p_prev[2], ''), true);
  perform set_config('hh.telegram', '', true);
end $$;

-- Кто пишет: пользователь, гость, группа или никто. Только по chat_id.
create or replace function telegram.who(p_chat bigint, p_group boolean)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  r record;
begin
  if p_group then
    select g.company_id, g.object_id, g.title into r from telegram_groups g where g.chat_id = p_chat;
    if found then
      return jsonb_build_object('kind', 'group', 'company_id', r.company_id, 'object_id', r.object_id,
        'objects', jsonb_build_array(r.object_id));
    end if;
    return jsonb_build_object('kind', 'none');
  end if;
  select l.profile_id, p.company_id, p.role, p.full_name, p.locale, l.last_object_id into r
    from telegram_links l join profiles p on p.id = l.profile_id
   where l.chat_id = p_chat and p.company_id is not null;
  if found then
    return jsonb_build_object('kind', 'user', 'profile_id', r.profile_id, 'company_id', r.company_id,
      'role', r.role, 'name', r.full_name, 'locale', r.locale, 'object_id', r.last_object_id);
  end if;
  select g.link_id, g.company_id, g.last_object_id, k.object_id as link_object, k.enabled into r
    from telegram_guests g join report_links k on k.id = g.link_id where g.chat_id = p_chat;
  if found then
    if not r.enabled then
      return jsonb_build_object('kind', 'guest_off');
    end if;
    return jsonb_build_object('kind', 'guest', 'link_id', r.link_id, 'company_id', r.company_id,
      'link_object_id', r.link_object,
      'object_id', coalesce(r.link_object, r.last_object_id),
      'objects', case when r.link_object is not null then jsonb_build_array(r.link_object)
                      else (select coalesce(jsonb_agg(o.id), '[]'::jsonb) from objects o where o.company_id = r.company_id) end);
  end if;
  return jsonb_build_object('kind', 'none');
end $$;

-- Может ли этот чат писать про объект (null — «объект уточнит менеджер»).
create or replace function telegram.object_allowed(p_who jsonb, p_object uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
begin
  if p_who->>'kind' = 'user' then
    if p_object is null then return true; end if;
    -- вызывается внутри act_as: can_see видит зону пользователя
    return exists (select 1 from objects o where o.id = p_object
                     and o.company_id = (p_who->>'company_id')::uuid)
       and public.can_see(p_object);
  elsif p_who->>'kind' in ('guest', 'group') then
    if p_object is null then
      return p_who->>'kind' = 'guest' and p_who->>'link_object_id' is null;
    end if;
    return (p_who->'objects') @> to_jsonb(p_object::text);
  end if;
  return false;
end $$;

revoke all on all functions in schema telegram from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. Функции приложения (authenticated)
-- ---------------------------------------------------------------------
-- Код привязки аккаунта: 8 знаков, 15 минут, один раз. Возвращается один
-- раз — в базе только хэш. Прежние неиспользованные коды гаснут.
create or replace function public.tg_create_link_code()
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
begin
  if v_uid is null or (select company_id from profiles where id = v_uid) is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from telegram.codes where profile_id = v_uid and purpose = 'account' and used_at is null;
  v_code := telegram.new_code();
  insert into telegram.codes(code_hash, purpose, profile_id, expires_at)
  values (telegram.code_hash(v_code), 'account', v_uid, now() + interval '15 minutes');
  return v_code;
end $$;
revoke all on function public.tg_create_link_code() from public, anon;
grant execute on function public.tg_create_link_code() to authenticated;

-- Код подключения группы к объекту: менеджер с правом на объект.
create or replace function public.tg_create_group_code(p_object uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
begin
  if v_uid is null or not public.is_manager()
     or not exists (select 1 from objects o where o.id = p_object and o.company_id = public.my_company_id())
     or not (public.is_admin() or public.can_manage(p_object)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from telegram.codes where profile_id = v_uid and purpose = 'group' and object_id = p_object and used_at is null;
  v_code := telegram.new_code();
  insert into telegram.codes(code_hash, purpose, profile_id, object_id, expires_at)
  values (telegram.code_hash(v_code), 'group', v_uid, p_object, now() + interval '15 minutes');
  return v_code;
end $$;
revoke all on function public.tg_create_group_code(uuid) from public, anon;
grant execute on function public.tg_create_group_code(uuid) to authenticated;

-- Право менять ссылку: объект — менеджер с правом на объект; компания — администратор.
create or replace function telegram.can_edit_link(p_object uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and public.is_manager() and public.my_company_id() is not null
     and case when p_object is null then public.is_admin()
              else exists (select 1 from objects o where o.id = p_object and o.company_id = public.my_company_id())
                   and (public.is_admin() or public.can_manage(p_object)) end;
$$;
revoke all on function telegram.can_edit_link(uuid) from public, anon, authenticated;

-- Новая ссылка (старая, если была, отключается — её QR и гости перестают работать).
create or replace function public.report_link_rotate(p_object uuid default null)
returns public.report_links language plpgsql volatile security definer set search_path = public as $$
declare
  v_company uuid := public.my_company_id();
  r public.report_links;
begin
  if not telegram.can_edit_link(p_object) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update report_links set enabled = false, disabled_at = now()
   where company_id = v_company and enabled and object_id is not distinct from p_object;
  insert into report_links(company_id, object_id, token, created_by)
  values (v_company, p_object, telegram.new_token(), auth.uid())
  returning * into r;
  return r;
end $$;
revoke all on function public.report_link_rotate(uuid) from public, anon;
grant execute on function public.report_link_rotate(uuid) to authenticated;

create or replace function public.report_link_disable(p_object uuid default null)
returns integer language plpgsql volatile security definer set search_path = public as $$
declare
  n integer;
begin
  if not telegram.can_edit_link(p_object) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update report_links set enabled = false, disabled_at = now()
   where company_id = public.my_company_id() and enabled and object_id is not distinct from p_object;
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.report_link_disable(uuid) from public, anon;
grant execute on function public.report_link_disable(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 7. Функции бота (только service_role)
-- ---------------------------------------------------------------------
-- Повтор от Telegram: true — обновление новое, false — уже обрабатывали.
create or replace function public.tg_take_update(p_update_id bigint)
returns boolean language plpgsql volatile security definer set search_path = public as $$
declare
  n integer;
begin
  insert into telegram.updates(update_id) values (p_update_id) on conflict do nothing;
  get diagnostics n = row_count;
  if n = 1 and p_update_id % 200 = 0 then
    perform public.tg_cleanup();
  end if;
  return n = 1;
end $$;

-- Очистка: повторы старше 7 дней, черновики старше 30 минут, коды старше суток.
create or replace function public.tg_cleanup()
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  delete from telegram.updates where processed_at < now() - interval '7 days';
  delete from telegram.sessions where updated_at < now() - interval '30 minutes';
  delete from telegram.codes where expires_at < now() - interval '1 day';
end $$;

-- Кто этот чат: {kind: user | guest | guest_off | group | none, …, company_name, object}.
create or replace function public.tg_resolve_chat(p_chat bigint, p_group boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  w jsonb := telegram.who(p_chat, p_group);
  o record;
begin
  if w->>'kind' in ('none', 'guest_off') then return w; end if;
  if w->>'kind' = 'guest' then
    update telegram_guests set last_seen_at = now() where chat_id = p_chat;
  end if;
  w := w || jsonb_build_object('company_name',
         (select c.name from companies c where c.id = (w->>'company_id')::uuid));
  if w->>'object_id' is not null then
    select ob.id, ob.name, coalesce(nullif(btrim(ob.city), ''), split_part(coalesce(ob.address, ''), ',', 1)) as city
      into o from objects ob where ob.id = (w->>'object_id')::uuid;
    if found then
      w := w || jsonb_build_object('object', jsonb_build_object('id', o.id, 'name', o.name, 'city', o.city));
    end if;
  end if;
  return w - 'objects';
end $$;

-- Привязка аккаунта: код из «Профиля → Telegram».
create or replace function public.tg_link_chat(
  p_code text, p_chat bigint, p_username text default null, p_name text default null, p_lang text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  c record;
begin
  update telegram.codes set used_at = now()
   where code_hash = telegram.code_hash(p_code) and purpose = 'account'
     and used_at is null and expires_at > now()
  returning profile_id into c;
  if not found then
    return jsonb_build_object('error', 'bad_code');
  end if;
  delete from public.telegram_links where profile_id = c.profile_id or chat_id = p_chat;
  delete from public.telegram_guests where chat_id = p_chat;
  delete from telegram.sessions where chat_id = p_chat;
  insert into public.telegram_links(profile_id, chat_id, tg_username, tg_name, language)
  values (c.profile_id, p_chat, left(p_username, 64), left(p_name, 128), left(p_lang, 8));
  return jsonb_build_object('ok', true,
    'name', (select full_name from profiles where id = c.profile_id),
    'company_name', (select co.name from profiles p join companies co on co.id = p.company_id where p.id = c.profile_id));
end $$;

-- Вход гостя по ссылке объекта или компании. Аккаунт той же компании —
-- просто меняет объект; другой компании — отказ.
create or replace function public.tg_guest_start(
  p_token text, p_chat bigint, p_name text default null, p_lang text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  k record;
  w jsonb := telegram.who(p_chat, false);
  v_obj uuid;
begin
  select * into k from report_links where token = p_token and enabled;
  if not found then
    return jsonb_build_object('error', 'bad_link');
  end if;
  if w->>'kind' = 'user' then
    if (w->>'company_id')::uuid <> k.company_id then
      return jsonb_build_object('error', 'other_company');
    end if;
    if k.object_id is not null then
      update telegram_links set last_object_id = k.object_id where chat_id = p_chat;
    end if;
    v_obj := coalesce(k.object_id, (w->>'object_id')::uuid);
  else
    -- прежний объект сохраняется, если вошли по ссылке той же компании
    select case when g.company_id = k.company_id then g.last_object_id end into v_obj
      from telegram_guests g where g.chat_id = p_chat;
    v_obj := coalesce(k.object_id, v_obj);
    insert into telegram_guests(chat_id, link_id, company_id, last_object_id, tg_name, language)
    values (p_chat, k.id, k.company_id, v_obj, left(p_name, 128), left(p_lang, 8))
    on conflict (chat_id) do update
      set link_id = excluded.link_id, company_id = excluded.company_id,
          last_object_id = excluded.last_object_id, tg_name = excluded.tg_name,
          language = excluded.language, last_seen_at = now();
  end if;
  delete from telegram.sessions where chat_id = p_chat;
  return jsonb_build_object('ok', true,
    'kind', case when w->>'kind' = 'user' then 'user' else 'guest' end,
    'scope', case when k.object_id is null then 'company' else 'object' end,
    'company_name', (select name from companies where id = k.company_id),
    'object', (select jsonb_build_object('id', ob.id, 'name', ob.name,
                        'city', coalesce(nullif(btrim(ob.city), ''), split_part(coalesce(ob.address, ''), ',', 1)))
                 from objects ob where ob.id = v_obj));
end $$;

-- Отвязать чат (/reset): гостя, аккаунт и черновик.
create or replace function public.tg_reset(p_chat bigint)
returns boolean language plpgsql volatile security definer set search_path = public as $$
declare
  n integer;
  m integer;
begin
  delete from telegram_guests where chat_id = p_chat;
  get diagnostics n = row_count;
  delete from telegram_links where chat_id = p_chat;
  get diagnostics m = row_count;
  delete from telegram.sessions where chat_id = p_chat;
  return n + m > 0;
end $$;

-- Подключить группу к объекту кодом из карточки объекта.
create or replace function public.tg_connect_group(p_code text, p_chat bigint, p_title text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  c record;
begin
  update telegram.codes set used_at = now()
   where code_hash = telegram.code_hash(p_code) and purpose = 'group'
     and used_at is null and expires_at > now()
  returning profile_id, object_id into c;
  if not found or c.object_id is null then
    return jsonb_build_object('error', 'bad_code');
  end if;
  insert into telegram_groups(chat_id, object_id, company_id, title, connected_by)
  select p_chat, o.id, o.company_id, left(p_title, 128), c.profile_id from objects o where o.id = c.object_id
  on conflict (chat_id) do update
    set object_id = excluded.object_id, company_id = excluded.company_id,
        title = excluded.title, connected_by = excluded.connected_by, created_at = now();
  return jsonb_build_object('ok', true, 'object_name', (select name from objects where id = c.object_id));
end $$;

-- Справочники для разбора: объекты, помещения, системы, оборудование —
-- что видит этот чат. Пользователь — как в приложении (зона доступа 0016),
-- гость и группа — только объект(ы) своей ссылки. p_object — сузить до объекта.
create or replace function public.tg_context(p_chat bigint, p_group boolean default false, p_object uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  w jsonb := telegram.who(p_chat, p_group);
  v_company uuid;
  prev text[];
  v_objects uuid[];
  res jsonb;
begin
  if w->>'kind' not in ('user', 'guest', 'group') then
    return jsonb_build_object('error', 'not_linked');
  end if;
  v_company := (w->>'company_id')::uuid;
  prev := telegram.act_as(case when w->>'kind' = 'user' then (w->>'profile_id')::uuid end);
  if p_object is not null and not telegram.object_allowed(w, p_object) then
    perform telegram.restore(prev);
    return jsonb_build_object('error', 'object_not_allowed');
  end if;
  if w->>'kind' = 'user' then
    select coalesce(array_agg(o.id), '{}') into v_objects from objects o
     where o.company_id = v_company and public.can_see(o.id);
  else
    select coalesce(array_agg(x::uuid), '{}') into v_objects from jsonb_array_elements_text(w->'objects') x;
  end if;

  select jsonb_build_object(
    'kind', w->>'kind',
    'layers', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'name_i18n', l.name_i18n)
                                         order by l.sort, l.name)
                          from layers l where l.company_id = v_company), '[]'::jsonb),
    'objects', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'name', o.name,
                                  'city', coalesce(nullif(btrim(o.city), ''), split_part(coalesce(o.address, ''), ',', 1)),
                                  'lat', o.lat, 'lng', o.lng) order by o.name)
                           from objects o where o.id = any (v_objects)), '[]'::jsonb),
    'places', coalesce((select jsonb_agg(x order by x->>'object_name', x->>'name') from (
                          select jsonb_build_object('id', l.id, 'object_id', l.object_id, 'name', l.name, 'code', l.code,
                                   'object_name', o.name,
                                   'object_city', coalesce(nullif(btrim(o.city), ''), split_part(coalesce(o.address, ''), ',', 1))) as x
                            from locations l join objects o on o.id = l.object_id
                           where l.object_id = any (v_objects)
                             and (p_object is null or l.object_id = p_object)
                             and (w->>'kind' <> 'user' or public.can_see(l.object_id, null, null, l.id))
                           order by (l.object_id = (w->>'object_id')::uuid) desc nulls last, o.name, l.name
                           limit 150) s), '[]'::jsonb),
    'assets', coalesce((select jsonb_agg(x) from (
                          select jsonb_build_object('id', a.id, 'name', a.name, 'location_id', a.location_id,
                                   'location_name', l.name, 'location_code', l.code, 'object_id', l.object_id,
                                   'object_name', o.name, 'floor_id', coalesce(a.floor_id, l.floor_id),
                                   'floor_name', f.name, 'kind', a.meta->>'kind', 'layer_id', a.layer_id,
                                   'manufacturer', a.manufacturer, 'model', a.model, 'serial_no', a.serial_no,
                                   'inventory_no', a.inventory_no,
                                   'open_order', exists (select 1 from work_orders wo where wo.asset_id = a.id
                                                           and wo.status not in ('done', 'cancelled'))) as x
                            from assets a join locations l on l.id = a.location_id join objects o on o.id = l.object_id
                            left join floors f on f.id = coalesce(a.floor_id, l.floor_id)
                           where l.object_id = any (v_objects)
                             and (coalesce(p_object, (w->>'object_id')::uuid) is null
                                  or l.object_id = coalesce(p_object, (w->>'object_id')::uuid))
                             and (w->>'kind' <> 'user' or public.can_see(l.object_id, a.layer_id, a.id, a.location_id))
                           limit 500) s), '[]'::jsonb)
  ) into res;
  perform telegram.restore(prev);
  return res;
end $$;

-- Сменить объект чата (кнопки объектов, геопозиция). Группа — объект постоянный.
create or replace function public.tg_set_object(p_chat bigint, p_object uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  w jsonb := telegram.who(p_chat, false);
  prev text[];
  ok boolean;
begin
  if w->>'kind' not in ('user', 'guest') or p_object is null then
    return jsonb_build_object('error', 'not_allowed');
  end if;
  prev := telegram.act_as(case when w->>'kind' = 'user' then (w->>'profile_id')::uuid end);
  ok := telegram.object_allowed(w, p_object);
  perform telegram.restore(prev);
  if not ok then
    return jsonb_build_object('error', 'not_allowed');
  end if;
  if w->>'kind' = 'user' then
    update telegram_links set last_object_id = p_object where chat_id = p_chat;
  else
    update telegram_guests set last_object_id = p_object, last_seen_at = now() where chat_id = p_chat;
  end if;
  return jsonb_build_object('ok', true, 'object',
    (select jsonb_build_object('id', o.id, 'name', o.name,
              'city', coalesce(nullif(btrim(o.city), ''), split_part(coalesce(o.address, ''), ',', 1)))
       from objects o where o.id = p_object));
end $$;

-- Ближайший доступный объект в радиусе [p_radius] м (геопозиция из Telegram).
create or replace function public.tg_nearest_object(p_chat bigint, p_lat double precision, p_lng double precision,
                                                    p_radius integer default 300)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  w jsonb := telegram.who(p_chat, false);
  prev text[];
  r record;
begin
  if w->>'kind' not in ('user', 'guest') or p_lat is null or p_lng is null
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    return jsonb_build_object('error', 'not_allowed');
  end if;
  prev := telegram.act_as(case when w->>'kind' = 'user' then (w->>'profile_id')::uuid end);
  select o.id, o.name, coalesce(nullif(btrim(o.city), ''), split_part(coalesce(o.address, ''), ',', 1)) as city, d.m
    into r
    from objects o
    cross join lateral (select 2 * 6371000 * asin(sqrt(
        power(sin(radians(o.lat - p_lat) / 2), 2) +
        cos(radians(p_lat)) * cos(radians(o.lat)) * power(sin(radians(o.lng - p_lng) / 2), 2))) as m) d
   where o.company_id = (w->>'company_id')::uuid and o.lat is not null and o.lng is not null
     and telegram.object_allowed(w, o.id)
     and d.m <= least(greatest(coalesce(p_radius, 300), 50), 2000)
   order by d.m limit 1;
  perform telegram.restore(prev);
  if r.id is null then
    return jsonb_build_object('error', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'object', jsonb_build_object('id', r.id, 'name', r.name, 'city', r.city),
                            'distance_m', round(r.m));
end $$;

-- Создать заявку. p_order: {title, description, object_id, location_id,
-- asset_id, layer_id, priority, photo_path, reporter: {name, username}}.
-- Пользователь — как из приложения (created_by = он, те же триггеры и зона);
-- гость и группа — только на объекте своей ссылки, created_by = null,
-- reporter.guest = true, статус «новая» (подрядчика назначает правило слоя,
-- как всегда). Фото «до» — файл, уже загруженный ботом в
-- work-photos/<компания>/<заявка>/…jpg.
create or replace function public.tg_create_order(p_chat bigint, p_group boolean, p_id uuid, p_order jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  w jsonb := telegram.who(p_chat, p_group);
  v_kind text := w->>'kind';
  v_company uuid;
  v_uid uuid;
  prev text[];
  v_object uuid;
  v_location uuid;
  v_asset uuid;
  v_layer uuid;
  v_layer_name text;
  v_priority text := coalesce(nullif(p_order->>'priority', ''), 'normal');
  v_title text := left(btrim(coalesce(p_order->>'title', '')), 200);
  v_desc text := nullif(left(btrim(coalesce(p_order->>'description', '')), 2000), '');
  v_photo text := nullif(p_order->>'photo_path', '');
  v_reporter jsonb;
  n integer;
  r record;
  uuid_re constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
begin
  if v_kind not in ('user', 'guest', 'group') then
    return jsonb_build_object('error', case when v_kind = 'guest_off' then 'link_disabled' else 'not_linked' end);
  end if;
  if p_id is null or v_title = '' or v_priority not in ('low', 'normal', 'high', 'critical') then
    return jsonb_build_object('error', 'bad_order');
  end if;
  for r in select k from unnest(array['object_id', 'location_id', 'asset_id', 'layer_id']) k loop
    if coalesce(p_order->>r.k, '') <> '' and (p_order->>r.k) !~ uuid_re then
      return jsonb_build_object('error', 'bad_order');
    end if;
  end loop;
  v_company := (w->>'company_id')::uuid;
  v_uid := case when v_kind = 'user' then (w->>'profile_id')::uuid end;
  v_object := nullif(p_order->>'object_id', '')::uuid;
  v_location := nullif(p_order->>'location_id', '')::uuid;
  v_asset := nullif(p_order->>'asset_id', '')::uuid;
  v_layer := nullif(p_order->>'layer_id', '')::uuid;

  -- Лимиты (по журналу заявок бота).
  if v_kind = 'user' then
    select count(*) into n from telegram.orders where profile_id = v_uid and created_at > now() - interval '1 hour';
    if n >= 30 then return jsonb_build_object('error', 'rate_limited'); end if;
  elsif v_kind = 'group' then
    select count(*) into n from telegram.orders where chat_id = p_chat and created_at > now() - interval '1 hour';
    if n >= 30 then return jsonb_build_object('error', 'rate_limited'); end if;
  else
    select count(*) into n from telegram.orders where chat_id = p_chat and created_at > now() - interval '1 hour';
    if n >= 5 then return jsonb_build_object('error', 'rate_limited'); end if;
    select count(*) into n from telegram.orders
     where link_id = (w->>'link_id')::uuid and created_at > now() - interval '1 day';
    if n >= 30 then return jsonb_build_object('error', 'rate_limited_link'); end if;
  end if;

  prev := telegram.act_as(v_uid);
  begin
    -- Объект: из заявки, иначе объект ссылки / группы.
    v_object := coalesce(v_object, case when v_kind in ('guest', 'group') then (w->>'object_id')::uuid end);
    if not telegram.object_allowed(w, v_object) then
      perform telegram.restore(prev);
      return jsonb_build_object('error', 'object_not_allowed');
    end if;
    -- Помещение и оборудование — только этого объекта и видимые.
    if v_location is not null and (v_object is null or not exists (
         select 1 from locations l where l.id = v_location and l.object_id = v_object)) then
      v_location := null;
    end if;
    if v_asset is not null then
      select a.location_id into r from assets a join locations l on l.id = a.location_id
       where a.id = v_asset and l.object_id = v_object;
      if not found then
        v_asset := null;
      else
        v_location := coalesce(v_location, r.location_id);
      end if;
    end if;
    if v_layer is not null then
      select l.name into v_layer_name from layers l where l.id = v_layer and l.company_id = v_company;
      if not found then v_layer := null; end if;
    end if;
    if v_kind = 'user' and not public.can_see(v_object, v_layer, v_asset, v_location) then
      perform telegram.restore(prev);
      return jsonb_build_object('error', 'object_not_allowed');
    end if;
    -- Фото: только в папке этой заявки и только уже загруженное.
    if v_photo is not null and (
         v_photo !~ ('^' || v_company::text || '/' || p_id::text || '/[A-Za-z0-9_-]{1,64}\.jpg$')
         or not exists (select 1 from storage.objects so where so.bucket_id = 'work-photos' and so.name = v_photo)) then
      v_photo := null;
    end if;

    v_reporter := jsonb_strip_nulls(jsonb_build_object(
      'name', nullif(left(btrim(coalesce(p_order#>>'{reporter,name}', '')), 80), ''),
      'username', nullif(left(regexp_replace(coalesce(p_order#>>'{reporter,username}', ''), '[^A-Za-z0-9_]', '', 'g'), 32), ''),
      'guest', v_kind <> 'user',
      'group', case when v_kind = 'group' then
                 nullif(left((select g.title from telegram_groups g where g.chat_id = p_chat), 80), '') end));

    perform set_config('hh.telegram', '1', true);
    insert into work_orders(id, company_id, object_id, location_id, asset_id, title, description,
                            layer_id, work_type, priority, status, input_channel, created_by, reporter)
    values (p_id, v_company, v_object, v_location, v_asset, v_title, v_desc,
            v_layer, v_layer_name, v_priority, 'new', 'telegram', v_uid, v_reporter);
    if v_photo is not null then
      insert into attachments(work_order_id, kind, stage, storage_path, taken_at, uploaded_by)
      values (p_id, 'photo', 'before', v_photo, now(), v_uid);
    end if;
    insert into telegram.orders(work_order_id, chat_id, link_id, profile_id)
    values (p_id, p_chat, nullif(w->>'link_id', '')::uuid, v_uid);
    perform telegram.restore(prev);
  exception when others then
    perform telegram.restore(prev);
    raise;
  end;
  delete from telegram.sessions where chat_id = p_chat;

  select wo.status, wo.priority, o.name as object_name, l.name as location_name, c.org_name
    into r
    from work_orders wo
    left join objects o on o.id = wo.object_id
    left join locations l on l.id = wo.location_id
    left join contractors c on c.id = wo.assigned_contractor_id
   where wo.id = p_id;
  return jsonb_build_object('ok', true, 'id', p_id, 'number', upper(left(p_id::text, 6)),
    'status', r.status, 'priority', r.priority, 'object_name', r.object_name,
    'location_name', r.location_name, 'contractor', r.org_name, 'photo', v_photo is not null);
end $$;

-- Черновик разговора (30 минут).
create or replace function public.tg_session_get(p_chat bigint)
returns jsonb language sql volatile security definer set search_path = public as $$
  select s.state from telegram.sessions s
   where s.chat_id = p_chat and s.updated_at > now() - interval '30 minutes';
$$;

create or replace function public.tg_session_put(p_chat bigint, p_state jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if p_state is null then
    delete from telegram.sessions where chat_id = p_chat;
    return;
  end if;
  if length(p_state::text) > 20000 then
    raise exception 'session too large' using errcode = '22023';
  end if;
  insert into telegram.sessions(chat_id, state, updated_at) values (p_chat, p_state, now())
  on conflict (chat_id) do update set state = excluded.state, updated_at = now();
end $$;

-- Права: функции бота — только service_role; приложение их не вызывает.
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.tg_take_update(bigint)',
    'public.tg_cleanup()',
    'public.tg_resolve_chat(bigint, boolean)',
    'public.tg_link_chat(text, bigint, text, text, text)',
    'public.tg_guest_start(text, bigint, text, text)',
    'public.tg_reset(bigint)',
    'public.tg_connect_group(text, bigint, text)',
    'public.tg_context(bigint, boolean, uuid)',
    'public.tg_set_object(bigint, uuid)',
    'public.tg_nearest_object(bigint, double precision, double precision, integer)',
    'public.tg_create_order(bigint, boolean, uuid, jsonb)',
    'public.tg_session_get(bigint)',
    'public.tg_session_put(bigint, jsonb)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- Таблицы схемы telegram — только через функции выше (даже не service_role).
revoke all on all tables in schema telegram from service_role;
```

## Что сделать вам
1. **Слить PR** этого шага (GitHub → Pull requests → «Шаг 23» → Merge).
2. **Миграция 0018:** GitHub → **Actions** → **Apply migration** → Run workflow → поле `file`: `0018_telegram.sql` → Run workflow → прочитать текст → **Review deployments** → `production-db` → **Approve and deploy**. Потом напишите мне «применена 0018». (Если 0017 ещё не применена — сначала её, `0017_photo_identify.sql`.)
3. **Бот в Telegram** (если ещё не создан): в Telegram откройте **@BotFather** → `/newbot` → имя «Hey Helpy» → username **`HeyHelpy_bot`** → BotFather пришлёт **токен**. Никому его не показывайте и не присылайте мне. ⚠️ Если имя `HeyHelpy_bot` занято — напишите мне, какое получилось: его нужно поменять в двух местах кода (`BOT_USERNAME` и `kTelegramBot`).
4. **Придумайте секрет вебхука** — 30–40 латинских букв и цифр подряд (например, сгенерировать менеджером паролей, без пробелов и спецзнаков).
5. **Секреты в Supabase:** Supabase → Edge Functions → **Secrets** → добавить `TELEGRAM_BOT_TOKEN` (токен из п. 3) и `TELEGRAM_WEBHOOK_SECRET` (из п. 4).
6. **Те же два секрета в GitHub:** Settings → Environments → `production-db` → Environment secrets → `TELEGRAM_BOT_TOKEN` и `TELEGRAM_WEBHOOK_SECRET` (значения — те же).
7. **Голосовые в боте:** Yandex Cloud → каталог (тот же, что в `YANDEX_FOLDER_ID`) → **Права доступа** → сервисный аккаунт ключа → **Изменить роли** → добавить **`ai.speechkit-stt.user`** → Сохранить. Без этого бот на голосовое ответит «Не расслышал. Повторите голосом или напишите текстом», а в логе функции будет код ошибки распознавания.
8. **Deploy functions:** Actions → **Deploy functions** → Run workflow (ветка `main`) → Approve. В Summary — `voice-intake=401 photo-identify=401 telegram-bot=401` (401 — правильно: без токена / секрета функция не пускает).
9. **Telegram webhook:** Actions → **Telegram webhook** → Run workflow (ветка `main`, `action`: `set`) → Approve. В Summary — адрес функции и «последняя ошибка: нет».
10. **Refresh demo** (после п. 2) — появятся заявки 277–278 из Telegram. ⚠️ Как всегда, удалятся тестовые заявки «Демо БЦ».
11. Сайт — Ctrl+Shift+R; Android — свежий APK по ссылке из `CLAUDE.md`.

## Как проверить руками
- **Привязка аккаунта:** приложение → Профиль → Настройки → **Telegram** → «Подключить Telegram» → «Открыть Telegram» (или наведите камеру телефона на QR) → в боте «Запустить» → бот: «Готово, <имя>. Теперь можно писать заявки сюда…». В приложении — «Подключён: …».
- **Заявка текстом:** боту — «Не работает кондиционер в переговорной 301» → карточка с объектом, местом, системой «Климат», срочностью → «✅ Создать» → бот присылает номер и «Открыть в приложении». Заявка видна в приложении с пометкой «Telegram» (список обновится сам за 15 с).
- **Голосом:** голосовое до 30 с → то же.
- **Фото:** снимок кондиционера → «Кондиционер … · Климат», кандидат из реестра → «✅ Создать» → в заявке фото «до».
- **Гость по QR:** менеджер → карточка «БЦ «Демо»» → «Заявки через Telegram» → «Создать ссылку и QR-код» → «Плакат для печати (PDF)». С **другого** Telegram-аккаунта (без привязки) отсканировать QR → бот: «Вы в БЦ «Демо». Опишите, что случилось…» → написать проблему → «Создать». В приложении — «Написал в Telegram · гость».
- **«Создать новую ссылку»** → старый QR перестаёт работать (бот: «Ссылка не работает: её отключили или пересоздали…»).
- **Группа:** карточка объекта → «Группы Telegram» → «Подключить группу» → «Добавить бота в группу» → выбрать группу. В группе: «@HeyHelpy_bot течёт кран на кухне» → карточка; сообщения без упоминания бот не читает; кнопки чужого черновика не нажимаются.
- **Незнакомый человек** пишет боту без ссылки → бот объясняет, как получить ссылку, и не показывает ни компаний, ни объектов.
- Английский язык Telegram → бот отвечает по-английски.
- `/where`, `/cancel`, `/help` — понятные ответы.

## Ограничения и что не сделано
- ⚠️ **Живой бот не проверен**: функция не выложена, у Claude Code нет токена бота и ключей (и не должно быть). Проверено тестами без сети (30), тестами базы (73) и предпросмотром экранов на локальной базе.
- ⚠️ Имя бота `HeyHelpy_bot` записано в коде; если оно в Telegram занято — нужна правка в двух местах (см. «Что сделать вам», п. 3).
- ⚠️ Голосовые — SpeechKit v1 (синхронный): до 30 с и 1 МБ; длиннее — бот просит короче или текстом.
- Заявки гостей без шага подтверждения менеджером (см. «Решения»): защита — лимиты и замена / отключение ссылки.
- Уведомлений из приложения в Telegram (статус заявки сменился) нет — только ответ на созданную заявку. Кандидат на следующий шаг.
- Старые черновики и коды чистит `tg_cleanup()` при работе бота; отдельного расписания (cron) нет.
- Сквозные тесты `tools/e2e` под Telegram не дополнял: бот в браузере не проверить, его логика покрыта `bot_test.ts`.

## Журнал
| Время | Что сделано | Коммит |
|---|---|---|
| 13.10 | Ветка, отчёт | 0f651bc |
| 13.10 | Блок 1: миграция 0018, тесты `telegram.sql` (73 ✅), все 914 ✅ | 548dde8 |
| 13.10 | Черновой PR #21 | — |
| 13.10 | Блок 2 (часть): `telegram-bot` — texts.ts, telegram.ts, stt.ts, bot.ts, index.ts; `deno check` ✅, тестов ещё нет | d7a1267 |
| 13.10 | Блок 2: `bot_test.ts` (30 тестов без сети), `config.toml` (`verify_jwt = false`), `telegram-bot` в «Deploy functions»; `deno test` 67 ✅ | 8b6baa6 |
| 13.10 | Блок 3: `.github/workflows/telegram-webhook.yml` (set / info / delete, команды из `texts.ts`) | 0e8a56f |
| 13.10 | Блок 4: приложение — `lib/features/telegram/` (Настройки → Telegram, QR и плакат объекта, ссылка компании, группы), `AppQrCode`, маршрут `/orders/:id`, канал `telegram`, автор из Telegram в карточке, автообновление списка 15 с; бот: `/start grp_<код>`; flutter test 372 ✅ | b57d092 |
| 13.10 | Блок 5 (часть): демо-заявки 277–278 (блок 5g), предпросмотр `docs/screens/preview23/` (17 ✅), кадр питча 19, `CLAUDE.md`, `DEMO_SCRIPT.md` | 69d6120 |
| 13.10 | `/check`: всё ✅; название листа шаблона импорта — через перевод (`importTemplateSheetName`) | 595a64f |
| 13.10 | `/screens`, итоговый отчёт, PR готов к проверке | (этот) |

## Где остановился
Шаг закончен: блоки 1–5 готовы, `/check` и `/screens` пройдены, PR #21 переведён из черновика в «готов к проверке». Ждёт проверки и слияния пользователем, затем — «Что сделать вам» (0018, секреты, выкладка, webhook, Refresh demo).
