-- =====================================================================
-- hey_helpy · Миграция 0008: исправления безопасности из аудита
-- 1) Заявки: исполнитель меняет у своей заявки только статус; заявитель —
--    только содержание своей заявки; назначение, обязательное фото, время
--    и приёмку меняет только менеджер (или правила в базе). Обязательное
--    фото у новой заявки берётся из слоя, а не от приложения.
-- 2) Чек-листы и история заявки видны тем, кто видит саму заявку.
-- 3) Приглашения создаёт и видит только менеджер; срок действия по умолчанию.
-- 4) Справочники (объекты, помещения, подрядчики, исполнители и т. д.)
--    видит вся компания, меняет только менеджер.
-- 5) Служебные функции нельзя вызвать без входа; триггерные — вообще
--    нельзя вызвать напрямую. Новые функции по умолчанию закрыты —
--    каждую нужно явно открыть для authenticated (см. CLAUDE.md).
--
-- Зависит от: 0004, 0006 (политики фото и правила статусов).
-- Применяется вручную: Supabase → SQL Editor. Безопасно запускать повторно.
-- =====================================================================
begin;

do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'attachments'
                    and column_name = 'stage') then
    raise exception '0008: сначала примените миграцию 0006 (фото «до/после»)';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 1. Заявки: кто какие поля может менять
--    Триггеры BEFORE срабатывают по алфавиту: trg_wo_guard — раньше
--    trg_wo_layer_and_route и trg_wo_status_flow, то есть проверяет то,
--    что прислало приложение, до того как правила базы что-то допишут.
-- ---------------------------------------------------------------------
create or replace function public.trg_wo_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  -- поля, которые заявитель у своей заявки менять не может
  v_locked text[] := array[
    'company_id', 'created_by', 'created_at',
    'assigned_contractor_id', 'assigned_executor_id', 'assigned_by',
    'requires_photo', 'requires_scan', 'input_channel',
    'started_at', 'submitted_at', 'accepted_at', 'accepted_by', 'time_spent_minutes'];
  -- всё, что исполнитель может менять у заявки своего подрядчика
  v_exec_allowed text[] := array['status', 'updated_at'];
  k text;
begin
  -- обслуживание из SQL Editor / сервисным ключом — без ограничений
  if v_uid is null then return new; end if;
  if public.is_manager() then return new; end if;

  if tg_op = 'INSERT' then
    -- Обязательное фото и скан задаёт не автор: сбрасываем к значению столбца
    -- по умолчанию (false), затем trg_wo_layer_and_route (срабатывает после
    -- этого триггера) берёт requires_photo из настроек слоя.
    -- company_id и created_by подменить нельзя: их проверяет политика wo_insert
    -- (своя компания, created_by = auth.uid()) уже после всех BEFORE-триггеров.
    new.requires_photo         := false;
    new.requires_scan          := false;
    -- новая заявка всегда начинается с «новой»; назначает правило слоя
    -- (trg_wo_layer_and_route) или менеджер, а не сам автор
    new.status                 := 'new';
    new.assigned_contractor_id := null;
    new.assigned_executor_id   := null;
    new.assigned_by            := null;
    new.started_at             := null;
    new.submitted_at           := null;
    new.accepted_at            := null;
    new.accepted_by            := null;
    new.time_spent_minutes     := null;
    new.return_reason          := null;
    return new;
  end if;

  if old.created_by = v_uid then
    foreach k in array v_locked loop
      if (to_jsonb(new) -> k) is distinct from (to_jsonb(old) -> k) then
        raise exception 'forbidden: % is changed by manager only', k using errcode = '42501';
      end if;
    end loop;
    return new;
  end if;

  -- сюда доходит только исполнитель: политика wo_update пропускает
  -- менеджера, автора или исполнителя назначенного подрядчика
  if (to_jsonb(new) - v_exec_allowed) is distinct from (to_jsonb(old) - v_exec_allowed) then
    raise exception 'forbidden: executor can change status only' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_wo_guard on public.work_orders;
create trigger trg_wo_guard
  before insert or update on public.work_orders
  for each row execute function public.trg_wo_guard();

