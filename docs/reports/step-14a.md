# Шаг 14a: миграция планов этажей (0013)

Ветка `step-14a`. В этом шаге **только база и документация**: экранов нет, код приложения
не менялся. Миграция **не применена** — её применяете вы (см. «Как применить»).

## Что сделано (по пунктам задания)

1. **Таблица `floors`** (этажи объекта): `id`, `company_id`, `object_id` (удаление объекта
   удаляет его этажи), `name` (1–60 символов, уникально внутри объекта), `level` (может быть
   отрицательным), `sort` (по умолчанию 0), `plan_path` (путь картинки, может быть пустым),
   `plan_w` / `plan_h` (> 0, если заданы), `created_by` (по умолчанию — кто создал),
   `created_at`, `updated_at` (обновляется сам, той же функцией, что у заявок).
   Индексы по `object_id` и `company_id`.
   Триггер `trg_floors_check`: компания этажа должна совпадать с компанией объекта.
   Дополнительно: **перенести этаж в другой объект нельзя** — иначе у его помещений
   остался бы этаж чужого объекта.
2. **`locations` и `assets`**: новые столбцы `floor_id` (удаление этажа → пусто),
   `plan_x`, `plan_y` (доли 0..1; оба пустые или оба заданы — проверка в базе),
   `plan_shape` (jsonb, на будущее). Триггеры `trg_locations_floor_check` и
   `trg_assets_floor_check`: этаж — только из того же объекта (у оборудования объект
   берётся через его помещение). Индексы по `floor_id`.
3. **Доступ к `floors`** — как к объектам в 0008: читает вся своя компания, создаёт /
   меняет / удаляет только менеджер (и админ) своей компании. Анонимам доступа нет.
   **Помещения и оборудование:** проверил политики в рабочей базе (запрос только на
   чтение) — изменять `locations` и `assets` может только менеджер (`locations_manage`,
   `assets_manage` из 0008), у исполнителя и заявителя только чтение. Значит, `plan_*` и
   `floor_id` они поменять не могут, отдельное закрытие не нужно — политики не менялись.
4. **Хранилище `floor-plans`**: закрытое, до 15 МБ, только PNG / JPEG / WebP. Путь
   `<company_id>/<object_id>/<floor_id>/<имя>`. Читать — участники своей компании
   (первая папка = своя компания). Загружать и заменять — только менеджер своей
   компании и **только в папку уже созданного этажа** (этаж, объект и компания в пути
   должны совпадать — чуть строже, чем в задании). Удалять — менеджер своей компании
   (в том числе файлы уже удалённого этажа). Публичных ссылок нет.
5. Ничего не удаляется и не переименовывается. В конце файла — 4 запроса для проверки.

Также:
- **CLAUDE.md**: 0013 добавлена в список «База данных» с пометкой «ещё не применена»,
  следующий свободный номер — 0014; новый раздел «Планы этажей (данные)» (таблицы, поля,
  бакет, доступ, правило про реальные планы); описание хука обновлено.
  Строка «Применённые миграции» **не менялась**.
- **Хук `block_secrets.sh`**: коммит останавливается, если в нём есть картинка или PDF
  (`*.png`, `*.jpg`, `*.jpeg`, `*.webp`, `*.pdf`, без учёта регистра) вне `docs/screens/`,
  `docs/design/`, `assets/`, `tools/screens/`. ⚠️ Добавил ещё два исключения, которых не было
  в задании: `android/app/src/main/res/` и `web/` — там уже лежат значки приложения
  (`ic_launcher.png`, `favicon.png`, `Icon-192.png` и др.), иначе их нельзя было бы
  поменять. Проверено: `tmpimg/plan.PNG` — коммит остановлен, `docs/screens/…png` — пропущен.

## Новые и изменённые файлы
- `supabase/migrations/0013_floor_plans.sql` — новая миграция (этажи, точки на плане, бакет).
- `.claude/hooks/block_secrets.sh` — запрет коммитить картинки и PDF вне разрешённых папок.
- `CLAUDE.md` — раздел «Планы этажей (данные)», 0013 в списке миграций, описание хука.
- `docs/reports/step-14a.md` — этот отчёт.

## Проверки
- `/check`: ✅ анализ — без замечаний; ✅ тесты — 116 прошли; ✅ веб-сборка — собирается;
  ✅ строки вне переводов — нарушений нет (кириллица только в словаре разбора, `debugPrint`
  и названиях языков); ✅ название продукта — нарушений нет.
