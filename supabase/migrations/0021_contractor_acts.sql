-- 0021 — «Оплата по доказательству»: ставки и акты подрядчикам (шаг 24).
-- Без реальных денег и платёжных систем: акт — документ для бухгалтерии.
--
-- 1) contractor_rates — необязательные ставки подрядчика: за заявку и за
--    визит планового ТО (задача ППР), валюта (ISO, по умолчанию RUB).
--    Отдельная таблица, а не столбцы contractors: подрядчик (исполнитель)
--    видит свою строку contractors, а ставки ему не показываются.
--    Читают менеджеры (с зоной — подрядчиков своей зоны) и администратор;
--    меняют администратор и менеджер без зон (как contractors_update, 0016).
-- 2) contractor_acts — сформированные акты: номер АКТ-<год>-<NNN> (сквозной
--    в компании за год), подрядчик, период, итоги и строки (снимок на момент
--    формирования), кто и когда, путь PDF в хранилище. Акт за тот же период
--    можно переформировать: новый номер, прежний — «заменён» (replaced).
--    Создаёт и помечает только функция contractor_act_issue (менеджер
--    с правом на подрядчика); PDF — contractor_act_set_pdf. Читают менеджеры
--    своей зоны и администратор. Подрядчики и исполнители актов не видят.
-- 3) Закрытое хранилище contractor-acts (PDF до 10 МБ):
--    <company_id>/<act_id>/<файл>.pdf.
--
-- Повторный запуск безопасен: if not exists, create or replace, drop … if exists.

-- ---------------------------------------------------------------------
-- 1. Ставки
-- ---------------------------------------------------------------------
create table if not exists public.contractor_rates (
  contractor_id uuid primary key references public.contractors(id) on delete cascade,
  company_id    uuid not null references public.companies(id) on delete cascade,
  rate_order    numeric(12,2) check (rate_order is null or rate_order >= 0),
  rate_visit    numeric(12,2) check (rate_visit is null or rate_visit >= 0),
  currency      text not null default 'RUB' check (currency ~ '^[A-Z]{3}$'),
  updated_by    uuid references public.profiles(id) on delete set null default auth.uid(),
  updated_at    timestamptz not null default now()
);
alter table public.contractor_rates enable row level security;
revoke all on public.contractor_rates from anon;
grant select, insert, update, delete on public.contractor_rates to authenticated;

-- Компания ставки = компания подрядчика.
create or replace function public.trg_contractor_rates_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from contractors c where c.id = new.contractor_id and c.company_id = new.company_id) then
    raise exception 'contractor_rates: подрядчик другой компании' using errcode = '42501';
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke all on function public.trg_contractor_rates_check() from public, anon, authenticated;
drop trigger if exists trg_contractor_rates_check on public.contractor_rates;
create trigger trg_contractor_rates_check before insert or update on public.contractor_rates
  for each row execute function public.trg_contractor_rates_check();

drop policy if exists contractor_rates_select on public.contractor_rates;
drop policy if exists contractor_rates_insert on public.contractor_rates;
drop policy if exists contractor_rates_update on public.contractor_rates;
drop policy if exists contractor_rates_delete on public.contractor_rates;
create policy contractor_rates_select on public.contractor_rates for select using (
  contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())
       or public.can_see_contractor(contractor_rates.contractor_id)));
create policy contractor_rates_insert on public.contractor_rates for insert with check (
  contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())));
create policy contractor_rates_update on public.contractor_rates for update
  using (contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
         and ((select public.is_admin()) or (select public.zones_unrestricted())))
  with check (contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
         and ((select public.is_admin()) or (select public.zones_unrestricted())));
create policy contractor_rates_delete on public.contractor_rates for delete using (
  contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())));

-- ---------------------------------------------------------------------
-- 2. Акты
-- ---------------------------------------------------------------------
create table if not exists public.contractor_acts (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade,
  contractor_id uuid not null references public.contractors(id) on delete cascade,
  year          int  not null check (year between 2000 and 2100),
  seq           int  not null check (seq > 0),
  number        text not null,
  period_start  date not null,
  period_end    date not null check (period_end >= period_start),
  status        text not null default 'active' check (status in ('active', 'replaced')),
  replaced_by   uuid references public.contractor_acts(id) on delete set null,
  totals        jsonb not null default '{}'::jsonb check (jsonb_typeof(totals) = 'object'),
  items         jsonb not null default '[]'::jsonb check (jsonb_typeof(items) = 'array'),
  pdf_path      text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  unique (company_id, year, seq)
);
create index if not exists idx_contractor_acts_contractor
  on public.contractor_acts (contractor_id, period_start, created_at desc);
alter table public.contractor_acts enable row level security;
revoke all on public.contractor_acts from anon;
grant select on public.contractor_acts to authenticated;