-- ---------------------------------------------------------------------
-- 2. Чек-листы и история: как сама заявка
--    (подзапрос к work_orders сам проходит через политику wo_select)
-- ---------------------------------------------------------------------
drop policy if exists checklist_company on public.checklist_items;
drop policy if exists checklist_select  on public.checklist_items;
drop policy if exists checklist_manage  on public.checklist_items;
drop policy if exists checklist_check   on public.checklist_items;

create policy checklist_select on public.checklist_items for select using (
  exists (select 1 from public.work_orders w where w.id = checklist_items.work_order_id));

create policy checklist_manage on public.checklist_items for all
  using ((select public.is_manager()) and exists (
    select 1 from public.work_orders w
     where w.id = checklist_items.work_order_id
       and w.company_id = (select public.my_company_id())))
  with check ((select public.is_manager()) and exists (
    select 1 from public.work_orders w
     where w.id = checklist_items.work_order_id
       and w.company_id = (select public.my_company_id())));

-- исполнитель отмечает пункты чек-листа своей заявки
create policy checklist_check on public.checklist_items for update
  using (exists (select 1 from public.work_orders w
                  where w.id = checklist_items.work_order_id
                    and w.assigned_contractor_id in (select public.my_contractor_ids())))
  with check (exists (select 1 from public.work_orders w
                       where w.id = checklist_items.work_order_id
                         and w.assigned_contractor_id in (select public.my_contractor_ids())));

drop policy if exists work_logs_company on public.work_logs;
drop policy if exists work_logs_select  on public.work_logs;
drop policy if exists work_logs_insert  on public.work_logs;

create policy work_logs_select on public.work_logs for select using (
  exists (select 1 from public.work_orders w where w.id = work_logs.work_order_id));

-- запись в историю — только от своего имени; исправлять и удалять историю нельзя
create policy work_logs_insert on public.work_logs for insert with check (
  by_profile = (select auth.uid())
  and exists (select 1 from public.work_orders w where w.id = work_logs.work_order_id));

-- ---------------------------------------------------------------------
-- 3. Приглашения: только менеджер; код действует 7 дней
--    (раньше любой сотрудник мог создать приглашение и сам себя
--    сделать исполнителем подрядчика)
-- ---------------------------------------------------------------------
drop policy if exists invites_company on public.invites;
drop policy if exists invites_manage  on public.invites;

create policy invites_manage on public.invites for all
  using ((select public.is_manager()) and exists (
    select 1 from public.contractors c
     where c.id = invites.contractor_id and c.company_id = (select public.my_company_id())))
  with check ((select public.is_manager()) and exists (
    select 1 from public.contractors c
     where c.id = invites.contractor_id and c.company_id = (select public.my_company_id())));

alter table public.invites alter column expires_at set default now() + interval '7 days';
update public.invites set expires_at = created_at + interval '7 days'
 where expires_at is null and used_at is null;

-- accept_invite: как в 0003, плюс проверка, что подрядчик существует
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
  if v_company is null then
    raise exception 'invite not found';
  end if;

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
revoke all on function public.accept_invite(text) from public, anon;
grant execute on function public.accept_invite(text) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Справочники: читает вся компания, меняет только менеджер
--    (слои и закрепления подрядчиков уже так устроены — 0004)
-- ---------------------------------------------------------------------

-- объекты
drop policy if exists objects_company on public.objects;
drop policy if exists objects_select  on public.objects;
drop policy if exists objects_manage  on public.objects;
create policy objects_select on public.objects for select
  using (company_id = (select public.my_company_id()));
create policy objects_manage on public.objects for all
  using (company_id = (select public.my_company_id()) and (select public.is_manager()))
  with check (company_id = (select public.my_company_id()) and (select public.is_manager()));

-- подрядчики
drop policy if exists contractors_company on public.contractors;
drop policy if exists contractors_select  on public.contractors;
drop policy if exists contractors_manage  on public.contractors;
create policy contractors_select on public.contractors for select
  using (company_id = (select public.my_company_id()));
create policy contractors_manage on public.contractors for all
  using (company_id = (select public.my_company_id()) and (select public.is_manager()))
  with check (company_id = (select public.my_company_id()) and (select public.is_manager()));

