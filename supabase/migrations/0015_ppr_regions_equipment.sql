-- =====================================================================
-- hey_helpy · Миграция 0015: ППР, регионы и страны, реестр оборудования,
-- номера помещений (шаг 16)
-- 1) Регионы компании (regions): один общий список, без дублей —
--    «Европа», «европа », «ЕВРОПА» база считает одним регионом.
-- 2) Объект: страна (код ISO из двух заглавных латинских букв, не текст),
--    город, регион. Город у существующих объектов — из адреса (до запятой).
-- 3) Помещение: номер (locations.code), уникален внутри объекта.
-- 4) Оборудование: система (слой), производитель, модель, серийный номер,
--    дата ввода.
-- 5) ППР — регулярные работы по периодам (maintenance_plans). Задача
--    периода — обычная заявка с plan_id и границами периода. Функция
--    ppr_generate() создаёт задачи текущего периода, повторный вызов
--    ничего не дублирует.
-- 6) Жёсткое разделение компаний: у новых таблиц company_id и RLS по
--    компании; все ссылки (регион, план, слой, объект, помещение,
--    оборудование, подрядчик) проверяются триггерами на ту же компанию —
--    и у новых, и у старых таблиц (заявки, закрепления подрядчиков,
--    исполнители, метки), где раньше политика проверяла не все ссылки.
--
-- Зависит от: 0008 (политики, функции закрыты по умолчанию), 0013 (этажи).
-- Применяет пользователь: GitHub Actions «Apply migration» (с одобрением)
-- или Supabase → SQL Editor. Без begin/commit: workflow сам выполняет файл
-- одной транзакцией. Только добавления (таблицы, столбцы, функции,
-- триггеры, индексы, политики); ничего не удаляет и не переименовывает.
-- Ограничение work_orders.input_channel пересоздаётся с новым значением
-- 'ppr' (старые значения те же). Безопасно запускать повторно.
-- Проверено локально на PostgreSQL 16: tools/db_test/run.sh.
-- =====================================================================

do $$
begin
  if to_regclass('public.floors') is null then
    raise exception '0015: сначала примените миграцию 0013 (планы этажей)';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 0. Нормализация названий: регистр, пробелы по краям и внутри, «ё» → «е».
--    Используется в уникальных индексах (регионы, планы ППР).
-- ---------------------------------------------------------------------
create or replace function public.norm_name(p text)
returns text language sql immutable parallel safe
set search_path = pg_catalog
as $$
  select regexp_replace(btrim(replace(lower(coalesce(p, '')), 'ё', 'е')), '\s+', ' ', 'g');
$$;
revoke all on function public.norm_name(text) from public, anon;
grant execute on function public.norm_name(text) to authenticated;

-- ---------------------------------------------------------------------
-- 1. Регионы
-- ---------------------------------------------------------------------
create table if not exists public.regions (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name       text not null,
  sort       int  not null default 0,
  created_at timestamptz not null default now()
);

alter table public.regions drop constraint if exists regions_name_check;
alter table public.regions add constraint regions_name_check
  check (char_length(btrim(name)) between 1 and 60);

-- Уникальность — только внутри компании: у разных компаний могут быть
-- одинаковые «Европа».
create unique index if not exists regions_company_norm_key
  on public.regions (company_id, public.norm_name(name));
create index if not exists idx_regions_company on public.regions (company_id, sort);

alter table public.regions enable row level security;
revoke all on public.regions from anon;
grant select, insert, update, delete on public.regions to authenticated;

drop policy if exists regions_select on public.regions;
drop policy if exists regions_manage on public.regions;
create policy regions_select on public.regions for select
  using (regions.company_id = (select public.my_company_id()));
create policy regions_manage on public.regions for all
  using (regions.company_id = (select public.my_company_id()) and (select public.is_manager()))
  with check (regions.company_id = (select public.my_company_id()) and (select public.is_manager()));

-- ---------------------------------------------------------------------
-- 2. Объект: страна, город, регион
-- ---------------------------------------------------------------------
alter table public.objects
  add column if not exists country_code char(2),
  add column if not exists city         text,
  add column if not exists region_id    uuid references public.regions(id) on delete set null;