- Синтаксис миграции проверен разборщиком PostgreSQL (`libpg-query`): 47 команд, ошибок нет.
  Настоящей базы для пробного запуска здесь нет — окончательная проверка будет при применении
  (при любой ошибке workflow откатывает всю миграцию).
- Проверка имён миграций (как в «PR check»): номер 0013 свободен.
- `/screens` **не запускался**: экраны в этом шаге не менялись, снимки были бы те же, что в 13b.

## Полный текст миграции

Зачем: хранить этажи объекта с картинкой плана и места помещений / оборудования на нём —
основа для экрана «План этажа» в шаге 14b.
Что меняет: новая таблица `floors`, 4 новых столбца у `locations` и у `assets`, 3 триггера-
проверки, новый бакет `floor-plans` и 4 политики хранилища. Существующие данные не трогает:
новые столбцы пустые.
Повторный запуск безопасен: `create table/index if not exists`, `add column if not exists`,
`drop … if exists` перед каждым ограничением, триггером и политикой, `on conflict` для бакета.
В начале проверка: если 0008 не применена — остановка с понятным сообщением.

```sql
-- =====================================================================
-- hey_helpy · Миграция 0013: планы этажей (только данные, без экранов)
-- 1) Таблица floors: этажи объекта; у этажа может быть картинка плана
--    (путь в Storage и размер в пикселях).
-- 2) locations и assets: на каком этаже и где на плане (доли 0..1 от
--    ширины и высоты картинки); plan_shape — на будущее (контур помещения).
-- 3) Доступ к floors как к объектам (0008): видит вся компания, меняет
--    только менеджер. Помещения и оборудование и так меняет только
--    менеджер (0008) — новые столбцы plan_* под той же защитой.
-- 4) Закрытое хранилище floor-plans. Путь файла:
--    <company_id>/<object_id>/<floor_id>/<имя>
--    Читает своя компания, загружает и удаляет только менеджер.
--
-- Зависит от: 0008 (политики справочников, my_company_id, is_manager,
-- touch_updated_at).
-- Применяет пользователь: GitHub Actions «Apply migration» (с одобрением)
-- или Supabase → SQL Editor. Без begin/commit: workflow сам выполняет
-- файл одной транзакцией (--single-transaction), SQL Editor — тоже одним
-- запросом. Ничего не удаляет и не переименовывает. Безопасно запускать
-- повторно.
-- =====================================================================

do $$
begin
  if to_regprocedure('public.trg_wo_guard()') is null then
    raise exception '0013: сначала примените миграцию 0008 (исправления безопасности)';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 1. Этажи
-- ---------------------------------------------------------------------
create table if not exists public.floors (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id  uuid not null references public.objects(id) on delete cascade,
  name       text not null,
  level      int,                         -- номер этажа, может быть отрицательным (подвал)
  sort       int not null default 0,      -- порядок в списке этажей
  plan_path  text,                        -- путь в Storage (бакет floor-plans); null — этаж без картинки
  plan_w     int,                         -- ширина картинки, px
  plan_h     int,                         -- высота картинки, px
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.floors drop constraint if exists floors_name_check;
alter table public.floors add constraint floors_name_check
  check (char_length(btrim(name)) between 1 and 60);

alter table public.floors drop constraint if exists floors_plan_size_check;
alter table public.floors add constraint floors_plan_size_check
  check ((plan_w is null or plan_w > 0) and (plan_h is null or plan_h > 0));

create unique index if not exists floors_object_name_key on public.floors (object_id, name);
create index if not exists idx_floors_object  on public.floors (object_id);
create index if not exists idx_floors_company on public.floors (company_id);

-- updated_at — та же функция, что у заявок (0003)
drop trigger if exists trg_floors_updated_at on public.floors;
create trigger trg_floors_updated_at
  before update on public.floors
  for each row execute function public.touch_updated_at();

-- Компания этажа = компания его объекта; перенести этаж в другой объект
-- нельзя (у его помещений и оборудования остался бы чужой этаж).
create or replace function public.trg_floors_check()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_company uuid;
begin
  if tg_op = 'UPDATE' and new.object_id is distinct from old.object_id then
    raise exception 'floor object cannot be changed' using errcode = '42501';
  end if;
  select company_id into v_company from objects where id = new.object_id;
  if v_company is null or v_company is distinct from new.company_id then
    raise exception 'floor company must match object company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_floors_check on public.floors;
create trigger trg_floors_check
  before insert or update on public.floors
  for each row execute function public.trg_floors_check();

-- ---------------------------------------------------------------------
-- 2. Помещения и оборудование: этаж и точка на плане
-- ---------------------------------------------------------------------
alter table public.locations
  add column if not exists floor_id   uuid references public.floors(id) on delete set null,
  add column if not exists plan_x     real,
  add column if not exists plan_y     real,
  add column if not exists plan_shape jsonb;

alter table public.assets
  add column if not exists floor_id   uuid references public.floors(id) on delete set null,
  add column if not exists plan_x     real,
  add column if not exists plan_y     real,
  add column if not exists plan_shape jsonb;

-- Точка: оба null или оба заданы, каждая координата — доля от 0 до 1.
alter table public.locations drop constraint if exists locations_plan_xy_check;
alter table public.locations add constraint locations_plan_xy_check
  check ((plan_x is null) = (plan_y is null)
         and (plan_x is null or (plan_x between 0 and 1 and plan_y between 0 and 1)));

alter table public.assets drop constraint if exists assets_plan_xy_check;
alter table public.assets add constraint assets_plan_xy_check
  check ((plan_x is null) = (plan_y is null)
         and (plan_x is null or (plan_x between 0 and 1 and plan_y between 0 and 1)));

create index if not exists idx_locations_floor on public.locations (floor_id);
create index if not exists idx_assets_floor    on public.assets (floor_id);

-- Этаж помещения — из того же объекта, что и помещение.
create or replace function public.trg_locations_floor_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.floor_id is not null and not exists (
       select 1 from floors f where f.id = new.floor_id and f.object_id = new.object_id) then
    raise exception 'floor must belong to the same object' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_locations_floor_check on public.locations;
create trigger trg_locations_floor_check
  before insert or update on public.locations
  for each row execute function public.trg_locations_floor_check();

-- Этаж оборудования — из того же объекта, что и его помещение.
create or replace function public.trg_assets_floor_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.floor_id is not null and not exists (
       select 1 from floors f
         join locations l on l.object_id = f.object_id
        where f.id = new.floor_id and l.id = new.location_id) then
    raise exception 'floor must belong to the same object' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_assets_floor_check on public.assets;
create trigger trg_assets_floor_check
  before insert or update on public.assets
  for each row execute function public.trg_assets_floor_check();

-- Триггерные функции вызываются только базой, напрямую — никем (как в 0008).
revoke all on function public.trg_floors_check()          from public, anon, authenticated;
revoke all on function public.trg_locations_floor_check() from public, anon, authenticated;
revoke all on function public.trg_assets_floor_check()    from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Доступ к этажам — как к объектам (0008)
-- ---------------------------------------------------------------------
alter table public.floors enable row level security;

revoke all on public.floors from anon;
grant select, insert, update, delete on public.floors to authenticated;

drop policy if exists floors_select on public.floors;
drop policy if exists floors_manage on public.floors;
create policy floors_select on public.floors for select
  using (company_id = (select public.my_company_id()));
create policy floors_manage on public.floors for all
  using (company_id = (select public.my_company_id()) and (select public.is_manager()))
  with check (company_id = (select public.my_company_id()) and (select public.is_manager()));

-- Помещения и оборудование: политики не меняем. В 0008 изменять их может
-- только менеджер (locations_manage, assets_manage), у исполнителя и
-- заявителя есть только чтение — значит, plan_* и floor_id они не поменяют.

-- ---------------------------------------------------------------------
-- 4. Хранилище планов
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('floor-plans', 'floor-plans', false, 15728640,
        array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists floor_plans_select on storage.objects;
drop policy if exists floor_plans_insert on storage.objects;
drop policy if exists floor_plans_update on storage.objects;
drop policy if exists floor_plans_delete on storage.objects;

-- Папки пути: [1] — компания, [2] — объект, [3] — этаж. Сравниваем как текст,
-- чтобы кривой путь давал «нет доступа», а не ошибку приведения к uuid.
create policy floor_plans_select on storage.objects for select to authenticated using (
  bucket_id = 'floor-plans'
  and (storage.foldername(name))[1] = (select public.my_company_id())::text);

-- Загрузить можно только в папку существующего этажа своей компании.
create policy floor_plans_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'floor-plans'
  and (select public.is_manager())
  and (storage.foldername(name))[1] = (select public.my_company_id())::text
  and exists (select 1 from public.floors f
               where f.id::text        = (storage.foldername(name))[3]
                 and f.object_id::text = (storage.foldername(name))[2]
                 and f.company_id      = (select public.my_company_id())));

-- Замена файла (upsert) — так же, как загрузка.
create policy floor_plans_update on storage.objects for update to authenticated
  using (
    bucket_id = 'floor-plans'
    and (select public.is_manager())
    and (storage.foldername(name))[1] = (select public.my_company_id())::text)
  with check (
    bucket_id = 'floor-plans'
    and (select public.is_manager())
    and (storage.foldername(name))[1] = (select public.my_company_id())::text
    and exists (select 1 from public.floors f
                 where f.id::text        = (storage.foldername(name))[3]
                   and f.object_id::text = (storage.foldername(name))[2]
                   and f.company_id      = (select public.my_company_id())));

-- Удалить — менеджер своей компании (в том числе файлы уже удалённого этажа).
create policy floor_plans_delete on storage.objects for delete to authenticated using (
  bucket_id = 'floor-plans'
  and (select public.is_manager())
  and (storage.foldername(name))[1] = (select public.my_company_id())::text);
```

