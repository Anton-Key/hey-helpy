-- Поле work_orders.assigned_contractor_id в рабочей базе добавлено вручную
-- (см. CLAUDE.md, «Миграции»), а 0004 на него опирается. Для чистой
-- установки добавляем его здесь — между 0003 и 0004, как в рабочей базе.
alter table public.work_orders
  add column if not exists assigned_contractor_id uuid
  references public.contractors(id) on delete set null;