-- Страна — только код ISO 3166-1 (две заглавные латинские буквы), не текст.
alter table public.objects drop constraint if exists objects_country_code_check;
alter table public.objects add constraint objects_country_code_check
  check (country_code is null or country_code ~ '^[A-Z]{2}$');

alter table public.objects drop constraint if exists objects_city_check;
alter table public.objects add constraint objects_city_check
  check (city is null or char_length(btrim(city)) between 1 and 100);

-- Город у существующих объектов — часть адреса до первой запятой
-- (так же считает приложение: cityOf в lib/features/directory/city.dart).
update public.objects
   set city = btrim(split_part(address, ',', 1))
 where city is null
   and position(',' in coalesce(address, '')) > 1
   and char_length(btrim(split_part(address, ',', 1))) between 1 and 100;

create index if not exists idx_objects_region       on public.objects (region_id);
create index if not exists idx_objects_country      on public.objects (company_id, country_code);
create index if not exists idx_objects_city         on public.objects (company_id, lower(city));

-- Регион объекта — из той же компании.
create or replace function public.trg_objects_refs_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.region_id is not null
     and (tg_op = 'INSERT' or new.region_id is distinct from old.region_id
          or new.company_id is distinct from old.company_id)
     and not exists (select 1 from regions r
                      where r.id = new.region_id and r.company_id = new.company_id) then
    raise exception 'region must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_objects_refs_check on public.objects;
create trigger trg_objects_refs_check
  before insert or update on public.objects
  for each row execute function public.trg_objects_refs_check();

-- ---------------------------------------------------------------------
-- 3. Помещение: номер (код), уникален внутри объекта без учёта регистра
-- ---------------------------------------------------------------------
alter table public.locations add column if not exists code text;

alter table public.locations drop constraint if exists locations_code_check;
alter table public.locations add constraint locations_code_check
  check (code is null or char_length(btrim(code)) between 1 and 20);

create unique index if not exists locations_object_code_key
  on public.locations (object_id, lower(btrim(code))) where code is not null;

-- Родительское помещение — из той же компании (раньше не проверялось).
create or replace function public.trg_locations_refs_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.parent_id is not null
     and (tg_op = 'INSERT' or new.parent_id is distinct from old.parent_id
          or new.object_id is distinct from old.object_id)
     and not exists (select 1 from locations p
                       join objects po on po.id = p.object_id
                       join objects o  on o.id = new.object_id
                      where p.id = new.parent_id and po.company_id = o.company_id) then
    raise exception 'parent location must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_locations_refs_check on public.locations;
create trigger trg_locations_refs_check
  before insert or update on public.locations
  for each row execute function public.trg_locations_refs_check();

-- ---------------------------------------------------------------------
-- 4. Оборудование: система, производитель, модель, серийный номер, дата ввода.
--    Политики assets не меняются (0008: читает компания, меняет менеджер).
-- ---------------------------------------------------------------------
alter table public.assets
  add column if not exists layer_id     uuid references public.layers(id) on delete set null,
  add column if not exists manufacturer text,
  add column if not exists model        text,
  add column if not exists serial_no    text,
  add column if not exists installed_at date;

alter table public.assets drop constraint if exists assets_registry_text_check;
alter table public.assets add constraint assets_registry_text_check
  check (coalesce(char_length(manufacturer), 0) <= 120
     and coalesce(char_length(model), 0) <= 120
     and coalesce(char_length(serial_no), 0) <= 120);

create index if not exists idx_assets_layer on public.assets (layer_id);

-- Система оборудования — слой той же компании, что и объект помещения.
create or replace function public.trg_assets_refs_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.layer_id is not null
     and (tg_op = 'INSERT' or new.layer_id is distinct from old.layer_id
          or new.location_id is distinct from old.location_id)
     and not exists (select 1 from layers y
                       join objects o on o.company_id = y.company_id
                       join locations l on l.object_id = o.id
                      where y.id = new.layer_id and l.id = new.location_id) then
    raise exception 'layer must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_assets_refs_check on public.assets;
