-- =====================================================================
-- hey_helpy · Миграция 001
-- 1) Закрывает эскалацию привилегий: пользователь больше не может сам
--    сменить себе company_id и role (раньше мог стать админом чужой компании).
-- 2) Онбординг переносится в серверные функции (RPC):
--    create_company, accept_invite, set_member_role.
-- 3) Убирает у anon доступ к таблицам.
-- 4) Индексы на внешние ключи и под отчёты.
-- 5) Автообновление updated_at у заявок.
-- ВАЖНО: после применения клиент не сможет обновлять profiles.company_id
-- и profiles.role напрямую — эти места в Flutter-коде нужно заменить
-- вызовами supabase.rpc(...).
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. profiles: пользователь может менять только имя и телефон
-- ---------------------------------------------------------------------
revoke update on public.profiles from anon, authenticated;
grant update (full_name, phone) on public.profiles to authenticated;

-- ---------------------------------------------------------------------
-- 2. anon: без доступа к таблицам (RLS и так не пускал, это второй рубеж)
-- ---------------------------------------------------------------------
revoke all on all tables in schema public from anon;
alter default privileges for role postgres in schema public revoke all on tables from anon;

-- ---------------------------------------------------------------------
-- 3. RPC: создание компании первым пользователем (он становится admin)
-- ---------------------------------------------------------------------
create or replace function public.create_company(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'company name is required';
  end if;
  if exists (select 1 from profiles where id = auth.uid() and company_id is not null) then
    raise exception 'user already belongs to a company';
  end if;

  insert into companies(name) values (trim(p_name)) returning id into v_company;

  insert into profiles(id, company_id, role)
  values (auth.uid(), v_company, 'admin')
  on conflict (id) do update set company_id = excluded.company_id, role = 'admin';

  return v_company;
end;
$$;

-- ---------------------------------------------------------------------
-- 4. RPC: принятие приглашения исполнителем подрядчика
-- ---------------------------------------------------------------------
create or replace function public.accept_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv      invites;
  v_company  uuid;
  v_executor uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_inv from invites where token = p_token for update;
  if not found then
    raise exception 'invite not found';
  end if;
  if v_inv.used_at is not null then
    raise exception 'invite already used';
  end if;
  if v_inv.expires_at is not null and v_inv.expires_at < now() then
    raise exception 'invite expired';
  end if;

  select company_id into v_company from contractors where id = v_inv.contractor_id;

  if exists (select 1 from profiles
             where id = auth.uid() and company_id is not null and company_id <> v_company) then
    raise exception 'user belongs to another company';
  end if;

  insert into profiles(id, company_id, role)
  values (auth.uid(), v_company, 'executor')
  on conflict (id) do update
    set company_id = v_company,
        -- админа/менеджера не понижаем, заявителя делаем исполнителем
        role = case when profiles.role = 'requester' then 'executor' else profiles.role end;

  select id into v_executor from executors
   where profile_id = auth.uid() and contractor_id = v_inv.contractor_id;
  if v_executor is null then
    insert into executors(profile_id, contractor_id)
    values (auth.uid(), v_inv.contractor_id)
    returning id into v_executor;
  end if;

  update invites set used_at = now() where id = v_inv.id;
  return v_executor;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. RPC: смена роли сотрудника (только admin своей компании)
-- ---------------------------------------------------------------------
create or replace function public.set_member_role(p_profile uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(public.my_role(), '') <> 'admin' then
    raise exception 'forbidden: admin only';
  end if;
  if p_role not in ('admin', 'manager', 'requester', 'contractor', 'executor') then
    raise exception 'unknown role %', p_role;
  end if;
  if p_profile = auth.uid() then
    raise exception 'cannot change own role';
  end if;

  update profiles
     set role = p_role
   where id = p_profile
     and company_id = public.my_company_id();

  if not found then
    raise exception 'profile not found in your company';
  end if;
end;
$$;

revoke all on function public.create_company(text)          from public, anon;
revoke all on function public.accept_invite(text)           from public, anon;
revoke all on function public.set_member_role(uuid, text)   from public, anon;
grant execute on function public.create_company(text)        to authenticated;
grant execute on function public.accept_invite(text)         to authenticated;
grant execute on function public.set_member_role(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 6. Индексы на внешние ключи (ускоряют RLS-проверки и выборки)
-- ---------------------------------------------------------------------
create index if not exists idx_locations_object        on public.locations (object_id);
create index if not exists idx_locations_parent        on public.locations (parent_id);
create index if not exists idx_assets_location         on public.assets (location_id);
create index if not exists idx_ar_anchors_asset        on public.ar_anchors (asset_id);
create index if not exists idx_scan_tags_asset         on public.scan_tags (asset_id);
create index if not exists idx_scan_tags_location      on public.scan_tags (location_id);
create index if not exists idx_executors_contractor    on public.executors (contractor_id);
create index if not exists idx_executors_profile       on public.executors (profile_id);
create index if not exists idx_profiles_company        on public.profiles (company_id);
create index if not exists idx_contractors_company     on public.contractors (company_id);
create index if not exists idx_departments_object      on public.departments (object_id);
create index if not exists idx_invites_contractor      on public.invites (contractor_id);
create index if not exists idx_contractor_objects_obj  on public.contractor_objects (object_id);
create index if not exists idx_wo_object               on public.work_orders (object_id);
create index if not exists idx_wo_location             on public.work_orders (location_id);
create index if not exists idx_wo_asset                on public.work_orders (asset_id);
create index if not exists idx_wo_created_by           on public.work_orders (created_by);
-- под отчёты: заявки компании за период
create index if not exists idx_wo_company_created      on public.work_orders (company_id, created_at desc);

-- ---------------------------------------------------------------------
-- 7. Политики верхнего уровня: вызов my_company_id() один раз на запрос,
--    а не на каждую строку (обёртка в подзапрос)
-- ---------------------------------------------------------------------
drop policy if exists objects_company on public.objects;
create policy objects_company on public.objects
  using (company_id = (select public.my_company_id()))
  with check (company_id = (select public.my_company_id()));

drop policy if exists contractors_company on public.contractors;
create policy contractors_company on public.contractors
  using (company_id = (select public.my_company_id()))
  with check (company_id = (select public.my_company_id()));

drop policy if exists work_orders_company on public.work_orders;
create policy work_orders_company on public.work_orders
  using (company_id = (select public.my_company_id()))
  with check (company_id = (select public.my_company_id()));

drop policy if exists companies_select_members on public.companies;
create policy companies_select_members on public.companies
  for select using (id = (select public.my_company_id()));

drop policy if exists profiles_select_company on public.profiles;
create policy profiles_select_company on public.profiles
  for select using (company_id is not null and company_id = (select public.my_company_id()));

-- ---------------------------------------------------------------------
-- 8. updated_at у заявок обновляется автоматически
-- ---------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_work_orders_updated_at on public.work_orders;
create trigger trg_work_orders_updated_at
  before update on public.work_orders
  for each row execute function public.touch_updated_at();

commit;
