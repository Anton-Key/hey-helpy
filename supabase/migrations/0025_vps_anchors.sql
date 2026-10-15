-- =====================================================================
-- hey_helpy · Миграция 0025: VPS-метки, уведомления исполнителю, мелочи
-- безопасности (шаг 28)
--
-- 1) VPS-эксперимент (Niantic Spatial NSDK 4, VPS2):
--    vps_sites — «VPS-скан помещения»: anchor payload из портала Niantic
--      (вводит менеджер в приложении). Не секрет, но видят только менеджеры
--      (своей зоны) и исполнители подрядчиков этого объекта.
--    vps_marks — метки оборудования ОТНОСИТЕЛЬНО VPS-якоря помещения:
--      позиция (м) и поворот (кватернион). Читают те, кто видит оборудование
--      (can_see); ставят и удаляют — менеджер с правом на объект /
--      администратор (can_manage).
--    Старую таблицу ar_anchors (0002) не трогаем: она не используется и
--    заменяется этими двумя (docs/research/vps-niantic.md).
-- 2) Уведомление исполнителю в Telegram о новой заявке (блок 2 шага 28) —
--    см. раздел 2 ниже.
-- 3) Мелочи из docs/security/review-2026-10.md — см. раздел 3 ниже.
--
-- Требует 0024. Повторный запуск безопасен: if not exists, create or
-- replace, drop … if exists.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. VPS: сайты (скан помещения) и метки
-- ---------------------------------------------------------------------
create table if not exists public.vps_sites (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  object_id      uuid not null references public.objects(id) on delete cascade,
  location_id    uuid references public.locations(id) on delete cascade,
  floor_id       uuid references public.floors(id) on delete cascade,
  name           text not null default '',
  anchor_payload text not null,
  created_by     uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint vps_sites_place check (location_id is not null or floor_id is not null),
  constraint vps_sites_name_len check (char_length(name) <= 80),
  constraint vps_sites_payload_len check (char_length(btrim(anchor_payload)) between 8 and 20000)
);
-- Один скан на помещение (новый payload — правка этой строки).
create unique index if not exists uq_vps_sites_location on public.vps_sites (location_id)
  where location_id is not null;
create index if not exists idx_vps_sites_company on public.vps_sites (company_id);
create index if not exists idx_vps_sites_object on public.vps_sites (object_id);
alter table public.vps_sites enable row level security;

create table if not exists public.vps_marks (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  site_id     uuid not null references public.vps_sites(id) on delete cascade,
  asset_id    uuid not null references public.assets(id) on delete cascade,
  pos_x       double precision not null,
  pos_y       double precision not null,
  pos_z       double precision not null,
  rot_x       double precision not null default 0,
  rot_y       double precision not null default 0,
  rot_z       double precision not null default 0,
  rot_w       double precision not null default 1,
  created_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  -- метка — в пределах помещения от якоря (то же проверяет PoseMath.isValidRelative)
  constraint vps_marks_pos check (abs(pos_x) <= 50 and abs(pos_y) <= 50 and abs(pos_z) <= 50),
  constraint vps_marks_rot check (
    abs(sqrt(rot_x * rot_x + rot_y * rot_y + rot_z * rot_z + rot_w * rot_w) - 1) < 0.01)
);
-- Одна метка на оборудование в скане (переставить = удалить и поставить).
create unique index if not exists uq_vps_marks_site_asset on public.vps_marks (site_id, asset_id);
create index if not exists idx_vps_marks_asset on public.vps_marks (asset_id);
create index if not exists idx_vps_marks_company on public.vps_marks (company_id);
alter table public.vps_marks enable row level security;

-- Компания и объект скана — из помещения / этажа (не от приложения);
-- перенести скан в другое место нельзя.
create or replace function public.trg_vps_sites_fill()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_obj uuid;
  v_fl_obj uuid;
