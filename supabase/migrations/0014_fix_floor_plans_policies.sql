-- =====================================================================
-- hey_helpy · Миграция 0014: исправление политик хранилища floor-plans
-- Ошибка 0013: внутри exists (select … from floors f …) имя столбца
-- name без таблицы означало floors.name («1 этаж»), а не путь файла
-- storage.objects.name. Поэтому загрузка плана всегда отклонялась
-- («new row violates row-level security policy»). Исправление —
-- явно objects.name (как в политиках work-photos из 0006).
-- Меняет только 2 политики. Безопасно запускать повторно.
-- =====================================================================

drop policy if exists floor_plans_insert on storage.objects;
create policy floor_plans_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'floor-plans'
  and (select public.is_manager())
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and exists (select 1 from public.floors f
               where f.id::text        = (storage.foldername(objects.name))[3]
                 and f.object_id::text = (storage.foldername(objects.name))[2]
                 and f.company_id      = (select public.my_company_id())));

drop policy if exists floor_plans_update on storage.objects;
create policy floor_plans_update on storage.objects for update to authenticated
  using (
    bucket_id = 'floor-plans'
    and (select public.is_manager())
    and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text)
  with check (
    bucket_id = 'floor-plans'
    and (select public.is_manager())
    and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
    and exists (select 1 from public.floors f
                 where f.id::text        = (storage.foldername(objects.name))[3]
                   and f.object_id::text = (storage.foldername(objects.name))[2]
                   and f.company_id      = (select public.my_company_id())));