create trigger trg_assets_refs_check
  before insert or update on public.assets
  for each row execute function public.trg_assets_refs_check();

-- ---------------------------------------------------------------------
-- 5. Планы ППР
-- ---------------------------------------------------------------------
create table if not exists public.maintenance_plans (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  object_id      uuid not null references public.objects(id) on delete cascade,
  location_id    uuid references public.locations(id) on delete set null,
  asset_id       uuid references public.assets(id) on delete set null,
  layer_id       uuid not null references public.layers(id),
  title          text not null,
  description    text,
  period_kind    text not null default 'month',
  period_days    int,
  starts_on      date not null default current_date,
  checklist      jsonb not null default '[]'::jsonb,
  requires_photo boolean not null default true,
  priority       text not null default 'normal',
  active         boolean not null default true,
  created_by     uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.maintenance_plans drop constraint if exists maintenance_plans_title_check;
alter table public.maintenance_plans add constraint maintenance_plans_title_check
  check (char_length(btrim(title)) between 1 and 120);
alter table public.maintenance_plans drop constraint if exists maintenance_plans_period_check;
alter table public.maintenance_plans add constraint maintenance_plans_period_check
  check (period_kind in ('month', 'quarter', 'half_year', 'year', 'days')
         and ((period_kind = 'days') = (period_days is not null))
         and (period_days is null or period_days between 1 and 3660));
alter table public.maintenance_plans drop constraint if exists maintenance_plans_checklist_check;
alter table public.maintenance_plans add constraint maintenance_plans_checklist_check
  check (jsonb_typeof(checklist) = 'array' and jsonb_array_length(checklist) <= 50);
alter table public.maintenance_plans drop constraint if exists maintenance_plans_priority_check;
alter table public.maintenance_plans add constraint maintenance_plans_priority_check
  check (priority in ('low', 'normal', 'high', 'critical'));

-- Название плана уникально внутри объекта (то есть внутри компании).
create unique index if not exists maintenance_plans_object_title_key
  on public.maintenance_plans (company_id, object_id, public.norm_name(title));
create index if not exists idx_mplans_company on public.maintenance_plans (company_id, active);
create index if not exists idx_mplans_object  on public.maintenance_plans (object_id);
create index if not exists idx_mplans_layer   on public.maintenance_plans (layer_id);
create index if not exists idx_mplans_asset   on public.maintenance_plans (asset_id);

drop trigger if exists trg_mplans_updated_at on public.maintenance_plans;
create trigger trg_mplans_updated_at
  before update on public.maintenance_plans
  for each row execute function public.touch_updated_at();

-- Объект, помещение, оборудование, слой — одной компании и согласованы:
-- помещение — из объекта плана, оборудование — из этого объекта (и из
-- помещения плана, если оно задано).
create or replace function public.trg_mplans_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from objects o
                  where o.id = new.object_id and o.company_id = new.company_id) then
    raise exception 'plan object must belong to the same company' using errcode = '42501';
  end if;
  if not exists (select 1 from layers y
                  where y.id = new.layer_id and y.company_id = new.company_id) then
    raise exception 'plan layer must belong to the same company' using errcode = '42501';
  end if;
  if new.location_id is not null and not exists (
       select 1 from locations l
        where l.id = new.location_id and l.object_id = new.object_id) then
    raise exception 'plan location must belong to the plan object' using errcode = '42501';
  end if;
  if new.asset_id is not null and not exists (
       select 1 from assets a join locations l on l.id = a.location_id
        where a.id = new.asset_id and l.object_id = new.object_id
          and (new.location_id is null or a.location_id = new.location_id)) then
    raise exception 'plan asset must belong to the plan object' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_mplans_check on public.maintenance_plans;
create trigger trg_mplans_check
  before insert or update on public.maintenance_plans
  for each row execute function public.trg_mplans_check();

