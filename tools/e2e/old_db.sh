#!/usr/bin/env bash
# База hh_old «как рабочая сейчас»: миграции 0001–0014 (без 0015 и 0016),
# заглушки Supabase и demo.sql. Для сценария 9 (приложение на старой базе).
set -euo pipefail
cd "$(dirname "$0")/../.."
DB=hh_old
PSQL=(sudo -u postgres PGOPTIONS="-c client_min_messages=warning" psql -X -q -v ON_ERROR_STOP=1)
"${PSQL[@]}" -d postgres -c "drop database if exists $DB" -c "create database $DB" >/dev/null
run() { "${PSQL[@]}" -d "$DB" "$@"; }
run -f tools/db_test/00_supabase_stub.sql >/dev/null
for f in supabase/migrations/[0-9][0-9][0-9][0-9]_*.sql; do
  n="$((10#$(basename "$f" | cut -c1-4)))"
  [ "$n" -ge 15 ] && break
  run -f "$f" >/dev/null 2>&1 || run -f "$f" >/dev/null
  [ "$n" -eq 3 ] && run -f tools/db_test/05_shim_after_0003.sql >/dev/null
done
run -c "insert into auth.users(id, email) values
  ('d0000000-0000-4000-8000-000000000001', 'manager@example.com'),
  ('d0000000-0000-4000-8000-000000000002', 'executor@example.com'),
  ('d0000000-0000-4000-8000-000000000003', 'requester@example.com') on conflict do nothing"
run -f supabase/seed/demo.sql >/dev/null
echo "hh_old: миграции 0001–0014 + demo.sql"
