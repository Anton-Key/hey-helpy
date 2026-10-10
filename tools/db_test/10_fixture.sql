-- Тестовые данные: две компании с ОДИНАКОВЫМИ названиями компании,
-- регионов, городов, объектов, помещений, подрядчиков.
-- id всех строк компании k начинаются с «c<k>» — так тест изоляции
-- отличает строки компании 2 в любой таблице (по любому uuid-столбцу).
-- Пользователи компании k: 100 менеджер, 101 администратор,
-- 102 исполнитель подрядчика 031, 103 заявитель.

create schema if not exists t;
grant usage on schema t to authenticated, anon;

create or replace function t.id(k int, n int) returns uuid
language sql immutable as $$
  select format('c%s000000-0000-4000-8000-%s', k, lpad(n::text, 12, '0'))::uuid;
$$;
grant execute on function t.id(int, int) to authenticated, anon;

-- Итоги проверок (пишет t.check под любой ролью).
create table if not exists t.results (
  n     serial primary key,
  ok    boolean not null,
  suite text,
  msg   text not null
);
create or replace function t.check(p_ok boolean, p_msg text, p_suite text default null)
returns void language plpgsql security definer set search_path = t, public as $$
begin
  insert into t.results(ok, suite, msg)
  values (coalesce(p_ok, false), coalesce(p_suite, current_setting('t.suite', true)), p_msg);
end $$;
grant execute on function t.check(boolean, text, text) to authenticated, anon;

-- Войти пользователем (роль authenticated + auth.uid()); null — выйти.
create or replace function t.login(p_uid uuid) returns void
language plpgsql as $$
begin
  if p_uid is null then
    perform set_config('request.jwt.claim.sub', '', false);
    execute 'reset role';
  else
    perform set_config('request.jwt.claim.sub', p_uid::text, false);
    execute 'set role authenticated';
  end if;
end $$;
grant execute on function t.login(uuid) to authenticated, anon;

create or replace function t.make_company(k int) returns void
language plpgsql as $$
declare
  c uuid := t.id(k, 1);
  climate uuid;
  elec uuid;
  u record;