begin
  if new.location_id is not null then
    select l.object_id into v_obj from locations l where l.id = new.location_id;
    if v_obj is null then raise exception 'vps_site_bad_place'; end if;
  end if;
  if new.floor_id is not null then
    select f.object_id into v_fl_obj from floors f where f.id = new.floor_id;
    if v_fl_obj is null or (v_obj is not null and v_fl_obj <> v_obj) then
      raise exception 'vps_site_bad_place';
    end if;
    v_obj := coalesce(v_obj, v_fl_obj);
  end if;
  if tg_op = 'UPDATE' and (new.location_id is distinct from old.location_id
                           or new.floor_id is distinct from old.floor_id) then
    raise exception 'vps_site_place_fixed';
  end if;
  new.object_id := v_obj;
  select o.company_id into new.company_id from objects o where o.id = v_obj;
  new.anchor_payload := btrim(new.anchor_payload);
  new.name := btrim(coalesce(new.name, ''));
  if tg_op = 'UPDATE' then
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;
  return new;
end $$;
drop trigger if exists trg_vps_sites_fill on public.vps_sites;
create trigger trg_vps_sites_fill before insert or update on public.vps_sites
  for each row execute function public.trg_vps_sites_fill();

-- Метка: компания — из скана; оборудование — того же объекта, что и скан.
create or replace function public.trg_vps_marks_fill()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_site record;
  v_asset_obj uuid;
begin
  select s.company_id, s.object_id into v_site from vps_sites s where s.id = new.site_id;
  if v_site.object_id is null then raise exception 'vps_mark_bad_site'; end if;
  select l.object_id into v_asset_obj
    from assets a join locations l on l.id = a.location_id where a.id = new.asset_id;
  if v_asset_obj is null or v_asset_obj <> v_site.object_id then
    raise exception 'vps_mark_bad_asset';
  end if;
  new.company_id := v_site.company_id;
  if tg_op = 'UPDATE' then
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  return new;
end $$;
drop trigger if exists trg_vps_marks_fill on public.vps_marks;
create trigger trg_vps_marks_fill before insert or update on public.vps_marks
  for each row execute function public.trg_vps_marks_fill();

-- Кто видит скан помещения: менеджер (админ) своей зоны или исполнитель
-- подрядчика, закреплённого за объектом (или с заявкой на этом объекте).
create or replace function public.vps_site_visible(p_object uuid, p_location uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from objects o where o.id = p_object and o.company_id = public.my_company_id())
    and public.can_see(p_object, null, null, p_location)
    and (
      public.is_manager()
      or exists (
        select 1 from contractor_layers cl
         where cl.contractor_id in (select public.my_contractor_ids())
           and (cl.object_id = p_object or cl.object_id is null))
      or exists (
        select 1 from work_orders w
         where w.object_id = p_object
           and w.assigned_contractor_id in (select public.my_contractor_ids()))
    );
$$;
revoke all on function public.vps_site_visible(uuid, uuid) from public, anon;
grant execute on function public.vps_site_visible(uuid, uuid) to authenticated;

drop policy if exists vps_sites_select on public.vps_sites;
create policy vps_sites_select on public.vps_sites for select using (
  vps_sites.company_id = (select public.my_company_id())
  and public.vps_site_visible(vps_sites.object_id, vps_sites.location_id));
drop policy if exists vps_sites_insert on public.vps_sites;
create policy vps_sites_insert on public.vps_sites for insert with check (
  vps_sites.company_id = (select public.my_company_id())
  and public.can_manage(vps_sites.object_id, null, null, vps_sites.location_id));
drop policy if exists vps_sites_update on public.vps_sites;
create policy vps_sites_update on public.vps_sites for update using (
  vps_sites.company_id = (select public.my_company_id())
  and public.can_manage(vps_sites.object_id, null, null, vps_sites.location_id))
  with check (
  vps_sites.company_id = (select public.my_company_id())
  and public.can_manage(vps_sites.object_id, null, null, vps_sites.location_id));
