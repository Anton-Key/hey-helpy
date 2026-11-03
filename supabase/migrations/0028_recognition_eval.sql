-- 0028 — тест точности распознавания оборудования (шаг 34) и валюта ставок.
--
-- Зачем: честный, повторяемый замер «Узнать по фото» на собственном наборе
-- фото компании. Человек размечает фото ДО того, как его увидит ИИ; test-набор
-- после заморозки не меняется; результаты прогона пишет только Edge Function
-- recognition-eval (через закрытую функцию), а не приложение — подкрутить
-- цифру из приложения нельзя.
--
-- 1) recognition_eval_sets — наборы фото компании (frozen_at — заморожен).
-- 2) recognition_eval_samples — фото: объект, помещение, что на нём на самом
--    деле (единица реестра или «нет в реестре»), условия съёмки, набор
--    dev / test. dev / test ставит база (≈ 30 % / 70 % единиц оборудования;
--    все фото одной единицы — в одном наборе), не приложение. Вид и «сколько
--    похожих в помещении» — снимок на момент разметки.
-- 3) recognition_eval_runs — прогон: кто, когда, набор, поставщик и модель,
--    хеш подсказки, статус. Создаёт только recognition_eval_run_start.
-- 4) recognition_eval_results — ответ ИИ по каждому фото. Пишет только
--    recognition_eval_put_result (service_role — функция recognition-eval).
-- 5) Хранилище eval-photos — закрытое, путь <company_id>/<set_id>/<uuid>.jpg.
-- Всё видит и меняет только администратор своей компании.
-- 6) contractor_rates.currency — по умолчанию USD (шаг 33: валюта по умолчанию).
--
-- Права Data API — явные grant (правило Supabase с 30.10.2026, шаг 31), anon —
-- ничего. Повторный запуск безопасен: if not exists, create or replace,
-- drop … if exists, on conflict do nothing.

-- ---------------------------------------------------------------------
-- 6. Валюта ставок по умолчанию
-- ---------------------------------------------------------------------
alter table public.contractor_rates alter column currency set default 'USD';

-- ---------------------------------------------------------------------
-- 1. Наборы
-- ---------------------------------------------------------------------
create table if not exists public.recognition_eval_sets (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 80),
  created_by  uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  frozen_at   timestamptz,
  frozen_by   uuid references public.profiles(id) on delete set null
);
create index if not exists recognition_eval_sets_company_idx
  on public.recognition_eval_sets(company_id, created_at desc);

-- Заморозка — только функцией recognition_eval_freeze; замороженный набор не
-- меняется и не удаляется.
create or replace function public.trg_eval_sets_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.frozen_at is not null or new.frozen_by is not null then
      if coalesce(current_setting('hh.eval_freeze', true), '') <> 'on' then
        raise exception 'eval_freeze_only_by_function' using errcode = '42501';
      end if;
    end if;
    return new;
  end if;
  if tg_op = 'DELETE' then
    if old.frozen_at is not null then
      raise exception 'eval_frozen' using errcode = '42501';
    end if;
    return old;
  end if;
  if old.frozen_at is not null then
    raise exception 'eval_frozen' using errcode = '42501';
  end if;
  if new.company_id is distinct from old.company_id
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'eval_immutable' using errcode = '42501';
  end if;
  if (new.frozen_at is distinct from old.frozen_at or new.frozen_by is distinct from old.frozen_by)
     and coalesce(current_setting('hh.eval_freeze', true), '') <> 'on' then
    raise exception 'eval_freeze_only_by_function' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.trg_eval_sets_guard() from public, anon;

drop trigger if exists trg_eval_sets_guard on public.recognition_eval_sets;
create trigger trg_eval_sets_guard
  before insert or update or delete on public.recognition_eval_sets
  for each row execute function public.trg_eval_sets_guard();