begin
  insert into public.companies(id, name) values (c, 'Демо БЦ');  -- слои создаёт триггер
  select id into climate from public.layers where company_id = c and name = 'Климат';
  select id into elec    from public.layers where company_id = c and name = 'Электрика';

  for u in select * from (values (100, 'manager'), (101, 'admin'), (102, 'executor'), (103, 'requester'))
           as v(n, role) loop
    insert into auth.users(id, email, raw_user_meta_data)
    values (t.id(k, u.n), format('u%s_%s@example.com', k, u.n),
            jsonb_build_object('full_name', format('Пользователь %s-%s', k, u.n)));
    update public.profiles set company_id = c, role = u.role where id = t.id(k, u.n);
  end loop;

  insert into public.regions(id, company_id, name, sort) values
    (t.id(k, 901), c, 'Европа', 1), (t.id(k, 902), c, 'Азия', 2);

  insert into public.objects(id, company_id, name, address, lat, lng, country_code, city, region_id) values
    (t.id(k, 10), c, 'Офис 1', 'Москва, ул. Лесная, 1', 55.75, 37.61, 'RU', 'Москва', t.id(k, 901)),
    (t.id(k, 11), c, 'Офис 1', 'Пекин, ул. 1', 39.90, 116.40, 'CN', 'Пекин', t.id(k, 902)),
    (t.id(k, 12), c, 'Офис 2', 'Шэньчжэнь, ул. 2', 22.54, 114.05, 'CN', 'Шэньчжэнь', t.id(k, 902));

  insert into public.departments(id, object_id, name) values (t.id(k, 15), t.id(k, 10), 'АХО');
  insert into public.floors(id, company_id, object_id, name, level, plan_path, plan_w, plan_h)
  values (t.id(k, 601), c, t.id(k, 10), '1 этаж', 1, format('%s/%s/%s/plan.png', c, t.id(k, 10), t.id(k, 601)), 1000, 800);

  insert into public.locations(id, object_id, name, code, floor_id, plan_x, plan_y, plan_shape) values
    (t.id(k, 21), t.id(k, 10), 'Переговорная', '305', t.id(k, 601), 0.5, 0.5,
       '{"type":"polygon","points":[[0.4,0.4],[0.6,0.4],[0.6,0.6],[0.4,0.6]]}'),
    (t.id(k, 22), t.id(k, 11), 'Серверная', '101', null, null, null, null),
    (t.id(k, 23), t.id(k, 12), 'Холл', null, null, null, null, null);
  insert into public.locations(id, object_id, parent_id, name) values
    (t.id(k, 24), t.id(k, 10), t.id(k, 21), 'Ниша');

  insert into public.assets(id, location_id, name, inventory_no, layer_id, manufacturer, model, serial_no, installed_at, floor_id, plan_x, plan_y) values
    (t.id(k, 701), t.id(k, 21), 'Кондиционер', 'INV-1', climate, 'Daikin', 'FTXM35', 'SN-1', '2024-05-01', t.id(k, 601), 0.45, 0.45),
    (t.id(k, 702), t.id(k, 22), 'ИБП', 'INV-2', elec, 'APC', 'SRT3000', 'SN-2', '2023-01-10', null, null, null),
    (t.id(k, 703), t.id(k, 23), 'Щит', 'INV-3', elec, 'ABB', 'X', 'SN-3', null, null, null, null);

  insert into public.contractors(id, company_id, org_name) values
    (t.id(k, 31), c, 'КлиматСервис'), (t.id(k, 32), c, 'ЭлектроПро');
  insert into public.contractor_layers(id, contractor_id, layer_id, object_id, visits_per_month) values
    (t.id(k, 41), t.id(k, 31), climate, t.id(k, 10), 2),
    (t.id(k, 42), t.id(k, 32), elec, null, null);
  insert into public.contractor_objects(contractor_id, object_id) values (t.id(k, 31), t.id(k, 10));
  insert into public.executors(id, profile_id, contractor_id) values (t.id(k, 51), t.id(k, 102), t.id(k, 31));
  insert into public.invites(id, contractor_id, token) values (t.id(k, 61), t.id(k, 31), format('token-%s', k));

  insert into public.maintenance_plans(id, company_id, object_id, location_id, asset_id, layer_id, title,
                                       period_kind, starts_on, checklist, created_by) values
    (t.id(k, 801), c, t.id(k, 10), t.id(k, 21), t.id(k, 701), climate, 'ТО кондиционеров', 'month',
     '2026-01-01', '["Фильтры", "Дренаж", "Фреон"]', t.id(k, 100)),
    (t.id(k, 802), c, t.id(k, 11), null, null, elec, 'Осмотр электрощитов', 'quarter',
     '2026-01-01', '["Затяжка", "Тепловизор"]', t.id(k, 100));

  insert into public.work_orders(id, company_id, object_id, location_id, asset_id, layer_id, title, status,
                                 created_by, assigned_contractor_id, assigned_executor_id, plan_id,
                                 period_start, period_end, due_at, input_channel, recurrence) values
    (t.id(k, 101), c, t.id(k, 10), t.id(k, 21), t.id(k, 701), climate, 'ТО кондиционеров — сентябрь 2026', 'in_progress',
     t.id(k, 100), t.id(k, 31), t.id(k, 51), t.id(k, 801), '2026-09-01', '2026-09-30', '2026-09-30 23:59Z', 'ppr',
     '{"kind":"ppr","period":"month"}'),
    (t.id(k, 102), c, t.id(k, 11), t.id(k, 22), t.id(k, 702), elec, 'Не работает ИБП', 'new',
     t.id(k, 103), null, null, null, null, null, null, 'text', null);

  insert into public.checklist_items(id, work_order_id, text) values (t.id(k, 111), t.id(k, 101), 'Фильтры');
  insert into public.work_logs(id, work_order_id, from_status, to_status, by_profile)
  values (t.id(k, 121), t.id(k, 101), 'assigned', 'in_progress', t.id(k, 102));
  insert into public.attachments(id, work_order_id, kind, storage_path, stage, uploaded_by)
  values (t.id(k, 131), t.id(k, 101), 'photo', format('%s/%s/a.jpg', c, t.id(k, 101)), 'after', t.id(k, 102));
  insert into public.visits(id, company_id, object_id, profile_id, work_order_id, lat, lng)
  values (t.id(k, 141), c, t.id(k, 10), t.id(k, 102), t.id(k, 101), 55.75, 37.61);
  insert into public.scan_tags(id, asset_id, location_id, code) values (t.id(k, 151), t.id(k, 701), t.id(k, 21), format('tag-%s', k));
  insert into public.ar_anchors(id, asset_id, anchor_id) values (t.id(k, 161), t.id(k, 701), format('anchor-%s', k));

  insert into storage.buckets(id, name, public) values ('work-photos', 'work-photos', false), ('floor-plans', 'floor-plans', false)
  on conflict (id) do nothing;
  insert into storage.objects(id, bucket_id, name, owner, owner_id) values
    (t.id(k, 171), 'work-photos', format('%s/%s/a.jpg', c, t.id(k, 101)), t.id(k, 102), t.id(k, 102)::text),
    (t.id(k, 172), 'floor-plans', format('%s/%s/%s/plan.png', c, t.id(k, 10), t.id(k, 601)), t.id(k, 100), t.id(k, 100)::text);
