#!/usr/bin/env bash
# Проверка перед применением миграции (workflow "Apply migration").
# Вход: переменная окружения FILE — имя файла, например 0011_example.sql.
# Пробелы и переводы строк в начале и в конце имени отбрасываются; обрезанное
# имя передаётся следующим шагам в переменной MIGRATION_FILE (через GITHUB_ENV).
# Ничего не меняет и к базе не подключается.
set -euo pipefail

fail() { echo "::error::$1"; exit 1; }

FILE="${FILE:-}"
# Обрезать пробелы, табуляции и переводы строк по краям (частая ошибка при копировании).
FILE="${FILE#"${FILE%%[![:space:]]*}"}"
FILE="${FILE%"${FILE##*[![:space:]]}"}"
[ -n "$FILE" ] || fail "Не указано имя файла миграции."

# Только имя файла, без папок: NNNN_название.sql (латиница, цифры, «_»).
[[ "$FILE" =~ ^[0-9]{4}_[A-Za-z0-9_]+\.sql$ ]] \
  || fail "Имя «$FILE» не подходит: нужно NNNN_название.sql (например 0011_example.sql), без папок. Проверьте, нет ли пробелов в имени."

PATH_SQL="supabase/migrations/$FILE"
[ -f "$PATH_SQL" ] || fail "Файла $PATH_SQL нет в репозитории (ветка ${GITHUB_REF_NAME:-?}). Проверьте имя (нет ли пробелов и опечаток) и что файл запушен."
[ -s "$PATH_SQL" ] || fail "Файл $PATH_SQL пустой."

NUM="${FILE:0:4}"

# Строка «Применённые миграции: 0001 0002 …» в CLAUDE.md — её ведёт пользователь.
APPLIED_LINE="$(grep -m1 '^Применённые миграции:' CLAUDE.md || true)"
[ -n "$APPLIED_LINE" ] || fail "В CLAUDE.md не найдена строка «Применённые миграции:» — не могу проверить номер."
APPLIED="$(echo "${APPLIED_LINE#*:}" | grep -oE '[0-9]{4}' || true)"

if echo "$APPLIED" | grep -qx "$NUM"; then
  fail "Миграция $NUM уже указана в «Применённые миграции» (CLAUDE.md). Повторно не применяю. Нужно изменение — новая миграция со следующим номером."
fi

# Номер встречается в папке только один раз.
COUNT="$(find supabase/migrations -maxdepth 1 -name "${NUM}_*.sql" | wc -l)"
[ "$COUNT" -eq 1 ] || fail "В supabase/migrations несколько файлов с номером $NUM — уточните, какой нужен."

# Предупреждение (не ошибка): есть неприменённые миграции с меньшими номерами.
MISSING=""
for f in supabase/migrations/[0-9][0-9][0-9][0-9]_*.sql; do
  n="$(basename "$f")"; n="${n:0:4}"
  if [ "$n" \< "$NUM" ] && ! echo "$APPLIED" | grep -qx "$n"; then
    MISSING="$MISSING $n"
  fi
done
if [ -n "$MISSING" ]; then
  echo "::warning::Миграции с меньшими номерами не отмечены как применённые:$MISSING. Обычно их применяют по порядку."
fi

# Обрезанное и проверенное имя — следующим шагам задачи (в нём нет пробелов
# и переводов строк, поэтому запись в GITHUB_ENV безопасна).
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "MIGRATION_FILE=$FILE" >> "$GITHUB_ENV"
fi

echo "Проверка пройдена: $PATH_SQL, номер $NUM, в «Применённых» его нет."
echo "Применённые по CLAUDE.md: $(echo $APPLIED)"