-- департаменты (через объект)
drop policy if exists departments_company on public.departments;
drop policy if exists departments_select  on public.departments;
drop policy if exists departments_manage  on public.departments;
create policy departments_select on public.departments for select using (exists (
  select 1 from public.objects o
   where o.id = departments.object_id and o.company_id = (select public.my_company_id())));
create policy departments_manage on public.departments for all
  using ((select public.is_manager()) and exists (
    select 1 from public.objects o
     where o.id = departments.object_id and o.company_id = (select public.my_company_id())))
  with check ((select public.is_manager()) and exists (
    select 1 from public.objects o
     where o.id = departments.object_id and o.company_id = (select public.my_company_id())));

-- помещения (через объект)
drop policy if exists locations_company on public.locations;
drop policy if exists locations_select  on public.locations;
drop policy if exists locations_manage  on public.locations;
create policy locations_select on public.locations for select using (exists (
  select 1 from public.objects o
   where o.id = locations.object_id and o.company_id = (select public.my_company_id())));
create policy locations_manage on public.locations for all
  using ((select public.is_manager()) and exists (
    select 1 from public.objects o
     where o.id = locations.object_id and o.company_id = (select public.my_company_id())))
  with check ((select public.is_manager()) and exists (
    select 1 from public.objects o
     where o.id = locations.object_id and o.company_id = (select public.my_company_id())));

-- оборудование (через помещение → объект)
drop policy if exists assets_company on public.assets;
drop policy if exists assets_select  on public.assets;
drop policy if exists assets_manage  on public.assets;
create policy assets_select on public.assets for select using (exists (
  select 1 from public.locations l join public.objects o on o.id = l.object_id
   where l.id = assets.location_id and o.company_id = (select public.my_company_id())));
create policy assets_manage on public.assets for all
  using ((select public.is_manager()) and exists (
    select 1 from public.locations l join public.objects o on o.id = l.object_id
     where l.id = assets.location_id and o.company_id = (select public.my_company_id())))
  with check ((select public.is_manager()) and exists (
    select 1 from public.locations l join public.objects o on o.id = l.object_id
     where l.id = assets.location_id and o.company_id = (select public.my_company_id())));

-- подрядчик ↔ объект (через подрядчика)
drop policy if exists contractor_objects_company on public.contractor_objects;
drop policy if exists contractor_objects_select  on public.contractor_objects;
drop policy if exists contractor_objects_manage  on public.contractor_objects;
create policy contractor_objects_select on public.contractor_objects for select using (exists (
  select 1 from public.contractors c
   where c.id = contractor_objects.contractor_id and c.company_id = (select public.my_company_id())));
create policy contractor_objects_manage on public.contractor_objects for all
  using ((select public.is_manager()) and exists (
    select 1 from public.contractors c
     where c.id = contractor_objects.contractor_id and c.company_id = (select public.my_company_id())))
  with check ((select public.is_manager()) and exists (
    select 1 from public.contractors c
     where c.id = contractor_objects.contractor_id and c.company_id = (select public.my_company_id())));

-- исполнители (через подрядчика). Сам себя исполнителем больше не добавить:
-- только менеджер или приглашение (accept_invite).
drop policy if exists executors_company on public.executors;
drop policy if exists executors_select  on public.executors;
drop policy if exists executors_manage  on public.executors;
create policy executors_select on public.executors for select using (exists (
  select 1 from public.contractors c
   where c.id = executors.contractor_id and c.company_id = (select public.my_company_id())));
create policy executors_manage on public.executors for all
  using ((select public.is_manager()) and exists (
    select 1 from public.contractors c
     where c.id = executors.contractor_id and c.company_id = (select public.my_company_id())))
  with check ((select public.is_manager()) and exists (
    select 1 from public.contractors c
     where c.id = executors.contractor_id and c.company_id = (select public.my_company_id())));

-- метки сканирования (через оборудование или помещение)
drop policy if exists scan_tags_company on public.scan_tags;
drop policy if exists scan_tags_select  on public.scan_tags;
drop policy if exists scan_tags_manage  on public.scan_tags;
create policy scan_tags_select on public.scan_tags for select using (
  exists (select 1 from public.assets a
            join public.locations l on l.id = a.location_id
            join public.objects o on o.id = l.object_id
           where a.id = scan_tags.asset_id and o.company_id = (select public.my_company_id()))
  or exists (select 1 from public.locations l
               join public.objects o on o.id = l.object_id
              where l.id = scan_tags.location_id and o.company_id = (select public.my_company_id())));
