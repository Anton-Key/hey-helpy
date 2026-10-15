# Шаг 28: VPS-эксперимент Niantic Spatial (отдельный APK) + уведомления исполнителю + офлайн-хвосты + кадры

Ветка `step-28` от свежего `main` (шаг 27 слит — коммит `a0927fd`). Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

Состояние рабочей базы (со слов пользователя, 15.10 12:30): применены 0001–0024, выложены 5 функций, Refresh demo выполнен. 0023 и 0024 дописаны в «Применённые миграции» `CLAUDE.md` первым коммитом.

## Чек-лист
- [x] 1. VPS-эксперимент: отдельный вариант сборки (`-PwithVps=true`, модуль `android/vps`), `VpsActivity`, канал `hey_helpy/vps`, миграция 0025 (`vps_sites`, `vps_marks`), «VPS-скан помещения», документ `docs/research/vps-niantic.md` — **VPS-APK собирается локально**, CI-сборку запускает пользователь
- [x] 2. Telegram: уведомление исполнителю о новой заявке + «Взять в работу» (0025 раздел 2, `telegram-notify` kind `assigned`, кнопка `tk:` в боте)
- [x] 3. Офлайн-хвосты: фото «до» и план этажа без сети (байты при предзагрузке, бюджеты 30 / 20 МБ), `work_logs` — только база, телефоны — `profile_contacts` (0025 раздел 3); ⚠️ новая заявка без сети — не делал
- [ ] 4. Кадры 18 / 21 / 28, `DEMO_DAY_CHECKLIST.md`, регрессия, `/check`, `/screens`

## Журнал
- 10:42 UTC · ветка `step-28`, отчёт, «Применённые миграции» += 0023 0024 · первый коммит
- 11:23 UTC · блок 1: модуль `android/vps` (NSDK 4.1.0 из официального Maven на GitHub), мост `hey_helpy/vps`, `VpsActivity`, 0025 раздел 1 + `tools/db_test/vps.sql`, Flutter `lib/features/vps/`, workflow «Build APK (VPS experiment)», `docs/research/vps-niantic.md` · коммит «Шаг 28 (блок 1)»

- 11:31 UTC · блок 2: `tg_notify_assign_claim` / `_release` / `tg_take_order` + `tools/db_test/tg_take.sql` (17/17), `telegram-bot/assign.ts`, кнопка «Взять в работу», режим `assigned` в `telegram-notify`, вызовы из приложения; deno 95/95, Flutter 504/504 · коммит «Шаг 28 (блок 2)»

- 11:36 UTC · блок 4 (часть): кадры 18 и 21 пересняты на рабочей базе (проверены глазами), кадр 28 — макет `tools/screens/tg_assign_mock.mjs`, README кадров; блок 3 (начало): предзагрузка фото «до» и планов этажей байтами (`OfflineService._prefetchMedia`, бюджеты в `offline_logic.dart`, тесты `test/offline_media_test.dart`) · коммит «Шаг 28 (блок 4, 3)»

- 11:45 UTC · блок 3: фото «до» в карточке без сети (`WorkPhoto.offline`, `Image.memory`), план без сети (`PlanPicture` → сохранённый, `OrderPlanLink` → `OfflinePlanScreen`), 0025 раздел 3 + `tools/db_test/privacy.sql` (13/13), чтение телефонов через `profile_contacts(phone)`; Flutter 508/508 · коммит «Шаг 28 (блок 3)»

- 11:50 UTC · блок 1 (доработка): касание «Поставить метку» — hit-test на свежем кадре ARCore; блок 4: `DEMO_DAY_CHECKLIST.md` (0025, 5 функций, исполнитель в Telegram, VPS-APK), `DEMO_SCRIPT.md`; откат случайного форматирования 4 файлов · коммит «Шаг 28 (блок 4)»

## Где остановился
- Блок 1 готов: VPS-APK собран локально (`flutter build apk --release -PwithVps=true --target-platform android-arm64`, 70,7 МБ), обычный APK без флага собирается как раньше; JUnit 12/12, Dart 504/504, база — все наборы зелёные (vps 25/25).
- Блок 2 готов (нужен Deploy functions: `telegram-notify` и `telegram-bot`).
- Кадры 18, 21, 28 готовы.
- Блок 3 готов.
- Сейчас: полная регрессия `tools/e2e` (идёт). Следующее: `/check`, `/screens`, итоговый отчёт, `gh pr ready`.
