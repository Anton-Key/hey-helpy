-- 0020 — системы (слои `layers`) в приложении (шаг 24).
--
-- 1) layers: значок (`icon` — код из набора приложения), архив
--    (`archived_at`): архивная система не предлагается в новых заявках,
--    оборудовании и зонах, но старые данные с ней остаются и видны.
--    Цвет — только #RRGGBB.
-- 2) Права. Было (0004): видит вся компания, меняет любой менеджер
--    («for all» — заодно и чтение всего). Стало:
--    • создаёт, меняет, удаляет — только администратор своей компании;
--    • менеджер с зонами доступа (0016) видит только системы своих зон;
--      зона «все системы» — все. Менеджер без зон — все, как раньше;
--    • администратор, исполнитель и заявитель видят все системы компании
--      (названия нужны в заявках) — раздела «Системы» у последних двух нет.
-- 3) Удалить можно только систему, на которую ничего не ссылается: заявки,
--    оборудование, закрепления подрядчиков, планы ППР, зоны менеджеров и
--    бригад. Иначе — ошибка «system_in_use» (в приложении — «Архивировать»).
--    Проверка — только для действий пользователя (auth.uid() не null):
--    удаление компании целиком и обслуживание из SQL Editor не мешает.
--
-- Повторный запуск безопасен: add column if not exists, drop … if exists,
-- create or replace.

alter table public.layers
  add column if not exists icon        text,
  add column if not exists archived_at timestamptz;

alter table public.layers drop constraint if exists layers_icon_code;
alter table public.layers add constraint layers_icon_code
  check (icon is null or icon ~ '^[a-z][a-z0-9_]{0,23}$');

alter table public.layers drop constraint if exists layers_color_hex;
alter table public.layers add constraint layers_color_hex
  check (color ~ '^#[0-9A-Fa-f]{6}$');

alter table public.layers drop constraint if exists layers_name_len;
alter table public.layers add constraint layers_name_len
  check (char_length(btrim(name)) between 1 and 60);

-- ---------------------------------------------------------------------
-- 1. Видимость систем по зоне доступа менеджера
-- ---------------------------------------------------------------------
-- true — систему видно: не менеджер с зонами, или у него есть зона «все
-- системы», или зона с этой системой. Одна проверка на строку (систем мало).
create or replace function public.layer_in_my_zone(p_layer uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when coalesce((select p.role from profiles p where p.id = auth.uid()), '') <> 'manager' then true
    when not exists (select 1 from access_zones z where z.profile_id = auth.uid()) then true
    else exists (select 1 from access_zones z
                  where z.profile_id = auth.uid()
                    and (cardinality(z.layer_ids) = 0 or p_layer = any (z.layer_ids)))
  end;
$$;
revoke all on function public.layer_in_my_zone(uuid) from public, anon;
grant execute on function public.layer_in_my_zone(uuid) to authenticated;

drop policy if exists layers_select on public.layers;
drop policy if exists layers_manage on public.layers;
drop policy if exists layers_insert on public.layers;
drop policy if exists layers_update on public.layers;
drop policy if exists layers_delete on public.layers;

create policy layers_select on public.layers for select using (
  layers.company_id = (select public.my_company_id())
  and ((select public.zones_unrestricted()) or public.layer_in_my_zone(layers.id)));

create policy layers_insert on public.layers for insert with check (
  layers.company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy layers_update on public.layers for update
  using (layers.company_id = (select public.my_company_id()) and (select public.is_admin()))
  with check (layers.company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy layers_delete on public.layers for delete using (
  layers.company_id = (select public.my_company_id()) and (select public.is_admin()));

-- ---------------------------------------------------------------------
-- 2. Удалить можно только неиспользуемую систему
-- ---------------------------------------------------------------------
create or replace function public.trg_layers_delete_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return old; end if;
  if exists (select 1 from work_orders w where w.layer_id = old.id)
     or exists (select 1 from assets a where a.layer_id = old.id)
     or exists (select 1 from contractor_layers cl where cl.layer_id = old.id)
     or exists (select 1 from maintenance_plans mp where mp.layer_id = old.id)
     or exists (select 1 from access_zones z where old.id = any (z.layer_ids))
     or exists (select 1 from crew_zones cz where old.id = any (cz.layer_ids)) then
    raise exception 'system_in_use' using errcode = 'P0001',
      hint = 'Систему используют заявки, оборудование, подрядчики, ППР или зоны — её можно только архивировать.';
  end if;
  return old;
end $$;
revoke all on function public.trg_layers_delete_guard() from public, anon, authenticated;

drop trigger if exists trg_layers_delete_guard on public.layers;
create trigger trg_layers_delete_guard before delete on public.layers
  for each row execute function public.trg_layers_delete_guard();
