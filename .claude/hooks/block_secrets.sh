#!/usr/bin/env bash
# PreToolUse (Bash): перед git commit — проверка, что в коммит не попадают секреты:
# env.json, *.env, токены Supabase (sbp_…), ключ service_role.
# Найдено — коммит останавливается (код 2), Claude должен сказать пользователю.
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')
grep -qE '\bgit\b[^|;&]*\bcommit\b' <<<"$cmd" || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Что уйдёт в коммит: уже добавленное. Если в той же команде есть «git add» или «commit -a»,
# индекс ещё не обновлён — проверяем также изменённые и новые (не игнорируемые) файлы.
staged=$(git diff --cached --name-only --diff-filter=ACMR)
extra=""
if grep -qE '\bgit\b[^|;&]*\badd\b|\bcommit\b[^|;&]*\s-[a-zA-Z]*a|--all' <<<"$cmd"; then
  extra=$(git diff --name-only --diff-filter=ACMR; git ls-files --others --exclude-standard)
fi

problems=()

is_service_role_jwt() {
  local payload pad
  payload=$(cut -d. -f2 <<<"$1" | tr '_-' '/+')
  pad=$(( (4 - ${#payload} % 4) % 4 ))
  while (( pad-- > 0 )); do payload+='='; done
  base64 -d <<<"$payload" 2>/dev/null | grep -q '"role"[[:space:]]*:[[:space:]]*"service_role"'
}

check_text() { # $1 — файл, stdin — проверяемый текст
  local f=$1 text jwt
  text=$(cat)
  grep -qE 'sbp_[A-Za-z0-9]{20,}' <<<"$text" && problems+=("$f: токен доступа Supabase (sbp_…)")
  grep -qiE 'service_role_key["'\'']?[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9._-]{20,}' <<<"$text" \
    && problems+=("$f: ключ service_role")
  for jwt in $(grep -oE 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' <<<"$text" | sort -u); do
    is_service_role_jwt "$jwt" && { problems+=("$f: ключ service_role (JWT)"); break; }
  done
}

while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  base=$(basename "$f")
  if [[ "$base" == "env.json" || "$base" == ".env" || "$base" == *.env || "$base" == .env.* ]]; then
    problems+=("$f: файл с ключами не должен попадать в git")
    continue
  fi
  # Проверяем только добавленные строки: старые упоминания (например, в schema.sql) не мешают.
  check_text "$f" < <(git diff --cached -U0 -- "$f" | grep -aE '^\+')
done <<<"$staged"

while IFS= read -r f; do
  [[ -n "$f" && -f "$f" ]] || continue
  grep -qxF -- "$f" <<<"$staged" && continue
  base=$(basename "$f")
  if [[ "$base" == "env.json" || "$base" == ".env" || "$base" == *.env || "$base" == .env.* ]]; then
    problems+=("$f: файл с ключами не должен попадать в git")
    continue
  fi
  if git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
    check_text "$f" < <(git diff -U0 -- "$f" | grep -aE '^\+')
  else
    check_text "$f" < <(grep -aI '' -- "$f" 2>/dev/null)
  fi
done <<<"$extra"

if (( ${#problems[@]} )); then
  {
    echo "Коммит остановлен: похоже, в него попадают секреты."
    printf ' - %s\n' "${problems[@]}"
    echo "Не обходи проверку. Остановись и скажи пользователю, что найдено и где;"
    echo "убрать файл из коммита (git restore --staged <файл>), ключ — в GitHub Secrets / env.json вне git."
  } >&2
  exit 2
fi
exit 0
