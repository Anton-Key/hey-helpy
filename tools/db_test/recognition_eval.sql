-- Проверки 0028 (шаг 34): тест точности распознавания — кто видит и меняет
-- наборы, фото, прогоны и результаты; dev / test по единицам; заморозка;
-- результаты пишет только service_role; хранилище eval-photos; валюта USD.

select set_config('t.suite', 'recognition_eval', false);

create or replace function t.eval_try(p_uid uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform t.login(p_uid);
  execute p_sql;
  perform t.login(null);
  return 'ok';
exception when others then
  perform t.login(null);
  return sqlerrm;
end $$;

do $$
declare
  n int;
  r text;
  c1 uuid := t.id(1, 1);
  adm uuid := t.id(1, 101);
  mgr uuid := t.id(1, 100);
  s uuid := t.id(1, 1101);
  run uuid;
  run2 uuid;
  sp text;
  p text;
  x1202 uuid;
  x1204 uuid;
begin
  -- Вид оборудования для снимка «вид / похожие рядом»: два кондиционера в 021.
  insert into public.assets(id, location_id, name, meta) values
    (t.id(1, 1401), t.id(1, 21), 'AC A', '{"kind":"ac"}'),
    (t.id(1, 1402), t.id(1, 21), 'AC B', '{"kind":"ac"}'),
    (t.id(1, 1403), t.id(1, 21), 'Smoke', '{"kind":"smoke"}');

  -- Администратор: видит только своё.
  perform t.login(adm);
  select count(*) into n from public.recognition_eval_sets;      perform t.check(n = 1, format('админ видит свой набор (%s)', n));
  select count(*) into n from public.recognition_eval_samples;   perform t.check(n = 2, format('админ видит фото своей компании (%s)', n));
  select count(*) into n from public.recognition_eval_runs;      perform t.check(n = 1, 'админ видит свой прогон');
  select count(*) into n from public.recognition_eval_results;   perform t.check(n = 1, 'админ видит свой результат');
  select count(*) into n from storage.objects where bucket_id = 'eval-photos';
  perform t.check(n = 1, format('админ видит только файлы своей компании в eval-photos (%s)', n));
  perform t.login(null);

  -- Менеджер, исполнитель, заявитель — раздела нет.
  foreach r in array array['100', '102', '103'] loop
    perform t.login(t.id(1, r::int));
    select count(*) into n from public.recognition_eval_sets;
    perform t.check(n = 0, format('не-админ %s не видит наборы', r));
    select count(*) into n from public.recognition_eval_samples;
    perform t.check(n = 0, format('не-админ %s не видит фото', r));
    select count(*) into n from public.recognition_eval_results;
    perform t.check(n = 0, format('не-админ %s не видит результаты', r));
    select count(*) into n from storage.objects where bucket_id = 'eval-photos';
    perform t.check(n = 0, format('не-админ %s не видит файлы eval-photos', r));
    perform t.login(null);
  end loop;
  r := t.eval_try(mgr, format($q$insert into public.recognition_eval_sets(company_id, name, created_by) values (%L, 'x', %L)$q$, c1, mgr));
  perform t.check(r <> 'ok', 'менеджер не создаёт набор: ' || r);
  r := t.eval_try(mgr, format($q$select public.recognition_eval_run_start(%L, 'dev')$q$, t.id(1, 1001)));
  perform t.check(r <> 'ok', 'менеджер не запускает прогон: ' || r);

  -- Новый набор администратора.
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_sets(id, company_id, name, created_by) values (%L, %L, 'Набор 2', %L)$q$, s, c1, adm));
  perform t.check(r = 'ok', 'админ создаёт набор: ' || r);
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_sets(company_id, name, created_by) values (%L, 'чужой', %L)$q$, t.id(2, 1), adm));
  perform t.check(r <> 'ok', 'набор в чужой компании нельзя: ' || r);
  r := t.eval_try(adm, format($q$update public.recognition_eval_sets set frozen_at = now() where id = %L$q$, s));
  perform t.check(r <> 'ok', 'заморозить в обход функции нельзя: ' || r);

  -- Фото: dev / test ставит база по единицам (клиент просит test — не важно).
  p := c1::text || '/' || s::text || '/';
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(id, set_id, company_id, created_by, photo_path, site_id, room_id, true_equipment_id, light, distance, angle, split)
      values (%L, %L, %L, %L, %L, %L, %L, %L, 'good', 'close', 'front', 'test')$q$,
      t.id(1, 1111), s, c1, adm, p || t.id(1, 1201) || '.jpg', t.id(1, 10), t.id(1, 21), t.id(1, 1401)));
  perform t.check(r = 'ok', 'админ добавляет фото: ' || r);
  select split into sp from public.recognition_eval_samples where id = t.id(1, 1111);
  perform t.check(sp = 'dev', 'первая единица — в dev, просьба клиента «test» не учитывается: ' || coalesce(sp, 'null'));
  select count(*) into n from public.recognition_eval_samples where id = t.id(1, 1111) and true_kind = 'ac' and similar_in_room = 2;
  perform t.check(n = 1, 'снимок вида и «2 похожих в помещении»');

  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(set_id, company_id, created_by, photo_path, site_id, room_id, true_equipment_id, light, distance, angle)
      values (%L, %L, %L, %L, %L, %L, %L, 'dim', 'far', 'side')$q$,
      s, c1, adm, p || t.id(1, 1202) || '.jpg', t.id(1, 10), t.id(1, 21), t.id(1, 1402)));
  perform t.check(r = 'ok', 'фото второй единицы: ' || r);
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(set_id, company_id, created_by, photo_path, site_id, room_id, true_equipment_id, light, distance, angle)
      values (%L, %L, %L, %L, %L, %L, %L, 'good', 'medium', 'front')$q$,
      s, c1, adm, p || t.id(1, 1203) || '.jpg', t.id(1, 10), t.id(1, 21), t.id(1, 1403)));
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(set_id, company_id, created_by, photo_path, site_id, room_id, true_equipment_id, light, distance, angle)
      values (%L, %L, %L, %L, %L, %L, %L, 'good', 'medium', 'side')$q$,
      s, c1, adm, p || t.id(1, 1204) || '.jpg', t.id(1, 10), t.id(1, 21), t.id(1, 1401)));
  perform t.check(r = 'ok', 'второе фото первой единицы: ' || r);
  select count(*) into n from (select true_equipment_id from public.recognition_eval_samples where set_id = s
                               group by true_equipment_id having count(distinct split) > 1) x;
  perform t.check(n = 0, 'все фото одной единицы — в одном наборе');
  select count(*) into n from public.recognition_eval_samples where set_id = s and split = 'test';
  perform t.check(n = 2, format('единицы 704 и 705 — в test (%s фото)', n));

  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(set_id, company_id, created_by, photo_path, site_id, room_id, true_equipment_id, light, distance, angle)
      values (%L, %L, %L, %L, %L, %L, %L, 'good', 'close', 'front')$q$,
      s, c1, adm, p || t.id(1, 1205) || '.jpg', t.id(1, 11), t.id(1, 22), t.id(1, 1401)));
  perform t.check(r like '%eval_bad_asset%', 'единица не из этого помещения — нельзя: ' || r);
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(set_id, company_id, created_by, photo_path, site_id, room_id, true_equipment_id, light, distance, angle)
      values (%L, %L, %L, %L, %L, %L, %L, 'good', 'close', 'front')$q$,
      s, c1, adm, p || t.id(1, 1206) || '.jpg', t.id(2, 10), t.id(2, 21), t.id(2, 701)));
  perform t.check(r <> 'ok', 'помещение другой компании — нельзя: ' || r);
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(set_id, company_id, created_by, photo_path, site_id, room_id, true_is_unregistered, light, distance, angle)
      values (%L, %L, %L, %L, %L, %L, true, 'good', 'close', 'front')$q$,
      s, c1, adm, t.id(2, 1) || '/' || s || '/' || t.id(1, 1207) || '.jpg', t.id(1, 10), t.id(1, 21)));
  perform t.check(r like '%eval_bad_path%', 'путь фото не своей компании — нельзя: ' || r);
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(set_id, company_id, created_by, photo_path, site_id, room_id, light, distance, angle)
      values (%L, %L, %L, %L, %L, %L, 'good', 'close', 'front')$q$,
      s, c1, adm, p || t.id(1, 1208) || '.jpg', t.id(1, 10), t.id(1, 21)));
  perform t.check(r <> 'ok', 'без разметки (ни единицы, ни «нет в реестре») — нельзя: ' || r);
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(set_id, company_id, created_by, photo_path, site_id, room_id, true_is_unregistered, true_kind, series_id, light, distance, angle)
      values (%L, %L, %L, %L, %L, %L, true, 'ups', %L, 'good', 'close', 'front')$q$,
      s, c1, adm, p || t.id(1, 1209) || '.jpg', t.id(1, 10), t.id(1, 21), t.id(1, 1301)));
  perform t.check(r = 'ok', 'фото «нет в реестре»: ' || r);

  select id into x1202 from public.recognition_eval_samples where photo_path = p || t.id(1, 1202) || '.jpg';
  select id into x1204 from public.recognition_eval_samples where photo_path = p || t.id(1, 1204) || '.jpg';
  -- После вставки меняются только условия съёмки.
  r := t.eval_try(adm, format($q$update public.recognition_eval_samples set light = 'backlight', occlusion = true where id = %L$q$, t.id(1, 1111)));
  perform t.check(r = 'ok', 'условия съёмки можно поправить: ' || r);
  r := t.eval_try(adm, format($q$update public.recognition_eval_samples set true_equipment_id = %L where id = %L$q$, t.id(1, 1402), t.id(1, 1111)));
  perform t.check(r like '%eval_immutable%', 'разметку после вставки не меняют: ' || r);
  r := t.eval_try(adm, format($q$update public.recognition_eval_samples set split = 'test' where id = %L$q$, t.id(1, 1111)));
  perform t.check(r like '%eval_immutable%', 'dev / test вручную не меняют: ' || r);

  -- Прогон: test — только после заморозки.
  r := t.eval_try(adm, format($q$select public.recognition_eval_run_start(%L, 'test')$q$, s));
  perform t.check(r like '%eval_not_frozen%', 'test до заморозки не запускается: ' || r);
  perform t.login(adm);
  run := public.recognition_eval_run_start(s, 'dev', 'default');
  perform t.login(null);
  perform t.check(run is not null, 'админ запускает прогон dev');
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_runs(company_id, set_id, split, sample_count) values (%L, %L, 'dev', 1)$q$, c1, s));
  perform t.check(r <> 'ok', 'прогон в обход функции не создать: ' || r);
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_results(run_id, sample_id, company_id) values (%L, %L, %L)$q$, run, t.id(1, 1111), c1));
  perform t.check(r <> 'ok', 'результат из приложения не записать: ' || r);
  r := t.eval_try(adm, format($q$select public.recognition_eval_put_result(%L, %L, %L, 'yandex', 'm', %L, '{}')$q$, adm, run, t.id(1, 1111), repeat('a', 64)));
  perform t.check(r <> 'ok', 'recognition_eval_put_result закрыта для authenticated: ' || r);

  -- service_role (функция recognition-eval).
  perform public.recognition_eval_put_result(adm, run, t.id(1, 1111), 'yandex', 'qwen', repeat('a', 64),
    jsonb_build_object('predicted_equipment_id', t.id(1, 1401), 'confidence', 0.75, 'predicted_kind', 'ac', 'ms', 3000,
                       'candidates', jsonb_build_array(jsonb_build_object('asset_id', t.id(1, 1401), 'score', 0.75))));
  select count(*) into n from public.recognition_eval_runs where id = run and provider = 'yandex' and model_vision = 'qwen';
  perform t.check(n = 1, 'первый ответ записывает поставщика и модель прогона');
  begin
    perform public.recognition_eval_put_result(adm, run, t.id(1, 1111), 'yandex', 'qwen', repeat('a', 64), '{"confidence":1}');
    r := 'ok';
  exception when others then r := sqlerrm;
  end;
  perform t.check(r like '%eval_result_exists%', 'хороший ответ не перезаписывается: ' || r);
  begin
    perform public.recognition_eval_put_result(adm, run, x1204, 'openai', 'gpt', repeat('a', 64), '{}');
    r := 'ok';
  exception when others then r := sqlerrm;
  end;
  perform t.check(r like '%eval_config_changed%', 'один прогон — один поставщик и модель: ' || r);
  begin
    perform public.recognition_eval_put_result(mgr, run, x1204, 'yandex', 'qwen', repeat('a', 64), '{}');
    r := 'ok';
  exception when others then r := sqlerrm;
  end;
  perform t.check(r like '%eval_forbidden%', 'от имени не-админа не пишется: ' || r);
  begin
    perform public.recognition_eval_put_result(t.id(2, 101), run, x1204, 'yandex', 'qwen', repeat('a', 64), '{}');
    r := 'ok';
  exception when others then r := sqlerrm;
  end;
  perform t.check(r like '%eval_forbidden%', 'от имени админа другой компании не пишется: ' || r);
  begin
    perform public.recognition_eval_put_result(adm, run, x1202, 'yandex', 'qwen', repeat('a', 64), '{}');
    r := 'ok';
  exception when others then r := sqlerrm;
  end;
  perform t.check(r like '%eval_bad_sample%', 'фото test в прогон dev не пишется: ' || r);
  -- Ответ с ошибкой можно повторить.
  perform public.recognition_eval_put_result(adm, run, x1204, 'yandex', 'qwen', repeat('a', 64), '{"error":"ai_unavailable"}');
  perform public.recognition_eval_put_result(adm, run, x1204, 'yandex', 'qwen', repeat('a', 64), '{"abstained":true}');
  select count(*) into n from public.recognition_eval_results where run_id = run and sample_id = x1204 and error is null and abstained;
  perform t.check(n = 1, 'ответ с ошибкой заменён повтором');

  r := t.eval_try(adm, format($q$select public.recognition_eval_run_finish(%L)$q$, run));
  perform t.check(r like '%eval_incomplete%', 'прогон без ответа на каждое фото не закрыть как done: ' || r);
  perform t.login(adm);
  r := public.recognition_eval_run_finish(run, true);
  perform t.login(null);
  perform t.check(r = 'cancelled', 'прогон можно отменить');

  -- Заморозка.
  perform t.login(adm);
  perform public.recognition_eval_freeze(s);
  perform t.login(null);
  select count(*) into n from public.recognition_eval_sets where id = s and frozen_at is not null and frozen_by = adm;
  perform t.check(n = 1, 'набор заморожен функцией');
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_samples(set_id, company_id, created_by, photo_path, site_id, room_id, true_equipment_id, light, distance, angle)
      values (%L, %L, %L, %L, %L, %L, %L, 'good', 'close', 'front')$q$,
      s, c1, adm, p || t.id(1, 1210) || '.jpg', t.id(1, 10), t.id(1, 21), t.id(1, 1401)));
  perform t.check(r like '%eval_frozen%', 'в замороженный набор фото не добавить: ' || r);
  r := t.eval_try(adm, format($q$update public.recognition_eval_samples set light = 'good' where id = %L$q$, t.id(1, 1111)));
  perform t.check(r like '%eval_frozen%', 'фото замороженного набора не править: ' || r);
  r := t.eval_try(adm, format($q$delete from public.recognition_eval_samples where id = %L$q$, x1202));
  perform t.check(r like '%eval_frozen%', 'фото замороженного набора не удалить: ' || r);
  r := t.eval_try(adm, format($q$delete from public.recognition_eval_sets where id = %L$q$, s));
  perform t.check(r like '%eval_frozen%', 'замороженный набор не удалить: ' || r);
  r := t.eval_try(adm, format($q$update public.recognition_eval_sets set name = 'другое' where id = %L$q$, s));
  perform t.check(r like '%eval_frozen%', 'замороженный набор не переименовать: ' || r);
  r := t.eval_try(adm, format($q$insert into storage.objects(bucket_id, name, owner, owner_id) values ('eval-photos', %L, %L, %L)$q$,
      p || t.id(1, 1211) || '.jpg', adm, adm::text));
  perform t.check(r <> 'ok', 'файл в замороженный набор не загрузить: ' || r);
  r := t.eval_try(adm, format($q$delete from storage.objects where bucket_id = 'eval-photos' and name = %L$q$,
      c1 || '/' || t.id(1, 1001) || '/' || t.id(1, 1007) || '.jpg'));
  select count(*) into n from storage.objects where id = t.id(1, 1006);
  perform t.check(n = 1, 'файл замороженного набора не удаляется');

  perform t.login(adm);
  run2 := public.recognition_eval_run_start(s, 'test');
  perform t.login(null);
  select count(*) into n from public.recognition_eval_runs where id = run2 and sample_count = 2 and set_frozen_at is not null;
  perform t.check(n = 1, 'после заморозки — прогон test на 2 фото');

  -- Хранилище: администратор загружает в незамороженный набор своей компании.
  r := t.eval_try(adm, format($q$insert into public.recognition_eval_sets(id, company_id, name, created_by) values (%L, %L, 'Набор 3', %L)$q$, t.id(1, 1102), c1, adm));
  r := t.eval_try(adm, format($q$insert into storage.objects(bucket_id, name, owner, owner_id) values ('eval-photos', %L, %L, %L)$q$,
      c1 || '/' || t.id(1, 1102) || '/' || t.id(1, 1212) || '.jpg', adm, adm::text));
  perform t.check(r = 'ok', 'админ загружает фото в свой незамороженный набор: ' || r);
  r := t.eval_try(mgr, format($q$insert into storage.objects(bucket_id, name, owner, owner_id) values ('eval-photos', %L, %L, %L)$q$,
      c1 || '/' || t.id(1, 1102) || '/' || t.id(1, 1213) || '.jpg', mgr, mgr::text));
  perform t.check(r <> 'ok', 'менеджер не загружает в eval-photos: ' || r);
  r := t.eval_try(adm, format($q$insert into storage.objects(bucket_id, name, owner, owner_id) values ('eval-photos', %L, %L, %L)$q$,
      t.id(2, 1) || '/' || t.id(2, 1001) || '/' || t.id(1, 1214) || '.jpg', adm, adm::text));
  perform t.check(r <> 'ok', 'в папку другой компании не загрузить: ' || r);

  -- Валюта ставок по умолчанию (хвост шага 33).
  select count(*) into n from information_schema.columns
   where table_schema = 'public' and table_name = 'contractor_rates' and column_name = 'currency'
     and column_default like '''USD''%';
  perform t.check(n = 1, 'contractor_rates.currency по умолчанию — USD');

  -- Оборудование из набора удаляется из реестра свободно (набор — снимок).
  delete from public.assets where id in (t.id(1, 1401), t.id(1, 1402), t.id(1, 1403));
  select count(*) into n from public.recognition_eval_samples where true_equipment_id = t.id(1, 1401);
  perform t.check(n = 2, 'удаление оборудования из реестра не трогает фото набора');
end $$;
