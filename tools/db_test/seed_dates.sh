#!/usr/bin/env bash
# Шаг 33-fix: демо-история (demo_history.sql) в разные дни — «подменённое
# сегодня». Запускать после run.sh (база hh_test с миграциями и demo.sql).
#
# Как подменяется дата: схема hh_clock с функцией now(), которая возвращает
# настройку hh.fake_now; search_path = hh_clock, pg_catalog, public — в
# скрипте сида now() без схемы берётся отсюда (триггеры в блоке 2 выключены,
# функции миграций получают даты аргументами).
#
# Сценарии:
#  1) один и тот же день дважды подряд — 1-е, 15-е и последнее число месяца,
#     переходы месяц → месяц, квартал → квартал, полугодие, год;
#  2) «старый сид из main 30.10.2026» (git a0927fd, русские демо-данные)
#     → новый сид 03.11.2026 — как упавший Refresh demo #16;
#  3) после ppr_generate() (менеджер вошёл в новом месяце) — новый сид.
# Запуск: bash tools/db_test/seed_dates.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
DB="${HH_TEST_DB:-hh_test}"
OLD_REV="${OLD_SEED_REV:-a0927fd}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
chmod 755 "$TMP"

psql_() { sudo -u postgres psql -X -q -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

psql_ -c "create schema if not exists hh_clock;
create or replace function hh_clock.now() returns timestamptz
  language sql stable as \$\$ select current_setting('hh.fake_now')::timestamptz \$\$;
grant usage on schema hh_clock to public;"

git show "$OLD_REV:supabase/seed/demo_history.sql" > "$TMP/old_history.sql"
git show "$OLD_REV:supabase/seed/demo.sql" > "$TMP/old_demo.sql"
cp supabase/seed/demo_history.sql "$TMP/new_history.sql"
cp supabase/seed/demo.sql "$TMP/new_demo.sql"
chmod 644 "$TMP"/*.sql

# seed <файл> <дата-время UTC>
seed() {
  sudo -u postgres env PGOPTIONS="-c client_min_messages=warning -c search_path=hh_clock,pg_catalog,public -c hh.fake_now=$2" \
    psql -X -q -v ON_ERROR_STOP=1 -d "$DB" --single-transaction -f "$1" >/dev/null
}

# Проверка после сида: задачи ППР без пересечений и текущий период «от сегодня».
check() {
  local day="$1" label="$2"
  local bad
  bad="$(sudo -u postgres psql -X -At -d "$DB" -c "
    select count(*) from (
      select 1 from work_orders w
       where w.company_id = 'de300000-0000-4000-8000-000000000001'
         and w.id in ('de300000-0000-4000-8000-000000000259', 'de300000-0000-4000-8000-000000000279',
                      'de300000-0000-4000-8000-000000000234', 'de300000-0000-4000-8000-000000000241')
         and not ('$day'::date between w.period_start and w.period_end)
      union all
      select 1 from work_orders w
       where w.id = 'de300000-0000-4000-8000-000000000258'
         and w.period_start <> (date_trunc('month', '$day'::date) - interval '1 month')::date
    ) x")"
  local tasks
  tasks="$(sudo -u postgres psql -X -At -d "$DB" -c "
    select count(*) from work_orders where company_id = 'de300000-0000-4000-8000-000000000001' and plan_id is not null")"
  if [ "$bad" != "0" ]; then
    echo "   ✗ $label: периоды задач не совпадают с датой $day ($bad)"; exit 1
  fi
  echo "   ✓ $label: задач ППР $tasks"
}

run_day() {  # <файл> <день> <подпись>
  if ! seed "$1" "${2}T09:00:00Z" 2>"$TMP/err"; then
    echo "   ✗ $3: ОШИБКА"; cat "$TMP/err"; exit 1
  fi
  check "$2" "$3"
}

echo "== 1) Новый сид: дни месяца, переходы периодов (каждый день — дважды подряд)"
for d in 2026-10-01 2026-10-15 2026-10-31 2026-11-01 2026-11-03 2026-11-15 2026-11-30 \
         2026-12-01 2026-12-31 2027-01-01 2027-01-15 2027-01-31 2027-02-28 2027-03-01 \
         2027-03-31 2027-04-01 2027-06-30 2027-07-01 2027-07-15 2027-12-31 2028-01-01 \
         2028-02-29 2028-03-31 2028-04-30; do
  run_day "$TMP/new_history.sql" "$d" "$d (1)"
  run_day "$TMP/new_history.sql" "$d" "$d (2)"
done

echo "== 1b) Новый сид: назад во времени (31.12.2027 → 01.10.2026)"
run_day "$TMP/new_history.sql" 2027-12-31 "2027-12-31"
run_day "$TMP/new_history.sql" 2026-10-01 "2026-10-01"

echo "== 2) Старый сид из main ($OLD_REV) 30.10.2026 → новый сид 03.11.2026"
psql_ -f "$TMP/old_demo.sql" >/dev/null
if ! seed "$TMP/old_history.sql" "2026-10-30T09:00:00Z" 2>"$TMP/err"; then
  echo "   ✗ старый сид 30.10: ОШИБКА"; cat "$TMP/err"; exit 1
fi
echo "   ✓ старый сид 30.10.2026"
psql_ -f "$TMP/new_demo.sql" >/dev/null
run_day "$TMP/new_history.sql" 2026-11-03 "новый сид 03.11.2026"
run_day "$TMP/new_history.sql" 2026-11-03 "новый сид 03.11.2026 ещё раз"

echo "== 3) Менеджер вошёл в новом месяце (ppr_generate) → новый сид"
run_day "$TMP/new_history.sql" 2026-11-30 "сид 30.11.2026"
# Задачи нового месяца со случайными id, как от приложения (ppr_generate
# считает «сейчас» сам, поэтому вставляем их так же, как он: on conflict do nothing).
psql_ -c "set session_replication_role = replica;
insert into work_orders (id, company_id, object_id, title, status, priority, input_channel,
                         plan_id, period_start, period_end, layer_id)
select gen_random_uuid(), p.company_id, p.object_id, p.title || ' (ppr_generate)', 'new', p.priority, 'ppr',
       p.id, b.period_start, b.period_end, p.layer_id
  from maintenance_plans p
  cross join lateral period_bounds(p.period_kind, p.period_days, p.starts_on, date '2026-12-02') b
 where p.company_id = 'de300000-0000-4000-8000-000000000001'
on conflict (plan_id, period_start) where plan_id is not null do nothing;" >/dev/null
run_day "$TMP/new_history.sql" 2026-12-02 "сид 02.12.2026 после ppr_generate"

echo "== Возврат: демо-история на настоящую дату, схема hh_clock удалена"
sudo -u postgres env PGOPTIONS="-c client_min_messages=warning" \
  psql -X -q -v ON_ERROR_STOP=1 -d "$DB" --single-transaction -f "$TMP/new_history.sql" >/dev/null 2>"$TMP/err" \
  || { echo "   ✗ пересев на настоящую дату: ОШИБКА"; cat "$TMP/err"; exit 1; }
psql_ -c "drop schema hh_clock cascade" >/dev/null 2>&1
echo "   ✓ $(date -u +%F)"
echo "Все прогоны сида по датам прошли."
