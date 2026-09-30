-- =====================================================================
-- Hey Helpy — миграция 0003: жизненный цикл заявки и безопасность
--
-- Приводит схему в соответствие с кодом приложения:
--   * статусы on_review / returned, поля assigned_contractor_id и
--     return_reason, порядок пунктов чек-листа;
--   * RPC онбординга: create_company, accept_invite, set_member_role;
--   * RPC create_work_order: заявка и чек-лист одной транзакцией;
--   * серверная проверка переходов статуса по ролям и журнал work_logs.
--
-- Закрывает дыры в правах:
--   * пользователь больше не может сам поменять себе role / company_id;
--   * удалять заявки может только админ;
--   * журнал work_logs пишет только сервер;
--   * приглашения видят и создают только админ и менеджер.
--
-- Миграцию можно запускать повторно.
-- =====================================================================

begin;

-- ------------------------- Схема ------------------------------------

alter table public.work_orders
  add column if not exists assigned_contractor_id uuid
    references public.contractors(id) on delete set null;
alter table public.work_orders add column if not exists return_reason text;
create index if not exists idx_wo_contractor on public.work_orders(assigned_contractor_id);
create index if not exists idx_wo_created_at on public.work_orders(company_id, created_at desc);

alter table public.work_orders drop constraint if exists work_orders_status_check;
alter table public.work_orders add constraint work_orders_status_check
  check (status in ('new','assigned','in_progress','on_review','returned',
                    'done','cancelled','overdue'));

-- Порядок пунктов: у пунктов одной заявки одинаковый created_at.
alter table public.checklist_items add column if not exists position integer not null default 0;

-- ------------------------- Хелперы ----------------------------------

create or replace function public.is_manager()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(public.my_role() in ('admin','manager'), false);
$$;

-- ------------------------- Профили ----------------------------------
-- Раньше политика profiles_update_self позволяла любому пользователю
-- выставить себе role = 'admin' и любой company_id. Теперь клиент может
-- менять только имя и телефон, остальное — через RPC ниже.

revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (full_name, phone) on public.profiles to authenticated;

-- ------------------------- Онбординг --------------------------------

