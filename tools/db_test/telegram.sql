-- Проверки 0018: Telegram-бот — функции tg_* только для service_role,
-- привязка аккаунта, ссылки объекта и компании, гость видит только свой
-- объект, группы, лимиты, заявки бота, защита канала telegram и reporter.

select set_config('t.suite', 'telegram', false);
grant usage on schema t to service_role;
grant execute on function t.id(int, int) to service_role;
grant execute on function t.check(boolean, text, text) to service_role;

-- Вызвать функцию бота «как Edge Function»: роль service_role, без auth.uid().
create or replace function t.as_bot(p_sql text) returns jsonb
language plpgsql as $$
declare
  res jsonb;
begin
  perform set_config('request.jwt.claim.sub', '', false);
  execute 'set role service_role';
  execute p_sql into res;
  execute 'reset role';
  return res;
exception when others then
  execute 'reset role';
  raise;
end $$;

do $$
declare
  n int;
  ok boolean;
  v text;
  code text;
  gcode text;
  j jsonb;
  tok_obj text;
  tok_co text;
  oid uuid;
  c1 uuid := t.id(1, 1);
  guest bigint := 555001;
  guest2 bigint := 555002;
  usr bigint := 555003;
  grp bigint := -555004;
  r record;
begin
  -- 1. Функции бота недоступны приложению и анониму.
  perform t.login(t.id(1, 100));
  begin
    perform public.tg_resolve_chat(1000102, false);
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'authenticated не вызывает tg_resolve_chat');
  begin
    perform public.tg_create_order(1000102, false, gen_random_uuid(), '{"title":"x"}');
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'authenticated не вызывает tg_create_order');
  begin
    perform count(*) from telegram.sessions;
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'authenticated не читает схему telegram');
  begin
    perform chat_id from public.telegram_links;
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'chat_id привязок из приложения не читается');
  select count(*) into n from public.telegram_links;
  perform t.check(n = 1, format('менеджер видит привязки своей компании (%s)', n));
  select count(*) into n from public.telegram_guests;
  perform t.check(n = 1, format('менеджер видит гостей своей компании (%s)', n));
  perform t.login(null);
  execute 'set role anon';
  begin
    perform public.tg_create_link_code();
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'аноним не создаёт код привязки');
  begin
    perform public.tg_take_update(1);
    ok := false;
  exception when others then ok := true;
  end;
  perform t.check(ok, 'аноним не вызывает функции бота');
  execute 'reset role';

  -- 2. Привязка аккаунта: код один раз, 15 минут.
  perform t.login(t.id(1, 103));
  code := public.tg_create_link_code();
  perform t.check(code ~ '^[A-HJ-NP-Z2-9]{8}$', format('код привязки — 8 знаков (%s)', code));
  perform t.login(null);
  select count(*) into n from telegram.codes where code_hash = telegram.code_hash(code);
  perform t.check(n = 1, 'в базе — хэш кода');
  select count(*) into n from telegram.codes where code_hash = code;
  perform t.check(n = 0, 'сам код в базе не хранится');
  j := t.as_bot(format('select public.tg_link_chat(%L, %s, %L, %L, %L)', lower(code), usr, 'req1', 'Заявитель', 'ru'));
  perform t.check((j->>'ok')::boolean, format('привязка по коду (регистр не важен): %s', j));
  j := t.as_bot(format('select public.tg_link_chat(%L, %s)', code, usr + 1));
  perform t.check(j->>'error' = 'bad_code', 'код второй раз не работает');
  j := t.as_bot(format('select public.tg_resolve_chat(%s)', usr));
  perform t.check(j->>'kind' = 'user' and (j->>'profile_id')::uuid = t.id(1, 103) and j->>'role' = 'requester',
    format('чат → пользователь компании 1: %s', j));
  update telegram.codes set used_at = null, expires_at = now() - interval '1 minute' where code_hash = telegram.code_hash(code);
  j := t.as_bot(format('select public.tg_link_chat(%L, %s)', code, usr + 2));
  perform t.check(j->>'error' = 'bad_code', 'просроченный код не работает');
  j := t.as_bot(format('select public.tg_resolve_chat(%s)', 999999));
  perform t.check(j->>'kind' = 'none', 'незнакомый чат — none');

  -- 3. Ссылки: объект — менеджер с правом, компания — администратор.
  perform t.login(t.id(1, 103));
  begin
    perform public.report_link_rotate(t.id(1, 10));
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'заявитель не создаёт ссылку объекта');
  perform t.login(t.id(1, 100));
  begin
    perform public.report_link_rotate(t.id(2, 10));
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'менеджер не создаёт ссылку на объект другой компании');
  begin
    perform public.report_link_rotate(null);
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'ссылку компании менеджер не создаёт (только администратор)');
  select token into tok_obj from public.report_link_rotate(t.id(1, 10));
  perform t.check(length(tok_obj) >= 16, format('ссылка объекта: токен %s знаков', length(tok_obj)));
  select count(*) into n from public.report_links where object_id = t.id(1, 10) and enabled;
  perform t.check(n = 1, 'включена одна ссылка на объект (старая отключена)');
  perform t.login(t.id(1, 101));
  select token into tok_co from public.report_link_rotate(null);
  perform t.check(tok_co is not null and tok_co <> tok_obj, 'администратор создаёт ссылку компании');
  perform t.login(null);
  -- гость старой ссылки fixture — отключён
  j := t.as_bot(format('select public.tg_resolve_chat(%s)', 1000007));
  perform t.check(j->>'kind' = 'guest_off', format('гость пересозданной ссылки — guest_off: %s', j));

  -- 4. Гость объекта: только свой объект.
  j := t.as_bot(format('select public.tg_guest_start(%L, %s, %L, %L)', 'нет-такого-токена-123', guest, 'Гость', 'ru'));
  perform t.check(j->>'error' = 'bad_link', 'неизвестный токен — bad_link');
  j := t.as_bot(format('select public.tg_guest_start(%L, %s, %L, %L)', tok_obj, guest, 'Гость', 'ru'));
  perform t.check((j->>'ok')::boolean and j#>>'{object,id}' = t.id(1, 10)::text and j->>'scope' = 'object',
    format('вход гостя по QR объекта: %s', j));
  j := t.as_bot(format('select public.tg_context(%s)', guest));
  perform t.check(jsonb_array_length(j->'objects') = 1 and j#>>'{objects,0,id}' = t.id(1, 10)::text,
    format('гость видит только свой объект (%s)', jsonb_array_length(j->'objects')));
  select count(*) into n from jsonb_array_elements(j->'places') p where p->>'object_id' <> t.id(1, 10)::text;
  perform t.check(n = 0 and jsonb_array_length(j->'places') >= 2, format('помещения — только своего объекта (%s)', jsonb_array_length(j->'places')));
  select count(*) into n from jsonb_array_elements(j->'assets') a where a->>'object_id' <> t.id(1, 10)::text;
  perform t.check(n = 0, 'оборудование — только своего объекта');
  perform t.check(position('c2000000' in j::text) = 0, 'в контексте гостя нет ничего компании 2');
  j := t.as_bot(format('select public.tg_context(%s, false, %L)', guest, t.id(1, 11)));
  perform t.check(j->>'error' = 'object_not_allowed', 'чужой объект в контексте гостя — отказ');
  j := t.as_bot(format('select public.tg_set_object(%s, %L)', guest, t.id(1, 11)));
  perform t.check(j->>'error' = 'not_allowed', 'гость QR не меняет объект на другой');

  oid := gen_random_uuid();
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', guest, oid,
    jsonb_build_object('title', 'Течёт кондиционер', 'object_id', t.id(1, 11))));
  perform t.check(j->>'error' = 'object_not_allowed', 'гость не создаёт заявку на другом объекте');
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', guest, oid,
    jsonb_build_object('title', 'Течёт кондиционер', 'object_id', t.id(2, 10))));
  perform t.check(j->>'error' = 'object_not_allowed', 'гость не создаёт заявку в другой компании');
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', guest, oid,
    jsonb_build_object('title', 'Течёт кондиционер', 'priority', 'high', 'location_id', t.id(1, 22),
      'layer_id', (select id from public.layers where company_id = c1 and name = 'Климат'),
      'photo_path', format('%s/%s/x.jpg', t.id(2, 1), oid),
      'reporter', jsonb_build_object('name', 'Мария', 'username', 'maria<script>'))));
  perform t.check((j->>'ok')::boolean and j->>'number' = upper(left(oid::text, 6)), format('заявка гостя создана: %s', j));
  select * into r from public.work_orders where id = oid;
  perform t.check(r.object_id = t.id(1, 10) and r.location_id is null and r.created_by is null
    and r.input_channel = 'telegram' and r.priority = 'high', 'объект — из ссылки, чужое помещение отброшено, автор пуст');
  perform t.check(r.reporter = '{"name":"Мария","username":"mariascript","guest":true}'::jsonb,
    format('reporter: %s', r.reporter));
  perform t.check(r.assigned_contractor_id = t.id(1, 31) and r.status = 'assigned',
    format('подрядчик — по правилу слоя (%s, %s)', r.status, r.assigned_contractor_id));
  select count(*) into n from public.attachments where work_order_id = oid;
  perform t.check(n = 0, 'фото из папки другой компании не прикрепляется');

  -- фото «до»: только уже загруженный файл в папке этой заявки
  oid := gen_random_uuid();
  insert into storage.objects(bucket_id, name) values ('work-photos', format('%s/%s/tg_1.jpg', c1, oid));
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', guest, oid,
    jsonb_build_object('title', 'Протечка', 'photo_path', format('%s/%s/tg_1.jpg', c1, oid))));
  select count(*) into n from public.attachments where work_order_id = oid and stage = 'before' and uploaded_by is null;
  perform t.check((j->>'photo')::boolean and n = 1, 'фото гостя прикреплено как фото «до»');

  -- лимит: 5 заявок в час с чата
  for i in 3 .. 5 loop
    j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', guest, gen_random_uuid(),
      jsonb_build_object('title', 'Заявка ' || i)));
  end loop;
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', guest, gen_random_uuid(),
    jsonb_build_object('title', 'Шестая')));
  perform t.check(j->>'error' = 'rate_limited', format('шестая заявка гостя за час — отказ: %s', j));
  -- лимит ссылки: 30 в сутки
  update telegram.orders set chat_id = 1 where chat_id = guest;
  with w as (
    insert into public.work_orders(company_id, title) select c1, 'Лимит ' || g from generate_series(1, 25) g returning id)
  insert into telegram.orders(work_order_id, chat_id, link_id)
  select w.id, 2, (select id from public.report_links where token = tok_obj) from w;
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', guest, gen_random_uuid(),
    jsonb_build_object('title', 'Тридцать первая')));
  perform t.check(j->>'error' like 'rate_limited%', format('больше 30 заявок в сутки по ссылке — отказ: %s', j));
  delete from public.work_orders where title like 'Лимит %';
  delete from telegram.orders where chat_id = 1;

  -- 5. Гость компании: объекты своей компании, выбор, геопозиция.
  j := t.as_bot(format('select public.tg_guest_start(%L, %s, %L, %L)', tok_co, guest2, 'Охранник', 'en'));
  perform t.check((j->>'ok')::boolean and j->>'scope' = 'company' and j->'object' = 'null'::jsonb,
    format('вход по ссылке компании: %s', j));
  j := t.as_bot(format('select public.tg_context(%s)', guest2));
  perform t.check(jsonb_array_length(j->'objects') = 3 and position('c2000000' in j::text) = 0,
    format('гость компании видит 3 объекта своей компании (%s)', jsonb_array_length(j->'objects')));
  j := t.as_bot(format('select public.tg_set_object(%s, %L)', guest2, t.id(2, 11)));
  perform t.check(j->>'error' = 'not_allowed', 'объект другой компании не выбрать');
  j := t.as_bot(format('select public.tg_nearest_object(%s, %s, %s)', guest2, 55.7502, 37.6102));
  perform t.check(j#>>'{object,id}' = t.id(1, 10)::text, format('ближайший объект по геопозиции: %s', j));
  j := t.as_bot(format('select public.tg_nearest_object(%s, %s, %s)', guest2, 55.80, 37.61));
  perform t.check(j->>'error' = 'not_found', 'дальше 300 м — не найден');
  j := t.as_bot(format('select public.tg_set_object(%s, %L)', guest2, t.id(1, 11)));
  perform t.check(j#>>'{object,id}' = t.id(1, 11)::text, 'гость компании выбирает объект');
  j := t.as_bot(format('select public.tg_resolve_chat(%s)', guest2));
  perform t.check(j#>>'{object,id}' = t.id(1, 11)::text, 'объект запомнился');
  oid := gen_random_uuid();
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', guest2, oid,
    jsonb_build_object('title', 'Не горит свет', 'location_id', t.id(1, 22))));
  select * into r from public.work_orders where id = oid;
  perform t.check(r.object_id = t.id(1, 11) and r.location_id = t.id(1, 22), 'заявка на выбранном объекте с помещением');
  j := t.as_bot(format('select to_jsonb(public.tg_reset(%s))', guest2));
  j := t.as_bot(format('select public.tg_resolve_chat(%s)', guest2));
  perform t.check(j->>'kind' = 'none', '/reset отвязывает гостя');

  -- 6. Пользователь: как в приложении.
  oid := gen_random_uuid();
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', usr, oid,
    jsonb_build_object('title', 'Не работает ИБП', 'object_id', t.id(1, 11), 'location_id', t.id(1, 22),
      'reporter', jsonb_build_object('name', 'Заявитель'))));
  select * into r from public.work_orders where id = oid;
  perform t.check(r.created_by = t.id(1, 103) and (r.reporter->>'guest')::boolean = false and r.status = 'new',
    format('заявка пользователя: автор — он, reporter.guest = false (%s)', j));
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', usr, gen_random_uuid(),
    jsonb_build_object('title', 'Чужой объект', 'object_id', t.id(2, 10))));
  perform t.check(j->>'error' = 'object_not_allowed', 'пользователь не создаёт заявку в другой компании');
  j := t.as_bot(format('select public.tg_context(%s)', usr));
  perform t.check(position('c2000000' in j::text) = 0 and jsonb_array_length(j->'objects') = 3,
    'контекст пользователя — только своя компания');
  -- менеджер с зоной (104: Климат + Сантехника, Офис 1) — только свой объект
  insert into public.telegram_links(profile_id, chat_id) values (t.id(1, 104), 555104);
  j := t.as_bot('select public.tg_context(555104)');
  perform t.check(jsonb_array_length(j->'objects') = 1, format('менеджер с зоной видит 1 объект (%s)', jsonb_array_length(j->'objects')));
  j := t.as_bot(format('select public.tg_create_order(555104, false, %L, %L)', gen_random_uuid(),
    jsonb_build_object('title', 'Вне зоны', 'object_id', t.id(1, 11))));
  perform t.check(j->>'error' = 'object_not_allowed', 'менеджер с зоной — не вне зоны');
  perform t.check(coalesce(current_setting('request.jwt.claims', true), '') = ''
    and coalesce(current_setting('hh.telegram', true), '') = '', 'после вызова личность и флаг сброшены');

  -- 7. Приложение не ставит канал telegram и reporter.
  perform t.login(t.id(1, 103));
  begin
    insert into public.work_orders(company_id, title, created_by, input_channel)
    values (c1, 'Подделка', t.id(1, 103), 'telegram');
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'приложение не создаёт заявку с каналом telegram');
  begin
    update public.work_orders set reporter = '{"guest":true}' where id = oid;
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'автор не меняет reporter');
  perform t.login(null);

  -- 8. Группы объекта.
  perform t.login(t.id(1, 103));
  begin
    perform public.tg_create_group_code(t.id(1, 10));
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'заявитель не создаёт код группы');
  perform t.login(t.id(1, 100));
  gcode := public.tg_create_group_code(t.id(1, 10));
  perform t.login(null);
  j := t.as_bot(format('select public.tg_connect_group(%L, %s, %L)', code, grp, 'Клининг'));
  perform t.check(j->>'error' = 'bad_code', 'код аккаунта не подключает группу');
  j := t.as_bot(format('select public.tg_connect_group(%L, %s, %L)', gcode, grp, 'Клининг'));
  perform t.check((j->>'ok')::boolean, format('группа подключена: %s', j));
  j := t.as_bot(format('select public.tg_resolve_chat(%s, true)', grp));
  perform t.check(j->>'kind' = 'group' and j#>>'{object,id}' = t.id(1, 10)::text, 'группа → объект');
  j := t.as_bot(format('select public.tg_resolve_chat(%s, false)', grp));
  perform t.check(j->>'kind' = 'none', 'чат группы не считается личным');
  oid := gen_random_uuid();
  j := t.as_bot(format('select public.tg_create_order(%s, true, %L, %L)', grp, oid,
    jsonb_build_object('title', 'Грязно в холле', 'reporter', jsonb_build_object('name', 'Ольга'))));
  select * into r from public.work_orders where id = oid;
  perform t.check(r.object_id = t.id(1, 10) and r.reporter->>'group' = 'Клининг' and r.created_by is null,
    format('заявка из группы: %s', r.reporter));
  j := t.as_bot(format('select public.tg_create_order(%s, true, %L, %L)', grp, gen_random_uuid(),
    jsonb_build_object('title', 'x', 'object_id', t.id(1, 11))));
  perform t.check(j->>'error' = 'object_not_allowed', 'группа — только свой объект');
  perform t.login(t.id(1, 103));
  delete from public.telegram_groups where object_id = t.id(1, 10);
  get diagnostics n = row_count;
  perform t.check(n = 0, 'заявитель не отключает группу');
  perform t.login(t.id(1, 100));
  delete from public.telegram_groups where title = 'Клининг';
  get diagnostics n = row_count;
  perform t.check(n = 1, 'менеджер отключает группу');
  perform t.login(null);

  -- 9. Повторы, черновик, отключение ссылки.
  j := t.as_bot('select to_jsonb(public.tg_take_update(77))');
  perform t.check(j = 'true'::jsonb, 'новое обновление — true');
  j := t.as_bot('select to_jsonb(public.tg_take_update(77))');
  perform t.check(j = 'false'::jsonb, 'повтор — false');
  perform t.as_bot(format('select to_jsonb(public.tg_session_put(%s, %L))', guest, '{"step":"confirm"}'));
  j := t.as_bot(format('select public.tg_session_get(%s)', guest));
  perform t.check(j->>'step' = 'confirm', 'черновик сохраняется');
  update telegram.sessions set updated_at = now() - interval '31 minutes' where chat_id = guest;
  j := t.as_bot(format('select public.tg_session_get(%s)', guest));
  perform t.check(j is null, 'черновик старше 30 минут не читается');
  perform t.login(t.id(1, 100));
  perform public.report_link_disable(t.id(1, 10));
  perform t.login(null);
  j := t.as_bot(format('select public.tg_create_order(%s, false, %L, %L)', guest, gen_random_uuid(),
    jsonb_build_object('title', 'После отключения')));
  perform t.check(j->>'error' = 'link_disabled', 'отключили ссылку — гость не создаёт заявок');
  perform t.login(t.id(1, 103));
  delete from public.telegram_links where profile_id = t.id(1, 103);
  get diagnostics n = row_count;
  perform t.check(n = 1, 'пользователь отключает свой Telegram');
  perform t.login(null);
end $$;
