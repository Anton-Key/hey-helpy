# Шаг 25: «Камера-помощник», WebXR-демо, кадры и видео для питча

Ветка `step-25` от `main` (шаг 24 слит). Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

⚠️ В задании сказано, что в рабочей базе применены миграции 0001–0022. По правилу `CLAUDE.md` номер дописывается в «Применённые миграции» только после сообщения «применена NNNN». Автоматическая проверка не дала мне изменить эту строку по тексту задания, поэтому 0019–0022 туда **не дописаны**. Напишите «применены 0019 0020 0021 0022» — допишу (или впишите сами).

## Чек-лист
- [ ] 1. «Камера-помощник»: живая камера, «Что это?», карточка поверх стоп-кадра
- [ ] 5. Демо-данные: ссылки Telegram (QR), КД-301 с открытой заявкой и ТО, КД-302 без заявок
- [ ] 4. Кадры 04, 18, 20, 21 для питча
- [ ] 6. Проверки и документация (`CLAUDE.md`, `DEMO_SCRIPT.md`, сквозной сценарий 15)
- [ ] 2. «Авто» — подсказка без нажатия
- [ ] 3. WebXR-демо `web/ar/`
- [ ] 4. Кадры 22–24, видео v2

## Журнал
- 08:26 · ветка, отчёт · первый коммит
- 09:30 · блок 1 (часть): пакет `camera`, слой камеры (Android / браузер / заглушка), чистая логика карточки и автоскана, данные карточки, общий «Где я» вынесен из «Узнать по фото», цвета камеры в дизайн-системе · коммит «Шаг 25 (блок 1, часть 1)». Работа остановлена по просьбе пользователя.

## Где остановился
**Остановлено по просьбе пользователя** (сохранено, `flutter analyze lib test` — без замечаний, `test/design_test.dart` проходит).

Готово в блоке 1:
- `pubspec.yaml` — пакет `camera` (Android; в браузере свой `<video>`).
- `lib/features/camera/live_camera.dart` — интерфейс `LiveCamera` (`start` / `stop` / `preview` / `capture`), `CameraProblem`, `LiveCameraException`, `createLiveCamera()`, `liveCameraAvailable()`, заглушка `MockLiveCamera` (картинка `assets/demo_photos/ac_indoor.jpg`, счётчики `starts` / `stops` для тестов).
- `live_camera_device.dart` (Android, CameraX, задняя камера, кадр → JPEG ≤ 1280 через `photo_recompress`), `live_camera_web.dart` (`getUserMedia` `facingMode: environment`, `HtmlElementView`, кадр через canvas, `stop` гасит треки).
- `camera_logic.dart` — `cameraCard` (ждём / узнал / не узнал / вручную, «Не тот» = следующий индекс), `shortAssetLabel` / `frameLabel` («КД-301 · 95 %»), `buildAssetFacts` (открытые заявки ≤ 3 без ППР, следующее ТО — своё, затем системы на объекте, последняя принятая), `AutoScanGate` и `frameDiff` (для блока 2).
- `asset_facts_repository.dart` — заявки единицы и задачи ППР системы на объекте под RLS.
- `lib/features/photo_identify/here_pickers.dart` — `loadPhotoHere` / `savePhotoHere`, `HereObjectPickerSheet`, `HereAssetPickerSheet` (вынесены из `photo_identify_screen.dart`, он теперь их использует).
- `lib/core/design/tokens.dart` — `AppColors.camera`, `cameraOverlay`, `onCamera`, `cameraFrame`, `glass` (+ проверка контраста в `test/design_test.dart`).

Следующее:
1. `lib/features/camera/camera_screen.dart` — экран: видео на весь экран, «Где я» сверху (контекст → последнее → GPS `quickPosition` + `nearestObject`), рамка-прицел, кнопка «Что это?» → `capture` → `PhotoIdentifyClient` / `MockPhotoIdentify` + журнал `IdentifyLog`; стоп-кадр (камера выключается), зелёная рамка, карточка (`cameraCard`, `AssetFactsRepo`), кнопки «Создать заявку» (`showOrderForm`, `PlaceOrigin.photo`, снимок), «Карточка оборудования», «Не тот», «Ещё раз»; «Не узнал» — оборудование помещения; ошибка камеры — текст + «Выбрать фото» (`PhotoIdentifyScreen`). Выключать камеру в `dispose` и при сворачивании приложения. Поля репозиториев — `late`, чтобы виджет-тест работал без Supabase.
2. `camera_entry.dart` — `openCamera(...)`: `liveCameraAvailable()` → «Камера», иначе `PhotoIdentifyScreen`; подключить в `requests_tab.dart` (`_openPhoto`), `equipment_section.dart` (`_findByPhoto`), `floor_plan_screen.dart` (`_MarkerAction.photo`).
3. Строки RU / EN в `.arb`, `flutter gen-l10n`; тесты `test/camera_logic_test.dart` и виджет-тест выключения камеры.
4. Затем блоки 5 → 4 → 6 → 2 → 3 (порядок из задания).