alter table public.maintenance_plans enable row level security;
revoke all on public.maintenance_plans from anon;
grant select, insert, update, delete on public.maintenance_plans to authenticated;

drop policy if exists mplans_select on public.maintenance_plans;
drop policy if exists mplans_manage on public.maintenance_plans;
create policy mplans_select on public.maintenance_plans for select
  using (maintenance_plans.company_id = (select public.my_company_id()));
create policy mplans_manage on public.maintenance_plans for all
  using (maintenance_plans.company_id = (select public.my_company_id()) and (select public.is_manager()))
  with check (maintenance_plans.company_id = (select public.my_company_id()) and (select public.is_manager()));

-- ---------------------------------------------------------------------
-- 6. Заявка: задача периода ППР
-- ---------------------------------------------------------------------
alter table public.work_orders
  add column if not exists plan_id      uuid references public.maintenance_plans(id) on delete set null,
  add column if not exists period_start date,
  add column if not exists period_end   date;

alter table public.work_orders drop constraint if exists work_orders_period_check;
alter table public.work_orders add constraint work_orders_period_check
  check ((period_start is null) = (period_end is null)
         and (period_start is null or period_end >= period_start));

-- Одна задача на план и период: повторная генерация ничего не дублирует.
create unique index if not exists work_orders_plan_period_key
  on public.work_orders (plan_id, period_start) where plan_id is not null;
create index if not exists idx_wo_plan       on public.work_orders (plan_id);
create index if not exists idx_wo_period_end on public.work_orders (company_id, period_end);

-- Канал «ppr» — задачу создал план ППР (остальные значения как в 0004).
alter table public.work_orders drop constraint if exists work_orders_input_channel_check;
alter table public.work_orders add constraint work_orders_input_channel_check
  check (input_channel = any (array['button','text','voice','camera','wake_word','ppr']));

-- Все ссылки заявки — из компании заявки. Раньше политика wo_insert
-- проверяла только company_id: можно было вписать чужой слой или
-- помещение. Проверяем только изменившиеся ссылки — смена статуса
-- ничего лишнего не читает.
-- BEFORE-триггеры идут по алфавиту: trg_wo_guard → trg_wo_layer_and_route →
-- trg_wo_refs_check → … — проверяется и подрядчик, назначенный правилом слоя.
create or replace function public.trg_wo_refs_check()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  c uuid := new.company_id;
  ins boolean := tg_op = 'INSERT';
begin
  if not ins and new.company_id is distinct from old.company_id then
    raise exception 'work order company cannot be changed' using errcode = '42501';
  end if;
  if new.object_id is not null and (ins or new.object_id is distinct from old.object_id)
     and not exists (select 1 from objects o where o.id = new.object_id and o.company_id = c) then
    raise exception 'object must belong to the same company' using errcode = '42501';
  end if;
  if new.location_id is not null and (ins or new.location_id is distinct from old.location_id)
     and not exists (select 1 from locations l join objects o on o.id = l.object_id
                      where l.id = new.location_id and o.company_id = c) then
    raise exception 'location must belong to the same company' using errcode = '42501';
  end if;
  if new.asset_id is not null and (ins or new.asset_id is distinct from old.asset_id)
     and not exists (select 1 from assets a join locations l on l.id = a.location_id
                       join objects o on o.id = l.object_id
                      where a.id = new.asset_id and o.company_id = c) then
    raise exception 'asset must belong to the same company' using errcode = '42501';
  end if;
  if new.layer_id is not null and (ins or new.layer_id is distinct from old.layer_id)
     and not exists (select 1 from layers y where y.id = new.layer_id and y.company_id = c) then
    raise exception 'layer must belong to the same company' using errcode = '42501';
  end if;
  if new.assigned_contractor_id is not null
     and (ins or new.assigned_contractor_id is distinct from old.assigned_contractor_id)
     and not exists (select 1 from contractors x
                      where x.id = new.assigned_contractor_id and x.company_id = c) then
    raise exception 'contractor must belong to the same company' using errcode = '42501';
  end if;
  if new.assigned_executor_id is not null
     and (ins or new.assigned_executor_id is distinct from old.assigned_executor_id)
     and not exists (select 1 from executors e join contractors x on x.id = e.contractor_id
                      where e.id = new.assigned_executor_id and x.company_id = c) then
    raise exception 'executor must belong to the same company' using errcode = '42501';
  end if;
  if new.plan_id is not null and (ins or new.plan_id is distinct from old.plan_id)
     and not exists (select 1 from maintenance_plans p
                      where p.id = new.plan_id and p.company_id = c) then
    raise exception 'plan must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_wo_refs_check on public.work_orders;
