#!/usr/bin/env bash
# Запасное видео демо: docs/demo/hey-helpy-demo.mp4 (ПК 1920×1080) и
# docs/demo/hey-helpy-demo-phone.mp4 (телефон 412). Локальная база, без сети.
# База hh_test пересоздаётся (tools/db_test/run.sh). Нужны:
# сборка build/web_e2e (tools/e2e/build.sh), PostgREST (POSTGREST=…), ffmpeg.
# Запуск: bash tools/e2e/record_demo.sh [--phone-only|--pc-only]
set -euo pipefail
cd "$(dirname "$0")/../.."
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
export POSTGREST="${POSTGREST:-postgrest}"
# Чистая база (сквозные тесты меняют данные): миграции + демо заново, ~40 с.
bash tools/db_test/run.sh > /tmp/hh_db_test.log 2>&1 || { tail -20 /tmp/hh_db_test.log; exit 1; }
sudo -u postgres psql -X -q -v ON_ERROR_STOP=1 -d hh_test -f tools/e2e/prep.sql
[ -f build/web_e2e/index.html ] || bash tools/e2e/build.sh
cd tools/e2e
if [ "${1:-}" != "--phone-only" ]; then node record_demo.mjs > /tmp/hh_demo_pc.log 2>&1 || true; grep -v '^[0-9][0-9]/[A-Z]' /tmp/hh_demo_pc.log | tail -3; fi
pkill -x postgrest 2>/dev/null || true
if [ "${1:-}" != "--pc-only" ]; then node record_demo.mjs --phone > /tmp/hh_demo_phone.log 2>&1 || true; grep -v '^[0-9][0-9]/[A-Z]' /tmp/hh_demo_phone.log | tail -3; fi
pkill -x postgrest 2>/dev/null || true
