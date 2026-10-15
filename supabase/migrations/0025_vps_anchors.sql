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
