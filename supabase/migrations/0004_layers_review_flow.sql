-- =====================================================================
-- hey_helpy · Миграция 002 (неделя 1 MVP)
-- 1) Слои (климат, электрика, клининг…) — справочник на компанию.
-- 2) Закрепление подрядчиков за слоями (на весь портфель или на объект).
-- 3) Автоназначение: новая заявка сама уходит подрядчику слоя.
-- 4) Статусы «На проверке» и «Возвращена»: заявка закрывается только
--    после приёмки автором или менеджером. Правила переходов — в базе.
-- 5) Доступ к заявкам по ролям: менеджер видит всё, заявитель — свои,
--    исполнитель — заявки своего подрядчика.
-- 6) Таблица визитов (прибытие/уход по геозоне) — для недели 2.
-- Повторный запуск безопасен.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Слои
-- ---------------------------------------------------------------------
create table if not exists public.layers (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  name           text not null,
  color          text not null default '#2F6FE0',
  requires_photo boolean not null default false,
  sort           int  not null default 100,
  created_at     timestamptz not null default now(),
  unique (company_id, name)
);
alter table public.layers enable row level security;

create or replace function public.seed_default_layers(p_company uuid)
returns void language sql security definer set search_path = public as $$
  insert into layers(company_id, name, color, requires_photo, sort) values
    -- обязательное фото включим, когда в приложении появится загрузка фото (неделя 2)
    (p_company, 'Климат',     '#0E8C80', false, 10),
    (p_company, 'Электрика',  '#C27A0A', false, 20),
    (p_company, 'Сантехника', '#2F6FE0', false, 30),
    (p_company, 'Клининг',    '#7A55C7', false, 40),
    (p_company, 'Мебель',     '#8A6A4F', false, 50),
    (p_company, 'Другое',     '#5E6D7C', false, 90)
  on conflict (company_id, name) do nothing;
$$;
revoke all on function public.seed_default_layers(uuid) from public, anon, authenticated;

select public.seed_default_layers(id) from public.companies;

create or replace function public.trg_company_default_layers()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform seed_default_layers(new.id);
  return new;
end $$;
drop trigger if exists trg_company_default_layers on public.companies;
create trigger trg_company_default_layers after insert on public.companies
  for each row execute function public.trg_company_default_layers();

-- ---------------------------------------------------------------------
-- 2. Закрепление подрядчиков за слоями
-- ---------------------------------------------------------------------
create table if not exists public.contractor_layers (
  id            uuid primary key default gen_random_uuid(),
  contractor_id uuid not null references public.contractors(id) on delete cascade,
  layer_id      uuid not null references public.layers(id) on delete cascade,
  object_id     uuid references public.objects(id) on delete cascade, -- null = все объекты
  created_at    timestamptz not null default now()
);
create unique index if not exists uq_contractor_layers
  on public.contractor_layers (contractor_id, layer_id, coalesce(object_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index if not exists idx_contractor_layers_layer on public.contractor_layers (layer_id);
alter table public.contractor_layers enable row level security;

-- ---------------------------------------------------------------------
-- 3. Вспомогательные функции доступа
-- ---------------------------------------------------------------------
create or replace function public.is_manager()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role in ('admin','manager') from profiles where id = auth.uid()), false);
$$;

create or replace function public.my_contractor_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select contractor_id from executors where profile_id = auth.uid();
$$;

grant execute on function public.is_manager()        to authenticated;
grant execute on function public.my_contractor_ids() to authenticated;

-- Политики слоёв: видят все в компании, меняют менеджеры
drop policy if exists layers_select on public.layers;
create policy layers_select on public.layers for select
  using (company_id = (select public.my_company_id()));
drop policy if exists layers_manage on public.layers;
create policy layers_manage on public.layers for all
  using (company_id = (select public.my_company_id()) and (select public.is_manager()))
  with check (company_id = (select public.my_company_id()) and (select public.is_manager()));

drop policy if exists contractor_layers_select on public.contractor_layers;
create policy contractor_layers_select on public.contractor_layers for select
  using (exists (select 1 from contractors c where c.id = contractor_id
                 and c.company_id = (select public.my_company_id())));