create policy scan_tags_manage on public.scan_tags for all
  using ((select public.is_manager()) and (
    exists (select 1 from public.assets a
              join public.locations l on l.id = a.location_id
              join public.objects o on o.id = l.object_id
             where a.id = scan_tags.asset_id and o.company_id = (select public.my_company_id()))
    or exists (select 1 from public.locations l
                 join public.objects o on o.id = l.object_id
                where l.id = scan_tags.location_id and o.company_id = (select public.my_company_id()))))
  with check ((select public.is_manager()) and (
    exists (select 1 from public.assets a
              join public.locations l on l.id = a.location_id
              join public.objects o on o.id = l.object_id
             where a.id = scan_tags.asset_id and o.company_id = (select public.my_company_id()))
    or exists (select 1 from public.locations l
                 join public.objects o on o.id = l.object_id
                where l.id = scan_tags.location_id and o.company_id = (select public.my_company_id()))));

-- AR-якоря (через оборудование)
drop policy if exists ar_anchors_company on public.ar_anchors;
drop policy if exists ar_anchors_select  on public.ar_anchors;
drop policy if exists ar_anchors_manage  on public.ar_anchors;
create policy ar_anchors_select on public.ar_anchors for select using (exists (
  select 1 from public.assets a
    join public.locations l on l.id = a.location_id
    join public.objects o on o.id = l.object_id
   where a.id = ar_anchors.asset_id and o.company_id = (select public.my_company_id())));
create policy ar_anchors_manage on public.ar_anchors for all
  using ((select public.is_manager()) and exists (
    select 1 from public.assets a
      join public.locations l on l.id = a.location_id
      join public.objects o on o.id = l.object_id
     where a.id = ar_anchors.asset_id and o.company_id = (select public.my_company_id())))
  with check ((select public.is_manager()) and exists (
    select 1 from public.assets a
      join public.locations l on l.id = a.location_id
      join public.objects o on o.id = l.object_id
     where a.id = ar_anchors.asset_id and o.company_id = (select public.my_company_id())));

-- визиты: свою отметку можно менять, но не переносить в чужую компанию
drop policy if exists visits_update on public.visits;
create policy visits_update on public.visits for update
  using (profile_id = (select auth.uid()) and company_id = (select public.my_company_id()))
  with check (profile_id = (select auth.uid()) and company_id = (select public.my_company_id()));

-- ---------------------------------------------------------------------
-- 5. Функции
-- ---------------------------------------------------------------------
-- Триггерные функции вызываются только базой, напрямую — никем.
revoke all on function public.handle_new_user()            from public, anon, authenticated;
revoke all on function public.trg_company_default_layers() from public, anon, authenticated;
revoke all on function public.trg_wo_layer_and_route()     from public, anon, authenticated;
revoke all on function public.trg_wo_status_flow()         from public, anon, authenticated;
revoke all on function public.trg_wo_guard()               from public, anon, authenticated;
revoke all on function public.touch_updated_at()           from public, anon, authenticated;
alter function public.touch_updated_at() set search_path = public;

-- Помощники для политик: нужны вошедшим пользователям, анонимам — нет.
revoke all on function public.my_company_id()     from public, anon;
revoke all on function public.my_role()           from public, anon;
revoke all on function public.is_manager()        from public, anon;
revoke all on function public.my_contractor_ids() from public, anon;
grant execute on function public.my_company_id()     to authenticated;
grant execute on function public.my_role()           to authenticated;
grant execute on function public.is_manager()        to authenticated;
grant execute on function public.my_contractor_ids() to authenticated;

-- Новые функции по умолчанию никому не открыты (как таблицы для anon — 0003).
-- Каждую новую функцию миграция открывает явно:
--   revoke all on function public.f(...) from public, anon;
--   grant execute on function public.f(...) to authenticated;  -- если её зовёт приложение или политика
-- Триггерным функциям grant не нужен.
-- Право «для всех» (PUBLIC) Postgres даёт глобально, а не по схеме — отзываем глобально.
alter default privileges for role postgres revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from anon;
alter default privileges for role postgres in schema public revoke execute on functions from authenticated;

commit;