-- ---------------------------------------------------------------------
-- 2. Фото набора
-- ---------------------------------------------------------------------
create table if not exists public.recognition_eval_samples (
  id                   uuid primary key default gen_random_uuid(),
  set_id               uuid not null references public.recognition_eval_sets(id) on delete cascade,
  company_id           uuid not null references public.companies(id) on delete cascade,
  created_by           uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at           timestamptz not null default now(),
  photo_path           text not null unique,
  -- Без внешних ключей на объект, помещение и оборудование: набор — снимок;
  -- удаление оборудования или помещения из реестра его не трогает и не
  -- блокируется им. Ссылки проверяет триггер при вставке (та же компания).
  site_id              uuid not null,
  room_id              uuid not null,
  -- Что на фото на самом деле — ставит человек до прогона.
  true_equipment_id    uuid,
  true_is_unregistered boolean not null default false,
  -- Снимок на момент разметки (реестр потом может меняться).
  true_kind            text check (true_kind is null or true_kind ~ '^[a-z0-9_]{1,40}$'),
  similar_in_room      int not null default 0 check (similar_in_room >= 0),
  -- Серия снимков одного предмета (для «нет в реестре» — ключ dev / test).
  series_id            uuid,
  light                text not null check (light in ('good', 'dim', 'backlight')),
  distance             text not null check (distance in ('close', 'medium', 'far')),
  angle                text not null check (angle in ('front', 'side')),
  occlusion            boolean not null default false,
  split                text not null default 'dev' check (split in ('dev', 'test')),
  constraint recognition_eval_samples_truth_check
    check ((true_equipment_id is null) = true_is_unregistered)
);
create index if not exists recognition_eval_samples_set_idx
  on public.recognition_eval_samples(set_id, split);
create index if not exists recognition_eval_samples_asset_idx
  on public.recognition_eval_samples(true_equipment_id);

create or replace function public.trg_eval_samples_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_set record;
  v_obj uuid;
  v_company uuid;
  v_asset_room uuid;
  v_kind text;
  v_key uuid;
  v_split text;
  v_dev int;
  v_total int;
begin
  if tg_op = 'DELETE' then
    if exists (select 1 from recognition_eval_sets s where s.id = old.set_id and s.frozen_at is not null) then
      raise exception 'eval_frozen' using errcode = '42501';
    end if;
    return old;
  end if;

  select * into v_set from recognition_eval_sets where id = new.set_id;
  if not found then
    raise exception 'eval_bad_set' using errcode = '23503';
  end if;
  if v_set.frozen_at is not null then
    raise exception 'eval_frozen' using errcode = '42501';
  end if;

  if tg_op = 'UPDATE' then
    -- После вставки меняются только условия съёмки (ошибся — удалить и снять заново).
    if new.set_id is distinct from old.set_id or new.company_id is distinct from old.company_id
       or new.photo_path is distinct from old.photo_path or new.site_id is distinct from old.site_id
       or new.room_id is distinct from old.room_id
       or new.true_equipment_id is distinct from old.true_equipment_id
       or new.true_is_unregistered is distinct from old.true_is_unregistered
       or new.true_kind is distinct from old.true_kind
       or new.similar_in_room is distinct from old.similar_in_room
       or new.series_id is distinct from old.series_id or new.split is distinct from old.split
       or new.created_by is distinct from old.created_by or new.created_at is distinct from old.created_at then
      raise exception 'eval_immutable' using errcode = '42501';
    end if;
    return new;
  end if;

  -- INSERT: компания — из набора; место и оборудование — той же компании.
  new.company_id := v_set.company_id;
  select l.object_id, o.company_id into v_obj, v_company
    from locations l join objects o on o.id = l.object_id where l.id = new.room_id;
  if v_obj is null or v_company <> v_set.company_id or v_obj <> new.site_id then
    raise exception 'eval_bad_place' using errcode = '23514';
  end if;
  if new.photo_path !~ ('^' || v_set.company_id::text || '/' || v_set.id::text || '/[0-9a-f-]{36}\.jpg$') then
    raise exception 'eval_bad_path' using errcode = '23514';
  end if;

  if new.true_equipment_id is not null then
    select a.location_id, nullif(a.meta->>'kind', '') into v_asset_room, v_kind
      from assets a where a.id = new.true_equipment_id;
    -- Единица — из реестра этого помещения.
    if v_asset_room is null or v_asset_room <> new.room_id then
      raise exception 'eval_bad_asset' using errcode = '23514';
    end if;
    new.true_kind := case when v_kind ~ '^[a-z0-9_]{1,40}$' then v_kind end;
    new.true_is_unregistered := false;
  end if;
  -- Сколько единиц того же вида в помещении (включая эту): «похожие рядом».
  new.similar_in_room := case when new.true_kind is null then 0 else
    (select count(*) from assets a where a.location_id = new.room_id and a.meta->>'kind' = new.true_kind) end;

  -- dev / test — по единицам: все фото одной единицы (серии «нет в реестре») —
  -- в одном наборе; новая единица — в dev, пока в dev меньше 30 % единиц этого
  -- типа (зарегистрированные и «нет в реестре» — отдельно).
  perform pg_advisory_xact_lock(hashtext('eval_split:' || new.set_id::text));
  v_key := coalesce(new.true_equipment_id, new.series_id, new.id);
  select s.split into v_split from recognition_eval_samples s
   where s.set_id = new.set_id
     and coalesce(s.true_equipment_id, s.series_id, s.id) = v_key
   limit 1;
  if v_split is null then
    select count(distinct coalesce(s.true_equipment_id, s.series_id, s.id)) filter (where s.split = 'dev'),
           count(distinct coalesce(s.true_equipment_id, s.series_id, s.id))
      into v_dev, v_total
      from recognition_eval_samples s
     where s.set_id = new.set_id and s.true_is_unregistered = new.true_is_unregistered;
    v_split := case when v_dev < 0.3 * (v_total + 1) then 'dev' else 'test' end;
  end if;
  new.split := v_split;
  new.created_at := now();
  return new;
