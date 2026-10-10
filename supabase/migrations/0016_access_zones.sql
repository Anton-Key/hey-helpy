-- =====================================================================
-- hey_helpy · Миграция 0016: зоны доступа менеджеров и бригады подрядчиков
-- (шаг 17)
--
-- Главный принцип: по умолчанию НИЧЕГО не меняется.
--   • Менеджер без зон доступа видит всю компанию, как раньше.
--   • Исполнитель без бригады видит всё по закреплениям своего подрядчика,
--     как раньше.
--   • Ограничения включаются, только когда администратор задал зоны
--     (access_zones) или менеджер подрядчика — бригады (crews).
-- Разделение компаний остаётся первым условием каждой политики.
--
-- 1) Роли: admin — администратор компании (всё в компании, сотрудники и
--    зоны); manager — менеджер (в своей зоне); executor / contractor;
--    requester. В компании всегда есть администратор: если его нет
--    (например, компания создана демо-скриптом), им становится самый
--    первый менеджер; последнего администратора нельзя понизить.
-- 2) access_zones — зоны менеджеров: системы (layer_ids, пусто = все) ×
--    место (вся компания / регион / страна / город / объект / этаж /
--    оборудование). Зоны складываются.
-- 3) crews, crew_members, crew_zones — бригады подрядчика (необязательно).
-- 4) Одна проверка can_see(объект, слой, оборудование, помещение) и
--    can_manage(…) — в политиках объектов, помещений, этажей, оборудования,
--    заявок, визитов, подрядчиков, закреплений, планов ППР, регионов и
--    хранилища. Вложения, чек-листы, история, исполнители, приглашения,
--    фото — через подзапрос к заявке / подрядчику, ограничение наследуется.
-- 5) access_audit — кто, когда, что менял в зонах, бригадах и ролях.
--
-- Зависит от: 0015 (регионы, страна и город объекта, планы ППР).
-- Применяет пользователь: Actions «Apply migration» (с одобрением) или
-- SQL Editor. Без begin/commit — workflow выполняет файл одной транзакцией.
-- Только добавления и замена политик (drop policy if exists / create
-- policy); таблицы и столбцы не удаляются. Одно изменение данных: в
-- компании без администратора первый менеджер становится администратором.
-- Безопасно запускать повторно. Откат ограничений: удалить строки
-- access_zones (и crew_members) — все снова видят как раньше.
-- Проверено локально: tools/db_test/run.sh (access_zones.sql,
-- tenant_isolation.sql).
-- =====================================================================

do $$
begin
  if to_regclass('public.maintenance_plans') is null
     or to_regclass('public.regions') is null then
    raise exception '0016: сначала примените миграцию 0015 (ППР, регионы, оборудование)';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 1. Администратор компании
-- ---------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select p.role = 'admin' from profiles p where p.id = auth.uid()), false);
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- В компании без администратора им становится самый первый менеджер.
update public.profiles p
   set role = 'admin'
 where p.id in (
   select distinct on (m.company_id) m.id
     from public.profiles m
    where m.role = 'manager' and m.company_id is not null
      and not exists (select 1 from public.profiles a
                       where a.company_id = m.company_id and a.role = 'admin')
    order by m.company_id, m.created_at, m.id);

