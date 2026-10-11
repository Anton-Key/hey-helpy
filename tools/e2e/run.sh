#!/usr/bin/env bash
# Сквозные сценарии одной командой (шаг 18). Рабочую базу не трогает.
#   1) локальная база hh_test: миграции 0001–0016 + демо (tools/db_test/run.sh,
#      заодно все SQL-тесты прав) и подготовка (prep.sql);
#   2) база hh_old: миграции 0001–0014 + demo.sql (как рабочая сейчас);
#   3) веб-сборка build/web_e2e (tools/e2e/build.sh; --no-build — взять готовую);
#   4) сценарии 1–8 на hh_test, сценарий 9 на hh_old (Playwright).
# Итоги — tools/e2e/out/results.md (таблица), снимки ошибок — tools/e2e/out/.
# Нужны: локальный PostgreSQL, PostgREST 12 (POSTGREST=путь, по умолчанию
# postgrest из PATH), браузер Playwright (/opt/pw-browsers), ffmpeg, poppler-utils.
# Запуск: bash tools/e2e/run.sh [--no-build] [--no-db] [--only=1,3] [--shots]
set -uo pipefail
cd "$(dirname "$0")/../.."
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
export POSTGREST="${POSTGREST:-postgrest}"
ARGS=()
BUILD=1; DBS=1
for a in "$@"; do
  case "$a" in
    --no-build) BUILD=0 ;;
    --no-db) DBS=0 ;;
    *) ARGS+=("$a") ;;
  esac
done
if [ "$DBS" = 1 ]; then
  echo "== Локальная база hh_test (миграции 0001–0016, SQL-тесты, демо)"
  bash tools/db_test/run.sh > /tmp/hh_db_test.log 2>&1 || { tail -30 /tmp/hh_db_test.log; exit 1; }
  tail -9 /tmp/hh_db_test.log
  echo "== База hh_old (0001–0014)"
  bash tools/e2e/old_db.sh
fi
sudo -u postgres psql -X -q -v ON_ERROR_STOP=1 -d hh_test -f tools/e2e/prep.sql
if [ "$BUILD" = 1 ] || [ ! -f build/web_e2e/index.html ]; then
  echo "== Веб-сборка (2–3 минуты)"
  bash tools/e2e/build.sh
fi
cd tools/e2e
echo "== Сценарии 1–8 (hh_test)"
HH_TEST_DB=hh_test node e2e.mjs "${ARGS[@]}" 2>&1 | grep -v '^[0-9][0-9]/[A-Z][a-z][a-z]/\|^127\.0\.0\.1 - '
echo "== Сценарий 9 (hh_old)"
HH_TEST_DB=hh_old node e2e.mjs --keep "${ARGS[@]}" 2>&1 | grep -v '^[0-9][0-9]/[A-Z][a-z][a-z]/\|^127\.0\.0\.1 - '
pkill -x postgrest 2>/dev/null || true
echo
cat out/results.md
! grep -q '❌' out/results.md
