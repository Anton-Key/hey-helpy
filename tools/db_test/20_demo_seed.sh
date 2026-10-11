#!/usr/bin/env bash
# Демо-данные на локальной базе после run.sh: три пользователя-заглушки
# (example.com, как в файлах), supabase/seed/demo.sql, затем
# demo_history.sql ДВАЖДЫ (повторный запуск безопасен) и итоговые числа.
# Запуск: bash tools/db_test/20_demo_seed.sh (после run.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
DB="${HH_TEST_DB:-hh_test}"
run() { sudo -u postgres PGOPTIONS="-c client_min_messages=warning" psql -X -q -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

run -c "insert into auth.users(id, email) values
  ('d0000000-0000-4000-8000-000000000001', 'manager@example.com'),
  ('d0000000-0000-4000-8000-000000000002', 'executor@example.com'),
  ('d0000000-0000-4000-8000-000000000003', 'requester@example.com')
  on conflict do nothing"
run -f supabase/seed/demo.sql
run --single-transaction -f supabase/seed/demo_history.sql
run --single-transaction -f supabase/seed/demo_history.sql
run -c "
select (select count(*) from work_orders where company_id = 'de300000-0000-4000-8000-000000000001') as orders,
       (select count(*) from work_orders where company_id = 'de300000-0000-4000-8000-000000000001' and plan_id is not null) as ppr_tasks,
       (select count(*) from visits where company_id = 'de300000-0000-4000-8000-000000000001') as visits,
       (select count(*) from regions where company_id = 'de300000-0000-4000-8000-000000000001') as regions,
       (select count(*) from objects where company_id = 'de300000-0000-4000-8000-000000000001') as objects,
       (select count(*) from objects where company_id = 'de300000-0000-4000-8000-000000000001' and country_code is not null and city is not null and region_id is not null) as objects_geo,
       (select count(*) from maintenance_plans where company_id = 'de300000-0000-4000-8000-000000000001') as plans,
       (select count(*) from assets a join locations l on l.id = a.location_id join objects o on o.id = l.object_id where o.company_id = 'de300000-0000-4000-8000-000000000001') as assets,
       (select count(*) from locations where code is not null and object_id in (select id from objects where company_id = 'de300000-0000-4000-8000-000000000001')) as coded_rooms,
       (select count(*) from locations where plan_shape is not null and object_id in (select id from objects where company_id = 'de300000-0000-4000-8000-000000000001')) as shaped_rooms"
run -c "select w.title, w.status, w.period_start, w.period_end, (w.due_at < now() and w.status not in ('done','cancelled')) as overdue,
              (select count(*) from checklist_items c where c.work_order_id = w.id) as checklist
         from work_orders w where w.plan_id is not null order by w.plan_id, w.period_start"