-- Смена роли — как в 0011, плюс: последнего администратора не понизить.
create or replace function public.set_member_role(p_profile uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     text := coalesce(public.my_role(), '');
  v_target text;
begin
  if v_me not in ('admin', 'manager') then
    raise exception 'forbidden: admin only';
  end if;
  if p_role not in ('admin', 'manager', 'requester', 'contractor', 'executor') then
    raise exception 'unknown role %', p_role;
  end if;
  if p_profile = auth.uid() then
    raise exception 'cannot change own role';
  end if;

  select role into v_target from profiles
   where id = p_profile and company_id = public.my_company_id()
   for update;
  if not found then
    raise exception 'profile not found in your company';
  end if;

  -- Менеджер не назначает администраторов и не меняет их роль.
  if v_me = 'manager' and (p_role = 'admin' or v_target = 'admin') then
    raise exception 'forbidden: admin only';
  end if;
  -- В компании должен остаться хотя бы один администратор.
  if v_target = 'admin' and p_role <> 'admin' and not exists (
       select 1 from profiles a
        where a.company_id = public.my_company_id() and a.role = 'admin' and a.id <> p_profile) then
    raise exception 'last admin';
  end if;

  update profiles set role = p_role where id = p_profile;
end;
$$;
revoke all on function public.set_member_role(uuid, text) from public, anon;
grant execute on function public.set_member_role(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Зоны доступа менеджеров
--    scope_kind / scope_ref:
--      company — вся компания (scope_ref пусто);
--      region  — id региона;     country — код страны («RU»);
--      city    — название города (без учёта регистра; город объекта —
--                objects.city, иначе часть адреса до запятой);
--      object  — id объекта;     floor — id этажа;   asset — id оборудования.
--    layer_ids — системы (слои); пустой массив — все системы.
-- ---------------------------------------------------------------------
create table if not exists public.access_zones (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  layer_ids  uuid[] not null default '{}',
  scope_kind text not null default 'company',
  scope_ref  text,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.crews (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade,
  contractor_id uuid not null references public.contractors(id) on delete cascade,
  name          text not null,
  created_at    timestamptz not null default now()
);

create table if not exists public.crew_members (
  crew_id     uuid not null references public.crews(id) on delete cascade,
  executor_id uuid not null references public.executors(id) on delete cascade,
  company_id  uuid not null references public.companies(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (crew_id, executor_id)
);

create table if not exists public.crew_zones (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  crew_id    uuid not null references public.crews(id) on delete cascade,
  layer_ids  uuid[] not null default '{}',
  scope_kind text not null default 'company',
  scope_ref  text,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.access_audit (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  actor      uuid references public.profiles(id) on delete set null,
  action     text not null,
  entity     text not null,
  target     uuid,
  details    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.access_zones drop constraint if exists access_zones_scope_check;
alter table public.access_zones add constraint access_zones_scope_check
  check (scope_kind in ('company', 'region', 'country', 'city', 'object', 'floor', 'asset')
         and ((scope_kind = 'company') = (scope_ref is null))
         and (scope_kind <> 'country' or scope_ref ~ '^[A-Z]{2}$')
         and (scope_ref is null or char_length(btrim(scope_ref)) between 1 and 100));
alter table public.crew_zones drop constraint if exists crew_zones_scope_check;
alter table public.crew_zones add constraint crew_zones_scope_check
  check (scope_kind in ('company', 'region', 'country', 'city', 'object', 'floor', 'asset')
         and ((scope_kind = 'company') = (scope_ref is null))
         and (scope_kind <> 'country' or scope_ref ~ '^[A-Z]{2}$')
         and (scope_ref is null or char_length(btrim(scope_ref)) between 1 and 100));
alter table public.crews drop constraint if exists crews_name_check;
alter table public.crews add constraint crews_name_check
  check (char_length(btrim(name)) between 1 and 60);

create unique index if not exists crews_contractor_name_key
  on public.crews (contractor_id, public.norm_name(name));
create index if not exists idx_access_zones_profile on public.access_zones (profile_id);
create index if not exists idx_access_zones_company on public.access_zones (company_id);
create index if not exists idx_crews_contractor     on public.crews (contractor_id);
create index if not exists idx_crew_members_exec    on public.crew_members (executor_id);
create index if not exists idx_crew_zones_crew      on public.crew_zones (crew_id);
create index if not exists idx_access_audit_company on public.access_audit (company_id, created_at desc);
-- Под проверку зон: объекты по региону / стране / городу, помещения по этажу.
create index if not exists idx_locations_floor_obj  on public.locations (object_id, floor_id);

-- Компания и ссылки — одной компании (как в 0015).
create or replace function public.trg_access_refs_check()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  ok boolean := true;
begin
  if tg_table_name = 'access_zones' then
    if not exists (select 1 from profiles p where p.id = new.profile_id and p.company_id = new.company_id) then
      raise exception 'zone profile must belong to the same company' using errcode = '42501';
    end if;
  elsif tg_table_name = 'crews' then
    if not exists (select 1 from contractors x where x.id = new.contractor_id and x.company_id = new.company_id) then
      raise exception 'crew contractor must belong to the same company' using errcode = '42501';
    end if;
    return new;
  elsif tg_table_name = 'crew_members' then
    if not exists (select 1 from crews c join executors e on e.contractor_id = c.contractor_id
                    where c.id = new.crew_id and e.id = new.executor_id and c.company_id = new.company_id) then
      raise exception 'crew member must be an executor of the crew contractor' using errcode = '42501';
    end if;
    return new;
  elsif tg_table_name = 'crew_zones' then
    if not exists (select 1 from crews c where c.id = new.crew_id and c.company_id = new.company_id) then
      raise exception 'crew must belong to the same company' using errcode = '42501';
    end if;
  end if;

  -- Системы зоны — слои этой компании.
  if exists (select 1 from unnest(new.layer_ids) l(id)
              where not exists (select 1 from layers y where y.id = l.id and y.company_id = new.company_id)) then
    raise exception 'zone layer must belong to the same company' using errcode = '42501';
  end if;
  -- Место зоны — из этой компании.
  ok := case new.scope_kind
    when 'region' then exists (select 1 from regions r where r.id::text = new.scope_ref and r.company_id = new.company_id)
    when 'object' then exists (select 1 from objects o where o.id::text = new.scope_ref and o.company_id = new.company_id)
    when 'floor'  then exists (select 1 from floors f where f.id::text = new.scope_ref and f.company_id = new.company_id)
    when 'asset'  then exists (select 1 from assets a join locations l on l.id = a.location_id
                                 join objects o on o.id = l.object_id
                                where a.id::text = new.scope_ref and o.company_id = new.company_id)
    else true end;
  if not ok then
    raise exception 'zone place must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_access_zones_check on public.access_zones;
create trigger trg_access_zones_check before insert or update on public.access_zones
  for each row execute function public.trg_access_refs_check();
drop trigger if exists trg_crews_check on public.crews;
create trigger trg_crews_check before insert or update on public.crews
  for each row execute function public.trg_access_refs_check();
drop trigger if exists trg_crew_members_check on public.crew_members;
create trigger trg_crew_members_check before insert or update on public.crew_members
  for each row execute function public.trg_access_refs_check();
drop trigger if exists trg_crew_zones_check on public.crew_zones;
create trigger trg_crew_zones_check before insert or update on public.crew_zones
  for each row execute function public.trg_access_refs_check();

-- ---------------------------------------------------------------------
-- 3. Проверка доступа
-- ---------------------------------------------------------------------
-- Правила зон текущего пользователя: зоны менеджера или зоны его бригад.
-- Пусто — ограничений нет. Одна выборка на запрос (stable).
create or replace function public.my_zone_rules()
returns table (layer_ids uuid[], scope_kind text, scope_ref text)
language sql stable security definer set search_path = public as $$
  select z.layer_ids, z.scope_kind, z.scope_ref
    from access_zones z
    join profiles p on p.id = z.profile_id
   where z.profile_id = auth.uid() and z.company_id = p.company_id
     and p.role = 'manager'
  union all
  select cz.layer_ids, cz.scope_kind, cz.scope_ref
    from crew_members m
    join executors e on e.id = m.executor_id
    join crew_zones cz on cz.crew_id = m.crew_id
    join profiles p on p.id = e.profile_id
   where e.profile_id = auth.uid() and p.role in ('executor', 'contractor')
     and cz.company_id = p.company_id;
$$;
revoke all on function public.my_zone_rules() from public, anon;
grant execute on function public.my_zone_rules() to authenticated;

-- Нет ограничений: администратор, заявитель, менеджер без зон, исполнитель
-- без бригады. Политики вызывают её в подзапросе — один раз на запрос.
create or replace function public.zones_unrestricted()
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when (select p.role from profiles p where p.id = auth.uid()) in ('manager') then
      not exists (select 1 from access_zones z where z.profile_id = auth.uid())
    when (select p.role from profiles p where p.id = auth.uid()) in ('executor', 'contractor') then
      not exists (select 1 from crew_members m join executors e on e.id = m.executor_id
                   where e.profile_id = auth.uid())
    else true end;
$$;
revoke all on function public.zones_unrestricted() from public, anon;
grant execute on function public.zones_unrestricted() to authenticated;

-- Видит ли пользователь место: объект (и, если известно, слой, оборудование,
-- помещение). Без ограничений — true. Объект не указан (закрепление «на все
-- объекты») — подходит любое место, проверяется только система. Слой не
-- указан (сам объект, помещение) — подходит любая система.
create or replace function public.can_see(
  p_object uuid, p_layer uuid default null, p_asset uuid default null, p_location uuid default null)
returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  o   record;
  r   record;
  any_rule boolean := false;
  floor_id uuid;
begin
  if public.zones_unrestricted() then
    return true;
  end if;
  if p_object is not null then
    select ob.id, ob.region_id, ob.country_code,
           lower(btrim(coalesce(nullif(btrim(ob.city), ''), split_part(coalesce(ob.address, ''), ',', 1)))) as city
      into o from objects ob where ob.id = p_object;
  end if;
  for r in select * from public.my_zone_rules() loop
    any_rule := true;
    -- система
    if p_layer is not null and cardinality(r.layer_ids) > 0 and not (p_layer = any (r.layer_ids)) then
      continue;
    end if;
    -- место
    if p_object is null or r.scope_kind = 'company' then
      return true;
    end if;
    if r.scope_kind = 'region' and o.region_id::text = r.scope_ref then return true; end if;
    if r.scope_kind = 'country' and o.country_code = r.scope_ref then return true; end if;
    if r.scope_kind = 'city' and o.city = lower(btrim(r.scope_ref)) then return true; end if;
    if r.scope_kind = 'object' and p_object::text = r.scope_ref then return true; end if;
    if r.scope_kind = 'floor' then
      -- объект с этим этажом: сам объект виден; заявка / оборудование —
      -- только на этом этаже (помещение или оборудование на этаже)
      if exists (select 1 from floors f where f.id::text = r.scope_ref and f.object_id = p_object) then
        if p_asset is null and p_location is null then return true; end if;
        if p_asset is not null and exists (
             select 1 from assets a left join locations l on l.id = a.location_id
              where a.id = p_asset and (a.floor_id::text = r.scope_ref or l.floor_id::text = r.scope_ref)) then
          return true;
        end if;
        if p_asset is null and p_location is not null and exists (
             select 1 from locations l where l.id = p_location and l.floor_id::text = r.scope_ref) then
          return true;
        end if;
      end if;
    end if;
    if r.scope_kind = 'asset' then
      if p_asset is not null then
        if p_asset::text = r.scope_ref then return true; end if;
      elsif p_location is null and exists (
             select 1 from assets a join locations l on l.id = a.location_id
              where a.id::text = r.scope_ref and l.object_id = p_object) then
        -- сам объект, где стоит это оборудование, виден
        return true;
      end if;
    end if;
  end loop;
  return not any_rule;
end $$;
revoke all on function public.can_see(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.can_see(uuid, uuid, uuid, uuid) to authenticated;

-- Менять: администратор — всё в компании; менеджер — в своей зоне;
-- остальные — нет (их права на заявки — отдельные политики и триггеры).
create or replace function public.can_manage(
  p_object uuid, p_layer uuid default null, p_asset uuid default null, p_location uuid default null)
returns boolean
language sql stable security definer set search_path = public as $$
  select case
    when (select p.role from profiles p where p.id = auth.uid()) = 'admin' then true
    when (select p.role from profiles p where p.id = auth.uid()) = 'manager' then
      public.can_see(p_object, p_layer, p_asset, p_location)
    else false end;
$$;
revoke all on function public.can_manage(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.can_manage(uuid, uuid, uuid, uuid) to authenticated;

-- Объекты в зоне по правилам «вся компания / регион / страна / город /
-- объект»: (объект, система); система null — все системы. Пусто — нет
-- таких правил. Политики берут это множество один раз на запрос.
create or replace function public.zone_obj_layers()
returns table (object_id uuid, layer_id uuid)
language sql stable security definer set search_path = public as $$
  select distinct o.id, l.layer
    from public.my_zone_rules() r
    join objects o on o.company_id = public.my_company_id()
     and case r.scope_kind
           when 'company' then true
           when 'region'  then o.region_id::text = r.scope_ref
           when 'country' then o.country_code = r.scope_ref
           when 'city'    then lower(btrim(coalesce(nullif(btrim(o.city), ''),
                                split_part(coalesce(o.address, ''), ',', 1)))) = lower(btrim(r.scope_ref))
           when 'object'  then o.id::text = r.scope_ref
           else false end
    cross join lateral unnest(case when cardinality(r.layer_ids) = 0 then array[null::uuid]
                                   else r.layer_ids end) as l(layer);
$$;
revoke all on function public.zone_obj_layers() from public, anon;
grant execute on function public.zone_obj_layers() to authenticated;

-- Объекты, где есть правила «этаж» / «оборудование»: сам объект виден,
-- а заявки и оборудование на нём проверяет can_see по строке.
create or replace function public.zone_partial_objects()
returns setof uuid
language sql stable security definer set search_path = public as $$
  select f.object_id from public.my_zone_rules() r join floors f on f.id::text = r.scope_ref
   where r.scope_kind = 'floor'
  union
  select l.object_id from public.my_zone_rules() r
    join assets a on a.id::text = r.scope_ref join locations l on l.id = a.location_id
   where r.scope_kind = 'asset';
$$;
revoke all on function public.zone_partial_objects() from public, anon;
grant execute on function public.zone_partial_objects() to authenticated;

-- Подрядчик виден, если хотя бы одно его закрепление в зоне
-- («на все объекты» — если в зоне есть его система).
create or replace function public.can_see_contractor(p_contractor uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.zones_unrestricted()
      or exists (
        select 1 from contractor_layers cl
         where cl.contractor_id = p_contractor
           and ((cl.object_id is null
                 and exists (select 1 from public.zone_obj_layers() z
                              where z.layer_id is null or z.layer_id = cl.layer_id))
                or exists (select 1 from public.zone_obj_layers() z
                            where z.object_id = cl.object_id
                              and (z.layer_id is null or z.layer_id = cl.layer_id))
                or (cl.object_id in (select public.zone_partial_objects())
                    and public.can_see(cl.object_id, cl.layer_id))));
$$;
revoke all on function public.can_see_contractor(uuid) from public, anon;
grant execute on function public.can_see_contractor(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Политики: условие компании — первым, зона — вторым.
--    Быстро: (select zones_unrestricted()) и множества zone_obj_layers() /
--    zone_partial_objects() вычисляются ОДИН раз на запрос (хеш-проверка
--    по строкам); у пользователей без ограничений зона не проверяется вовсе.
--    can_see по строке — только для объектов с зонами «этаж» /
--    «оборудование». Изменение — отдельными политиками insert / update /
--    delete: «for all» дал бы и чтение, и проверка менеджера шла бы по
--    каждой строке выборки.
-- ---------------------------------------------------------------------

-- объекты
drop policy if exists objects_select on public.objects;
create policy objects_select on public.objects for select using (
  objects.company_id = (select public.my_company_id())
  and ((select public.zones_unrestricted())
         or objects.id in (select z.object_id from public.zone_obj_layers() z)
         or objects.id in (select public.zone_partial_objects())));
drop policy if exists objects_manage on public.objects;
drop policy if exists objects_insert on public.objects;
drop policy if exists objects_update on public.objects;
drop policy if exists objects_delete on public.objects;
create policy objects_insert on public.objects for insert with check (
  objects.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(objects.id, null, null, null)));
create policy objects_update on public.objects for update
  using (objects.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(objects.id, null, null, null)))
  with check (objects.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(objects.id, null, null, null)));
create policy objects_delete on public.objects for delete using (
  objects.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(objects.id, null, null, null)));

-- помещения
drop policy if exists locations_select on public.locations;
create policy locations_select on public.locations for select using (
  exists (select 1 from public.objects o where o.id = locations.object_id and o.company_id = (select public.my_company_id()))
  and ((select public.zones_unrestricted())
         or locations.object_id in (select z.object_id from public.zone_obj_layers() z)
         or (locations.object_id in (select public.zone_partial_objects())
             and public.can_see(locations.object_id, null, null, locations.id))));
drop policy if exists locations_manage on public.locations;
drop policy if exists locations_insert on public.locations;
drop policy if exists locations_update on public.locations;
drop policy if exists locations_delete on public.locations;
create policy locations_insert on public.locations for insert with check (
  (select public.is_manager()) and exists (select 1 from public.objects o where o.id = locations.object_id and o.company_id = (select public.my_company_id()))
  and ((select public.is_admin()) or public.can_manage(locations.object_id, null, null, locations.id)));
create policy locations_update on public.locations for update
  using ((select public.is_manager()) and exists (select 1 from public.objects o where o.id = locations.object_id and o.company_id = (select public.my_company_id()))
  and ((select public.is_admin()) or public.can_manage(locations.object_id, null, null, locations.id)))
  with check ((select public.is_manager()) and exists (select 1 from public.objects o where o.id = locations.object_id and o.company_id = (select public.my_company_id()))
  and ((select public.is_admin()) or public.can_manage(locations.object_id, null, null, locations.id)));
create policy locations_delete on public.locations for delete using (
  (select public.is_manager()) and exists (select 1 from public.objects o where o.id = locations.object_id and o.company_id = (select public.my_company_id()))
  and ((select public.is_admin()) or public.can_manage(locations.object_id, null, null, locations.id)));

-- этажи
drop policy if exists floors_select on public.floors;
create policy floors_select on public.floors for select using (
  floors.company_id = (select public.my_company_id())
  and ((select public.zones_unrestricted())
         or floors.object_id in (select z.object_id from public.zone_obj_layers() z)
         or floors.object_id in (select public.zone_partial_objects())));
drop policy if exists floors_manage on public.floors;
drop policy if exists floors_insert on public.floors;
drop policy if exists floors_update on public.floors;
drop policy if exists floors_delete on public.floors;
create policy floors_insert on public.floors for insert with check (
  floors.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(floors.object_id, null, null, null)));
create policy floors_update on public.floors for update
  using (floors.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(floors.object_id, null, null, null)))
  with check (floors.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(floors.object_id, null, null, null)));
create policy floors_delete on public.floors for delete using (
  floors.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(floors.object_id, null, null, null)));

-- оборудование
drop policy if exists assets_select on public.assets;
create policy assets_select on public.assets for select using (
  exists (select 1 from public.locations l join public.objects o on o.id = l.object_id
   where l.id = assets.location_id and o.company_id = (select public.my_company_id())
     and ((select public.zones_unrestricted())
         or l.object_id in (select z.object_id from public.zone_obj_layers() z where z.layer_id is null)
         or (l.object_id, assets.layer_id) in (select z.object_id, z.layer_id from public.zone_obj_layers() z
                           where z.layer_id is not null)
         or (l.object_id in (select public.zone_partial_objects())
             and public.can_see(l.object_id, assets.layer_id, assets.id, assets.location_id)))));
drop policy if exists assets_manage on public.assets;
drop policy if exists assets_insert on public.assets;
drop policy if exists assets_update on public.assets;
drop policy if exists assets_delete on public.assets;
create policy assets_insert on public.assets for insert with check (
  (select public.is_manager()) and exists (select 1 from public.locations l join public.objects o on o.id = l.object_id
   where l.id = assets.location_id and o.company_id = (select public.my_company_id())
     and ((select public.is_admin()) or public.can_manage(l.object_id, assets.layer_id, assets.id, assets.location_id))));
create policy assets_update on public.assets for update
  using ((select public.is_manager()) and exists (select 1 from public.locations l join public.objects o on o.id = l.object_id
   where l.id = assets.location_id and o.company_id = (select public.my_company_id())
     and ((select public.is_admin()) or public.can_manage(l.object_id, assets.layer_id, assets.id, assets.location_id))))
  with check ((select public.is_manager()) and exists (select 1 from public.locations l join public.objects o on o.id = l.object_id
   where l.id = assets.location_id and o.company_id = (select public.my_company_id())
     and ((select public.is_admin()) or public.can_manage(l.object_id, assets.layer_id, assets.id, assets.location_id))));
create policy assets_delete on public.assets for delete using (
  (select public.is_manager()) and exists (select 1 from public.locations l join public.objects o on o.id = l.object_id
   where l.id = assets.location_id and o.company_id = (select public.my_company_id())
     and ((select public.is_admin()) or public.can_manage(l.object_id, assets.layer_id, assets.id, assets.location_id))));

-- заявки (как в 0004 + зона; свои заявки автор видит всегда)
drop policy if exists wo_select on public.work_orders;
drop policy if exists wo_insert on public.work_orders;
drop policy if exists wo_update on public.work_orders;
drop policy if exists wo_delete on public.work_orders;
create policy wo_select on public.work_orders for select using (
  work_orders.company_id = (select public.my_company_id()) and (
    (select public.is_manager())
    or work_orders.created_by = (select auth.uid())
    or work_orders.assigned_contractor_id in (select public.my_contractor_ids()))
  and (work_orders.created_by = (select auth.uid())
       or ((select public.zones_unrestricted())
         or work_orders.object_id in (select z.object_id from public.zone_obj_layers() z where z.layer_id is null)
         or (work_orders.object_id, work_orders.layer_id) in (select z.object_id, z.layer_id from public.zone_obj_layers() z
                           where z.layer_id is not null)
         or (work_orders.object_id in (select public.zone_partial_objects())
             and public.can_see(work_orders.object_id, work_orders.layer_id, work_orders.asset_id, work_orders.location_id)))));
create policy wo_insert on public.work_orders for insert with check (
  work_orders.company_id = (select public.my_company_id())
  and work_orders.created_by = (select auth.uid())
  and ((select public.zones_unrestricted())
         or work_orders.object_id in (select z.object_id from public.zone_obj_layers() z where z.layer_id is null)
         or (work_orders.object_id, work_orders.layer_id) in (select z.object_id, z.layer_id from public.zone_obj_layers() z
                           where z.layer_id is not null)
         or (work_orders.object_id in (select public.zone_partial_objects())
             and public.can_see(work_orders.object_id, work_orders.layer_id, work_orders.asset_id, work_orders.location_id))));
create policy wo_update on public.work_orders for update using (
  work_orders.company_id = (select public.my_company_id()) and (
    (select public.is_manager())
    or work_orders.created_by = (select auth.uid())
    or work_orders.assigned_contractor_id in (select public.my_contractor_ids()))
  and (work_orders.created_by = (select auth.uid())
       or ((select public.zones_unrestricted())
         or work_orders.object_id in (select z.object_id from public.zone_obj_layers() z where z.layer_id is null)
         or (work_orders.object_id, work_orders.layer_id) in (select z.object_id, z.layer_id from public.zone_obj_layers() z
                           where z.layer_id is not null)
         or (work_orders.object_id in (select public.zone_partial_objects())
             and public.can_see(work_orders.object_id, work_orders.layer_id, work_orders.asset_id, work_orders.location_id)))))
  with check (work_orders.company_id = (select public.my_company_id())
  and (work_orders.created_by = (select auth.uid())
       or ((select public.zones_unrestricted())
         or work_orders.object_id in (select z.object_id from public.zone_obj_layers() z where z.layer_id is null)
         or (work_orders.object_id, work_orders.layer_id) in (select z.object_id, z.layer_id from public.zone_obj_layers() z
                           where z.layer_id is not null)
         or (work_orders.object_id in (select public.zone_partial_objects())
             and public.can_see(work_orders.object_id, work_orders.layer_id, work_orders.asset_id, work_orders.location_id)))));
create policy wo_delete on public.work_orders for delete using (
  work_orders.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(work_orders.object_id, work_orders.layer_id, work_orders.asset_id, work_orders.location_id)));


-- визиты: менеджер — в своей зоне, остальные — свои (как в 0009)
drop policy if exists visits_select on public.visits;
create policy visits_select on public.visits for select using (
  visits.company_id = (select public.my_company_id())
  and (((select public.is_manager()) and ((select public.zones_unrestricted())
         or visits.object_id in (select z.object_id from public.zone_obj_layers() z)
         or visits.object_id in (select public.zone_partial_objects())))
       or visits.profile_id = (select auth.uid())));


-- подрядчики: видны, если хотя бы одно закрепление в зоне; новых
-- подрядчиков заводит администратор или менеджер без ограничений
drop policy if exists contractors_select on public.contractors;
create policy contractors_select on public.contractors for select using (
  contractors.company_id = (select public.my_company_id())
  and ((select public.zones_unrestricted()) or public.can_see_contractor(contractors.id)));
drop policy if exists contractors_manage on public.contractors;
drop policy if exists contractors_insert on public.contractors;
drop policy if exists contractors_update on public.contractors;
drop policy if exists contractors_delete on public.contractors;
create policy contractors_insert on public.contractors for insert with check (
  contractors.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())));
