-- Проверки 0024 (шаг 27): очередь действий без сети, честное время,
-- отпечаток фото, конфликты, решения менеджера по доказательствам.
-- Пользователи fixture компании 1: 100 менеджер, 101 администратор,
-- 102 исполнитель «КлиматСервис» (031), 103 заявитель, 107 исполнитель
-- «ЭлектроПро» (032) без бригады.

select set_config('t.suite', 'offline_sync', false);

-- Очередь под пользователем; ошибка — {"error": текст}.
create or replace function t.sync(p_uid uuid, p_actions jsonb)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform t.login(p_uid);
  r := public.offline_sync(p_actions);
  perform t.login(null);
  return r;
exception when others then
  perform t.login(null);
  return jsonb_build_object('error', sqlerrm);
end $$;

-- Решение по доказательству под пользователем: null — получилось, иначе текст ошибки.
create or replace function t.decide(p_uid uuid, p_order uuid, p_decision text, p_reason text)
returns text language plpgsql as $$
begin
  perform t.login(p_uid);
  perform public.act_proof_decide(p_order, p_decision, p_reason);
  perform t.login(null);
  return null;
exception when others then
  perform t.login(null);
  return sqlerrm;
end $$;

-- Результат действия по id.
create or replace function t.res(p jsonb, p_id uuid) returns jsonb
language sql immutable as $$
  select e from jsonb_array_elements(p) e where e->>'id' = p_id::text limit 1;
$$;

-- Действие очереди.
create or replace function t.act(p_id uuid, p_kind text, p_order uuid, p_device timestamptz,
                                 p_extra jsonb default '{}', p_boot text default 'b1',
                                 p_mono bigint default null, p_gps timestamptz default null)
returns jsonb language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', p_id, 'kind', p_kind, 'order_id', p_order, 'device_at', p_device,
    'boot', case when p_mono is null then null else p_boot end, 'mono_ms', p_mono, 'gps_at', p_gps)) || p_extra;
$$;

do $$
declare
  c1 uuid := t.id(1, 1);
  climate uuid := (select id from public.layers where company_id = t.id(1, 1) and name = 'Климат');
  mgr uuid := t.id(1, 100); adm uuid := t.id(1, 101); ex uuid := t.id(1, 102); req uuid := t.id(1, 103);
  ex_other uuid := t.id(1, 107);
  w1 uuid := t.id(1, 391);  -- всё без сети, часы честные
  w2 uuid := t.id(1, 392);  -- часы телефона переведены на 2 ч
  w3 uuid := t.id(1, 393);  -- отменили, пока исполнитель был без сети
  w4 uuid := t.id(1, 394);  -- нет ни якоря, ни GPS / только GPS
  ci uuid := t.id(1, 395);
  p1 text; p2 text; p3 text; p4 text;
  t0 timestamptz := now() - interval '20 minutes';
  q jsonb;
  r jsonb;
  n int;
  a record;
  v record;
  w record;
  err text;