(В файле после этого ещё блок-комментарий с запросами для проверки — они ниже.)

## Как применить (после merge этого PR)
1. GitHub → **Actions** → **«Apply migration»** → **Run workflow** (ветка `main`).
2. В поле `file` — `0013_floor_plans.sql` → **Run workflow**.
3. Задача «Проверка и текст миграции» напечатает текст файла — прочитать.
4. **Review deployments** → `production-db` → **Approve and deploy**.
5. Итог — в Summary запуска. При любой ошибке вся миграция откатывается, база не меняется.
6. Написать мне «применена 0013» — тогда я допишу номер в «Применённые миграции».

Запасной способ: Supabase → SQL Editor → вставить весь файл → Run.

## Запросы для проверки (только чтение, SQL Editor, по одному)

```sql
-- 1) Таблица этажей и новые столбцы есть
select table_name, column_name, data_type
  from information_schema.columns
 where table_schema = 'public'
   and (table_name = 'floors'
        or (table_name in ('locations', 'assets')
            and column_name in ('floor_id', 'plan_x', 'plan_y', 'plan_shape')))
 order by table_name, ordinal_position;

-- 2) RLS включён, политики на месте (ожидается floors_select, floors_manage)
select c.relname, c.relrowsecurity, p.policyname, p.cmd
  from pg_class c left join pg_policies p
    on p.schemaname = 'public' and p.tablename = c.relname
 where c.oid = 'public.floors'::regclass;

-- 3) Бакет закрытый, 15 МБ, png/jpeg/webp
select id, public, file_size_limit, allowed_mime_types
  from storage.buckets where id = 'floor-plans';

-- 4) Политики хранилища и триггеры (4 политики floor_plans_*,
--    3 триггера-проверки + trg_floors_updated_at)
select 'policy' as kind, policyname as name from pg_policies
 where schemaname = 'storage' and policyname like 'floor_plans_%'
union all
select 'trigger', tgname from pg_trigger
 where not tgisinternal
   and tgrelid in ('public.floors'::regclass, 'public.locations'::regclass,
                   'public.assets'::regclass)
 order by 1, 2;
```