create policy contractors_update on public.contractors for update
  using (contractors.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())
       or public.can_see_contractor(contractors.id)))
  with check (contractors.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())));
create policy contractors_delete on public.contractors for delete using (
  contractors.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())
       or public.can_see_contractor(contractors.id)));

-- закрепления подрядчиков («на все объекты» — по системе)
drop policy if exists contractor_layers_select on public.contractor_layers;
create policy contractor_layers_select on public.contractor_layers for select using (
  exists (select 1 from public.contractors c where c.id = contractor_layers.contractor_id
                and c.company_id = (select public.my_company_id()))
  and ((contractor_layers.object_id is null
        and ((select public.zones_unrestricted())
             or exists (select 1 from public.zone_obj_layers() z
                         where z.layer_id is null or z.layer_id = contractor_layers.layer_id)))
       or ((select public.zones_unrestricted())
         or contractor_layers.object_id in (select z.object_id from public.zone_obj_layers() z where z.layer_id is null)
         or (contractor_layers.object_id, contractor_layers.layer_id) in (select z.object_id, z.layer_id from public.zone_obj_layers() z
                           where z.layer_id is not null)
         or (contractor_layers.object_id in (select public.zone_partial_objects())
             and public.can_see(contractor_layers.object_id, contractor_layers.layer_id, null, null)))));
