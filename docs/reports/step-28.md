# Шаг 28: VPS-эксперимент Niantic Spatial (отдельный APK) + уведомления исполнителю + офлайн-хвосты + кадры

Ветка `step-28` от свежего `main` (шаг 27 слит — коммит `a0927fd`). Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

Состояние рабочей базы (со слов пользователя, 15.10 12:30): применены 0001–0024, выложены 5 функций, Refresh demo выполнен. 0023 и 0024 дописаны в «Применённые миграции» `CLAUDE.md` первым коммитом.

## Чек-лист
- [x] 1. VPS-эксперимент: отдельный вариант сборки (`-PwithVps=true`, модуль `android/vps`), `VpsActivity`, канал `hey_helpy/vps`, миграция 0025 (`vps_sites`, `vps_marks`), «VPS-скан помещения», документ `docs/research/vps-niantic.md` — **VPS-APK собирается локально**, CI-сборку запускает пользователь
- [ ] 2. Telegram: уведомление исполнителю о новой заявке + «Взять в работу»
- [ ] 3. Офлайн-хвосты: миниатюры фото «до», план этажа без сети, `work_logs`, телефоны сотрудников
- [ ] 4. Кадры 18 / 21 / 28, `DEMO_DAY_CHECKLIST.md`, регрессия, `/check`, `/screens`

## Журнал
- 10:45 · ветка `step-28`, отчёт, «Применённые миграции» += 0023 0024 · первый коммит
- 12:05 · блок 1: модуль `android/vps` (NSDK 4.1.0 из официального Maven на GitHub), мост `hey_helpy/vps`, `VpsActivity`, 0025 раздел 1 + `tools/db_test/vps.sql`, Flutter `lib/features/vps/`, workflow «Build APK (VPS experiment)», `docs/research/vps-niantic.md` · коммит «Шаг 28 (блок 1)»

## Где остановился
- Блок 1 готов: VPS-APK собран локально (`flutter build apk --release -PwithVps=true --target-platform android-arm64`, 70,7 МБ), обычный APK без флага собирается как раньше; JUnit 12/12, Dart 504/504, база — все наборы зелёные (vps 25/25).
- Следующее: блок 2 — уведомление исполнителю в Telegram (`supabase/functions/telegram-notify`, `tg_*` в 0025, кнопка «Взять в работу» в боте).