Ожидаемо: 1) 12 строк `floors` + по 4 у `locations` и `assets`; 2) `relrowsecurity = true`,
две политики; 3) `public = false`, `15728640`, три типа; 4) 4 политики и 4 триггера.
Можно также запустить `/db` — он сверит базу с файлами миграций.

## Что проверить в приложении
Ничего нового на экранах нет. После применения 0013 приложение должно работать как раньше
(новые столбцы пустые, старые запросы их не используют).

## Что будет в шаге 14b
- Экран «Этажи» в карточке объекта: список этажей, добавление / переименование / удаление
  (менеджер), загрузка картинки плана в `floor-plans` (размер записывается в `plan_w/plan_h`).
- Экран «План этажа»: картинка с масштабом и прокруткой, маркеры помещений и оборудования
  по `plan_x/plan_y`, расстановка маркеров перетаскиванием (менеджер), заявки на маркерах.
- Только компоненты дизайн-системы, строки на RU и EN.
- Для демо — нарисованная схема, **не** реальный план здания.

## Ограничения и что не сделано
- Миграция не применена (по правилам — применяете вы).
- Проверен только синтаксис; на настоящей базе не запускалась.
- `plan_shape` пока никак не проверяется (просто jsonb) — формат зададим в 14b или позже.
- Если оборудование переносят в помещение другого объекта, а `floor_id` остаётся старым,
  триггер это остановит — сначала нужно сменить или очистить этаж.
- `/screens` не запускался (экраны не менялись).