end $$;
revoke all on function public.trg_eval_samples_guard() from public, anon;

drop trigger if exists trg_eval_samples_guard on public.recognition_eval_samples;
create trigger trg_eval_samples_guard
  before insert or update or delete on public.recognition_eval_samples
  for each row execute function public.trg_eval_samples_guard();

-- ---------------------------------------------------------------------
-- 3. Прогоны
-- ---------------------------------------------------------------------
create table if not exists public.recognition_eval_runs (
  id                 uuid primary key default gen_random_uuid(),
  company_id         uuid not null references public.companies(id) on delete cascade,
  set_id             uuid not null references public.recognition_eval_sets(id) on delete cascade,
  split              text not null check (split in ('dev', 'test')),
  created_by         uuid references public.profiles(id) on delete set null,
  created_at         timestamptz not null default now(),
  -- Что просили (default — как у пользователей) и что ответило на самом деле.
  provider_requested text not null default 'default' check (provider_requested in ('default', 'yandex', 'openai')),
  provider           text check (provider is null or provider in ('yandex', 'openai')),
  model_vision       text check (model_vision is null or char_length(model_vision) <= 120),
  prompt_hash        text check (prompt_hash is null or prompt_hash ~ '^[0-9a-f]{64}$'),
  status             text not null default 'running' check (status in ('running', 'done', 'cancelled')),
  sample_count       int not null check (sample_count > 0),
  set_frozen_at      timestamptz,
  finished_at        timestamptz
);
create index if not exists recognition_eval_runs_set_idx
  on public.recognition_eval_runs(set_id, created_at desc);