drop policy if exists contractor_layers_manage on public.contractor_layers;
drop policy if exists contractor_layers_insert on public.contractor_layers;
drop policy if exists contractor_layers_update on public.contractor_layers;
drop policy if exists contractor_layers_delete on public.contractor_layers;
create policy contractor_layers_insert on public.contractor_layers for insert with check (
  (select public.is_manager()) and exists (select 1 from public.contractors c where c.id = contractor_layers.contractor_id
                and c.company_id = (select public.my_company_id()))
  and ((select public.is_admin()) or public.can_manage(contractor_layers.object_id, contractor_layers.layer_id, null, null)));
create policy contractor_layers_update on public.contractor_layers for update
  using ((select public.is_manager()) and exists (select 1 from public.contractors c where c.id = contractor_layers.contractor_id
                and c.company_id = (select public.my_company_id()))
  and ((select public.is_admin()) or public.can_manage(contractor_layers.object_id, contractor_layers.layer_id, null, null)))
  with check ((select public.is_manager()) and exists (select 1 from public.contractors c where c.id = contractor_layers.contractor_id
                and c.company_id = (select public.my_company_id()))
  and ((select public.is_admin()) or public.can_manage(contractor_layers.object_id, contractor_layers.layer_id, null, null)));
create policy contractor_layers_delete on public.contractor_layers for delete using (
  (select public.is_manager()) and exists (select 1 from public.contractors c where c.id = contractor_layers.contractor_id
                and c.company_id = (select public.my_company_id()))
  and ((select public.is_admin()) or public.can_manage(contractor_layers.object_id, contractor_layers.layer_id, null, null)));

