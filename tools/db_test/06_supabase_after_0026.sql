-- Правило Supabase с 30.10.2026 (шаг 31): новые таблицы в схеме public больше
-- НЕ получают права для Data API (anon, authenticated, service_role)
-- автоматически — без явного grant supabase-js / PostgREST вернёт
-- «permission denied». Таблицы 0001–0026 уже получили права по старым
-- правилам (заглушка 00_supabase_stub.sql) и не меняются.
-- run.sh выполняет этот файл сразу после 0026: каждая миграция 0027+ должна
-- писать grant сама, иначе тест grants.sql упадёт.
alter default privileges for role postgres in schema public revoke all on tables    from anon, authenticated, service_role;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated, service_role;
