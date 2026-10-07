-- 0010_report_visit_norms.sql
-- Назначение: данные для отчётов по подрядчикам.
-- 1) Норма посещений по договору: у закрепления подрядчика за слоем
--    (и объектом) — сколько визитов в месяц положено. Отчёт показывает
--    «факт / норма».
-- 2) Счётчик возвратов заявки: сколько раз работу вернули на доработку.
--    По нему отчёт считает «приёмку с первого раза». Считает только база,
--    приложение и пользователи изменить его не могут.
-- Зависит от: 0004 (contractor_layers, статус «returned»), 0008 (trg_wo_guard,
-- новые функции закрыты по умолчанию).
-- Применяется вручную: Supabase → SQL Editor. Безопасно запускать повторно.

begin;

-- ---------------------------------------------------------------------
-- 1. Норма визитов в месяц у закрепления подрядчика
--    null — нормы нет (в отчёте показывается только факт).
--    Меняет только менеджер: политика contractor_layers_manage из 0004.
-- ---------------------------------------------------------------------
alter table public.contractor_layers
  add column if not exists visits_per_month integer;
alter table public.contractor_layers drop constraint if exists contractor_layers_visits_per_month_check;
alter table public.contractor_layers add constraint contractor_layers_visits_per_month_check
  check (visits_per_month is null or visits_per_month between 0 and 1000);

-- ---------------------------------------------------------------------
-- 2. Счётчик возвратов заявки
-- ---------------------------------------------------------------------
alter table public.work_orders
  add column if not exists return_count integer not null default 0;

-- Заявки, которые уже возвращали до этой миграции: истории статусов нет,
-- но причина возврата остаётся в заявке — считаем такой возврат один раз.
update public.work_orders
   set return_count = 1
 where return_count = 0
   and coalesce(trim(return_reason), '') <> '';

-- Значение задаёт только база: при создании — 0, при переходе в «Возвращена» — +1.
-- Всё, что прислал клиент (в том числе менеджер), перезаписывается.
-- BEFORE-триггеры срабатывают по алфавиту: trg_wo_guard → trg_wo_layer_and_route →
-- trg_wo_return_count → trg_wo_status_flow. Если переход статуса запрещён,
-- trg_wo_status_flow отменит всё изменение целиком, и счётчик не вырастет.
create or replace function public.trg_wo_return_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.return_count := 0;
  else
    new.return_count := old.return_count
      + case when new.status = 'returned' and old.status is distinct from 'returned'
             then 1 else 0 end;
  end if;
  return new;
end $$;

drop trigger if exists trg_wo_return_count on public.work_orders;
create trigger trg_wo_return_count
  before insert or update on public.work_orders
  for each row execute function public.trg_wo_return_count();

-- Триггерную функцию вызывает только база.
revoke all on function public.trg_wo_return_count() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Индекс для отчёта по посещениям за период
-- ---------------------------------------------------------------------
create index if not exists idx_visits_company_started
  on public.visits (company_id, started_at desc);

commit;