-- ---------------------------------------------------------------------
-- 4. Результаты
-- ---------------------------------------------------------------------
create table if not exists public.recognition_eval_results (
  id                     uuid primary key default gen_random_uuid(),
  run_id                 uuid not null references public.recognition_eval_runs(id) on delete cascade,
  sample_id              uuid not null references public.recognition_eval_samples(id) on delete cascade,
  company_id             uuid not null references public.companies(id) on delete cascade,
  created_at             timestamptz not null default now(),
  -- Без внешнего ключа: оборудование могут удалить из реестра, результат остаётся.
  predicted_equipment_id uuid,
  candidates             jsonb not null default '[]' check (jsonb_typeof(candidates) = 'array' and jsonb_array_length(candidates) <= 3),
  confidence             numeric check (confidence is null or confidence between 0 and 1),
  model_confidence       numeric check (model_confidence is null or model_confidence between 0 and 1),
  predicted_kind         text check (predicted_kind is null or char_length(predicted_kind) <= 40),
  no_equipment           boolean not null default false,
  abstained              boolean not null default false,
  ms                     int check (ms is null or ms >= 0),
  tokens                 int check (tokens is null or tokens >= 0),
  cost_usd               numeric check (cost_usd is null or cost_usd >= 0),
  model_tag              text check (model_tag is null or model_tag in ('main', 'lite')),
  error                  text check (error is null or error ~ '^[a-z_]{1,40}$'),
  unique (run_id, sample_id)
);
create index if not exists recognition_eval_results_run_idx on public.recognition_eval_results(run_id);

-- ---------------------------------------------------------------------
-- RLS: только администратор своей компании; прогоны и результаты — только
-- чтение (пишут функции ниже).
-- ---------------------------------------------------------------------
alter table public.recognition_eval_sets    enable row level security;
alter table public.recognition_eval_samples enable row level security;
alter table public.recognition_eval_runs    enable row level security;
alter table public.recognition_eval_results enable row level security;

