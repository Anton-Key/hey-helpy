-- =====================================================================
-- hey_helpy · Миграция 0023: кто что может делать с заявкой (шаг 26)
--
-- Разделение обязанностей: работу делает и сдаёт ТОЛЬКО исполнитель
-- назначенного подрядчика, принимает — менеджер (не тот, кто сдал).
-- Раньше (0006) менеджер мог сам начать, сам сдать и сам принять.
--
-- 1) work_orders.submitted_by — кто отправил на проверку (ставит только
--    база). Принять / вернуть этот же человек не может.
-- 2) trg_wo_status_flow — новая версия (теперь и на insert):
--      назначить (→ assigned)        менеджер с правом на заявку, автор — пока «Новая»;
--      начать (→ in_progress)        только исполнитель назначенного подрядчика
--                                    (в бригаде — только в зоне бригады, как 0016);
--      на проверку (→ on_review)     только он же, с фото «после», если нужно;
--      принять / вернуть             менеджер с правом на заявку или администратор,
--                                    но не тот, кто отправил на проверку;
--      отменить                      менеджер с правом на заявку; автор — пока
--                                    работа не начата (new / assigned).
--    Новая заявка от вошедшего пользователя — только «Новая» или
--    «Назначена» (раньше менеджер мог вставить сразу «Выполнена»).
--    Без auth.uid() (SQL Editor, Refresh demo, service_role) — как раньше,
--    без ограничений. Функции бота tg_* создают заявки «Новая» — не меняется.
-- 3) trg_wo_guard — автор меняет содержание своей заявки, только пока
--    работа не начата (new / assigned); submitted_by — только база.
-- 4) Соседние правила: фото «после» (attachments_insert), отметка
--    чек-листа (trg_checklist_guard), визит (visits_insert) — только
--    исполнитель назначенного подрядчика. Фото «до» и документы менеджер
--    прикладывает по-прежнему.
-- 5) attachments.source: camera | file | telegram | demo. Ставит
--    приложение при вставке; изменить потом нельзя никому, кроме
--    обслуживания (trg_attachments_source). Время снимка — уже
--    существующий столбец taken_at. Старые строки: demo/… — demo,
--    …/tg_… — telegram, остальные — file.
--
-- Повторный запуск безопасен: add column if not exists, create or replace,
-- drop … if exists.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Кто отправил на проверку
-- ---------------------------------------------------------------------
alter table public.work_orders
  add column if not exists submitted_by uuid references public.profiles(id) on delete set null;

-- ---------------------------------------------------------------------
-- 2. Исполнитель назначенного подрядчика (с зоной бригады) — одна функция
--    для триггеров и политик.
-- ---------------------------------------------------------------------
create or replace function public.wo_is_executor(p_order uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select w.assigned_contractor_id is not null
       and w.assigned_contractor_id in (select public.my_contractor_ids())
       and (public.zones_unrestricted()
            or public.can_see(w.object_id, w.layer_id, w.asset_id, w.location_id))
      from work_orders w where w.id = p_order), false);
$$;
revoke all on function public.wo_is_executor(uuid) from public, anon;
grant execute on function public.wo_is_executor(uuid) to authenticated;