create trigger trg_wo_refs_check
  before insert or update on public.work_orders
  for each row execute function public.trg_wo_refs_check();

-- ---------------------------------------------------------------------
-- 7. Старые связи, где политика проверяла не все ссылки
--    (закрепления подрядчиков, подрядчик ↔ объект, исполнители, метки)
-- ---------------------------------------------------------------------
create or replace function public.trg_contractor_links_check()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_company uuid;
begin
  select x.company_id into v_company from contractors x where x.id = new.contractor_id;
  if tg_table_name = 'contractor_layers' then
    if not exists (select 1 from layers y where y.id = new.layer_id and y.company_id = v_company) then
      raise exception 'layer must belong to the contractor company' using errcode = '42501';
    end if;
  end if;
  if new.object_id is not null and not exists (
       select 1 from objects o where o.id = new.object_id and o.company_id = v_company) then
    raise exception 'object must belong to the contractor company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_contractor_layers_check on public.contractor_layers;
create trigger trg_contractor_layers_check
  before insert or update on public.contractor_layers
  for each row execute function public.trg_contractor_links_check();

drop trigger if exists trg_contractor_objects_check on public.contractor_objects;
create trigger trg_contractor_objects_check
  before insert or update on public.contractor_objects
  for each row execute function public.trg_contractor_links_check();

-- Исполнитель — сотрудник компании подрядчика (accept_invite сначала
-- переводит профиль в компанию, потом добавляет исполнителя).
create or replace function public.trg_executors_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.profile_id is not null and not exists (
       select 1 from profiles p join contractors x on x.company_id = p.company_id
        where p.id = new.profile_id and x.id = new.contractor_id) then
    raise exception 'executor must belong to the contractor company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_executors_check on public.executors;
create trigger trg_executors_check
  before insert or update on public.executors
  for each row execute function public.trg_executors_check();

-- Метка: оборудование и помещение (если заданы оба) — одной компании.
create or replace function public.trg_scan_tags_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.asset_id is not null and new.location_id is not null and not exists (
       select 1 from assets a
         join locations al on al.id = a.location_id join objects ao on ao.id = al.object_id
         join locations l  on l.id = new.location_id join objects lo on lo.id = l.object_id
        where a.id = new.asset_id and ao.company_id = lo.company_id) then
    raise exception 'scan tag asset and location must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_scan_tags_check on public.scan_tags;
create trigger trg_scan_tags_check
  before insert or update on public.scan_tags
  for each row execute function public.trg_scan_tags_check();

-- ---------------------------------------------------------------------
-- 8. Периоды ППР
--    period_bounds: начало и конец периода, в который попадает дата.
--    Месяц, квартал, полугодие, год — календарные; days — от starts_on
--    шагами по N дней.
-- ---------------------------------------------------------------------
create or replace function public.period_bounds(
  p_kind text, p_days int, p_starts_on date, p_on date,
  out period_start date, out period_end date)
language plpgsql immutable set search_path = pg_catalog as $$
declare
  n int;