drop policy if exists contractor_layers_manage on public.contractor_layers;
create policy contractor_layers_manage on public.contractor_layers for all
  using ((select public.is_manager()) and exists (select 1 from contractors c where c.id = contractor_id
                 and c.company_id = (select public.my_company_id())))
  with check ((select public.is_manager()) and exists (select 1 from contractors c where c.id = contractor_id
                 and c.company_id = (select public.my_company_id())));

-- ---------------------------------------------------------------------
-- 4. Новые поля и статусы заявок
-- ---------------------------------------------------------------------
alter table public.work_orders
  add column if not exists layer_id      uuid references public.layers(id),
  add column if not exists started_at    timestamptz,
  add column if not exists submitted_at  timestamptz,
  add column if not exists accepted_at   timestamptz,
  add column if not exists accepted_by   uuid references public.profiles(id),
  add column if not exists return_reason text;
create index if not exists idx_wo_layer on public.work_orders (layer_id);
create index if not exists idx_wo_contractor on public.work_orders (assigned_contractor_id);

alter table public.work_orders drop constraint if exists work_orders_status_check;
alter table public.work_orders add constraint work_orders_status_check check (status = any (array[
  'new','assigned','in_progress','on_review','returned','done','cancelled','overdue']));
alter table public.work_orders drop constraint if exists work_orders_assigned_by_check;
alter table public.work_orders add constraint work_orders_assigned_by_check
  check (assigned_by = any (array['ai','manager','rule']));
alter table public.work_orders drop constraint if exists work_orders_input_channel_check;
alter table public.work_orders add constraint work_orders_input_channel_check
  check (input_channel = any (array['button','text','voice','camera','wake_word']));

-- ---------------------------------------------------------------------
-- 5. Слой по виду работ + автоназначение подрядчика
-- ---------------------------------------------------------------------
create or replace function public.trg_wo_layer_and_route()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_layer layers;
  v_contr uuid;
begin
  -- при смене вида работ слой пересчитывается
  if tg_op = 'UPDATE' and new.work_type is distinct from old.work_type
     and new.layer_id is not distinct from old.layer_id then
    new.layer_id := null;
  end if;
  -- слой определяется по виду работ (названию), если не задан явно
  if new.layer_id is null and new.work_type is not null then
    select * into v_layer from layers
     where company_id = new.company_id and lower(name) = lower(trim(new.work_type));
    new.layer_id := v_layer.id;
  elsif new.layer_id is not null then
    select * into v_layer from layers where id = new.layer_id;
  end if;

  if tg_op = 'INSERT' then
    if v_layer.id is not null then
      new.requires_photo := new.requires_photo or v_layer.requires_photo;
    end if;
    -- автоназначение: сначала подрядчик объекта, затем «на все объекты»
    if new.assigned_contractor_id is null and new.layer_id is not null then
      select cl.contractor_id into v_contr
        from contractor_layers cl
       where cl.layer_id = new.layer_id
         and (cl.object_id = new.object_id or cl.object_id is null)
       order by (cl.object_id is null), cl.created_at
       limit 1;
      if v_contr is not null then
        new.assigned_contractor_id := v_contr;
        new.assigned_by := 'rule';
        if new.status = 'new' then new.status := 'assigned'; end if;
      end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_wo_layer_and_route on public.work_orders;
create trigger trg_wo_layer_and_route
  before insert or update of work_type, layer_id on public.work_orders
  for each row execute function public.trg_wo_layer_and_route();

-- ---------------------------------------------------------------------
-- 6. Правила смены статуса (нельзя закрыть без приёмки)
-- ---------------------------------------------------------------------
create or replace function public.trg_wo_status_flow()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_mgr    boolean;
  v_author boolean;
  v_exec   boolean;
  f text := old.status;
  t text := new.status;
