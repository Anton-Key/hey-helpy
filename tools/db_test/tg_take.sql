-- Проверки 0025, раздел 2 (шаг 28): «Новая заявка» исполнителю в Telegram
-- и «Взять в работу» из бота. Функции — только service_role; адресаты —
-- исполнители назначенного подрядчика с привязкой (бригада — по зоне);
-- повтор не шлёт; «Взять» — те же правила шага 26.
-- Файл назван tg_take.sql, чтобы идти после telegram.sql (там t.as_bot).

select set_config('t.suite', 'tg_assign', false);

do $$
declare
  ok boolean;
  j jsonb;
  c1 uuid := t.id(1, 1);
  wo uuid := t.id(1, 196);          -- новая заявка КлиматСервис (031), объект 010
  wo_el uuid := t.id(1, 197);       -- Электрика (032), объект 010 (Москва)
  exec_chat bigint := 1000102;      -- исполнитель 102 (fixture make_company23)
begin
  insert into public.work_orders(id, company_id, object_id, location_id, layer_id, title, status,
                                 created_by, assigned_contractor_id, priority)
  values (wo, c1, t.id(1, 10), t.id(1, 21),
          (select id from public.layers where company_id = c1 and name = 'Климат'),
          'Капает вода с кондиционера', 'assigned', t.id(1, 100), t.id(1, 31), 'high');
  -- исполнители ЭлектроПро: 106 — в бригаде «Пекин», 107 — без бригады
  insert into public.telegram_links(profile_id, chat_id, language) values
    (t.id(1, 106), 1000106, 'ru'), (t.id(1, 107), 1000107, 'en')
  on conflict (profile_id) do nothing;
  insert into public.work_orders(id, company_id, object_id, location_id, layer_id, title, status,
                                 created_by, assigned_contractor_id)
  values (wo_el, c1, t.id(1, 10), t.id(1, 21),
          (select id from public.layers where company_id = c1 and name = 'Электрика'),
          'Искрит розетка', 'assigned', t.id(1, 100), t.id(1, 32));

  -- ===================== только service_role =====================
  perform t.login(t.id(1, 100));
  begin
    perform public.tg_notify_assign_claim(wo, null);
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'приложение не вызывает tg_notify_assign_claim');
  begin
    perform public.tg_take_order(exec_chat, wo);
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'приложение не вызывает tg_take_order');
  perform t.login(null);

  -- ===================== кому =====================
  j := t.as_bot(format('select public.tg_notify_assign_claim(%L, null)', wo));
  perform t.check(jsonb_array_length(j->'targets') = 1 and (j#>>'{targets,0,chat_id}')::bigint = exec_chat,
                  'исполнитель подрядчика с Telegram получает, ответ ' || coalesce(j::text, 'null'));
  perform t.check(j->>'title' = 'Капает вода с кондиционера' and j->>'priority' = 'high'
                  and j->>'object' = 'Офис 1' and j->>'place' = '305 Переговорная',
                  'в уведомлении — заявка, объект, помещение с номером, срочность');
  j := t.as_bot(format('select public.tg_notify_assign_claim(%L, null)', wo));
  perform t.check(j is null, 'повтор — второго сообщения нет');

  perform t.as_bot(format('select null::jsonb from (select public.tg_notify_assign_release(%L, %L, %L)) x',
                          wo, t.id(1, 31), t.id(1, 102)));
  perform t.as_bot(format('select null::jsonb from (select public.tg_notify_optout(%s, true)) x', exec_chat));
  j := t.as_bot(format('select public.tg_notify_assign_claim(%L, null)', wo));
  perform t.check(j is null, 'отписавшемуся (/stop) — ничего');
  perform t.as_bot(format('select null::jsonb from (select public.tg_notify_optout(%s, false)) x', exec_chat));
  j := t.as_bot(format('select public.tg_notify_assign_claim(%L, %L)', wo, t.id(1, 102)));
  perform t.check(j is null, 'сам себе назначил — себе не шлём');
  j := t.as_bot(format('select public.tg_notify_assign_claim(%L, null)', wo));
  perform t.check(j is not null, 'после release и /start — отправляется');

  -- Бригада: 106 (бригада «Пекин») не получает заявку в Москве, 107 — получает.
  j := t.as_bot(format('select public.tg_notify_assign_claim(%L, null)', wo_el));
  perform t.check(jsonb_array_length(j->'targets') = 1 and (j#>>'{targets,0,chat_id}')::bigint = 1000107
                  and j#>>'{targets,0,lang}' = 'en',
                  'бригада другого города не получает, исполнитель без бригады — да: ' || coalesce(j::text, 'null'));

  -- Заявка без подрядчика / в работе — ничего.
  insert into public.work_orders(id, company_id, object_id, title, status, created_by)
  values (t.id(1, 198), c1, t.id(1, 12), 'Без подрядчика', 'new', t.id(1, 100));
  j := t.as_bot(format('select public.tg_notify_assign_claim(%L, null)', t.id(1, 198)));
  perform t.check(j is null, 'без подрядчика — ничего: ' || coalesce(j::text, 'null'));

  -- ===================== «Взять в работу» =====================
  j := t.as_bot(format('select public.tg_take_order(%s, %L)', 1000106, wo));
  perform t.check(j->>'error' = 'not_executor', 'исполнитель другого подрядчика не берёт: ' || coalesce(j::text, ''));
  j := t.as_bot(format('select public.tg_take_order(%s, %L)', 999999, wo));
  perform t.check(j->>'error' = 'not_linked', 'неизвестный чат — not_linked');
  j := t.as_bot(format('select public.tg_take_order(%s, %L)', 2000102, wo));
  perform t.check(j->>'error' in ('not_found', 'not_linked'), 'исполнитель другой компании не видит заявку: ' || coalesce(j::text, ''));
  j := t.as_bot(format('select public.tg_take_order(%s, %L)', exec_chat, wo));
  perform t.check((j->>'ok')::boolean, 'исполнитель берёт в работу из Telegram: ' || coalesce(j::text, ''));
  perform t.check((select status from public.work_orders where id = wo) = 'in_progress', 'статус — в работе');
  j := t.as_bot(format('select public.tg_take_order(%s, %L)', exec_chat, wo));
  perform t.check(j->>'error' = 'already', 'второе нажатие — «уже в работе»');
  j := t.as_bot(format('select public.tg_notify_assign_claim(%L, null)', wo));
  perform t.check(j is null, 'в работе — «новая заявка» больше не шлётся');

  delete from public.work_orders where id in (wo, wo_el, t.id(1, 198));
  delete from public.telegram_links where profile_id in (t.id(1, 106), t.id(1, 107));
end $$;