create or replace function public.create_company(p_name text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_existing uuid;
  v_company uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if coalesce(btrim(p_name), '') = '' then raise exception 'company name is required'; end if;

  select company_id into v_existing from profiles where id = v_uid for update;
  if not found then raise exception 'profile not found'; end if;
  if v_existing is not null then raise exception 'user already belongs to a company'; end if;

  insert into companies (name) values (btrim(p_name)) returning id into v_company;
  update profiles set company_id = v_company, role = 'admin' where id = v_uid;
  return v_company;
end;
$$;

create or replace function public.accept_invite(p_token text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_invite invites%rowtype;
  v_company uuid;
  v_existing uuid;
  v_executor uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select * into v_invite from invites where token = btrim(p_token) for update;
  if not found then raise exception 'invite not found'; end if;
  if v_invite.used_at is not null then raise exception 'invite already used'; end if;
  if v_invite.expires_at is not null and v_invite.expires_at < now() then
    raise exception 'invite expired';
  end if;

  select company_id into v_company from contractors where id = v_invite.contractor_id;

  select company_id into v_existing from profiles where id = v_uid for update;
  if not found then raise exception 'profile not found'; end if;
  if v_existing is not null and v_existing <> v_company then
    raise exception 'user belongs to another company';
  end if;
  if v_existing is null then
    update profiles set company_id = v_company, role = 'executor' where id = v_uid;
  end if;

  insert into executors (profile_id, contractor_id)
  values (v_uid, v_invite.contractor_id)
  returning id into v_executor;

  update invites set used_at = now() where id = v_invite.id;
  return v_executor;
end;
$$;

create or replace function public.set_member_role(p_profile uuid, p_role text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.my_role() is distinct from 'admin' then raise exception 'forbidden: admin only'; end if;
  if p_profile = auth.uid() then raise exception 'cannot change own role'; end if;
  if p_role not in ('admin','manager','requester','contractor','executor') then
    raise exception 'invalid role';
  end if;

  update profiles set role = p_role
  where id = p_profile and company_id = public.my_company_id();
  if not found then raise exception 'profile not found in your company'; end if;
end;
$$;

-- ------------------------- Создание заявки --------------------------
-- security invoker: работают обычные RLS-политики пользователя.

create or replace function public.create_work_order(
  p_title         text,
  p_description   text    default null,
  p_work_type     text    default null,
  p_priority      text    default 'normal',
  p_object_id     uuid    default null,
  p_recurrence    jsonb   default null,
  p_due_at        timestamptz default null,
  p_checklist     text[]  default '{}',
  p_input_channel text    default 'button'
)
returns uuid
language plpgsql security invoker set search_path = public
as $$
declare
  v_company uuid := public.my_company_id();
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if v_company is null then raise exception 'user has no company'; end if;
  if coalesce(btrim(p_title), '') = '' then raise exception 'title is required'; end if;

  insert into work_orders (company_id, title, description, work_type, priority,
                           object_id, recurrence, due_at, input_channel, created_by)
  values (v_company, btrim(p_title), nullif(btrim(p_description), ''),
          nullif(btrim(p_work_type), ''), coalesce(p_priority, 'normal'),
          p_object_id, p_recurrence, p_due_at, coalesce(p_input_channel, 'button'),
          auth.uid())
  returning id into v_id;

  insert into checklist_items (work_order_id, text, position)
  select v_id, btrim(item), ord::int
  from unnest(coalesce(p_checklist, '{}')) with ordinality as t(item, ord)
  where btrim(item) <> '';

  return v_id;
end;
$$;

-- ------------------------- Правила заявок ---------------------------
-- Одни и те же правила для любого клиента. Если auth.uid() пуст
-- (service_role, SQL Editor, фоновые задачи), проверки ролей пропускаются.

create or replace function public.work_orders_guard()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_uid     uuid    := auth.uid();
  v_role    text    := public.my_role();
  v_manager boolean := v_role in ('admin','manager');
  v_author  boolean;
  v_worker  boolean;
begin
  -- Ссылки должны вести на объекты и подрядчиков той же компании
  -- (внешний ключ этого не проверяет).
  if new.object_id is not null and not exists (
      select 1 from objects where id = new.object_id and company_id = new.company_id) then
    raise exception 'object not found in company';
  end if;
  if new.assigned_contractor_id is not null and not exists (
      select 1 from contractors where id = new.assigned_contractor_id and company_id = new.company_id) then
    raise exception 'contractor not found in company';
  end if;

  if tg_op = 'INSERT' then
    if v_uid is not null then
      new.created_by := v_uid;
      if new.status <> 'new' then raise exception 'status transition not allowed'; end if;
      if not v_manager and (new.assigned_contractor_id is not null
                            or new.assigned_executor_id is not null) then
        raise exception 'assignment not allowed';
      end if;
    end if;
    return new;
  end if;

  new.updated_at := now();
  if v_uid is null then return new; end if;

  if new.company_id <> old.company_id
     or new.created_by is distinct from old.created_by
     or new.created_at <> old.created_at then
    raise exception 'change not allowed';
  end if;

  v_author := old.created_by = v_uid;
  -- Исполнитель подрядчика работает только с заявками своего подрядчика.
  v_worker := v_manager
    or v_role = 'contractor'
    or (v_role = 'executor' and (new.assigned_contractor_id is null or exists (
          select 1 from executors e
          where e.profile_id = v_uid and e.contractor_id = new.assigned_contractor_id)));

  if (new.title, new.description, new.work_type, new.priority, new.object_id,
      new.location_id, new.asset_id, new.recurrence, new.requires_photo,
      new.requires_scan, new.due_at, new.input_channel, new.return_reason)
     is distinct from
     (old.title, old.description, old.work_type, old.priority, old.object_id,
      old.location_id, old.asset_id, old.recurrence, old.requires_photo,
      old.requires_scan, old.due_at, old.input_channel, old.return_reason)
     and not (v_author or v_manager) then
    raise exception 'edit not allowed';
  end if;

  if (new.assigned_contractor_id, new.assigned_executor_id, new.assigned_by)
     is distinct from
     (old.assigned_contractor_id, old.assigned_executor_id, old.assigned_by)
     and not v_manager then
    raise exception 'assignment not allowed';
  end if;

  if new.status is distinct from old.status then
    if not (
      (new.status = 'assigned' and old.status in ('new','returned')
         and v_manager and new.assigned_contractor_id is not null)
      or (new.status = 'in_progress' and old.status in ('new','assigned','returned') and v_worker)
      or (new.status = 'on_review' and old.status = 'in_progress' and v_worker)
      or (new.status in ('done','returned') and old.status = 'on_review' and (v_author or v_manager))
      or (new.status = 'cancelled' and old.status not in ('done','cancelled') and (v_author or v_manager))
    ) then
      raise exception 'status transition not allowed';
    end if;

    if new.status = 'returned' and coalesce(btrim(new.return_reason), '') = '' then
      raise exception 'return reason required';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists work_orders_guard on public.work_orders;
create trigger work_orders_guard
  before insert or update on public.work_orders
  for each row execute function public.work_orders_guard();

-- Журнал статусов пишет только сервер.
create or replace function public.work_orders_log()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into work_logs (work_order_id, from_status, to_status, by_profile)
    values (new.id, null, new.status, auth.uid());
  elsif new.status is distinct from old.status then
    insert into work_logs (work_order_id, from_status, to_status, by_profile, note)
    values (new.id, old.status, new.status, auth.uid(),
            case when new.status = 'returned' then new.return_reason end);
  end if;
  return null;
end;
$$;

drop trigger if exists work_orders_log on public.work_orders;
create trigger work_orders_log
  after insert or update on public.work_orders
  for each row execute function public.work_orders_log();

-- Отметка пункта чек-листа: кто и когда.
create or replace function public.checklist_items_stamp()
returns trigger
language plpgsql
as $$
begin
  if new.is_done and (tg_op = 'INSERT' or not old.is_done) then
    new.done_at := now();
    new.done_by := auth.uid();
  elsif not new.is_done then
    new.done_at := null;
    new.done_by := null;
  end if;
  return new;
end;
$$;

drop trigger if exists checklist_items_stamp on public.checklist_items;
create trigger checklist_items_stamp
  before insert or update on public.checklist_items
  for each row execute function public.checklist_items_stamp();

-- ------------------------- RLS --------------------------------------

drop policy if exists work_orders_company on public.work_orders;
drop policy if exists work_orders_select  on public.work_orders;
drop policy if exists work_orders_insert  on public.work_orders;
drop policy if exists work_orders_update  on public.work_orders;
drop policy if exists work_orders_delete  on public.work_orders;

create policy work_orders_select on public.work_orders
  for select using (company_id = public.my_company_id());
create policy work_orders_insert on public.work_orders
  for insert with check (company_id = public.my_company_id());
create policy work_orders_update on public.work_orders
  for update using (company_id = public.my_company_id())
  with check (company_id = public.my_company_id());
create policy work_orders_delete on public.work_orders
  for delete using (company_id = public.my_company_id() and public.my_role() = 'admin');

drop policy if exists work_logs_company on public.work_logs;
drop policy if exists work_logs_select  on public.work_logs;
create policy work_logs_select on public.work_logs
  for select using (exists (
    select 1 from public.work_orders w
    where w.id = work_logs.work_order_id and w.company_id = public.my_company_id()));

drop policy if exists invites_company on public.invites;
drop policy if exists invites_managers on public.invites;
create policy invites_managers on public.invites
  for all using (public.is_manager() and exists (
    select 1 from public.contractors c
    where c.id = invites.contractor_id and c.company_id = public.my_company_id()))
  with check (public.is_manager() and exists (
    select 1 from public.contractors c
    where c.id = invites.contractor_id and c.company_id = public.my_company_id()));

-- ------------------------- Права на функции -------------------------

revoke all on function public.is_manager()                 from public, anon;
revoke all on function public.create_company(text)         from public, anon;
revoke all on function public.accept_invite(text)          from public, anon;
revoke all on function public.set_member_role(uuid, text)  from public, anon;
revoke all on function public.create_work_order(text, text, text, text, uuid, jsonb, timestamptz, text[], text)
  from public, anon;
revoke all on function public.work_orders_guard()          from public, anon, authenticated;
revoke all on function public.work_orders_log()            from public, anon, authenticated;

grant execute on function public.is_manager()                to authenticated;
grant execute on function public.create_company(text)        to authenticated;
grant execute on function public.accept_invite(text)         to authenticated;
grant execute on function public.set_member_role(uuid, text) to authenticated;
grant execute on function public.create_work_order(text, text, text, text, uuid, jsonb, timestamptz, text[], text)
  to authenticated;

commit;
