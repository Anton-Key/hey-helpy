-- 0012_ci_smoke_test.sql
-- Назначение: ПРОВЕРКА workflow «Apply migration» (GitHub Actions), а не настоящая
-- миграция. Ничего не меняет в базе — только читает: под каким пользователем
-- подключился workflow, время сервера и число компаний.
-- Если запуск зелёный, значит секрет SUPABASE_DB_URL, окружение production-db
-- и одобрение настроены верно.
-- Без begin/commit: workflow сам выполняет файл одной транзакцией (--single-transaction).
-- Безопасно запускать повторно. Следующая настоящая миграция — 0013.

select current_user, now(), (select count(*) from public.companies) as companies;