drop policy if exists vps_sites_delete on public.vps_sites;
create policy vps_sites_delete on public.vps_sites for delete using (
  vps_sites.company_id = (select public.my_company_id())
  and public.can_manage(vps_sites.object_id, null, null, vps_sites.location_id));

-- Метку видит тот, кто видит оборудование (и сам скан — иначе нечего
-- показывать, но позы без payload бесполезны, поэтому проверяем только
-- оборудование, как в задании).
drop policy if exists vps_marks_select on public.vps_marks;
create policy vps_marks_select on public.vps_marks for select using (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_see(l.object_id, a.layer_id, a.id, a.location_id)));
drop policy if exists vps_marks_insert on public.vps_marks;
create policy vps_marks_insert on public.vps_marks for insert with check (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_manage(l.object_id, a.layer_id, a.id, a.location_id)));
drop policy if exists vps_marks_update on public.vps_marks;
create policy vps_marks_update on public.vps_marks for update using (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_manage(l.object_id, a.layer_id, a.id, a.location_id)))
  with check (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_manage(l.object_id, a.layer_id, a.id, a.location_id)));
drop policy if exists vps_marks_delete on public.vps_marks;
create policy vps_marks_delete on public.vps_marks for delete using (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_manage(l.object_id, a.layer_id, a.id, a.location_id)));

grant select, insert, update, delete on public.vps_sites to authenticated;
grant select, insert, update, delete on public.vps_marks to authenticated;

-- ---------------------------------------------------------------------
-- 2. Telegram: исполнителю — «Новая заявка» и «Взять в работу» (блок 2)
--
-- Как в 0022, без pg_net: после назначения подрядчика приложение вызывает
-- Edge Function telegram-notify ({orderId, kind: "assigned"}) со своим JWT;
-- бот после создания заявки — сам. Функции ниже — только service_role.
--
-- Кому: исполнители назначенного подрядчика с привязанным Telegram
-- (telegram_links). Если в заявке выбран конкретный исполнитель — только
-- ему. Исполнитель в бригаде — только если заявка в зоне его бригады:
-- проверяет та же wo_is_executor() шага 26 «от его имени» (telegram.act_as).
-- Тот, кто назначил, себе не получает. Отписка — тот же переключатель чата,
-- что и у уведомлений о статусе (telegram.optout: /stop и кнопка 🔕;
-- /start — снова присылать).
-- Повтор: (заявка, подрядчик, человек) — один раз; передали другому
-- подрядчику — новым исполнителям придёт.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('telegram.notified') is null then
    raise exception '0025: сначала примените миграцию 0022 (уведомления в Telegram)';
  end if;
end $$;

create table if not exists telegram.assign_notified (
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  contractor_id uuid not null,
  profile_id    uuid not null,
  sent_at       timestamptz not null default now(),
  primary key (work_order_id, contractor_id, profile_id)
);
revoke all on telegram.assign_notified from public, anon, authenticated, service_role;

