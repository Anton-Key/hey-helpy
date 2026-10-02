#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit|Bash): запрет менять уже применённые миграции.
# Список применённых — строка «Применённые миграции: 0001 0002 …» в CLAUDE.md.
# Изменения схемы после применения — только новой миграцией (/migration).
set -uo pipefail

input=$(cat)
root="${CLAUDE_PROJECT_DIR:-.}"

applied=$(grep -m1 -E '^Применённые миграции:' "$root/CLAUDE.md" 2>/dev/null | grep -oE '[0-9]{4}' | tr '\n' ' ')
# Если строку случайно удалили — защищаем хотя бы то, что точно применено.
[[ -n "$applied" ]] || applied="0001 0002 0003 0004 0005"

tool=$(jq -r '.tool_name' <<<"$input")
if [[ "$tool" == "Bash" ]]; then
  text=$(jq -r '.tool_input.command // empty' <<<"$input")
  # Только команды, которые меняют, переносят или удаляют файлы; чтение (cat, grep) разрешено.
  grep -qE '(\brm\b|\bmv\b|\bcp\b|\btee\b|\btruncate\b|\bdd\b|sed[^|;&]*\s-[a-zA-Z]*i|--in-place|perl[^|;&]*\s-[a-zA-Z]*i|>>?[[:space:]]*["'\'']?[^[:space:]]*supabase/migrations/|git\s+(rm|mv|checkout|restore|reset)\b)' <<<"$text" || exit 0
else
  text=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
fi

for num in $(grep -oE 'supabase/migrations/[0-9]{4}_' <<<"$text" | grep -oE '[0-9]{4}' | sort -u); do
  if [[ " $applied " == *" $num "* ]]; then
    cat >&2 <<MSG
Миграция $num уже применена в рабочей базе (см. «Применённые миграции» в CLAUDE.md) — её файл менять нельзя.
Нужное изменение оформи новой миграцией со следующим номером (команда /migration).
MSG
    exit 2
  fi
done
exit 0
