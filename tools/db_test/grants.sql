-- Шаг 31: права на таблицы для Data API — правило Supabase с 30.10.2026.
-- Новые таблицы public не получают права автоматически (run.sh после 0026
-- выполняет 06_supabase_after_0026.sql), поэтому каждая миграция 0027+ пишет
-- grant сама. Тест ловит:
--   * таблицу, которую приложение не может даже читать (забыли grant select
--     to authenticated) — кроме списка closed ниже;
--   * таблицу без прав service_role (Edge Functions, бот);
--   * любую таблицу или последовательность, открытую anon (приложение работает
--     только после входа) — кроме списка anon_ok ниже (пока пустой);
--   * таблицу без RLS;
--   * что сама заглушка работает: новая таблица без grant закрыта.

select set_config('t.suite', 'grants', false);

do $$
declare
  -- Таблицы, которые приложение намеренно не читает (только функции бота и т. п.).
  -- Сейчас таких нет: telegram_* читаются по столбцам (без chat_id, 0018).
  closed text[] := array[]::text[];
  -- Таблицы, открытые без входа. Добавлять сюда — только осознанно, с ⚠️ в отчёте.
  anon_ok text[] := array[]::text[];
  -- Последовательности до 0027 (права anon — по старым правилам по умолчанию;
  -- без прав на саму таблицу безвредны, 0001–0026 не меняем — хук). Закрыть их —
  -- в заготовке docs/security/grants-0001-0026.md.
  legacy_seq text[] := array['offline_clock_anchors_id_seq'];
  r record;
  ok boolean;
  n int := 0;
begin
  for r in
    select c.oid, c.relname, c.relrowsecurity
      from pg_class c join pg_namespace s on s.oid = c.relnamespace
     where s.nspname = 'public' and c.relkind in ('r', 'p')
     order by c.relname
  loop
    n := n + 1;
    perform t.check(r.relrowsecurity, 'RLS включён: ' || r.relname);
    if not r.relname = any(closed) then
      perform t.check(has_any_column_privilege('authenticated', r.oid, 'select'),
        'authenticated читает (grant select … to authenticated): ' || r.relname);
    end if;
    perform t.check(has_table_privilege('service_role', r.oid, 'select'),
      'service_role читает (grant … to service_role): ' || r.relname);
    if not r.relname = any(anon_ok) then
      perform t.check(
        not has_any_column_privilege('anon', r.oid, 'select, insert, update, references')
          and not has_table_privilege('anon', r.oid, 'delete, truncate, trigger'),
        'anon без прав: ' || r.relname);
    end if;
  end loop;
  perform t.check(n >= 40, 'таблиц public проверено: ' || n);

  for r in
    select c.oid, c.relname
      from pg_class c join pg_namespace s on s.oid = c.relnamespace
     where s.nspname = 'public' and c.relkind = 'S' and not c.relname = any(legacy_seq)
  loop
    perform t.check(not has_sequence_privilege('anon', r.oid, 'usage, select, update'),
      'anon без прав на последовательность: ' || r.relname);
  end loop;

  -- Заглушка «как Supabase после 30.10.2026»: таблица без grant закрыта.
  begin
    create table public.t_grants_probe (id int primary key);
    ok := not has_table_privilege('authenticated', 'public.t_grants_probe', 'select')
      and not has_table_privilege('anon', 'public.t_grants_probe', 'select')
      and not has_table_privilege('service_role', 'public.t_grants_probe', 'select');
    raise exception 'rollback probe' using errcode = 'P0001', detail = ok::text;
  exception when sqlstate 'P0001' then
    get stacked diagnostics ok = pg_exception_detail;
  end;
  perform t.check(ok, 'новая таблица без grant не видна authenticated / anon / service_role');
end $$;