-- Менеджер (админ) с правом на заявку: администратор — вся компания,
-- менеджер — своя зона (0016).
create or replace function public.wo_is_manager(p_order uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_manager() and coalesce((
    select w.company_id = public.my_company_id()
       and (public.is_admin()
            or public.can_manage(w.object_id, w.layer_id, w.asset_id, w.location_id))
      from work_orders w where w.id = p_order), false);
$$;
revoke all on function public.wo_is_manager(uuid) from public, anon;
grant execute on function public.wo_is_manager(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Смена статуса
-- ---------------------------------------------------------------------
create or replace function public.trg_wo_status_flow()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_mgr    boolean;
  v_author boolean;
  v_exec   boolean;
  f text;
  t text := new.status;
begin
  -- обслуживание из SQL Editor / сервисным ключом — без ограничений
  if v_uid is null then return new; end if;

  if tg_op = 'INSERT' then
    -- новая заявка начинается с «Новой» (или «Назначена» правилом слоя)
    if new.status not in ('new', 'assigned') then
      raise exception 'status change -> % not allowed', new.status using errcode = '42501';
    end if;
    new.started_at   := null;
    new.submitted_at := null;
    new.submitted_by := null;
    new.accepted_at  := null;
    new.accepted_by  := null;
    return new;
  end if;

  -- кто сдал работу, пишет только база
  new.submitted_by := old.submitted_by;
  f := old.status;
  if f = t then return new; end if;

  v_mgr    := public.wo_is_manager(old.id);
  v_author := old.created_by = v_uid;
  v_exec   := public.wo_is_executor(old.id);

  if t = 'assigned' and f in ('new', 'returned') and (v_mgr or (v_author and f = 'new')) then
    null;
  elsif t = 'in_progress' and f in ('new', 'assigned', 'returned') and v_exec then
    new.started_at := coalesce(old.started_at, now());
  elsif t = 'on_review' and f = 'in_progress' and v_exec then
    if old.requires_photo and not exists (
         select 1 from attachments a
          where a.work_order_id = old.id and a.kind = 'photo'
            and coalesce(a.stage, 'after') = 'after') then
      raise exception 'photo required' using hint = 'Прикрепите фото выполненной работы';
    end if;
    new.submitted_at := now();
    new.submitted_by := v_uid;
    if old.started_at is not null then
      new.time_spent_minutes := greatest(1, ceil(extract(epoch from now() - old.started_at) / 60))::int;
    end if;
  elsif t in ('done', 'returned') and f = 'on_review' and v_mgr
        and old.submitted_by is not distinct from v_uid then
    raise exception 'status change % -> % not allowed: same person submitted', f, t
      using errcode = '42501', hint = 'Принять должен другой менеджер';
  elsif t = 'done' and f = 'on_review' and v_mgr then
    new.accepted_at := now();
    new.accepted_by := v_uid;
  elsif t = 'returned' and f = 'on_review' and v_mgr then
    if coalesce(trim(new.return_reason), '') = '' then
      raise exception 'return reason required' using hint = 'Укажите, что не так';
    end if;
  elsif t = 'cancelled' and f not in ('done', 'cancelled')
        and (v_mgr or (v_author and f in ('new', 'assigned'))) then
    null;
  else
    raise exception 'status change % -> % not allowed', f, t using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.trg_wo_status_flow() from public, anon, authenticated;

-- Теперь и на insert, и на любое изменение (submitted_by защищён всегда).
drop trigger if exists trg_wo_status_flow on public.work_orders;
create trigger trg_wo_status_flow
  before insert or update on public.work_orders
  for each row execute function public.trg_wo_status_flow();

-- ---------------------------------------------------------------------
-- 4. Кто какие поля меняет (0008 + submitted_by, автор — до начала работы)
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
    'started_at', 'submitted_at', 'submitted_by', 'accepted_at', 'accepted_by',
    'time_spent_minutes'];
  -- всё, что исполнитель может менять у заявки своего подрядчика
  v_exec_allowed text[] := array['status', 'updated_at'];
  k text;
begin
  -- обслуживание из SQL Editor / сервисным ключом — без ограничений
  if v_uid is null then return new; end if;
  if public.is_manager() then return new; end if;

  if tg_op = 'INSERT' then
    new.requires_photo         := false;
    new.requires_scan          := false;
    new.status                 := 'new';
    new.assigned_contractor_id := null;
    new.assigned_executor_id   := null;
    new.assigned_by            := null;
    new.started_at             := null;
    new.submitted_at           := null;
    new.submitted_by           := null;
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
    -- содержание — только пока работа не начата; статус проверяет trg_wo_status_flow
    if old.status not in ('new', 'assigned')
       and (to_jsonb(new) - v_exec_allowed) is distinct from (to_jsonb(old) - v_exec_allowed) then
      raise exception 'forbidden: author edits only before work starts' using errcode = '42501';
    end if;
    return new;
  end if;

  -- сюда доходит только исполнитель: политика wo_update пропускает
  -- менеджера, автора или исполнителя назначенного подрядчика
  if (to_jsonb(new) - v_exec_allowed) is distinct from (to_jsonb(old) - v_exec_allowed) then
    raise exception 'forbidden: executor can change status only' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.trg_wo_guard() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. Вложения: источник фото
-- ---------------------------------------------------------------------
alter table public.attachments
  add column if not exists source text not null default 'file';

alter table public.attachments drop constraint if exists attachments_source_check;
alter table public.attachments add constraint attachments_source_check
  check (source in ('camera', 'file', 'telegram', 'demo'));

-- старые строки: демо-картинки и фото из бота (повторно — ничего не меняет)
update public.attachments set source = 'demo'
 where source = 'file' and storage_path like 'demo/%';
update public.attachments set source = 'telegram'
 where source = 'file' and kind = 'photo' and storage_path like '%/tg\_%';

-- Источник ставится один раз при вставке; потом его не меняет никто, кроме
-- обслуживания. «demo» — только обслуживание, «telegram» — только бот
-- (tg_create_order ставит hh.telegram = 1), «camera» — только фото.
create or replace function public.trg_attachments_source()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;
  if tg_op = 'UPDATE' then
    new.source   := old.source;
    new.taken_at := old.taken_at;
    return new;
  end if;
  if coalesce(current_setting('hh.telegram', true), '') = '1' and new.kind = 'photo' then
    new.source := 'telegram';
  elsif new.source not in ('camera', 'file') or new.kind <> 'photo' then
    new.source := 'file';
  end if;
  return new;
end $$;
revoke all on function public.trg_attachments_source() from public, anon, authenticated;

drop trigger if exists trg_attachments_source on public.attachments;
create trigger trg_attachments_source
  before insert or update on public.attachments
  for each row execute function public.trg_attachments_source();

-- Фото «после» — только исполнитель назначенного подрядчика (был ещё
-- менеджер, 0006 / 0019). Фото «до» и документы — без изменений.
drop policy if exists attachments_insert on public.attachments;
create policy attachments_insert on public.attachments for insert with check (
  uploaded_by = (select auth.uid())
  and (
    (kind = 'photo'
     and exists (
       select 1 from public.work_orders w
        where w.id = attachments.work_order_id
          and w.company_id = (select public.my_company_id())
          and (
            (attachments.stage = 'after'
               and w.status = 'in_progress'
               and public.wo_is_executor(w.id))
            or
            (attachments.stage = 'before'
               and w.status not in ('done', 'cancelled')
               and ((select public.is_manager()) or w.created_by = (select auth.uid())))
          )))
    or
    (kind = 'document'
     and exists (
       select 1 from public.work_orders w
        where w.id = attachments.work_order_id
          and w.company_id = (select public.my_company_id())
          and w.status <> 'cancelled'
          and attachments.storage_path like w.company_id::text || '/' || w.id::text || '/%'
          and ((select public.is_manager())
               or w.created_by = (select auth.uid())
               or w.assigned_contractor_id in (select public.my_contractor_ids()))))
  ));

-- ---------------------------------------------------------------------
-- 6. Чек-лист: пункты заводит менеджер (0008), отмечает — только
--    исполнитель назначенного подрядчика; кто и когда — пишет база.
-- ---------------------------------------------------------------------
create or replace function public.trg_checklist_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_exec boolean;
begin
  if v_uid is null then return new; end if;
  if tg_op = 'INSERT' then
    new.is_done := false;
    new.done_at := null;
    new.done_by := null;
    return new;
  end if;
  v_exec := public.wo_is_executor(old.work_order_id);
  if new.is_done is distinct from old.is_done then
    if not v_exec then
      raise exception 'checklist is checked by contractor executor only' using errcode = '42501';
    end if;
    new.done_by := case when new.is_done then v_uid end;
    new.done_at := case when new.is_done then now() end;
  else
    new.done_by := old.done_by;
    new.done_at := old.done_at;
  end if;
  -- исполнитель меняет только отметку
  if not public.is_manager()
     and (new.text is distinct from old.text or new.work_order_id is distinct from old.work_order_id) then
    raise exception 'forbidden: executor can check items only' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.trg_checklist_guard() from public, anon, authenticated;

drop trigger if exists trg_checklist_guard on public.checklist_items;
create trigger trg_checklist_guard
  before insert or update on public.checklist_items
  for each row execute function public.trg_checklist_guard();

-- ---------------------------------------------------------------------
-- 7. Визит — только исполнитель назначенного подрядчика (был ещё менеджер, 0009)
-- ---------------------------------------------------------------------
drop policy if exists visits_insert on public.visits;
create policy visits_insert on public.visits for insert with check (
  company_id = (select public.my_company_id())
  and profile_id = (select auth.uid())
  and exists (
    select 1 from public.work_orders w
     where w.id = visits.work_order_id
       and w.company_id = (select public.my_company_id())
       and w.status = 'in_progress'
       and public.wo_is_executor(w.id)));
