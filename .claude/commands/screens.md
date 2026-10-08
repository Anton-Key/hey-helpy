---
description: Скриншоты веб-версии под тремя ролями в docs/screens/latest/ (для отчёта и PR)
allowed-tools: Bash(ls:*), Bash(test:*), Bash(du:*), Read, Glob
---

Сними скриншоты главных экранов веб-версии под менеджером, исполнителем и заявителем.
**В базе ничего не меняй**: скрипт только входит и смотрит. Единственный след — экран «Уведомления» сам отмечает их прочитанными у демо-пользователя (`profiles.notifications_seen_at`).

## 1. Проверка
- Есть ли файл `.env.demo` в корне репозитория (`test -f .env.demo`). **Не читай и не выводи его содержимое.**
  Если файла нет — остановись и скажи пользователю: нужно создать `.env.demo` в корне со строками
  `DEMO_MANAGER_EMAIL`, `DEMO_MANAGER_PASSWORD`, `DEMO_EXECUTOR_EMAIL`, `DEMO_EXECUTOR_PASSWORD`,
  `DEMO_REQUESTER_EMAIL`, `DEMO_REQUESTER_PASSWORD` (файл в `.gitignore`, в git не попадёт).
- Есть ли `env.json` (публичные `SUPABASE_URL`, `SUPABASE_ANON_KEY`) — без него сайт не подключится к базе.
- Есть ли `tools/screens/node_modules` (нет — `cd tools/screens && npm ci`) и браузер в `/opt/pw-browsers`.
  Браузер ставится сам при создании Codespace (`postCreateCommand` в `.devcontainer/devcontainer.json`).
  **`playwright install` самому не запускать**: если браузера нет — остановись и скажи пользователю
  (пересобрать Codespace или разрешить установку).

## 2. Съёмка
```
cd tools/screens && PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node screens.mjs
```
Скрипт сам собирает веб-версию (`flutter build web --dart-define-from-file=env.json`), поднимает
локальный сервер, входит по очереди под тремя ролями и снимает: список заявок, карточку демо-заявки,
отчёты (30 дней, только менеджер), историю, подрядчиков, локации, профиль, уведомления,
окно выбора подрядчика (только менеджер, первая заявка «Новая»; окно закрывается без назначения).
Менеджер — ширина 1280 и 412, исполнитель и заявитель — 412.
Файлы: `docs/screens/latest/<роль>-<ширина>-<экран>.png` (папка перезаписывается), итоги —
`docs/screens/latest/README.md`. PNG больше ~300 КБ отмечаются в README.

## 3. Проверка результата
- Прочитай `docs/screens/latest/README.md`. Каждый ❌ — в отчёт шага с причиной, **не пропускать молча**.
- Открой несколько снимков (Read) — хотя бы `manager-1280-reports.png`, `manager-412-order.png`,
  `executor-412-requests.png`: нет ли пустых экранов, ошибок, обрезанного текста.
- `du -k docs/screens/latest/*.png` — нет ли файлов больше 300 КБ.

## Итог
Коротко по-русски: сколько снимков, что не открылось и почему, что заметно не так на экранах.
Папка `docs/screens/latest/` коммитится в ветку шага.