begin
  if f = t then return new; end if;
  -- обслуживание из SQL Editor / сервисным ключом — без ограничений
  if v_uid is null then return new; end if;

  v_mgr    := public.is_manager();
  v_author := old.created_by = v_uid;
  v_exec   := old.assigned_contractor_id is not null
              and old.assigned_contractor_id in (select public.my_contractor_ids());

  if t = 'assigned' and f in ('new','returned') and (v_mgr or v_author) then
    null;
  elsif t = 'in_progress' and f in ('new','assigned','returned') and (v_exec or v_mgr) then
    new.started_at := coalesce(old.started_at, now());
  elsif t = 'on_review' and f = 'in_progress' and (v_exec or v_mgr) then
    if old.requires_photo and not exists (
         select 1 from attachments a where a.work_order_id = old.id and a.kind = 'photo') then
      raise exception 'photo required' using hint = 'Прикрепите фото выполненной работы';
    end if;
    new.submitted_at := now();
    if old.started_at is not null then
      new.time_spent_minutes := greatest(1, ceil(extract(epoch from now() - old.started_at) / 60))::int;
    end if;
  elsif t = 'done' and f = 'on_review' and (v_author or v_mgr) then
    new.accepted_at := now();
    new.accepted_by := v_uid;
  elsif t = 'returned' and f = 'on_review' and (v_author or v_mgr) then
    if coalesce(trim(new.return_reason), '') = '' then
      raise exception 'return reason required' using hint = 'Укажите, что не так';
    end if;
  elsif t = 'cancelled' and f not in ('done','cancelled') and (v_author or v_mgr) then
    null;
  else
    raise exception 'status change % -> % not allowed', f, t;
  end if;
  return new;
end $$;

drop trigger if exists trg_wo_status_flow on public.work_orders;
create trigger trg_wo_status_flow
  before update of status on public.work_orders
  for each row execute function public.trg_wo_status_flow();

-- ---------------------------------------------------------------------
-- 7. Доступ к заявкам по ролям
-- ---------------------------------------------------------------------
drop policy if exists work_orders_company on public.work_orders;
drop policy if exists wo_select on public.work_orders;
drop policy if exists wo_insert on public.work_orders;
drop policy if exists wo_update on public.work_orders;
drop policy if exists wo_delete on public.work_orders;

create policy wo_select on public.work_orders for select using (
  company_id = (select public.my_company_id()) and (
    (select public.is_manager())
    or created_by = (select auth.uid())
    or assigned_contractor_id in (select public.my_contractor_ids())));

create policy wo_insert on public.work_orders for insert with check (
  company_id = (select public.my_company_id()) and created_by = (select auth.uid()));

create policy wo_update on public.work_orders for update using (
  company_id = (select public.my_company_id()) and (
    (select public.is_manager())
    or created_by = (select auth.uid())
    or assigned_contractor_id in (select public.my_contractor_ids())))
  with check (company_id = (select public.my_company_id()));

create policy wo_delete on public.work_orders for delete using (
  company_id = (select public.my_company_id()) and (select public.is_manager()));

-- ---------------------------------------------------------------------
-- 8. Визиты (прибытие и уход по геозоне) — используются с недели 2
-- ---------------------------------------------------------------------
create table if not exists public.visits (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade,
  object_id     uuid not null references public.objects(id) on delete cascade,
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  contractor_id uuid references public.contractors(id),
  started_at    timestamptz not null default now(),
  ended_at      timestamptz,
  source        text not null default 'geofence' check (source in ('geofence','manual')),
  lat           double precision,
  lng           double precision,
  mock_location boolean not null default false,
  created_at    timestamptz not null default now()
);
create index if not exists idx_visits_object on public.visits (object_id, started_at desc);
create index if not exists idx_visits_profile on public.visits (profile_id, started_at desc);
alter table public.visits enable row level security;

drop policy if exists visits_select on public.visits;
create policy visits_select on public.visits for select using (
  company_id = (select public.my_company_id())
  and ((select public.is_manager()) or profile_id = (select auth.uid())));
drop policy if exists visits_insert on public.visits;
create policy visits_insert on public.visits for insert with check (
  company_id = (select public.my_company_id()) and profile_id = (select auth.uid()));
drop policy if exists visits_update on public.visits;
create policy visits_update on public.visits for update using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

revoke all on public.layers, public.contractor_layers, public.visits from anon;

commit;
