-- 0009_visit_geofence.sql
-- Назначение: отметка визита по геозоне. У объекта — радиус геозоны; визит
-- привязан к заявке, хранит точность GPS, расстояние до объекта и флаг
-- «в геозоне». Время, геозону и компанию считает база, а не приложение.
-- Визит закрывается сам, когда заявка выходит из статуса «в работе».
-- Зависит от: 0004 (visits, my_contractor_ids, is_manager), 0008 (функции закрыты по умолчанию).
-- Применяется вручную: Supabase → SQL Editor. Безопасно запускать повторно.

begin;

-- ---------------------------------------------------------------------
-- 1. Геозона объекта: центр — objects.lat / objects.lng (уже есть), радиус — новый
-- ---------------------------------------------------------------------
alter table public.objects
  add column if not exists geofence_radius_m integer not null default 150;
alter table public.objects drop constraint if exists objects_geofence_radius_check;
alter table public.objects add constraint objects_geofence_radius_check
  check (geofence_radius_m between 20 and 5000);

-- ---------------------------------------------------------------------
-- 2. Визит: заявка, точность, расстояние, флаг геозоны
--    in_geofence: true — в геозоне, false — вне её, null — не проверить
--    (нет координат у объекта или телефон не дал местоположение).
-- ---------------------------------------------------------------------
alter table public.visits
  add column if not exists work_order_id uuid references public.work_orders(id) on delete cascade,
  add column if not exists accuracy_m    double precision,
  add column if not exists distance_m    double precision,
  add column if not exists in_geofence   boolean;

create index if not exists idx_visits_work_order on public.visits (work_order_id, started_at);
-- Один открытый визит человека по заявке.
create unique index if not exists uq_visits_open
  on public.visits (work_order_id, profile_id) where ended_at is null;

-- ---------------------------------------------------------------------
-- 3. Заполнение и защита визита
--    Вставка: компания, объект, подрядчик — из заявки; начало — время базы;
--    расстояние и флаг геозоны — по координатам объекта.
--    Изменение: можно только поставить время окончания (тоже время базы).
-- ---------------------------------------------------------------------
create or replace function public.trg_visits_fill()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_wo   record;
  v_obj  record;
  v_tol  double precision;
begin
  if tg_op = 'UPDATE' then
    new.id            := old.id;
    new.company_id    := old.company_id;
    new.object_id     := old.object_id;
    new.profile_id    := old.profile_id;
    new.contractor_id := old.contractor_id;
    new.work_order_id := old.work_order_id;
    new.started_at    := old.started_at;
    new.source        := old.source;
    new.lat           := old.lat;
    new.lng           := old.lng;
    new.accuracy_m    := old.accuracy_m;
    new.distance_m    := old.distance_m;
    new.in_geofence   := old.in_geofence;
    new.mock_location := old.mock_location;
    new.created_at    := old.created_at;
    if old.ended_at is not null then
      new.ended_at := old.ended_at;
    elsif new.ended_at is not null then
      new.ended_at := now();
    end if;
    return new;
  end if;

  if new.work_order_id is null then
    raise exception 'visit: work order required';
  end if;
  select w.company_id, w.object_id, w.assigned_contractor_id into v_wo
    from work_orders w where w.id = new.work_order_id;
  if not found then
    raise exception 'visit: work order not found';
  end if;
  if v_wo.object_id is null then
    raise exception 'visit: work order has no object';
  end if;

  new.company_id    := v_wo.company_id;
  new.object_id     := v_wo.object_id;
  new.contractor_id := v_wo.assigned_contractor_id;
  new.started_at    := now();
  new.ended_at      := null;
  new.source        := 'geofence';
  new.created_at    := now();
  new.mock_location := coalesce(new.mock_location, false);

  -- Неправдоподобные координаты и точность не сохраняем.
  if new.lat is null or new.lng is null
     or new.lat not between -90 and 90 or new.lng not between -180 and 180 then
    new.lat := null; new.lng := null;
  end if;
  if new.accuracy_m is not null and (new.accuracy_m < 0 or new.accuracy_m > 100000) then
    new.accuracy_m := null;
  end if;

  select o.lat, o.lng, o.geofence_radius_m into v_obj from objects o where o.id = new.object_id;
  if new.lat is null or v_obj.lat is null or v_obj.lng is null then
    new.distance_m  := null;
    new.in_geofence := null;
  else
    -- Расстояние по формуле гаверсинусов, метры.
    new.distance_m := 2 * 6371000 * asin(sqrt(
        power(sin(radians(new.lat - v_obj.lat) / 2), 2)
      + cos(radians(v_obj.lat)) * cos(radians(new.lat))
      * power(sin(radians(new.lng - v_obj.lng) / 2), 2)));
    -- Погрешность GPS прощаем, но не больше 50 м.
    v_tol := least(coalesce(new.accuracy_m, 0), 50);
    new.in_geofence := new.distance_m <= v_obj.geofence_radius_m + v_tol;
  end if;
  return new;
end $$;

drop trigger if exists trg_visits_fill on public.visits;
create trigger trg_visits_fill before insert or update on public.visits
  for each row execute function public.trg_visits_fill();

-- ---------------------------------------------------------------------
-- 4. Визит закрывается, когда заявка выходит из «в работе»
--    (на проверку, отмена и т. д.) — с любого телефона и даже без приложения.
-- ---------------------------------------------------------------------
create or replace function public.trg_wo_close_visits()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update visits set ended_at = now()
   where work_order_id = new.id and ended_at is null;
  return null;
end $$;

drop trigger if exists trg_wo_close_visits on public.work_orders;
create trigger trg_wo_close_visits after update of status on public.work_orders
  for each row
  when (old.status = 'in_progress' and new.status is distinct from 'in_progress')
  execute function public.trg_wo_close_visits();

-- ---------------------------------------------------------------------
-- 5. Права (RLS)
--    Читать: менеджер — все визиты компании, остальные — только свои (как в 0004).
--    Записать: только свой визит, только по заявке в работе, назначенной
--    своему подрядчику (или менеджер). Удалять — никто.
-- ---------------------------------------------------------------------
drop policy if exists visits_select on public.visits;
create policy visits_select on public.visits for select using (
  company_id = (select public.my_company_id())
  and ((select public.is_manager()) or profile_id = (select auth.uid())));

drop policy if exists visits_insert on public.visits;
create policy visits_insert on public.visits for insert with check (
  company_id = (select public.my_company_id())
  and profile_id = (select auth.uid())
  and exists (
    select 1 from public.work_orders w
     where w.id = visits.work_order_id
       and w.company_id = (select public.my_company_id())
       and w.status = 'in_progress'
       and ((select public.is_manager())
            or w.assigned_contractor_id in (select public.my_contractor_ids()))));

drop policy if exists visits_update on public.visits;
create policy visits_update on public.visits for update
  using (profile_id = (select auth.uid()) and company_id = (select public.my_company_id()))
  with check (profile_id = (select auth.uid()) and company_id = (select public.my_company_id()));

drop policy if exists visits_delete on public.visits;

revoke all on public.visits from anon;

-- Триггерные функции вызывает только база.
revoke all on function public.trg_visits_fill()     from public, anon, authenticated;
revoke all on function public.trg_wo_close_visits() from public, anon, authenticated;

commit;