begin
  if p_kind = 'month' then
    period_start := date_trunc('month', p_on)::date;
    period_end   := (period_start + interval '1 month' - interval '1 day')::date;
  elsif p_kind = 'quarter' then
    period_start := date_trunc('quarter', p_on)::date;
    period_end   := (period_start + interval '3 months' - interval '1 day')::date;
  elsif p_kind = 'half_year' then
    period_start := (date_trunc('year', p_on)
                     + case when extract(month from p_on) > 6 then interval '6 months'
                            else interval '0' end)::date;
    period_end   := (period_start + interval '6 months' - interval '1 day')::date;
  elsif p_kind = 'year' then
    period_start := date_trunc('year', p_on)::date;
    period_end   := (period_start + interval '1 year' - interval '1 day')::date;
  elsif p_kind = 'days' then
    if p_days is null or p_days < 1 or p_starts_on is null then
      raise exception 'period_days and starts_on are required for days';
    end if;
    n := floor((p_on - p_starts_on)::numeric / p_days)::int;
    period_start := p_starts_on + n * p_days;
    period_end   := period_start + p_days - 1;
  else
    raise exception 'unknown period kind %', p_kind;
  end if;
end $$;
revoke all on function public.period_bounds(text, int, date, date) from public, anon;
grant execute on function public.period_bounds(text, int, date, date) to authenticated;

-- Подпись периода: «октябрь 2026», «IV кв. 2026», «II полугодие 2026»,
-- «2026 год», «10.10–19.10.2026» (en: «October 2026», «Q4 2026», «H2 2026»…).
create or replace function public.period_label(
  p_kind text, p_start date, p_end date, p_locale text default 'ru')
returns text language plpgsql immutable set search_path = pg_catalog as $$
declare
  m int := extract(month from p_start);
  y text := extract(year from p_start)::text;
  en boolean := coalesce(p_locale, 'ru') = 'en';
  ru_months text[] := array['январь','февраль','март','апрель','май','июнь','июль',
                            'август','сентябрь','октябрь','ноябрь','декабрь'];
  en_months text[] := array['January','February','March','April','May','June','July',
                            'August','September','October','November','December'];
  roman text[] := array['I','II','III','IV'];
begin
  if p_kind = 'month' then
    return case when en then en_months[m] else ru_months[m] end || ' ' || y;
  elsif p_kind = 'quarter' then
    return case when en then 'Q' || ((m - 1) / 3 + 1) || ' ' || y
                else roman[(m - 1) / 3 + 1] || ' кв. ' || y end;
  elsif p_kind = 'half_year' then
    return case when en then 'H' || ((m - 1) / 6 + 1) || ' ' || y
                else roman[(m - 1) / 6 + 1] || ' полугодие ' || y end;
  elsif p_kind = 'year' then
    return case when en then y else y || ' год' end;
  else
    return to_char(p_start, 'DD.MM') || '–' || to_char(p_end, 'DD.MM.YYYY');
  end if;
end $$;
revoke all on function public.period_label(text, date, date, text) from public, anon;
grant execute on function public.period_label(text, date, date, text) to authenticated;

-- ---------------------------------------------------------------------
-- 9. Генерация задач ППР текущего периода
--    Только для компании текущего пользователя; вызывает менеджер или
--    администратор (приложение — при входе и по «Обновить»). У остальных
--    ничего не делает и возвращает 0. Подрядчик назначается обычным
--    триггером по слою и объекту (trg_wo_layer_and_route).
--    Ночной запуск без приложения — следующий шаг (pg_cron, см. отчёт шага 16).
-- ---------------------------------------------------------------------
create or replace function public.ppr_generate()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company uuid := public.my_company_id();
  v_locale  text;
  v_today   date := (now() at time zone 'utc')::date;
  v_count   int := 0;
  v_id      uuid;
  p         record;
  b         record;