end $$;

select t.make_company(1);
select t.make_company(2);

-- ---------------------------------------------------------------------
-- Шаг 17 (0016): зоны менеджеров и бригады — для access_zones.sql и
-- tenant_isolation.sql (у компании 2 те же строки).
--   104 — менеджер с зоной «Климат + Сантехника · объект 010 (Москва)»;
--   105 — менеджер с зоной «регион Азия» (Пекин 011, Шэньчжэнь 012);
--   106 — исполнитель «ЭлектроПро» (032) в бригаде «Пекин» (зона — город Пекин);
--   107 — исполнитель «ЭлектроПро» без бригады.
-- ---------------------------------------------------------------------
create or replace function t.make_company17(k int) returns void
language plpgsql as $$
declare
  c uuid := t.id(k, 1);
  climate uuid := (select id from public.layers where company_id = t.id(k, 1) and name = 'Климат');
  elec    uuid := (select id from public.layers where company_id = t.id(k, 1) and name = 'Электрика');
  plumb   uuid := (select id from public.layers where company_id = t.id(k, 1) and name = 'Сантехника');
  sec     uuid := (select id from public.layers where company_id = t.id(k, 1) and name = 'Системы безопасности');
  u record;
begin
  for u in select * from (values (104, 'manager'), (105, 'manager'), (106, 'executor'), (107, 'executor'))
           as v(n, role) loop
    insert into auth.users(id, email) values (t.id(k, u.n), format('u%s_%s@example.com', k, u.n));
    update public.profiles set company_id = c, role = u.role where id = t.id(k, u.n);
  end loop;

  insert into public.contractors(id, company_id, org_name) values
    (t.id(k, 33), c, 'СантехСервис'), (t.id(k, 34), c, 'Охрана-Сервис');
  insert into public.contractor_layers(id, contractor_id, layer_id, object_id) values
    (t.id(k, 43), t.id(k, 33), plumb, t.id(k, 10)),
    (t.id(k, 44), t.id(k, 34), sec, t.id(k, 10));
  insert into public.executors(id, profile_id, contractor_id) values
    (t.id(k, 52), t.id(k, 106), t.id(k, 32)),
    (t.id(k, 53), t.id(k, 107), t.id(k, 32));

  insert into public.assets(id, location_id, name, layer_id) values
    (t.id(k, 704), t.id(k, 21), 'Щит переговорной', elec),
    (t.id(k, 705), t.id(k, 21), 'Датчик дыма', sec);

  insert into public.work_orders(id, company_id, object_id, location_id, asset_id, layer_id, title, status,
                                 created_by, assigned_contractor_id) values
    (t.id(k, 103), c, t.id(k, 10), t.id(k, 21), t.id(k, 704), elec,  'Искрит щит',        'assigned', t.id(k, 100), t.id(k, 32)),
    (t.id(k, 104), c, t.id(k, 10), t.id(k, 21), t.id(k, 705), sec,   'Сработал датчик',   'assigned', t.id(k, 100), t.id(k, 34)),
    (t.id(k, 105), c, t.id(k, 10), t.id(k, 21), null,         plumb, 'Течёт кран',        'assigned', t.id(k, 100), t.id(k, 33)),
    (t.id(k, 106), c, t.id(k, 11), t.id(k, 22), null,         elec,  'Нет света (Пекин)', 'assigned', t.id(k, 100), t.id(k, 32)),
    (t.id(k, 107), c, t.id(k, 12), t.id(k, 23), null,         elec,  'Нет света (Шэньчжэнь)', 'assigned', t.id(k, 100), t.id(k, 32));

  insert into public.crews(id, company_id, contractor_id, name) values (t.id(k, 951), c, t.id(k, 32), 'Пекин');
  insert into public.crew_members(crew_id, executor_id, company_id) values (t.id(k, 951), t.id(k, 52), c);
  insert into public.crew_zones(id, company_id, crew_id, scope_kind, scope_ref)
  values (t.id(k, 961), c, t.id(k, 951), 'city', 'Пекин');

  insert into public.access_zones(id, company_id, profile_id, layer_ids, scope_kind, scope_ref) values
    (t.id(k, 971), c, t.id(k, 104), array[climate, plumb], 'object', t.id(k, 10)::text),
    (t.id(k, 972), c, t.id(k, 105), '{}', 'region', t.id(k, 902)::text);
end $$;

select t.make_company17(1);
select t.make_company17(2);