-- планы ППР
drop policy if exists mplans_select on public.maintenance_plans;
create policy mplans_select on public.maintenance_plans for select using (
  maintenance_plans.company_id = (select public.my_company_id())
  and ((select public.zones_unrestricted())
         or maintenance_plans.object_id in (select z.object_id from public.zone_obj_layers() z where z.layer_id is null)
         or (maintenance_plans.object_id, maintenance_plans.layer_id) in (select z.object_id, z.layer_id from public.zone_obj_layers() z
                           where z.layer_id is not null)
         or (maintenance_plans.object_id in (select public.zone_partial_objects())
             and public.can_see(maintenance_plans.object_id, maintenance_plans.layer_id, maintenance_plans.asset_id, maintenance_plans.location_id))));
drop policy if exists mplans_manage on public.maintenance_plans;
drop policy if exists mplans_insert on public.maintenance_plans;
drop policy if exists mplans_update on public.maintenance_plans;
drop policy if exists mplans_delete on public.maintenance_plans;
create policy mplans_insert on public.maintenance_plans for insert with check (
  maintenance_plans.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(maintenance_plans.object_id, maintenance_plans.layer_id, maintenance_plans.asset_id, maintenance_plans.location_id)));
create policy mplans_update on public.maintenance_plans for update
  using (maintenance_plans.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(maintenance_plans.object_id, maintenance_plans.layer_id, maintenance_plans.asset_id, maintenance_plans.location_id)))
  with check (maintenance_plans.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(maintenance_plans.object_id, maintenance_plans.layer_id, maintenance_plans.asset_id, maintenance_plans.location_id)));
