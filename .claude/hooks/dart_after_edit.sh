#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): после изменения .dart-файла —
# dart format этого файла и dart analyze по нему.
# Есть ошибки или предупреждения — код 2: текст уходит Claude, чтобы он сразу исправил.
set -uo pipefail

file=$(jq -r '.tool_input.file_path // empty')
[[ "$file" == *.dart ]] || exit 0
[[ -f "$file" ]] || exit 0
# Сгенерированные переводы (flutter gen-l10n) руками не правятся и не проверяются.
[[ "$file" == */lib/l10n/app_localizations*.dart ]] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

if ! fmt_out=$(dart format "$file" 2>&1); then
  echo "dart format не смог отформатировать $file (синтаксическая ошибка?):" >&2
  echo "$fmt_out" >&2
  exit 2
fi

# Без --fatal-infos: подсказки (info) не останавливают, ошибки и предупреждения — да.
if ! an_out=$(dart analyze "$file" 2>&1); then
  echo "dart analyze нашёл проблемы в $file — исправь их:" >&2
  echo "$an_out" | grep -E '^\s*(error|warning|info) ' >&2 || echo "$an_out" >&2
  exit 2
fi
exit 0