drop policy if exists eval_sets_select on public.recognition_eval_sets;
drop policy if exists eval_sets_insert on public.recognition_eval_sets;
drop policy if exists eval_sets_update on public.recognition_eval_sets;
drop policy if exists eval_sets_delete on public.recognition_eval_sets;
create policy eval_sets_select on public.recognition_eval_sets for select to authenticated
  using (company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy eval_sets_insert on public.recognition_eval_sets for insert to authenticated
  with check (company_id = (select public.my_company_id()) and (select public.is_admin())
              and created_by = (select auth.uid()));
create policy eval_sets_update on public.recognition_eval_sets for update to authenticated
  using (company_id = (select public.my_company_id()) and (select public.is_admin()))
  with check (company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy eval_sets_delete on public.recognition_eval_sets for delete to authenticated
  using (company_id = (select public.my_company_id()) and (select public.is_admin()));

drop policy if exists eval_samples_select on public.recognition_eval_samples;
drop policy if exists eval_samples_insert on public.recognition_eval_samples;
drop policy if exists eval_samples_update on public.recognition_eval_samples;
drop policy if exists eval_samples_delete on public.recognition_eval_samples;
create policy eval_samples_select on public.recognition_eval_samples for select to authenticated
  using (company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy eval_samples_insert on public.recognition_eval_samples for insert to authenticated
  with check (company_id = (select public.my_company_id()) and (select public.is_admin())
              and created_by = (select auth.uid()));
create policy eval_samples_update on public.recognition_eval_samples for update to authenticated
  using (company_id = (select public.my_company_id()) and (select public.is_admin()))
  with check (company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy eval_samples_delete on public.recognition_eval_samples for delete to authenticated
  using (company_id = (select public.my_company_id()) and (select public.is_admin()));

drop policy if exists eval_runs_select on public.recognition_eval_runs;
create policy eval_runs_select on public.recognition_eval_runs for select to authenticated
  using (company_id = (select public.my_company_id()) and (select public.is_admin()));

drop policy if exists eval_results_select on public.recognition_eval_results;
create policy eval_results_select on public.recognition_eval_results for select to authenticated
  using (company_id = (select public.my_company_id()) and (select public.is_admin()));

grant select, insert, update, delete on table public.recognition_eval_sets    to authenticated;
grant select, insert, update, delete on table public.recognition_eval_samples to authenticated;
grant select on table public.recognition_eval_runs    to authenticated;
grant select on table public.recognition_eval_results to authenticated;
grant select, insert, update, delete on table public.recognition_eval_sets    to service_role;
grant select, insert, update, delete on table public.recognition_eval_samples to service_role;
grant select, insert, update, delete on table public.recognition_eval_runs    to service_role;
grant select, insert, update, delete on table public.recognition_eval_results to service_role;

-- ---------------------------------------------------------------------
-- Функции
-- ---------------------------------------------------------------------

-- Заморозить набор (администратор своей компании; нужно хотя бы одно фото test).
create or replace function public.recognition_eval_freeze(p_set uuid)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare v_set record; v_at timestamptz := now();
begin
  select * into v_set from recognition_eval_sets where id = p_set for update;
  if not found or v_set.company_id is distinct from my_company_id() or not is_admin() then
    raise exception 'eval_forbidden' using errcode = '42501';
  end if;
  if v_set.frozen_at is not null then
    return v_set.frozen_at;
  end if;
  if not exists (select 1 from recognition_eval_samples where set_id = p_set and split = 'test') then
    raise exception 'eval_empty_test' using errcode = '22023';
  end if;
  perform set_config('hh.eval_freeze', 'on', true);
  update recognition_eval_sets set frozen_at = v_at, frozen_by = auth.uid() where id = p_set;
  perform set_config('hh.eval_freeze', '', true);
  return v_at;
end $$;
revoke all on function public.recognition_eval_freeze(uuid) from public, anon;
grant execute on function public.recognition_eval_freeze(uuid) to authenticated;

-- Начать прогон: администратор; test — только замороженный набор.
create or replace function public.recognition_eval_run_start(p_set uuid, p_split text, p_provider text default 'default')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_set record; v_n int; v_id uuid;
begin
  select * into v_set from recognition_eval_sets where id = p_set;
  if not found or v_set.company_id is distinct from my_company_id() or not is_admin() then
    raise exception 'eval_forbidden' using errcode = '42501';
  end if;
  if p_split not in ('dev', 'test') or coalesce(p_provider, '') not in ('default', 'yandex', 'openai') then
    raise exception 'eval_bad_request' using errcode = '22023';
  end if;
  if p_split = 'test' and v_set.frozen_at is null then
    raise exception 'eval_not_frozen' using errcode = '22023';
  end if;
  select count(*) into v_n from recognition_eval_samples where set_id = p_set and split = p_split;
  if v_n = 0 then
    raise exception 'eval_empty' using errcode = '22023';
  end if;
  insert into recognition_eval_runs(company_id, set_id, split, created_by, provider_requested, sample_count, set_frozen_at)
  values (v_set.company_id, p_set, p_split, auth.uid(), p_provider, v_n, v_set.frozen_at)
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.recognition_eval_run_start(uuid, text, text) from public, anon;
grant execute on function public.recognition_eval_run_start(uuid, text, text) to authenticated;

-- Закончить прогон: done — только когда есть ответ на каждое фото; иначе cancelled.
create or replace function public.recognition_eval_run_finish(p_run uuid, p_cancel boolean default false)
returns text language plpgsql security definer set search_path = public as $$
declare v_run record; v_done int;
begin
  select * into v_run from recognition_eval_runs where id = p_run for update;
  if not found or v_run.company_id is distinct from my_company_id() or not is_admin() then
    raise exception 'eval_forbidden' using errcode = '42501';
  end if;
  if v_run.status <> 'running' then
    return v_run.status;
  end if;
  select count(*) into v_done from recognition_eval_results where run_id = p_run;
  if not p_cancel and v_done < v_run.sample_count then
    raise exception 'eval_incomplete' using errcode = '22023';
  end if;
  update recognition_eval_runs
     set status = case when p_cancel then 'cancelled' else 'done' end, finished_at = now()
   where id = p_run;
  return case when p_cancel then 'cancelled' else 'done' end;
end $$;
revoke all on function public.recognition_eval_run_finish(uuid, boolean) from public, anon;
grant execute on function public.recognition_eval_run_finish(uuid, boolean) to authenticated;

-- Записать ответ ИИ по одному фото. Только service_role (Edge Function
-- recognition-eval); от чьего имени — p_user (функция проверила JWT). Хороший
-- ответ не перезаписывается; ответ с ошибкой можно повторить. Один прогон —
-- один поставщик, модель и подсказка: сменились секреты — нужен новый прогон.
create or replace function public.recognition_eval_put_result(
  p_user uuid, p_run uuid, p_sample uuid, p_provider text, p_model text, p_prompt_hash text, p_result jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_run record; v_prev record; v_cands jsonb;
begin
  select * into v_run from recognition_eval_runs where id = p_run for update;
  if not found or not exists (
       select 1 from profiles p where p.id = p_user and p.company_id = v_run.company_id and p.role = 'admin') then
    raise exception 'eval_forbidden' using errcode = '42501';
  end if;
  if v_run.status <> 'running' then
    raise exception 'eval_run_closed' using errcode = '22023';
  end if;
  if not exists (select 1 from recognition_eval_samples s
                  where s.id = p_sample and s.set_id = v_run.set_id and s.split = v_run.split) then
    raise exception 'eval_bad_sample' using errcode = '22023';
  end if;
  if v_run.provider is null then
    update recognition_eval_runs set provider = p_provider, model_vision = p_model, prompt_hash = p_prompt_hash
     where id = p_run;
  elsif v_run.provider is distinct from p_provider or v_run.model_vision is distinct from p_model
        or v_run.prompt_hash is distinct from p_prompt_hash then
    raise exception 'eval_config_changed' using errcode = '22023';
  end if;
  select * into v_prev from recognition_eval_results where run_id = p_run and sample_id = p_sample;
  if found and v_prev.error is null then
    raise exception 'eval_result_exists' using errcode = '23505';
  end if;
  v_cands := coalesce(p_result->'candidates', '[]');
  if jsonb_typeof(v_cands) <> 'array' then v_cands := '[]'; end if;
  delete from recognition_eval_results where run_id = p_run and sample_id = p_sample;
  insert into recognition_eval_results(run_id, sample_id, company_id, predicted_equipment_id, candidates,
    confidence, model_confidence, predicted_kind, no_equipment, abstained, ms, tokens, cost_usd, model_tag, error)
  values (p_run, p_sample, v_run.company_id,
    nullif(p_result->>'predicted_equipment_id', '')::uuid,
    v_cands,
    (p_result->>'confidence')::numeric,
    (p_result->>'model_confidence')::numeric,
    nullif(p_result->>'predicted_kind', ''),
    coalesce((p_result->>'no_equipment')::boolean, false),
    coalesce((p_result->>'abstained')::boolean, false),
    (p_result->>'ms')::int,
    (p_result->>'tokens')::int,
    (p_result->>'cost_usd')::numeric,
    nullif(p_result->>'model_tag', ''),
    nullif(p_result->>'error', ''));
end $$;
revoke all on function public.recognition_eval_put_result(uuid, uuid, uuid, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.recognition_eval_put_result(uuid, uuid, uuid, text, text, text, jsonb) to service_role;

-- ---------------------------------------------------------------------
-- 5. Хранилище eval-photos (закрытое): <company_id>/<set_id>/<uuid>.jpg.
-- Урок 0014: в подзапросах только objects.name.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('eval-photos', 'eval-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

drop policy if exists eval_photos_select on storage.objects;
drop policy if exists eval_photos_insert on storage.objects;
drop policy if exists eval_photos_delete on storage.objects;

create policy eval_photos_select on storage.objects for select to authenticated using (
  bucket_id = 'eval-photos'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and (select public.is_admin()));

create policy eval_photos_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'eval-photos'
  and objects.name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and (select public.is_admin())
  and exists (select 1 from public.recognition_eval_sets s
               where s.id::text = (storage.foldername(objects.name))[2]
                 and s.company_id::text = (storage.foldername(objects.name))[1]
                 and s.frozen_at is null));

create policy eval_photos_delete on storage.objects for delete to authenticated using (
  bucket_id = 'eval-photos'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and (select public.is_admin())
  and exists (select 1 from public.recognition_eval_sets s
               where s.id::text = (storage.foldername(objects.name))[2]
                 and s.company_id::text = (storage.foldername(objects.name))[1]
                 and s.frozen_at is null));