begin
  if auth.uid() is null or v_company is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not public.is_manager() then
    return 0;
  end if;
  select coalesce(pr.locale, 'ru') into v_locale from profiles pr where pr.id = auth.uid();

  for p in
    select mp.*, l.name as layer_name,
           coalesce(mp.location_id, a.location_id) as loc_id
      from maintenance_plans mp
      join layers l on l.id = mp.layer_id
      left join assets a on a.id = mp.asset_id
     where mp.company_id = v_company and mp.active
  loop
    select * into b from public.period_bounds(p.period_kind, p.period_days, p.starts_on, v_today);
    continue when b.period_end < p.starts_on;

    insert into work_orders (
      company_id, object_id, location_id, asset_id, layer_id, work_type,
      title, description, priority, status, recurrence, requires_photo,
      input_channel, created_by, due_at, plan_id, period_start, period_end)
    values (
      v_company, p.object_id, p.loc_id, p.asset_id, p.layer_id, p.layer_name,
      left(p.title || ' — ' || public.period_label(p.period_kind, b.period_start, b.period_end, v_locale), 200),
      p.description, p.priority, 'new',
      jsonb_build_object('kind', 'ppr', 'period', p.period_kind, 'days', p.period_days),
      p.requires_photo, 'ppr', coalesce(p.created_by, auth.uid()),
      (b.period_end::timestamp + interval '23 hours 59 minutes') at time zone 'utc',
      p.id, b.period_start, b.period_end)
    on conflict (plan_id, period_start) where plan_id is not null do nothing
    returning id into v_id;

    if v_id is not null then
      v_count := v_count + 1;
      insert into checklist_items (work_order_id, text)
      select v_id, btrim(item #>> '{}')
        from jsonb_array_elements(p.checklist) with ordinality as t(item, ord)
       where jsonb_typeof(item) = 'string' and btrim(item #>> '{}') <> ''
       order by ord;
      v_id := null;
    end if;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.ppr_generate() from public, anon;
grant execute on function public.ppr_generate() to authenticated;

-- Триггерные функции вызываются только базой.
revoke all on function public.trg_objects_refs_check()     from public, anon, authenticated;
revoke all on function public.trg_locations_refs_check()   from public, anon, authenticated;
revoke all on function public.trg_assets_refs_check()      from public, anon, authenticated;
revoke all on function public.trg_mplans_check()           from public, anon, authenticated;
revoke all on function public.trg_wo_refs_check()          from public, anon, authenticated;
revoke all on function public.trg_contractor_links_check() from public, anon, authenticated;
revoke all on function public.trg_executors_check()        from public, anon, authenticated;
revoke all on function public.trg_scan_tags_check()        from public, anon, authenticated;

-- =====================================================================
-- Проверка после применения (только чтение; запускать в SQL Editor
-- по одному запросу):
--
-- 1) Новые таблицы и RLS (ожидается regions, maintenance_plans — true):
-- select relname, relrowsecurity from pg_class
--  where oid in ('public.regions'::regclass, 'public.maintenance_plans'::regclass);
--
-- 2) Новые столбцы:
-- select table_name, column_name from information_schema.columns
--  where table_schema = 'public'
--    and ((table_name = 'objects' and column_name in ('country_code', 'city', 'region_id'))
--      or (table_name = 'locations' and column_name = 'code')
--      or (table_name = 'assets' and column_name in ('layer_id', 'manufacturer', 'model', 'serial_no', 'installed_at'))
--      or (table_name = 'work_orders' and column_name in ('plan_id', 'period_start', 'period_end')))
--  order by 1, 2;
--
-- 3) Город заполнен из адреса:
-- select name, address, city from public.objects order by city, name;
--
-- 4) Границы периодов (ожидается 2026-10-01 … 2026-10-31 и 2026-10-01 … 2026-12-31):
-- select * from public.period_bounds('month', null, '2026-01-01', '2026-10-10')
-- union all
-- select * from public.period_bounds('quarter', null, '2026-01-01', '2026-10-10');
--
-- 5) Политики новых таблиц (ожидается regions_select, regions_manage,
--    mplans_select, mplans_manage):
-- select tablename, policyname, cmd from pg_policies
--  where schemaname = 'public' and tablename in ('regions', 'maintenance_plans')
--  order by 1, 2;
--
-- 6) Функции закрыты от анонимов (ожидается false для anon, true для authenticated):
-- select p.proname,
--        has_function_privilege('anon', p.oid, 'execute') as anon,
--        has_function_privilege('authenticated', p.oid, 'execute') as authenticated
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and p.proname in ('ppr_generate', 'period_bounds', 'period_label', 'norm_name');
-- =====================================================================
