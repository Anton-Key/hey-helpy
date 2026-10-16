-- Файл назван tg_leads.sql, чтобы идти после telegram.sql (там t.as_bot).
-- Проверки 0026: заявки на демо с сайта — таблица sales.site_leads не видна
-- приложению ни под какой ролью, tg_lead_save — только service_role,
-- лимит 3 лида в сутки с чата, проверка текста.

select set_config('t.suite', 'site_leads', false);
grant execute on function t.as_bot(text) to service_role;

do $$
declare
  ok boolean;
  j jsonb;
  n int;
  u uuid;
  chat bigint := 7000001;
begin
  -- Приложение: ни чтения таблицы, ни вызова функции — под любой ролью компании.
  foreach u in array array[t.id(1, 100), t.id(1, 101), t.id(1, 102), t.id(1, 103)] loop
    perform t.login(u);
    begin
      perform count(*) from sales.site_leads;
      ok := false;
    exception when others then ok := sqlstate = '42501';
    end;
    perform t.check(ok, 'приложение не читает sales.site_leads: ' || u);
    begin
      perform public.tg_lead_save(chat, 'x', 'x', 'ru', 'спам');
      ok := false;
    exception when others then ok := sqlstate = '42501';
    end;
    perform t.check(ok, 'приложение не вызывает tg_lead_save: ' || u);
  end loop;
  perform t.login(null);

  -- Аноним — тоже нет.
  execute 'set role anon';
  begin
    perform count(*) from sales.site_leads;
    ok := false;
  exception when others then ok := sqlstate = '42501';
  end;
  execute 'reset role';
  perform t.check(ok, 'аноним не читает sales.site_leads');

  -- Бот: проверка текста.
  j := t.as_bot(format('select public.tg_lead_save(%s, %L, %L, %L, %L)', chat, 'ivan', 'Иван', 'ru', '   '));
  perform t.check(j->>'error' = 'bad_text', 'пустой текст — bad_text, получено ' || j::text);
  j := t.as_bot(format('select public.tg_lead_save(%s, %L, %L, %L, %L)', chat, 'ivan', 'Иван', 'ru', repeat('я', 2001)));
  perform t.check(j->>'error' = 'bad_text', 'текст > 2000 — bad_text');

  -- Три лида в сутки — да, четвёртый — нет.
  for i in 1..3 loop
    j := t.as_bot(format('select public.tg_lead_save(%s, %L, %L, %L, %L)', chat, 'ivan', 'Иван', 'xx',
                         'Компания, 3 объекта в Москве, хотим посмотреть акты'));
    perform t.check((j->>'ok')::boolean, format('лид %s сохранён', i));
  end loop;
  j := t.as_bot(format('select public.tg_lead_save(%s, %L, %L, %L, %L)', chat, 'ivan', 'Иван', 'ru', 'ещё'));
  perform t.check(j->>'error' = 'rate_limited', '4-й лид за сутки — rate_limited');

  -- Другой чат — свой лимит; язык не ru/en → ru; длинный ник обрезан.
  j := t.as_bot(format('select public.tg_lead_save(%s, %L, %L, %L, %L)', chat + 1, repeat('u', 80), null, 'en', 'Hello'));
  perform t.check((j->>'ok')::boolean, 'другой чат — сохраняется');

  select count(*) into n from sales.site_leads where chat_id = chat and language = 'ru' and status = 'new';
  perform t.check(n = 3, 'три лида чата: язык ru, статус new, получено ' || n);
  select count(*) into n from sales.site_leads where chat_id = chat + 1 and language = 'en' and char_length(tg_username) = 64;
  perform t.check(n = 1, 'язык en и ник ≤ 64');

  -- Статус меняет владелец (SQL Editor) — проверка ограничения.
  begin
    update sales.site_leads set status = 'won' where chat_id = chat;
    ok := false;
  exception when check_violation then ok := true;
  end;
  perform t.check(ok, 'статус только new / contacted / closed');

  delete from sales.site_leads where chat_id in (chat, chat + 1);
end $$;
