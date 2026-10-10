-- Ссылки на чужую компанию: менеджер компании 1 вписывает в СВОЮ строку
-- id из компании 2 (регион, слой, объект, помещение, оборудование, план,
-- подрядчик, профиль). Каждая попытка должна быть отклонена триггером
-- проверки ссылок (а не случайно — уникальностью или внешним ключом).

select set_config('t.suite', 'cross_refs', false);

create or replace function t.expect_refused(p_sql text, p_msg text) returns void
language plpgsql as $$
begin
  begin
    execute p_sql;
    perform t.check(false, p_msg || ' — ПРОШЛО');
  exception when others then
    perform t.check(sqlstate = '42501' and sqlerrm not like '%row-level security%',
      format('%s — отклонено (%s %s)', p_msg, sqlstate, sqlerrm));
  end;
end $$;
grant execute on function t.expect_refused(text, text) to authenticated;

do $$
declare
  c1 uuid := t.id(1, 1);
  l1 uuid := (select id from public.layers where company_id = t.id(1, 1) and name = 'Климат');
  l2 uuid := (select id from public.layers where company_id = t.id(2, 1) and name = 'Климат');
begin
  perform t.login(t.id(1, 100));

  perform t.expect_refused(format(
    'insert into public.objects(company_id, name, region_id) values (%L, %L, %L)', c1, 'X', t.id(2, 901)),
    'objects: регион компании 2');
  perform t.expect_refused(format(
    'update public.objects set region_id = %L where id = %L', t.id(2, 901), t.id(1, 10)),
    'objects: смена региона на регион компании 2');
  perform t.expect_refused(format(
    'insert into public.locations(object_id, name, parent_id) values (%L, %L, %L)', t.id(1, 10), 'X', t.id(2, 21)),
    'locations: родитель из компании 2');
  perform t.expect_refused(format(
    'update public.assets set layer_id = %L where id = %L', l2, t.id(1, 701)),
    'assets: система (слой) компании 2');
  perform t.expect_refused(format(
    'insert into public.maintenance_plans(company_id, object_id, layer_id, title) values (%L, %L, %L, %L)',
    c1, t.id(2, 10), l1, 'X'), 'maintenance_plans: объект компании 2');
  perform t.expect_refused(format(
    'insert into public.maintenance_plans(company_id, object_id, layer_id, title) values (%L, %L, %L, %L)',
    c1, t.id(1, 10), l2, 'X'), 'maintenance_plans: слой компании 2');
  perform t.expect_refused(format(
    'insert into public.maintenance_plans(company_id, object_id, location_id, layer_id, title) values (%L, %L, %L, %L, %L)',
    c1, t.id(1, 10), t.id(2, 21), l1, 'X'), 'maintenance_plans: помещение компании 2');
  perform t.expect_refused(format(
    'insert into public.maintenance_plans(company_id, object_id, asset_id, layer_id, title) values (%L, %L, %L, %L, %L)',
    c1, t.id(1, 10), t.id(2, 701), l1, 'X'), 'maintenance_plans: оборудование компании 2');
  perform t.expect_refused(format(
    'insert into public.maintenance_plans(company_id, object_id, location_id, layer_id, title) values (%L, %L, %L, %L, %L)',
    c1, t.id(1, 10), t.id(1, 22), l1, 'X'), 'maintenance_plans: помещение другого объекта своей компании');

  perform t.expect_refused(format(
    'insert into public.work_orders(company_id, title, created_by, object_id) values (%L, %L, %L, %L)',
    c1, 'X', t.id(1, 100), t.id(2, 10)), 'work_orders: объект компании 2');
  perform t.expect_refused(format(
    'insert into public.work_orders(company_id, title, created_by, location_id) values (%L, %L, %L, %L)',
    c1, 'X', t.id(1, 100), t.id(2, 21)), 'work_orders: помещение компании 2');
  perform t.expect_refused(format(
    'insert into public.work_orders(company_id, title, created_by, asset_id) values (%L, %L, %L, %L)',
    c1, 'X', t.id(1, 100), t.id(2, 701)), 'work_orders: оборудование компании 2');
  perform t.expect_refused(format(
    'insert into public.work_orders(company_id, title, created_by, layer_id) values (%L, %L, %L, %L)',
    c1, 'X', t.id(1, 100), l2), 'work_orders: слой компании 2');
  perform t.expect_refused(format(
    'insert into public.work_orders(company_id, title, created_by, assigned_contractor_id) values (%L, %L, %L, %L)',
    c1, 'X', t.id(1, 100), t.id(2, 31)), 'work_orders: подрядчик компании 2');
  perform t.expect_refused(format(
    'insert into public.work_orders(company_id, title, created_by, plan_id) values (%L, %L, %L, %L)',
    c1, 'X', t.id(1, 100), t.id(2, 801)), 'work_orders: план ППР компании 2');
  perform t.expect_refused(format(
    'update public.work_orders set assigned_contractor_id = %L where id = %L', t.id(2, 31), t.id(1, 102)),
    'work_orders: назначить подрядчика компании 2');

  perform t.expect_refused(format(
    'insert into public.contractor_layers(contractor_id, layer_id) values (%L, %L)', t.id(1, 31), l2),
    'contractor_layers: слой компании 2');
  perform t.expect_refused(format(
    'insert into public.contractor_layers(contractor_id, layer_id, object_id) values (%L, %L, %L)', t.id(1, 31), l1, t.id(2, 10)),
    'contractor_layers: объект компании 2');
  perform t.expect_refused(format(
    'insert into public.contractor_objects(contractor_id, object_id) values (%L, %L)', t.id(1, 32), t.id(2, 10)),
    'contractor_objects: объект компании 2');
  perform t.expect_refused(format(
    'insert into public.executors(profile_id, contractor_id) values (%L, %L)', t.id(2, 102), t.id(1, 32)),
    'executors: сотрудник компании 2');
  perform t.expect_refused(format(
    'insert into public.scan_tags(asset_id, location_id, code) values (%L, %L, %L)', t.id(2, 701), t.id(1, 21), 'zz'),
    'scan_tags: оборудование компании 2');

  perform t.login(null);
end $$;
