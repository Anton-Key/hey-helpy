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

-- =====================================================================
-- Проверка после применения (только чтение; запускать в SQL Editor
-- по одному запросу):
--
-- 1) Таблица этажей и новые столбцы есть:
-- select table_name, column_name, data_type
--   from information_schema.columns
--  where table_schema = 'public'
--    and (table_name = 'floors'
--         or (table_name in ('locations', 'assets')
--             and column_name in ('floor_id', 'plan_x', 'plan_y', 'plan_shape')))
--  order by table_name, ordinal_position;
--
-- 2) RLS включён, политики на месте (ожидается floors_select, floors_manage):
-- select c.relname, c.relrowsecurity, p.policyname, p.cmd
--   from pg_class c left join pg_policies p
--     on p.schemaname = 'public' and p.tablename = c.relname
--  where c.oid = 'public.floors'::regclass;
--
-- 3) Бакет закрытый, 15 МБ, png/jpeg/webp:
-- select id, public, file_size_limit, allowed_mime_types
--   from storage.buckets where id = 'floor-plans';
--
-- 4) Политики хранилища и триггеры (ожидается 4 политики floor_plans_* и
--    3 триггера-проверки + trg_floors_updated_at):
-- select 'policy' as kind, policyname as name from pg_policies
--  where schemaname = 'storage' and policyname like 'floor_plans_%'
-- union all
-- select 'trigger', tgname from pg_trigger
--  where not tgisinternal
--    and tgrelid in ('public.floors'::regclass, 'public.locations'::regclass,
--                    'public.assets'::regclass)
--  order by 1, 2;
-- =====================================================================