-- Кому и что отправить: {number, title, object, place, priority, targets:
-- [{chat_id, lang, profile_id}]} или null (нет подрядчика, статус не «новая /
-- назначена», некому).
create or replace function public.tg_notify_assign_claim(p_order uuid, p_actor uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  w record;
  r record;
  prev text[];
  ok boolean;
  inserted int;
  targets jsonb := '[]'::jsonb;
begin
  select wo.id, wo.status, wo.title, wo.priority, wo.company_id, wo.assigned_contractor_id,
         wo.assigned_executor_id, o.name as object_name,
         nullif(btrim(concat_ws(' ', nullif(btrim(coalesce(l.code, '')), ''), l.name)), '') as place
    into w
    from work_orders wo
    left join objects o on o.id = wo.object_id
    left join locations l on l.id = wo.location_id
   where wo.id = p_order;
  if not found or w.assigned_contractor_id is null or w.status not in ('new', 'assigned') then
    return null;
  end if;

  for r in
    select distinct on (e.profile_id) e.profile_id, tl.chat_id, coalesce(tl.language, 'ru') as lang
      from executors e
      join telegram_links tl on tl.profile_id = e.profile_id
      join profiles p on p.id = e.profile_id and p.company_id = w.company_id
     where e.contractor_id = w.assigned_contractor_id
       and e.profile_id is not null
       and (w.assigned_executor_id is null or e.id = w.assigned_executor_id)
       and e.profile_id is distinct from p_actor
       and not exists (select 1 from telegram.optout x where x.chat_id = tl.chat_id)
     order by e.profile_id
  loop
    -- Бригада: заявка должна быть в зоне — проверка «от имени» исполнителя.
    prev := telegram.act_as(r.profile_id);
    begin
      ok := public.wo_is_executor(p_order);
      perform telegram.restore(prev);
    exception when others then
      perform telegram.restore(prev);
      ok := false;
    end;
    continue when not ok;

    insert into telegram.assign_notified(work_order_id, contractor_id, profile_id)
    values (p_order, w.assigned_contractor_id, r.profile_id)
    on conflict do nothing;
    get diagnostics inserted = row_count;
    continue when inserted = 0;
    targets := targets || jsonb_build_object('chat_id', r.chat_id, 'lang', r.lang, 'profile_id', r.profile_id);
  end loop;

  if jsonb_array_length(targets) = 0 then
    return null;
  end if;
  return jsonb_build_object(
    'number', upper(left(p_order::text, 6)), 'title', left(coalesce(w.title, ''), 200),
    'object', w.object_name, 'place', w.place, 'priority', w.priority,
    'contractor_id', w.assigned_contractor_id, 'targets', targets);
end $$;

-- Отправить не удалось — снять отметку (следующий вызов попробует снова).
create or replace function public.tg_notify_assign_release(p_order uuid, p_contractor uuid, p_profile uuid)
returns void language sql volatile security definer set search_path = public as $$
  delete from telegram.assign_notified
   where work_order_id = p_order and contractor_id = p_contractor and profile_id = p_profile;
$$;

-- «Взять в работу» из Telegram: человек — по chat_id из привязки, смена
-- статуса — обычным update «от его имени»: права проверяют те же триггеры
-- шага 26 (trg_wo_status_flow: только исполнитель назначенного подрядчика,
-- в бригаде — в её зоне). Ответ: {ok, number, title} или {error}.
create or replace function public.tg_take_order(p_chat bigint, p_order uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid;
  v_company uuid;
  w record;
  prev text[];
begin
  select l.profile_id, p.company_id into v_uid, v_company
    from telegram_links l join profiles p on p.id = l.profile_id
   where l.chat_id = p_chat;
  if v_uid is null then
    return jsonb_build_object('error', 'not_linked');
  end if;
  select wo.status, wo.title, wo.company_id into w from work_orders wo where wo.id = p_order;
  if not found or w.company_id is distinct from v_company then
    return jsonb_build_object('error', 'not_found');
  end if;
  if w.status = 'in_progress' then
    return jsonb_build_object('error', 'already', 'number', upper(left(p_order::text, 6)), 'title', w.title);
  end if;
  if w.status not in ('new', 'assigned', 'returned') then
    return jsonb_build_object('error', 'bad_status', 'status', w.status);
  end if;

  prev := telegram.act_as(v_uid);
  begin
    if not public.wo_is_executor(p_order) then
      perform telegram.restore(prev);
      return jsonb_build_object('error', 'not_executor');
    end if;
    update work_orders set status = 'in_progress' where id = p_order;
    perform telegram.restore(prev);
  exception when others then
    perform telegram.restore(prev);
    return jsonb_build_object('error', 'not_executor');
  end;
  return jsonb_build_object('ok', true, 'number', upper(left(p_order::text, 6)), 'title', w.title);
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.tg_notify_assign_claim(uuid, uuid)',
    'public.tg_notify_assign_release(uuid, uuid, uuid)',
    'public.tg_take_order(bigint, uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