create policy mplans_delete on public.maintenance_plans for delete using (
  maintenance_plans.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or public.can_manage(maintenance_plans.object_id, maintenance_plans.layer_id, maintenance_plans.asset_id, maintenance_plans.location_id)));

-- регионы: виден, если в зоне есть хоть один его объект; список регионов
-- общий для компании — меняет администратор или менеджер без ограничений
drop policy if exists regions_select on public.regions;
create policy regions_select on public.regions for select using (
  regions.company_id = (select public.my_company_id())
  and ((select public.zones_unrestricted())
       or regions.id in (select o.region_id from public.objects o
                          where o.id in (select z.object_id from public.zone_obj_layers() z)
                             or o.id in (select public.zone_partial_objects()))));
drop policy if exists regions_manage on public.regions;
drop policy if exists regions_insert on public.regions;
drop policy if exists regions_update on public.regions;
drop policy if exists regions_delete on public.regions;
create policy regions_insert on public.regions for insert with check (
  regions.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())));
create policy regions_update on public.regions for update
  using (regions.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())))
  with check (regions.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())));
create policy regions_delete on public.regions for delete using (
  regions.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())));

-- хранилище планов этажей: файл этажа виден тем, кто видит этаж
-- (подзапрос к floors проходит через floors_select). Урок 0014: objects.name.
drop policy if exists floor_plans_select on storage.objects;
create policy floor_plans_select on storage.objects for select to authenticated using (
  bucket_id = 'floor-plans'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and ((select public.zones_unrestricted())
       or exists (select 1 from public.floors f
                   where f.id::text = (storage.foldername(objects.name))[3])));