drop policy if exists contractor_acts_select on public.contractor_acts;
create policy contractor_acts_select on public.contractor_acts for select using (
  contractor_acts.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())
       or public.can_see_contractor(contractor_acts.contractor_id)));

-- Сформировать акт: номер по компании за год, прежние активные акты этого
-- подрядчика за тот же период — «заменён». Проверки: менеджер (админ) своей
-- компании, подрядчик своей компании и в его зоне доступа, строки ≤ 2000.
create or replace function public.contractor_act_issue(
  p_contractor uuid, p_from date, p_to date, p_totals jsonb, p_items jsonb)
returns table (id uuid, number text)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_company uuid := public.my_company_id();
  v_year int := extract(year from p_to)::int;
  v_seq int;
  v_id uuid;
  v_number text;
begin
  if auth.uid() is null or not public.is_manager() then
    raise exception 'act_denied' using errcode = '42501';
  end if;
  if not exists (select 1 from contractors c where c.id = p_contractor and c.company_id = v_company) then
    raise exception 'act_denied' using errcode = '42501';
  end if;
  if not (public.is_admin() or public.zones_unrestricted() or public.can_see_contractor(p_contractor)) then
    raise exception 'act_denied' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 400 then
    raise exception 'act_bad_period' using errcode = '22023';
  end if;
  if jsonb_typeof(coalesce(p_totals, '{}')) <> 'object' or jsonb_typeof(coalesce(p_items, '[]')) <> 'array'
     or jsonb_array_length(coalesce(p_items, '[]')) > 2000 then
    raise exception 'act_bad_payload' using errcode = '22023';
  end if;

  -- Номер — сквозной по компании за год; блокировка на время транзакции,
  -- чтобы два одновременных акта не получили один номер.
  perform pg_advisory_xact_lock(hashtext('contractor_acts:' || v_company::text || ':' || v_year));
  select coalesce(max(a.seq), 0) + 1 into v_seq
    from contractor_acts a where a.company_id = v_company and a.year = v_year;
  v_number := format('АКТ-%s-%s', v_year, lpad(v_seq::text, 3, '0'));

  insert into contractor_acts(company_id, contractor_id, year, seq, number, period_start, period_end,
                              totals, items, created_by)
  values (v_company, p_contractor, v_year, v_seq, v_number, p_from, p_to,
          coalesce(p_totals, '{}'), coalesce(p_items, '[]'), auth.uid())
  returning contractor_acts.id into v_id;

  update contractor_acts a set status = 'replaced', replaced_by = v_id
   where a.company_id = v_company and a.contractor_id = p_contractor
     and a.period_start = p_from and a.period_end = p_to
     and a.status = 'active' and a.id <> v_id;

  return query select v_id, v_number;
end $$;
revoke all on function public.contractor_act_issue(uuid, date, date, jsonb, jsonb) from public, anon;
grant execute on function public.contractor_act_issue(uuid, date, date, jsonb, jsonb) to authenticated;

-- Путь PDF акта: только свой акт (видимый по RLS) и только папка этого акта.
create or replace function public.contractor_act_set_pdf(p_act uuid, p_path text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_company uuid := public.my_company_id();
begin
  if auth.uid() is null or not public.is_manager() then
    raise exception 'act_denied' using errcode = '42501';
  end if;
  if p_path is null or p_path !~ ('^' || v_company::text || '/' || p_act::text || '/[A-Za-z0-9_.-]{1,80}\.pdf$') then
    raise exception 'act_bad_path' using errcode = '22023';
  end if;
  update contractor_acts a set pdf_path = p_path
   where a.id = p_act and a.company_id = v_company
     and (public.is_admin() or public.zones_unrestricted() or public.can_see_contractor(a.contractor_id));
  if not found then
    raise exception 'act_denied' using errcode = '42501';
  end if;
end $$;
revoke all on function public.contractor_act_set_pdf(uuid, text) from public, anon;
grant execute on function public.contractor_act_set_pdf(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Хранилище PDF актов
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('contractor-acts', 'contractor-acts', false, 10485760, array['application/pdf'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists contractor_acts_files_select on storage.objects;
drop policy if exists contractor_acts_files_insert on storage.objects;

-- Папки: [1] — компания, [2] — акт. Подзапрос к contractor_acts проходит
-- через contractor_acts_select (менеджер своей зоны). Урок 0014: objects.name.
create policy contractor_acts_files_select on storage.objects for select to authenticated using (
  bucket_id = 'contractor-acts'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and exists (select 1 from public.contractor_acts a
               where a.id::text = (storage.foldername(objects.name))[2]));

create policy contractor_acts_files_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'contractor-acts'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and (select public.is_manager())
  and exists (select 1 from public.contractor_acts a
               where a.id::text = (storage.foldername(objects.name))[2]
                 and a.pdf_path is null));
