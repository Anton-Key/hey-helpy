#!/usr/bin/env bash
# PreToolUse (Bash): Claude Code не запускает GitHub Actions сам и не выкладывает
# Edge Functions: supabase functions deploy, supabase secrets set, supabase link,
# supabase login (в том числе через npx / bunx) — это делает workflow «Deploy functions»
# с одобрением пользователя.
# Запрещены: gh workflow run, gh run rerun, gh workflow enable, вызовы API
# …/dispatches (запуск workflow) и …/pending_deployments (одобрение окружения,
# например production-db). Запускает и одобряет только пользователь
# (CLAUDE.md → «Миграции»). Найдено — команда останавливается (код 2).
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

# gh с любыми флагами перед подкомандой (gh -R owner/repo workflow run …),
# в любом месте цепочки (&&, ;, |, $(…)).
gh='(^|[^[:alnum:]_./-])gh([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+'
reason=""
if grep -qE "${gh}workflow[[:space:]]+(run|enable)\b" <<<"$cmd"; then
  reason="gh workflow run/enable"
elif grep -qE "${gh}run[[:space:]]+rerun\b" <<<"$cmd"; then
  reason="gh run rerun"
elif grep -qE '(^|[^[:alnum:]_./-])gh\b[^|;&]*\bapi\b' <<<"$cmd" \
     && grep -qiE 'dispatches|pending_deployments' <<<"$cmd"; then
  reason="gh api …/dispatches или …/pending_deployments"
elif grep -qiE 'api\.github\.com[^[:space:]]*/(dispatches|pending_deployments)' <<<"$cmd"; then
  reason="прямой запрос к GitHub API (dispatches / pending_deployments)"
fi

# supabase с любыми флагами перед подкомандой (supabase --debug functions deploy …),
# в том числе npx supabase / bunx supabase.
sb='(^|[^[:alnum:]_./-])supabase([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+'
if [ -z "$reason" ]; then
  if grep -qE "${sb}functions[[:space:]]+deploy\b" <<<"$cmd"; then
    reason="supabase functions deploy"
  elif grep -qE "${sb}secrets[[:space:]]+(set|unset)\b" <<<"$cmd"; then
    reason="supabase secrets set/unset"
  elif grep -qE "${sb}(link|login)\b" <<<"$cmd"; then
    reason="supabase link/login"
  fi
  if [ -n "$reason" ]; then
    echo "Запрещено ($reason): Claude Code не выкладывает Edge Functions, не задаёт секреты и не подключается к проекту Supabase. Выкладка — только workflow «Deploy functions» с одобрением пользователя (CLAUDE.md → «Edge Functions»)." >&2
    exit 2
  fi
fi

if [ -n "$reason" ]; then
  echo "Запрещено ($reason): Claude Code не запускает, не перезапускает и не одобряет GitHub Actions. Это делает только пользователь — см. CLAUDE.md → «Миграции». Сообщите пользователю, что нужно запустить." >&2
  exit 2
fi
exit 0
