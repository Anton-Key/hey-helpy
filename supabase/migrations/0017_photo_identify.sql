-- 0017 — «Узнать по фото» (шаг 22): журнал узнаваний для цифр к питчу.
--
-- 1) Таблица photo_identifications: одно узнавание — одна строка. БЕЗ фото и
--    без текста шильдика: вид, уверенность, место, лучший кандидат функции,
--    что выбрал человек и чем кончилось (outcome), модель и время.
-- 2) Доступ: вставляет и дописывает выбор (chosen_asset_id, outcome) только
--    автор, в своей компании; читают автор (свою строку — чтобы дописать) и
--    менеджеры / администратор компании. Удалять нельзя никому (кроме каскада
--    при удалении компании или пользователя).
-- 3) Триггер: ссылки на объект, этаж, помещение и оборудование — только своей
--    компании (при изменении проверяются только изменённые ссылки: при
--    удалении оборудования вторая ссылка на него ещё не обнулена); после вставки меняются только chosen_asset_id и outcome
--    (обнуление ссылок при удалении объекта / оборудования разрешено).
-- 4) photo_identify_stats(компания, с, по): всего узнаваний, с решением,
--    «угадал с первого раза» (matched_top), доля, среднее время. Под RLS
--    вызывающего (security invoker): менеджер видит свою компанию.
--
-- Повторный запуск безопасен: if not exists, create or replace, drop … if exists.

-- ---------------------------------------------------------------------
-- 1. Таблица
-- ---------------------------------------------------------------------
create table if not exists public.photo_identifications (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies(id) on delete cascade,
  user_id         uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  object_id       uuid references public.objects(id) on delete set null,
  floor_id        uuid references public.floors(id) on delete set null,
  location_id     uuid references public.locations(id) on delete set null,
  kind            text,
  confidence      real,
  top_asset_id    uuid references public.assets(id) on delete set null,
  chosen_asset_id uuid references public.assets(id) on delete set null,
  outcome         text,
  model           text,
  ms              integer,
  created_at      timestamptz not null default now()
);

alter table public.photo_identifications drop constraint if exists photo_ident_kind_chk;
alter table public.photo_identifications add constraint photo_ident_kind_chk
  check (kind is null or kind ~ '^[a-z_]{1,32}$');
alter table public.photo_identifications drop constraint if exists photo_ident_confidence_chk;
alter table public.photo_identifications add constraint photo_ident_confidence_chk
  check (confidence is null or (confidence >= 0 and confidence <= 1));
alter table public.photo_identifications drop constraint if exists photo_ident_outcome_chk;
alter table public.photo_identifications add constraint photo_ident_outcome_chk
  check (outcome is null or outcome in ('matched_top', 'matched_other', 'new_asset', 'dismissed'));
alter table public.photo_identifications drop constraint if exists photo_ident_dismissed_chk;
alter table public.photo_identifications add constraint photo_ident_dismissed_chk
  check (outcome is distinct from 'dismissed' or chosen_asset_id is null);
alter table public.photo_identifications drop constraint if exists photo_ident_model_chk;
alter table public.photo_identifications add constraint photo_ident_model_chk
  check (model is null or model in ('main', 'lite'));
alter table public.photo_identifications drop constraint if exists photo_ident_ms_chk;
alter table public.photo_identifications add constraint photo_ident_ms_chk
  check (ms is null or (ms >= 0 and ms <= 600000));

create index if not exists idx_photo_ident_company_created
  on public.photo_identifications (company_id, created_at desc);
create index if not exists idx_photo_ident_user on public.photo_identifications (user_id);
create index if not exists idx_photo_ident_object on public.photo_identifications (object_id);
create index if not exists idx_photo_ident_floor on public.photo_identifications (floor_id);
create index if not exists idx_photo_ident_location on public.photo_identifications (location_id);
create index if not exists idx_photo_ident_top on public.photo_identifications (top_asset_id);
create index if not exists idx_photo_ident_chosen on public.photo_identifications (chosen_asset_id);