-- Фото заявок (work-photos) уже проверяются через заявку (0006):
-- подзапрос к work_orders проходит через wo_select с зоной.


-- ---------------------------------------------------------------------
-- 5. Права на новые таблицы
-- ---------------------------------------------------------------------
alter table public.access_zones enable row level security;
alter table public.crews        enable row level security;
alter table public.crew_members enable row level security;
alter table public.crew_zones   enable row level security;
alter table public.access_audit enable row level security;
revoke all on public.access_zones, public.crews, public.crew_members, public.crew_zones,
              public.access_audit from anon;
grant select, insert, update, delete on public.access_zones, public.crews, public.crew_members,
              public.crew_zones to authenticated;
grant select on public.access_audit to authenticated;

-- зоны: свои видит сам менеджер, все — администратор; меняет только администратор
drop policy if exists access_zones_select on public.access_zones;
create policy access_zones_select on public.access_zones for select using (
  access_zones.company_id = (select public.my_company_id())
  and (access_zones.profile_id = (select auth.uid()) or (select public.is_admin())));
drop policy if exists access_zones_manage on public.access_zones;
drop policy if exists access_zones_insert on public.access_zones;
drop policy if exists access_zones_update on public.access_zones;
drop policy if exists access_zones_delete on public.access_zones;
create policy access_zones_insert on public.access_zones for insert with check (
  access_zones.company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy access_zones_update on public.access_zones for update
  using (access_zones.company_id = (select public.my_company_id()) and (select public.is_admin()))
  with check (access_zones.company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy access_zones_delete on public.access_zones for delete using (
  access_zones.company_id = (select public.my_company_id()) and (select public.is_admin()));

-- бригады: видны, если виден подрядчик; меняет менеджер, которому виден подрядчик
drop policy if exists crews_select on public.crews;
create policy crews_select on public.crews for select using (
  crews.company_id = (select public.my_company_id())
  and exists (select 1 from public.contractors c where c.id = crews.contractor_id));
drop policy if exists crews_manage on public.crews;
drop policy if exists crews_insert on public.crews;
drop policy if exists crews_update on public.crews;
drop policy if exists crews_delete on public.crews;
create policy crews_insert on public.crews for insert with check (
  crews.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.contractors c where c.id = crews.contractor_id));
create policy crews_update on public.crews for update
  using (crews.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.contractors c where c.id = crews.contractor_id))
  with check (crews.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.contractors c where c.id = crews.contractor_id));
create policy crews_delete on public.crews for delete using (
  crews.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.contractors c where c.id = crews.contractor_id));

drop policy if exists crew_members_select on public.crew_members;
create policy crew_members_select on public.crew_members for select using (
  crew_members.company_id = (select public.my_company_id())
  and exists (select 1 from public.crews c where c.id = crew_members.crew_id));
