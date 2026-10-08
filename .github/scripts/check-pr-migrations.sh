#!/usr/bin/env bash
# Проверка файлов миграций в Pull Request (workflow "PR check").
# Вход: BASE — коммит, с которым сравниваем (по умолчанию HEAD^1: для pull_request
# GitHub собирает merge-коммит, его первый родитель — текущий main).
# Проверяет:
#   - новые файлы в supabase/migrations называются NNNN_название.sql;
#   - номера в папке не повторяются;
#   - номер новой миграции не указан в «Применённые миграции» (CLAUDE.md);
#   - применённые миграции не изменены и не удалены (нужна новая миграция).
# К базе не подключается и ничего не меняет.
set -euo pipefail

BASE="${BASE:-HEAD^1}"
errors=0
err() { echo "::error::$1"; errors=$((errors + 1)); }

APPLIED_LINE="$(grep -m1 '^Применённые миграции:' CLAUDE.md || true)"
APPLIED="$(echo "${APPLIED_LINE#*:}" | grep -oE '[0-9]{4}' || true)"

# Новые файлы миграций в PR.
added="$(git diff --name-only --diff-filter=A "$BASE" HEAD -- supabase/migrations || true)"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  name="$(basename "$f")"
  if [[ ! "$name" =~ ^[0-9]{4}_[A-Za-z0-9_]+\.sql$ ]]; then
    err "$f: имя не подходит — нужно NNNN_название.sql (латиница, цифры, «_»)."
    continue
  fi
  [ -s "$f" ] || err "$f: файл пустой."
  if echo "$APPLIED" | grep -qx "${name:0:4}"; then
    err "$f: номер ${name:0:4} уже в «Применённые миграции» (CLAUDE.md) — нужен следующий свободный номер."
  fi
done <<<"$added"

# Номера во всей папке не повторяются.
dups="$(find supabase/migrations -maxdepth 1 -name '[0-9][0-9][0-9][0-9]_*.sql' -printf '%f\n' \
  | cut -c1-4 | sort | uniq -d)"
for n in $dups; do
  err "В supabase/migrations несколько файлов с номером $n."
done

# Применённые миграции не меняются: изменение — только новой миграцией.
changed="$(git diff --name-only --diff-filter=MDR "$BASE" HEAD -- supabase/migrations || true)"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  name="$(basename "$f")"
  if echo "$APPLIED" | grep -qx "${name:0:4}"; then
    err "$f: миграция ${name:0:4} уже применена — её нельзя менять или удалять, нужна новая."
  fi
done <<<"$changed"

if [ "$errors" -gt 0 ]; then
  echo "Проверка миграций: ошибок $errors."
  exit 1
fi
echo "Проверка миграций пройдена. Новые файлы: $(echo ${added:-нет})."
