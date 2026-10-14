-- 0019 — документы в заявке (шаг 24): PDF, Word, Excel, картинки, текст.
--
-- 1) attachments: новый вид 'document' и поля файла — имя (как его назвал
--    человек, 1–200 символов), тип (mime) и размер (≤ 20 МБ). У документа нет
--    стадии «до / после». Фото (kind = 'photo') — как раньше, правила 0006 не
--    меняются.
-- 2) Закрытое хранилище order-files: 20 МБ, только разрешённые типы.
--    Путь: <company_id>/<work_order_id>/<uuid>-<безопасное имя>; в путь
--    приложение кладёт только латиницу, цифры и -_. (остальное — «_»).
-- 3) Права — как у фото:
--    • видит документ тот, кто видит заявку (подзапрос к work_orders проходит
--      через wo_select с зонами доступа 0016);
--    • загружают автор заявки, менеджер (администратор) с правом на заявку и
--      исполнитель назначенного подрядчика; в отменённую заявку — нельзя;
--    • удаляют загрузивший и менеджер (администратор) с правом на заявку;
--    • чужая компания — никогда: компания пути = компания заявки = своя.
--
-- Повторный запуск безопасен: add column if not exists, drop … if exists,
-- on conflict do update.

-- ---------------------------------------------------------------------
-- 1. Вложения: вид 'document' и поля файла
-- ---------------------------------------------------------------------
alter table public.attachments
  add column if not exists file_name  text,
  add column if not exists mime       text,
  add column if not exists size_bytes bigint;

alter table public.attachments drop constraint if exists attachments_kind_check;
alter table public.attachments add constraint attachments_kind_check
  check (kind = any (array['photo', 'audio', 'video', 'model', 'document']));

alter table public.attachments drop constraint if exists attachments_document_check;
alter table public.attachments add constraint attachments_document_check
  check (kind <> 'document' or (
    stage is null
    and file_name is not null and char_length(btrim(file_name)) between 1 and 200
    and mime is not null and char_length(mime) between 3 and 120
    and size_bytes is not null and size_bytes between 1 and 20971520));

alter table public.attachments drop constraint if exists attachments_file_name_len;
alter table public.attachments add constraint attachments_file_name_len
  check (file_name is null or char_length(file_name) <= 200);

create index if not exists idx_attachments_wo_kind on public.attachments (work_order_id, kind);

-- Видят — как раньше (0006): те, кто видит заявку.
-- Добавляют: фото — без изменений (0006); документ — автор, менеджер,
-- исполнитель назначенного подрядчика; путь — папка этой заявки.
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
               and ((select public.is_manager())
                    or w.assigned_contractor_id in (select public.my_contractor_ids())))
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

-- Удаляют: фото — своё, пока работу не отправили на проверку (0006);
-- документ — загрузивший или менеджер с правом на заявку, в любом статусе.
drop policy if exists attachments_delete on public.attachments;
create policy attachments_delete on public.attachments for delete using (
  (kind <> 'document'
   and uploaded_by = (select auth.uid())
   and exists (select 1 from public.work_orders w
                where w.id = attachments.work_order_id
                  and w.status not in ('on_review', 'done', 'cancelled')))
  or
  (kind = 'document'
   and (uploaded_by = (select auth.uid()) or (select public.is_manager()))
   and exists (select 1 from public.work_orders w
                where w.id = attachments.work_order_id
                  and w.company_id = (select public.my_company_id()))));

-- ---------------------------------------------------------------------
-- 2. Хранилище документов
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('order-files', 'order-files', false, 20971520, array[
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'image/jpeg',
  'image/png',
  'text/plain'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists order_files_select on storage.objects;
drop policy if exists order_files_insert on storage.objects;
drop policy if exists order_files_delete on storage.objects;

-- Папки пути: [1] — компания, [2] — заявка. Сравнение текстом: кривой путь —
-- «нет доступа», а не ошибка приведения. Урок 0014: только objects.name.
create policy order_files_select on storage.objects for select to authenticated using (
  bucket_id = 'order-files'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and exists (select 1 from public.work_orders w
               where w.id::text = (storage.foldername(objects.name))[2]
                 and w.company_id::text = (storage.foldername(objects.name))[1]));

create policy order_files_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'order-files'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and exists (select 1 from public.work_orders w
               where w.id::text = (storage.foldername(objects.name))[2]
                 and w.company_id::text = (storage.foldername(objects.name))[1]
                 and w.status <> 'cancelled'
                 and ((select public.is_manager())
                      or w.created_by = (select auth.uid())
                      or w.assigned_contractor_id in (select public.my_contractor_ids()))));

-- Удаляет файл загрузивший или менеджер компании с правом на заявку.
create policy order_files_delete on storage.objects for delete to authenticated using (
  bucket_id = 'order-files'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and (objects.owner_id = (select auth.uid())::text
       or ((select public.is_manager())
           and exists (select 1 from public.work_orders w
                        where w.id::text = (storage.foldername(objects.name))[2]
                          and w.company_id::text = (storage.foldername(objects.name))[1]))));