begin
  perform t.login(null);
  insert into public.work_orders(id, company_id, object_id, location_id, layer_id, title, status,
                                 created_by, assigned_contractor_id, requires_photo) values
    (w1, c1, t.id(1, 10), t.id(1, 21), climate, 'Без сети: всё честно', 'assigned', req, t.id(1, 31), true),
    (w2, c1, t.id(1, 10), t.id(1, 21), climate, 'Без сети: часы',      'assigned', req, t.id(1, 31), true),
    (w3, c1, t.id(1, 10), t.id(1, 21), climate, 'Без сети: отмена',    'assigned', req, t.id(1, 31), true),
    (w4, c1, t.id(1, 10), t.id(1, 21), climate, 'Без сети: источники', 'assigned', req, t.id(1, 31), false);
  insert into public.checklist_items(id, work_order_id, text) values (ci, w1, 'Очистить фильтр');
  p1 := format('%s/%s/off_%s.jpg', c1, w1, t.id(1, 396));
  p2 := format('%s/%s/off_%s.jpg', c1, w2, t.id(1, 397));
  p3 := format('%s/%s/off_%s.jpg', c1, w3, t.id(1, 398));
  p4 := format('%s/%s/off_%s.jpg', c1, w1, t.id(1, 399));

  -- ===== Якорь часов =====
  perform t.login(ex);
  perform public.offline_clock('b-real', 5000);
  perform t.login(null);
  perform t.check((select count(*) from public.offline_clock_anchors where profile_id = ex and boot_id = 'b-real') = 1,
                  'offline_clock записывает якорь «время сервера ↔ монотонные часы»');
  perform t.check(t.sync(req, '[]') = '[]'::jsonb, 'пустая очередь — пустой ответ');
  -- якорь 30 минут назад: монотонные 1 000 000 мс
  insert into public.offline_clock_anchors(profile_id, company_id, boot_id, mono_ms, server_at)
  values (ex, c1, 'b1', 1000000, now() - interval '30 minutes');

  -- ===== Хранилище: исполнитель кладёт фото очереди =====
  perform t.login(ex);
  begin
    insert into storage.objects(bucket_id, name, owner, owner_id)
    values ('work-photos', p1, ex, ex::text);
    perform t.check(true, 'исполнитель кладёт фото очереди в заявку своего подрядчика');
  exception when others then
    perform t.check(false, 'исполнитель кладёт фото очереди в заявку своего подрядчика: ' || sqlerrm);
  end;
  perform t.login(null);
  insert into storage.objects(bucket_id, name, owner, owner_id) values
    ('work-photos', p2, ex, ex::text), ('work-photos', p4, ex, ex::text);
  insert into public.offline_photo_hashes(storage_path, company_id, sha256) values
    (p1, c1, repeat('1', 64)), (p2, c1, repeat('2', 64)), (p4, c1, repeat('4', 64));

  -- ===== Очередь по порядку: начать → визит → чек-лист → фото → сдать =====
  q := jsonb_build_array(
    t.act(t.id(1, 401), 'start',  w1, t0,                     p_mono => 1000000 + 600000),
    t.act(t.id(1, 402), 'visit',  w1, t0 + interval '1 min',  '{"lat":55.75,"lng":37.61,"accuracy":12}', p_mono => 1000000 + 660000),
    t.act(t.id(1, 403), 'check',  w1, t0 + interval '2 min',  jsonb_build_object('item_id', ci, 'done', true), p_mono => 1000000 + 720000),
    t.act(t.id(1, 404), 'photo',  w1, t0 + interval '3 min',  jsonb_build_object('path', p1, 'sha256', repeat('1', 64), 'lat', 55.75, 'lng', 37.61), p_mono => 1000000 + 780000),
    t.act(t.id(1, 405), 'submit', w1, t0 + interval '4 min',  p_mono => 1000000 + 840000));
  r := t.sync(ex, q);
  perform t.check(not (r ? 'error') and jsonb_array_length(r) = 5, 'очередь из 5 действий принята: ' || r::text);
  perform t.check((select count(*) from jsonb_array_elements(r) e where e->>'result' = 'applied') = 5,
                  'все 5 действий применены');
  perform t.check((select count(*) from jsonb_array_elements(r) e where e->>'trust' = 'monotonic') = 5,
                  'время всех действий подтверждено монотонными часами');
  select * into w from public.work_orders where id = w1;
  perform t.check(w.status = 'on_review' and w.submitted_by = ex, 'заявка «на проверке», сдал исполнитель');
  perform t.check(abs(extract(epoch from w.started_at - t0)) < 5,
                  'начало работы — время действия, а не время отправки');
  perform t.check(abs(extract(epoch from w.submitted_at - (t0 + interval '4 min'))) < 5,
                  'сдача на проверку — время действия');
  select * into a from public.attachments where storage_path = p1;
  perform t.check(a.offline and a.time_trust = 'monotonic' and a.sha256_ok and a.source = 'camera'
                  and a.stage = 'after' and a.sync_note is null and a.synced_at is not null,
                  'фото: без сети, время по монотонным часам, отпечаток сверен, живой снимок');
  perform t.check(abs(extract(epoch from a.trusted_at - (t0 + interval '3 min'))) < 5,
                  'доверенное время снимка = якорь + прошедший интервал');
  select * into v from public.visits where work_order_id = w1;
  perform t.check(v.offline and v.time_trust = 'monotonic' and v.in_geofence
                  and abs(extract(epoch from v.started_at - (t0 + interval '1 min'))) < 5
                  and v.ended_at is not null and abs(extract(epoch from v.ended_at - (t0 + interval '4 min'))) < 5,
                  'визит: в геозоне, начало и конец — по времени действий');
  perform t.check((select is_done and done_by = ex and abs(extract(epoch from done_at - (t0 + interval '2 min'))) < 5
                     from public.checklist_items where id = ci), 'пункт чек-листа отмечен временем действия');

  -- ===== Повтор той же очереди — без дублей =====
  r := t.sync(ex, q);
  perform t.check((select count(*) from jsonb_array_elements(r) e where (e->>'repeat')::boolean) = 5,
                  'повторная отправка: все 5 действий узнаны как повтор');
  perform t.check((select count(*) from public.attachments where work_order_id = w1) = 1
                  and (select count(*) from public.visits where work_order_id = w1) = 1
                  and (select count(*) from public.offline_actions where work_order_id = w1) = 5,
                  'повтор не создал второго фото, визита и записи журнала');

  -- ===== Отпечаток не совпал — фото отклоняется =====
  perform t.login(null);
  update public.work_orders set status = 'in_progress' where id = w2;
  r := t.sync(ex, jsonb_build_array(
    t.act(t.id(1, 411), 'photo', w2, now() - interval '5 min',
          jsonb_build_object('path', p2, 'sha256', repeat('f', 64)), p_mono => 1000000 + 1500000)));
  perform t.check(t.res(r, t.id(1, 411))->>'reason' = 'photo_hash_mismatch'
                  and not exists (select 1 from public.attachments where storage_path = p2),
                  'отпечаток фото не совпал с файлом — фото отклонено');

  -- ===== Часы телефона переведены на 2 ч =====
  r := t.sync(ex, jsonb_build_array(
    t.act(t.id(1, 412), 'photo', w2, now() - interval '10 min' + interval '2 hours',
          jsonb_build_object('path', p2, 'sha256', repeat('2', 64)), p_mono => 1000000 + 1200000)));
  select * into a from public.attachments where storage_path = p2;
  perform t.check(a.time_trust = 'unverified' and a.time_drift_s between 7100 and 7300,
                  'часы телефона расходятся на 2 ч — время не подтверждено, расхождение записано');
  perform t.check(abs(extract(epoch from a.trusted_at - (now() - interval '10 min'))) < 5,
                  'доверенное время — по монотонным часам, не по часам телефона');

  -- ===== Нет якоря и GPS / только GPS / GPS спорит с монотонными =====
  r := t.sync(ex, jsonb_build_array(
    t.act(t.id(1, 421), 'start', w4, now() - interval '3 min'),
    t.act(t.id(1, 422), 'visit', w4, now() - interval '2 min', '{"lat":55.75,"lng":37.61}',
          p_gps => now() - interval '2 min' + interval '20 seconds'),
    t.act(t.id(1, 423), 'check', w4, now() - interval '1 min', '{"item_id":"00000000-0000-4000-8000-000000000000"}',
          p_mono => 1000000 + 1740000, p_gps => now() - interval '2 hours')));
  perform t.check(t.res(r, t.id(1, 421))->>'trust' = 'device_only', 'нет ни якоря, ни GPS — device_only');
  perform t.check(t.res(r, t.id(1, 422))->>'trust' = 'gps', 'есть только время GPS — gps');
  perform t.check(t.res(r, t.id(1, 423))->>'trust' = 'unverified', 'GPS и монотонные часы расходятся — unverified');
  perform t.check(t.res(r, t.id(1, 423))->>'reason' = 'not_found', 'чужой пункт чек-листа — not_found');
  perform t.check((select time_trust from public.visits where work_order_id = w4) = 'gps', 'визит по GPS-времени');
  r := t.sync(ex, jsonb_build_array(
    t.act(t.id(1, 424), 'start', w4, now() - interval '1 min', p_boot => 'unknown-boot', p_mono => 5)));
  perform t.check(t.res(r, t.id(1, 424))->>'trust' = 'device_only'
                  and t.res(r, t.id(1, 424))->>'result' = 'applied',
                  'телефон перезагружали (нет якоря этой загрузки) — device_only, «уже в работе» — без ошибки');

  -- ===== Чужой подрядчик, менеджер, заявитель =====
  r := t.sync(ex_other, jsonb_build_array(t.act(t.id(1, 431), 'start', w3, now())));
  perform t.check(t.res(r, t.id(1, 431))->>'result' = 'rejected' and t.res(r, t.id(1, 431))->>'reason' = 'denied',
                  'исполнитель чужого подрядчика не начинает работу через очередь');
  r := t.sync(mgr, jsonb_build_array(t.act(t.id(1, 432), 'start', w3, now())));
  perform t.check(t.res(r, t.id(1, 432))->>'result' = 'rejected', 'менеджер не начинает работу через очередь');
  r := t.sync(req, jsonb_build_array(t.act(t.id(1, 433), 'start', w3, now())));
  perform t.check(t.res(r, t.id(1, 433))->>'result' = 'rejected', 'заявитель не начинает работу через очередь');
  perform t.check((select status from public.work_orders where id = w3) = 'assigned', 'статус не изменился');
  r := t.sync(ex_other, jsonb_build_array(t.act(t.id(1, 401), 'start', w3, now())));
  perform t.check(t.res(r, t.id(1, 401))->>'reason' = 'denied', 'чужой id действия другого человека — отказ');
  perform t.check(t.sync(null, '[]') ? 'error', 'без входа — отказ');

  -- ===== Отменили, пока исполнитель был без сети =====
  perform t.login(mgr);
  update public.work_orders set status = 'cancelled' where id = w3;
  perform t.login(ex);
  begin
    insert into storage.objects(bucket_id, name, owner, owner_id) values ('work-photos', p3, ex, ex::text);
    perform t.check(true, 'фото очереди кладётся и в отменённую заявку своего подрядчика');
  exception when others then
    perform t.check(false, 'фото очереди кладётся и в отменённую заявку своего подрядчика: ' || sqlerrm);
  end;
  perform t.login(null);
  r := t.sync(ex, jsonb_build_array(
    t.act(t.id(1, 441), 'start',  w3, now() - interval '9 min', p_mono => 1000000 + 1260000),
    t.act(t.id(1, 442), 'photo',  w3, now() - interval '8 min',
          jsonb_build_object('path', p3, 'sha256', repeat('3', 64)), p_mono => 1000000 + 1320000),
    t.act(t.id(1, 443), 'submit', w3, now() - interval '7 min', p_mono => 1000000 + 1380000)));
  perform t.check(t.res(r, t.id(1, 441))->>'reason' = 'cancelled', 'начать отменённую — отказ «cancelled»');
  perform t.check(t.res(r, t.id(1, 442))->>'result' = 'saved_late'
                  and (select sync_note = 'after_cancel' and stage = 'after' and sha256_ok is null
                         from public.attachments where storage_path = p3),
                  'фото всё равно сохранено с пометкой «прислано после отмены» (отпечаток не сверен)');
  perform t.check(t.res(r, t.id(1, 443))->>'reason' = 'cancelled'
                  and (select status from public.work_orders where id = w3) = 'cancelled',
                  'сдать отменённую — отказ, статус остался «отменена»');
  -- чужой исполнитель не кладёт фото очереди
  perform t.login(ex_other);
  begin
    insert into storage.objects(bucket_id, name, owner, owner_id)
    values ('work-photos', format('%s/%s/off_%s.jpg', c1, w3, t.id(1, 409)), ex_other, ex_other::text);
    perform t.check(false, 'чужой исполнитель не кладёт фото очереди');
  exception when others then
    perform t.check(true, 'чужой исполнитель не кладёт фото очереди');
  end;
  perform t.login(null);

  -- ===== Обычная вставка не может притвориться офлайн-действием =====
  perform t.login(null);
  update public.work_orders set status = 'in_progress' where id = w4;
  perform t.login(ex);
  begin
    insert into public.attachments(work_order_id, kind, stage, storage_path, uploaded_by, source,
                                   offline, time_trust, sha256_ok, sync_note)
    values (w4, 'photo', 'after', format('%s/%s/x.jpg', c1, w4), ex, 'camera', true, 'gps', true, 'after_close');
  exception when others then
    perform t.check(false, 'вставка фото исполнителем: ' || sqlerrm);
  end;
  perform t.login(null);
  select * into a from public.attachments where storage_path = format('%s/%s/x.jpg', c1, w4);
  perform t.check(not a.offline and a.time_trust = 'online' and a.sha256_ok is null and a.sync_note is null,
                  'обычная вставка: пометки «без сети» и «время по GPS» ставит только база');

  -- ===== Решения менеджера по доказательствам =====
  perform t.check(t.decide(mgr, w1, 'approve', 'Звонил исполнителю') like 'act_decision_not_accepted%',
                  'решение — только по принятой заявке');
  perform t.login(mgr);
  update public.work_orders set status = 'done' where id = w1;
  perform t.login(null);
  perform t.check(t.decide(ex, w1, 'approve', 'сам себе') like 'act_decision_denied%', 'исполнитель не решает');
  perform t.check(t.decide(req, w1, 'approve', 'автор') like 'act_decision_denied%', 'заявитель не решает');
  perform t.check(t.decide(mgr, w1, 'approve', '') like 'act_decision_reason_required%',
                  '«Подтвердить к оплате» без комментария — нельзя');
  perform t.check(t.decide(mgr, w1, 'approve', 'Звонил исполнителю, визит подтверждён охраной') is null,
                  'менеджер подтверждает к оплате с комментарием');
  perform t.check(t.decide(adm, w1, 'reject', null) is null, 'администратор меняет решение («Не принимать» без комментария)');
  perform t.check((select count(*) from public.act_proof_decisions where work_order_id = w1) = 2,
                  'каждое изменение решения — отдельная строка журнала');
  perform t.login(ex);
  perform t.check((select count(*) from public.act_proof_decisions where work_order_id = w1) = 0,
                  'исполнитель не видит решений');
  perform t.login(null);
  insert into public.contractor_acts(company_id, contractor_id, year, seq, number, period_start, period_end, items)
  values (c1, t.id(1, 31), 2026, 77, 'АКТ-2026-077', current_date - 30, current_date,
          jsonb_build_array(jsonb_build_object('id', w1::text, 'paid', false)));
  perform t.check(t.decide(mgr, w1, 'approve', 'передумал') like 'act_decision_locked%',
                  'после формирования акта решение не меняется');
  begin
    perform t.login(mgr);
    insert into public.act_proof_decisions(company_id, work_order_id, decision, decided_by)
    values (c1, w2, 'approve', mgr);
    perform t.login(null);
    perform t.check(false, 'решение напрямую, мимо функции — нельзя');
  exception when others then
    perform t.login(null);
    perform t.check(true, 'решение напрямую, мимо функции — нельзя');
  end;
end $$;
