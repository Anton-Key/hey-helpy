-- =====================================================================
-- hey_helpy · Миграция 0006: фото «до» и «после»
-- 1) attachments: стадия фото (before/after), кто загрузил, флаг
--    подменённых координат. Доступ к вложениям — как к самой заявке
--    (раньше их видела и меняла вся компания).
-- 2) Хранилище work-photos (закрытое). Путь файла:
--    <company_id>/<work_order_id>/<имя>.jpg
-- 3) «На проверку» — только с фото со стадией «после» (раньше подходило
--    любое фото, в том числе «до» от заявителя).
-- 4) Фото «после» обязательно: у всех слоёв и по умолчанию для новых.
--
-- Не зависит от 0007 (языки): применять можно в любом порядке.
-- Повторный запуск безопасен.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Вложения
-- ---------------------------------------------------------------------
alter table public.attachments
  add column if not exists stage         text,
  add column if not exists uploaded_by   uuid references public.profiles(id) on delete set null,
  add column if not exists mock_location boolean not null default false;

-- Старые фото без стадии считаем фото «после».
update public.attachments set stage = 'after' where stage is null and kind = 'photo';

alter table public.attachments drop constraint if exists attachments_stage_check;
alter table public.attachments add constraint attachments_stage_check
  check (stage is null or stage in ('before', 'after'));

alter table public.attachments alter column uploaded_by set default auth.uid();

create index if not exists idx_attachments_wo on public.attachments (work_order_id, stage);

drop policy if exists attachments_company on public.attachments;
drop policy if exists attachments_select on public.attachments;
drop policy if exists attachments_insert on public.attachments;
drop policy if exists attachments_delete on public.attachments;

-- Видят те, кто видит заявку (политика wo_select из 0004 действует и здесь).
create policy attachments_select on public.attachments for select using (
  exists (select 1 from public.work_orders w where w.id = attachments.work_order_id));

-- Фото «после» — исполнитель назначенного подрядчика или менеджер, пока заявка в работе.
-- Фото «до» — автор заявки или менеджер, пока заявка не закрыта.
create policy attachments_insert on public.attachments for insert with check (
  uploaded_by = (select auth.uid())
  and kind = 'photo'
  and exists (
    select 1 from public.work_orders w
     where w.id = attachments.work_order_id
       and w.company_id = (select public.my_company_id())
       and (
         (attachments.stage = 'after'
            and w.status = 'in_progress'
            and ((select public.is_manager())
                 or w.assigned_contractor_id in (select public.my_contractor_ids())))
         or
         (attachments.stage = 'before'
            and w.status not in ('done', 'cancelled')
            and ((select public.is_manager()) or w.created_by = (select auth.uid())))
       )));

-- Удалить своё фото можно, пока работу не отправили на проверку.
create policy attachments_delete on public.attachments for delete using (
  uploaded_by = (select auth.uid())
  and exists (select 1 from public.work_orders w
               where w.id = attachments.work_order_id
                 and w.status not in ('on_review', 'done', 'cancelled')));

revoke all on public.attachments from anon;

-- ---------------------------------------------------------------------
-- 2. Хранилище фото
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('work-photos', 'work-photos', false, 10485760, array['image/jpeg'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists work_photos_select on storage.objects;
drop policy if exists work_photos_insert on storage.objects;
drop policy if exists work_photos_delete on storage.objects;

-- Папки пути: [1] — компания, [2] — заявка. Сравниваем как текст, чтобы
-- кривой путь давал «нет доступа», а не ошибку приведения к uuid.
create policy work_photos_select on storage.objects for select to authenticated using (
  bucket_id = 'work-photos'
  and exists (select 1 from public.work_orders w
               where w.id::text = (storage.foldername(name))[2]
                 and w.company_id::text = (storage.foldername(name))[1]));

create policy work_photos_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'work-photos'
  and exists (select 1 from public.work_orders w
               where w.id::text = (storage.foldername(name))[2]
                 and w.company_id::text = (storage.foldername(name))[1]
                 and w.company_id = (select public.my_company_id())
                 and w.status not in ('done', 'cancelled')
                 and ((select public.is_manager())
                      or w.created_by = (select auth.uid())
                      or w.assigned_contractor_id in (select public.my_contractor_ids()))));

create policy work_photos_delete on storage.objects for delete to authenticated using (
  bucket_id = 'work-photos' and owner_id = (select auth.uid())::text);

-- ---------------------------------------------------------------------
-- 3. Правила смены статуса: на проверку — только с фото «после».
--    Остальное без изменений относительно 0004.
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
         select 1 from attachments a
          where a.work_order_id = old.id and a.kind = 'photo'
            and coalesce(a.stage, 'after') = 'after') then
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

-- ---------------------------------------------------------------------
-- 4. Фото «после» обязательно.
--    Новые заявки берут requires_photo из слоя (триггер из 0004).
--    Слои новых компаний получают значение по умолчанию столбца, если
--    функция seed_default_layers его не задаёт явно (так в 0007).
-- ---------------------------------------------------------------------
alter table public.layers alter column requires_photo set default true;
update public.layers set requires_photo = true where requires_photo = false;

commit;
