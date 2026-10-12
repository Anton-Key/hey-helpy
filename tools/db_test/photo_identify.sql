-- Проверки 0017: журнал узнаваний по фото — кто пишет, кто читает, что
-- меняется, статистика.

select set_config('t.suite', 'photo_identify', false);

do $$
declare
  n int;
  ok boolean;
  s record;
  c1 uuid := t.id(1, 1);
  new_id uuid := gen_random_uuid();
begin
  -- Исполнитель: пишет своё, видит только своё.
  perform t.login(t.id(1, 102));
  insert into public.photo_identifications(id, company_id, user_id, object_id, location_id, kind, confidence, top_asset_id, model, ms)
  values (new_id, c1, t.id(1, 102), t.id(1, 10), t.id(1, 21), 'ac', 0.8, t.id(1, 701), 'main', 3000);
  select count(*) into n from public.photo_identifications;
  perform t.check(n = 2, format('исполнитель видит только свои узнавания (%s)', n));
  update public.photo_identifications set chosen_asset_id = t.id(1, 701), outcome = 'matched_top' where id = new_id;
  get diagnostics n = row_count;
  perform t.check(n = 1, 'автор дописывает выбор и итог');

  begin
    update public.photo_identifications set kind = 'ups' where id = new_id;
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'вид после вставки не меняется');

  begin
    update public.photo_identifications set chosen_asset_id = t.id(2, 701), outcome = 'matched_other' where id = new_id;
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'выбрать оборудование другой компании нельзя');

  begin
    insert into public.photo_identifications(company_id, user_id, kind) values (c1, t.id(1, 100), 'ac');
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'писать от имени другого пользователя нельзя');

  begin
    update public.photo_identifications set outcome = 'dismissed', chosen_asset_id = t.id(1, 701) where id = new_id;
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, '«dismissed» — без выбранного оборудования');

  -- Заявитель: чужие строки не видит и не меняет.
  perform t.login(t.id(1, 103));
  select count(*) into n from public.photo_identifications;
  perform t.check(n = 0, 'заявитель не видит чужие узнавания');

  -- Менеджер: видит все строки компании, но чужие не меняет.
  perform t.login(t.id(1, 100));
  select count(*) into n from public.photo_identifications;
  perform t.check(n = 3, format('менеджер видит все узнавания компании (%s)', n));
  update public.photo_identifications set outcome = 'dismissed' where id = new_id;
  get diagnostics n = row_count;
  perform t.check(n = 0, 'менеджер не меняет чужое узнавание');
  begin
    delete from public.photo_identifications where id = new_id;
    get diagnostics n = row_count;
    ok := n = 0;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'удалить узнавание нельзя');

  select * into s from public.photo_identify_stats();
  perform t.check(s.total = 3 and s.decided = 2 and s.matched_top = 2 and s.top_rate = 1,
    format('статистика: всего %s, с решением %s, с первого раза %s, доля %s', s.total, s.decided, s.matched_top, s.top_rate));
  perform t.check(s.avg_ms = round((4200 + 9100 + 3000) / 3.0), format('среднее время %s', s.avg_ms));
  select * into s from public.photo_identify_stats(t.id(2, 1));
  perform t.check(s.total = 0, 'статистика чужой компании — пусто');

  -- Аноним: функция закрыта.
  perform t.login(null);
  execute 'set role anon';
  begin
    perform public.photo_identify_stats();
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'аноним не вызывает photo_identify_stats');
  execute 'reset role';

  -- Удаление оборудования обнуляет ссылки (триггер это разрешает), строка остаётся.
  update public.work_orders set asset_id = null where asset_id = t.id(1, 701);
  update public.maintenance_plans set asset_id = null where asset_id = t.id(1, 701);
  delete from public.assets where id = t.id(1, 701);
  select count(*) into n from public.photo_identifications
   where id = new_id and top_asset_id is null and chosen_asset_id is null and outcome = 'matched_top';
  perform t.check(n = 1, 'удаление оборудования обнуляет ссылки, узнавание остаётся');
end $$;
