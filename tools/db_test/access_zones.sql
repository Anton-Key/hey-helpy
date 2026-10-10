-- Зоны доступа менеджеров и бригады подрядчиков (0016).
-- Данные — 10_fixture.sql (make_company17): менеджеры 104 (Климат +
-- Сантехника на объекте 010), 105 (регион Азия), исполнители 106 (бригада
-- «Пекин») и 107 (без бригады) подрядчика «ЭлектроПро» (032).

select set_config('t.suite', 'access_zones', false);

create or replace function t.ids(p_sql text) returns text[]
language plpgsql as $$
declare
  out text[];
begin
  execute format('select coalesce(array_agg(right(id::text, 3) order by id), ''{}'') from (%s) x', p_sql) into out;
  return out;
end $$;
grant execute on function t.ids(text) to authenticated;

do $$
declare
  c1 uuid := t.id(1, 1);
  elec uuid := (select id from public.layers where company_id = t.id(1, 1) and name = 'Электрика');
  climate uuid := (select id from public.layers where company_id = t.id(1, 1) and name = 'Климат');
  got text[];
  n int;
begin
  -- 1. Менеджер «Климат + Сантехника» на объекте 010
  perform t.login(t.id(1, 104));
  got := t.ids('select id from public.work_orders');
  perform t.check(got @> array['101', '105'] and not (got && array['103', '104', '102', '106', '107']),
    format('менеджер «Климат+Сантехника · объект»: заявки %s (ожидается 101, 105 и задачи ППР климата; без 102, 103, 104, 106, 107)', got));
  got := t.ids('select id from public.assets');
  perform t.check(got @> array['701'] and not (got && array['704', '705', '702', '703']),
    format('… оборудование %s (только климат на объекте: 701)', got));
  got := t.ids('select id from public.contractors');
  perform t.check(got = array['031', '033'],
    format('… подрядчики %s (031 Климат, 033 Сантехника; без ЭлектроПро 032 и Охраны 034)', got));
  got := t.ids('select id from public.objects');
  perform t.check(got = array['010'], format('… объекты %s (только 010)', got));
  update public.work_orders set priority = 'high' where id = t.id(1, 103);
  get diagnostics n = row_count;
  perform t.check(n = 0, '… не может изменить заявку «Электрики» своего объекта');
  update public.assets set name = 'взлом' where id = t.id(1, 705);
  get diagnostics n = row_count;
  perform t.check(n = 0, '… не может изменить оборудование «Безопасности»');
  begin
    insert into public.work_orders(company_id, title, created_by, object_id, layer_id)
    values (c1, 'Не моя система', t.id(1, 104), t.id(1, 10), elec);
    perform t.check(false, '… создал заявку «Электрики» — ПРОШЛО');
  exception when others then
    perform t.check(sqlstate = '42501', format('… заявку «Электрики» создать нельзя (%s)', sqlstate));
  end;
  insert into public.work_orders(company_id, title, created_by, object_id, layer_id)
  values (c1, 'Своя система', t.id(1, 104), t.id(1, 10), climate);
  perform t.check(true, '… заявку «Климата» на своём объекте создать можно');
  perform t.login(null);

  -- 2. Региональный менеджер «Азия»
  perform t.login(t.id(1, 105));
  got := t.ids('select id from public.objects');
  perform t.check(got = array['011', '012'], format('менеджер «Азия»: объекты %s (Пекин 011, Шэньчжэнь 012; без Москвы 010)', got));
  got := t.ids('select id from public.work_orders');
  perform t.check(got @> array['102', '106', '107'] and not (got && array['101', '103', '104', '105']),
    format('… заявки %s (102, 106, 107 и задачи ППР Азии; без московских)', got));
  got := t.ids('select id from public.regions');
  perform t.check(got = array['902'], format('… регионы %s (только «Азия»)', got));
  perform t.login(null);

  -- 3. Менеджер без зон — вся компания, как раньше
  perform t.login(t.id(1, 100));
  got := t.ids('select id from public.work_orders where company_id = ''' || c1 || '''');
  perform t.check(got @> array['101', '102', '103', '104', '105', '106', '107'],
    format('менеджер без зон видит все заявки компании: %s', got));
  got := t.ids('select id from public.objects');
  perform t.check(got = array['010', '011', '012'], format('… все объекты: %s', got));
  perform t.login(null);

  -- 4. Бригада «Пекин» и исполнитель без бригады
  perform t.login(t.id(1, 106));
  got := t.ids('select id from public.work_orders');
  perform t.check(got @> array['102', '106'] and not (got && array['103', '107']),
    format('исполнитель бригады «Пекин»: заявки %s (Пекин: 102, 106 и задача ППР; без Шэньчжэня 107 и Москвы 103)', got));
  got := t.ids('select id from public.assets');
  perform t.check(got = array['702'], format('… оборудование %s (только Пекин: 702)', got));
  update public.work_orders set status = 'in_progress' where id = t.id(1, 107);
  get diagnostics n = row_count;
  perform t.check(n = 0, '… не может взять в работу заявку Шэньчжэня');
  perform t.login(null);

  perform t.login(t.id(1, 107));
  got := t.ids('select id from public.work_orders');
  perform t.check(got @> array['102', '103', '106', '107'],
    format('исполнитель без бригады — как раньше, все заявки «ЭлектроПро»: %s (102, 103, 106, 107)', got));
  perform t.login(null);

  -- 5. Администратор — всё в своей компании
  perform t.login(t.id(1, 101));
  got := t.ids('select id from public.work_orders where company_id = ''' || c1 || '''');
  perform t.check(got @> array['101', '102', '103', '104', '105', '106', '107'],
    format('администратор видит всё: %s', got));
  -- зоны меняет только администратор; запись — в аудит
  insert into public.access_zones(company_id, profile_id, layer_ids, scope_kind, scope_ref)
  values (c1, t.id(1, 104), '{}', 'country', 'CN');
  select count(*) into n from public.access_audit
   where company_id = c1 and actor = t.id(1, 101) and entity = 'access_zones' and action = 'insert';
  perform t.check(n >= 1, format('аудит: добавление зоны записано (%s)', n));
  delete from public.access_zones where company_id = c1 and scope_kind = 'country';
  perform t.login(null);

  -- 6. Менеджер не меняет зоны; заявитель — как раньше
  perform t.login(t.id(1, 100));
  begin
    insert into public.access_zones(company_id, profile_id, scope_kind) values (c1, t.id(1, 100), 'company');
    perform t.check(false, 'менеджер дал себе зону — ПРОШЛО');
  exception when others then
    perform t.check(sqlstate = '42501', 'менеджер не меняет зоны (только администратор)');
  end;
  select count(*) into n from public.access_zones;
  perform t.check(n = 0, format('менеджер без зон не видит чужие зоны (%s)', n));
  select count(*) into n from public.access_audit;
  perform t.check(n = 0, 'аудит видит только администратор');
  perform t.login(null);

  perform t.login(t.id(1, 104));
  select count(*) into n from public.access_zones;
  perform t.check(n = 1, format('менеджер видит свою зону (%s)', n));
  perform t.login(null);

  perform t.login(t.id(1, 103));
  got := t.ids('select id from public.work_orders');
  perform t.check(got = array['102'], format('заявитель — только свои заявки: %s', got));
  perform t.login(null);

  -- 7. Зоны не выходят за компанию: зона менеджера компании 1 с объектом компании 2
  perform t.login(t.id(1, 101));
  begin
    insert into public.access_zones(company_id, profile_id, scope_kind, scope_ref)
    values (c1, t.id(1, 104), 'object', t.id(2, 10)::text);
    perform t.check(false, 'зона на объект компании 2 — ПРОШЛО');
  exception when others then
    perform t.check(sqlstate = '42501', 'зона на объект компании 2 — отклонена');
  end;
  begin
    insert into public.access_zones(company_id, profile_id, scope_kind) values (c1, t.id(2, 104), 'company');
    perform t.check(false, 'зона сотруднику компании 2 — ПРОШЛО');
  exception when others then
    perform t.check(sqlstate = '42501', 'зона сотруднику компании 2 — отклонена');
  end;
  perform t.login(null);
end $$;