-- ---------------------------------------------------------------------
-- 2. Проверка ссылок и неизменяемых полей
-- ---------------------------------------------------------------------
create or replace function public.photo_ident_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    -- Меняются только выбор человека и итог; ссылки можно только обнулить
    -- (так делает on delete set null при удалении объекта или оборудования).
    if new.id is distinct from old.id
       or new.company_id is distinct from old.company_id
       or new.user_id is distinct from old.user_id
       or new.kind is distinct from old.kind
       or new.confidence is distinct from old.confidence
       or new.model is distinct from old.model
       or new.ms is distinct from old.ms
       or new.created_at is distinct from old.created_at
       or (new.object_id is not null and new.object_id is distinct from old.object_id)
       or (new.floor_id is not null and new.floor_id is distinct from old.floor_id)
       or (new.location_id is not null and new.location_id is distinct from old.location_id)
       or (new.top_asset_id is not null and new.top_asset_id is distinct from old.top_asset_id)
    then
      raise exception 'photo_identifications: можно изменить только chosen_asset_id и outcome'
        using errcode = '42501';
    end if;
  end if;

  if new.object_id is not null and (tg_op = 'INSERT' or new.object_id is distinct from old.object_id) and not exists (
       select 1 from objects o where o.id = new.object_id and o.company_id = new.company_id) then
    raise exception 'photo_identifications: объект другой компании' using errcode = '42501';
  end if;
  if new.floor_id is not null and (tg_op = 'INSERT' or new.floor_id is distinct from old.floor_id) and not exists (
       select 1 from floors f where f.id = new.floor_id and f.company_id = new.company_id) then
    raise exception 'photo_identifications: этаж другой компании' using errcode = '42501';
  end if;
  if new.location_id is not null and (tg_op = 'INSERT' or new.location_id is distinct from old.location_id) and not exists (
       select 1 from locations l join objects o on o.id = l.object_id
        where l.id = new.location_id and o.company_id = new.company_id) then
    raise exception 'photo_identifications: помещение другой компании' using errcode = '42501';
  end if;
  if new.top_asset_id is not null and (tg_op = 'INSERT' or new.top_asset_id is distinct from old.top_asset_id) and not exists (
       select 1 from assets a join locations l on l.id = a.location_id join objects o on o.id = l.object_id
        where a.id = new.top_asset_id and o.company_id = new.company_id) then
    raise exception 'photo_identifications: оборудование другой компании' using errcode = '42501';
  end if;
  if new.chosen_asset_id is not null and (tg_op = 'INSERT' or new.chosen_asset_id is distinct from old.chosen_asset_id) and not exists (
       select 1 from assets a join locations l on l.id = a.location_id join objects o on o.id = l.object_id
        where a.id = new.chosen_asset_id and o.company_id = new.company_id) then
    raise exception 'photo_identifications: оборудование другой компании' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.photo_ident_check() from public, anon, authenticated;

drop trigger if exists trg_photo_ident_check on public.photo_identifications;
create trigger trg_photo_ident_check
  before insert or update on public.photo_identifications
  for each row execute function public.photo_ident_check();

-- ---------------------------------------------------------------------
-- 3. RLS
-- ---------------------------------------------------------------------
alter table public.photo_identifications enable row level security;

drop policy if exists photo_ident_select on public.photo_identifications;
create policy photo_ident_select on public.photo_identifications for select using (
  company_id = public.my_company_id()
  and (user_id = auth.uid() or public.is_manager())
);

drop policy if exists photo_ident_insert on public.photo_identifications;
create policy photo_ident_insert on public.photo_identifications for insert with check (
  company_id = public.my_company_id() and user_id = auth.uid()
);

drop policy if exists photo_ident_update on public.photo_identifications;
create policy photo_ident_update on public.photo_identifications for update
  using (company_id = public.my_company_id() and user_id = auth.uid())
  with check (company_id = public.my_company_id() and user_id = auth.uid());

revoke all on public.photo_identifications from anon;
grant select, insert, update on public.photo_identifications to authenticated;

-- ---------------------------------------------------------------------
-- 4. Статистика для «Отчётов»
-- ---------------------------------------------------------------------
create or replace function public.photo_identify_stats(
  p_company uuid default null, p_from timestamptz default null, p_to timestamptz default null)
returns table (
  total         bigint,   -- всего узнаваний
  decided       bigint,   -- человек выбрал что-то (outcome задан)
  matched_top   bigint,   -- угадал с первого раза
  top_rate      numeric,  -- matched_top / decided, 0..1; null — решений нет
  avg_ms        numeric   -- среднее время узнавания, мс
)
language sql stable security invoker set search_path = public as $$
  select count(*),
         count(*) filter (where p.outcome is not null),
         count(*) filter (where p.outcome = 'matched_top'),
         round((count(*) filter (where p.outcome = 'matched_top'))::numeric
               / nullif(count(*) filter (where p.outcome is not null), 0), 3),
         round(avg(p.ms)::numeric, 0)
    from photo_identifications p
   where p.company_id = coalesce(p_company, public.my_company_id())
     and (p_from is null or p.created_at >= p_from)
     and (p_to is null or p.created_at < p_to);
$$;
revoke all on function public.photo_identify_stats(uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.photo_identify_stats(uuid, timestamptz, timestamptz) to authenticated;
