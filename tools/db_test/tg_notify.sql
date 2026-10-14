-- Файл назван tg_notify.sql, чтобы идти после telegram.sql (там t.as_bot).
-- Проверки 0022: уведомления автору в Telegram — функции только для
-- service_role; отметка «уже отправлено» по (заявка, статус); только текущий
-- статус заявки; отписка чата.

select set_config('t.suite', 'telegram_notify', false);
grant execute on function t.as_bot(text) to service_role;

do $$
declare
  ok boolean;
  j jsonb;
  wo uuid := t.id(1, 101);   -- в работе, компания 1
  guest bigint := 1000007;   -- гость ссылки объекта компании 1 (fixture)
begin
  insert into telegram.orders(work_order_id, chat_id, link_id) values (wo, guest, t.id(1, 451))
  on conflict (work_order_id) do update set chat_id = excluded.chat_id;

  perform t.login(t.id(1, 100));
  begin
    perform public.tg_notify_claim(wo, 'in_progress');
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'приложение не вызывает tg_notify_claim');
  begin
    perform public.tg_notify_optout(guest, true);
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  perform t.check(ok, 'приложение не вызывает tg_notify_optout');
  perform t.login(null);

  j := t.as_bot(format('select public.tg_notify_claim(%L, %L)', wo, 'in_progress'));
  perform t.check(j->>'kind' = 'guest' and (j->>'chat_id')::bigint = guest,
                  'первый вызов: гость и его чат, получено ' || coalesce(j::text, 'null'));
  j := t.as_bot(format('select public.tg_notify_claim(%L, %L)', wo, 'in_progress'));
  perform t.check(j is null, 'повтор на тот же статус — ничего');
  j := t.as_bot(format('select public.tg_notify_claim(%L, %L)', wo, 'done'));
  perform t.check(j is null, 'статус не совпадает с базой — ничего');
  j := t.as_bot(format('select public.tg_notify_claim(%L, %L)', wo, 'on_review'));
  perform t.check(j is null, 'статус без уведомления — ничего');

  perform t.as_bot(format('select null::jsonb from (select public.tg_notify_release(%L, %L)) x', wo, 'in_progress'));
  j := t.as_bot(format('select public.tg_notify_claim(%L, %L)', wo, 'in_progress'));
  perform t.check(j is not null, 'после release можно отправить снова');

  perform t.as_bot(format('select null::jsonb from (select public.tg_notify_release(%L, %L)) x', wo, 'in_progress'));
  perform t.as_bot(format('select null::jsonb from (select public.tg_notify_optout(%s, true)) x', guest));
  j := t.as_bot(format('select public.tg_notify_claim(%L, %L)', wo, 'in_progress'));
  perform t.check(j is null, 'отписавшемуся — ничего');
  perform t.as_bot(format('select null::jsonb from (select public.tg_notify_optout(%s, false)) x', guest));
  j := t.as_bot(format('select public.tg_notify_claim(%L, %L)', wo, 'in_progress'));
  perform t.check(j is not null, 'после /start — снова присылать');

  -- Заявка не из Telegram — ничего.
  j := t.as_bot(format('select public.tg_notify_claim(%L, %L)', t.id(1, 103), 'assigned'));
  perform t.check(j is null, 'заявка не из Telegram — ничего');
  delete from telegram.orders where work_order_id = wo;
  delete from telegram.notified where work_order_id = wo;
end $$;