drop policy if exists crew_members_manage on public.crew_members;
drop policy if exists crew_members_insert on public.crew_members;
drop policy if exists crew_members_update on public.crew_members;
drop policy if exists crew_members_delete on public.crew_members;
create policy crew_members_insert on public.crew_members for insert with check (
  crew_members.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.crews c where c.id = crew_members.crew_id));
create policy crew_members_update on public.crew_members for update
  using (crew_members.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.crews c where c.id = crew_members.crew_id))
  with check (crew_members.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.crews c where c.id = crew_members.crew_id));
create policy crew_members_delete on public.crew_members for delete using (
  crew_members.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.crews c where c.id = crew_members.crew_id));

drop policy if exists crew_zones_select on public.crew_zones;
create policy crew_zones_select on public.crew_zones for select using (
  crew_zones.company_id = (select public.my_company_id())
  and exists (select 1 from public.crews c where c.id = crew_zones.crew_id));
drop policy if exists crew_zones_manage on public.crew_zones;
drop policy if exists crew_zones_insert on public.crew_zones;
drop policy if exists crew_zones_update on public.crew_zones;
drop policy if exists crew_zones_delete on public.crew_zones;
create policy crew_zones_insert on public.crew_zones for insert with check (
  crew_zones.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.crews c where c.id = crew_zones.crew_id));
create policy crew_zones_update on public.crew_zones for update
  using (crew_zones.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.crews c where c.id = crew_zones.crew_id))
  with check (crew_zones.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.crews c where c.id = crew_zones.crew_id));
create policy crew_zones_delete on public.crew_zones for delete using (
  crew_zones.company_id = (select public.my_company_id()) and (select public.is_manager())
  and exists (select 1 from public.crews c where c.id = crew_zones.crew_id));

-- аудит: читает только администратор; пишет только база (триггеры)
drop policy if exists access_audit_select on public.access_audit;
create policy access_audit_select on public.access_audit for select using (
  access_audit.company_id = (select public.my_company_id()) and (select public.is_admin()));

-- ---------------------------------------------------------------------
-- 6. Аудит: зоны, бригады, роли
-- ---------------------------------------------------------------------
create or replace function public.trg_access_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  rec jsonb := to_jsonb(coalesce(new, old));
  v_company uuid := (rec ->> 'company_id')::uuid;
  v_target uuid;
begin
  if tg_table_name = 'profiles' then
    if tg_op <> 'UPDATE' or new.role is not distinct from old.role or new.company_id is null then
      return null;
    end if;
    insert into access_audit(company_id, actor, action, entity, target, details)
    values (new.company_id, auth.uid(), 'role', 'profiles', new.id,
            jsonb_build_object('from', old.role, 'to', new.role));
    return null;
  end if;
  v_target := coalesce((rec ->> 'profile_id')::uuid, (rec ->> 'crew_id')::uuid, (rec ->> 'id')::uuid);
  insert into access_audit(company_id, actor, action, entity, target, details)
  values (v_company, auth.uid(), lower(tg_op), tg_table_name, v_target,
          case when tg_op = 'UPDATE'
               then jsonb_build_object('old', to_jsonb(old), 'new', to_jsonb(new))
               else rec end);
  return null;
end $$;

drop trigger if exists trg_access_zones_audit on public.access_zones;
create trigger trg_access_zones_audit after insert or update or delete on public.access_zones
  for each row execute function public.trg_access_audit();
drop trigger if exists trg_crews_audit on public.crews;
create trigger trg_crews_audit after insert or update or delete on public.crews
  for each row execute function public.trg_access_audit();
drop trigger if exists trg_crew_members_audit on public.crew_members;
create trigger trg_crew_members_audit after insert or update or delete on public.crew_members
  for each row execute function public.trg_access_audit();
drop trigger if exists trg_crew_zones_audit on public.crew_zones;
create trigger trg_crew_zones_audit after insert or update or delete on public.crew_zones
  for each row execute function public.trg_access_audit();
drop trigger if exists trg_profiles_role_audit on public.profiles;
create trigger trg_profiles_role_audit after update of role on public.profiles
  for each row execute function public.trg_access_audit();

revoke all on function public.trg_access_refs_check() from public, anon, authenticated;
revoke all on function public.trg_access_audit()      from public, anon, authenticated;

-- =====================================================================
-- Проверка после применения (только чтение; по одному запросу):
--
-- 1) Новые таблицы с RLS (ожидается 5 строк, все true):
-- select relname, relrowsecurity from pg_class
--  where oid in ('public.access_zones'::regclass, 'public.crews'::regclass,
--                'public.crew_members'::regclass, 'public.crew_zones'::regclass,
--                'public.access_audit'::regclass);
--
-- 2) Администраторы компаний (в каждой компании — хотя бы один):
-- select c.name, count(*) filter (where p.role = 'admin') as admins
--   from public.companies c left join public.profiles p on p.company_id = c.id
--  group by c.name order by 1;
--
-- 3) Зон пока нет — все видят как раньше (ожидается 0):
-- select count(*) from public.access_zones;
--
-- 4) Функции закрыты от анонимов (anon — false, authenticated — true):
-- select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon,
--        has_function_privilege('authenticated', p.oid, 'execute') as authenticated
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and p.proname in ('can_see', 'can_manage', 'can_see_contractor', 'zones_unrestricted',
--                      'my_zone_rules', 'is_admin');
-- =====================================================================
