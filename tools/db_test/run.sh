#!/usr/bin/env bash
# Локальная проверка миграций и прав на настоящем PostgreSQL.
# 1) пустая база hh_test, заглушки Supabase (00_supabase_stub.sql);
# 2) миграции supabase/migrations по порядку номеров (0015+ — одной
#    транзакцией, как workflow «Apply migration»), затем каждая новая
#    миграция ещё раз — проверка повторного запуска;
# 3) тестовые данные двух компаний (10_fixture.sql);
# 4) тесты tools/db_test/*.sql (кроме 0*_ и 1*_), итоги — таблица t.results.
# Нужен локальный PostgreSQL (sudo apt-get install -y postgresql); скрипт сам
# запускает кластер, если он остановлен. Рабочую базу не трогает.
# Запуск: bash tools/db_test/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

DB="${HH_TEST_DB:-hh_test}"
PSQL=(sudo -u postgres PGOPTIONS="-c client_min_messages=warning" psql -X -q -v ON_ERROR_STOP=1)

if command -v pg_lsclusters >/dev/null; then
  read -r ver cluster _ status _ < <(pg_lsclusters --no-header | head -1)
  if [ "${status:-}" != "online" ]; then
    sudo pg_ctlcluster "$ver" "$cluster" start
  fi
fi

"${PSQL[@]}" -d postgres -c "drop database if exists $DB" -c "create database $DB"
run() { "${PSQL[@]}" -d "$DB" "$@"; }

echo "== Заглушки Supabase"
run -f tools/db_test/00_supabase_stub.sql

echo "== Миграции"
for f in supabase/migrations/[0-9][0-9][0-9][0-9]_*.sql; do
  n="$(basename "$f" | cut -c1-4)"
  if [ "$n" -ge 15 ] 2>/dev/null || [ "$((10#$n))" -ge 15 ]; then
    run --single-transaction -f "$f" >/dev/null
  else
    run -f "$f" >/dev/null 2>&1 || run -f "$f"
  fi
  echo "   $(basename "$f")"
  if [ "$((10#$n))" -eq 3 ]; then
    run -f tools/db_test/05_shim_after_0003.sql
  fi
done

echo "== Повторный запуск новых миграций (0015+)"
for f in supabase/migrations/[0-9][0-9][0-9][0-9]_*.sql; do
  n="$(basename "$f" | cut -c1-4)"
  if [ "$((10#$n))" -ge 15 ]; then
    run --single-transaction -f "$f" >/dev/null
    echo "   $(basename "$f") — ещё раз без ошибок"
  fi
done

echo "== Тестовые данные двух компаний"
run -f tools/db_test/10_fixture.sql >/dev/null

for f in tools/db_test/[a-z]*.sql; do
  echo "== Тест $(basename "$f")"
  run -f "$f"
done

echo "== Итоги"
run -c "select suite, count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed
          from t.results group by suite order by suite"
failed="$(sudo -u postgres psql -X -At -d "$DB" -c "select count(*) from t.results where not ok")"
if [ "$failed" != "0" ]; then
  echo "ОШИБКИ:"
  run -c "select suite, msg from t.results where not ok order by n"
  exit 1
fi
echo "Все проверки пройдены."
