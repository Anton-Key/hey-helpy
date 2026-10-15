# Шаг 27: работа без интернета + оборудование точно на плане + подготовка к заморозке

Ветка `step-27` от свежего `main` (шаг 26 слит — коммит `6e575ce`). Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

**Новая миграция — 0024** `0024_offline_sync.sql` (требует 0023; полный текст — в конце отчёта). **Новая Edge Function — `offline-sync`** (нужен Deploy functions). **Менялись демо-данные** (`demo_history.sql`, блок 6c) — нужен Refresh demo после 0024. Новые пакеты: `path_provider`, `crypto` (уже приходили вместе с другими, теперь прямые). Новых секретов нет. Изменён `MainActivity.kt` (часы для работы без сети) — нужен свежий APK.

Часть работы шла параллельно у трёх помощников (блоки 6+9, документы блоков 7/8/10, загрузка сайта и ошибки блока 8); их ветки слиты в `step-27`.

## Чек-лист
- [x] 1. Данные на телефоне (предзагрузка своих заявок, хранилище, «Нет сети · данные на 14:02»)
- [x] 2. Очередь действий без сети, отправка, конфликты («Заявку отменили, пока вы были без сети», фото сохраняется с пометкой)
- [x] 3. Честное время (монотонные часы + якорь сервера, время GPS), SHA-256 фото, `time_trust`, миграция 0024
- [x] 4. Акт: три группы, «Подтвердить к оплате» / «Не принимать», карточка, плашка, отчёты, демо
- [x] 5. Проверки, сквозные сценарии 17–18, `CLAUDE.md`, `DEMO_SCRIPT.md`, кадры 25–27
- [x] 6. Оборудование точно на плане (экран выбора точки, лупа, «где именно», фото места)
- [~] 7. Хвосты: README кадров 1–27, инструкция по второму менеджеру — да; пересъёмка 17 / 18 / 21 на рабочей базе — нет (см. ниже)
- [x] 8. Надёжность: документ по правам (найдено и исправлено 3 дыры); первая загрузка и ошибки — см. раздел «Блок 8»
- [x] 9. Экспорт реестра оборудования в Excel (и обратно импортом)
- [x] 10. Чек-лист утра показа `docs/DEMO_DAY_CHECKLIST.md`

## Что сделано

### Блок 1. Данные на телефоне
- `lib/features/offline/offline_store.dart` — ⚠️ **решение: JSON-файлы в каталоге приложения** (`<support>/offline/<uid>/`), а не sqflite / drift: данных мало (свои заявки исполнителя), не нужен новый нативный пакет и схема базы на телефоне. Запись — во временный файл и переименование (не бьётся при обрыве). Снимки очереди — отдельными файлами.
- **Предзагрузка** (`OfflineService.prefetch`) — при входе, при открытии списка заявок и раз в 15 минут: свои назначенные заявки «назначена / в работе / возвращена» (строки списка и карточки), чек-листы, помещения, этажи и оборудование их объектов, справочники (объекты с координатами и радиусом геозоны, системы, подрядчики).
- **Кэш ответов** (`cachedJson`): профиль, роль, компания, объекты, подрядчики, системы, карточка заявки, чек-лист — нет сети → последний сохранённый ответ.
- **Вход без сети**: `SessionController` хранит строку профиля (только того же пользователя) — приложение открывается со своими заявками.
- Плашка вверху списка и карточки: «Нет сети · данные на 14:02».
- **Выход из аккаунта — всё с телефона удаляется** (`detach`).
- ⚠️ Миниатюры фото «до» без сети **не** сохраняются (не успел; подписанные ссылки живут час). План этажа без сети тоже не открывается.

### Блок 2. Очередь действий
- «Начать работу», визит (координаты, точность, подмена GPS), отметка пункта чек-листа, фото «после», «Выполнено, на проверку» — без сети (или если по заявке уже есть неотправленное — порядок важен) уходят в очередь. У каждого действия свой id. Экран сразу показывает результат: статус, «ждёт отправки · 6», отмеченные пункты, миниатюры снимков.
- **Чек-лист в карточке заявки** — раньше его в приложении не было вовсе (`lib/features/requests/order_checklist.dart`): отмечает исполнитель, пока заявка «в работе».
- Плашка: «Нет сети — сохранено на телефоне: 6 действий» → «Отправляю сохранённое…» → «Отправлено ✓» (2 с). Отказ — «Не удалось отправить 1 действие · Подробнее» (шторка с причинами).
- «📍 В геозоне / Вне геозоны · 240 м / Нет GPS» после «Начать работу» без сети — считается на телефоне (GPS работает без интернета).
- **Сервер принимает очередь одной функцией** — ⚠️ решение: **RPC `offline_sync` в базе** (security definer), а не Edge Function: права проверяют **те же триггеры шага 26** (`trg_wo_status_flow`, `trg_wo_guard`, `trg_checklist_guard`, `wo_is_executor`), функция лишь подставляет время действия вместо `now()` (`hh_now()`). Каждое действие — в своей подтранзакции. Повтор id — тот же ответ, без дублей (`offline_actions`).
- **Конфликты**: заявку отменили / передали другому / уже приняли — действие отклоняется с причиной («Заявку отменили, пока вы были без сети»), **фото «после» всё равно сохраняется в заявке** с пометкой `sync_note` (`after_cancel | after_reassign | after_close`). Для этого — история назначений `wo_contractor_history` и политика хранилища `work_photos_insert_offline`.
- ⚠️ Офлайн-создание **новой** заявки — не делал (по желанию, не успел).
- Визит закрывается временем действия «на проверку» (`trg_wo_close_visits` с `hh_now()`); отдельного «выхода» нет.

### Блок 3. Честное время и подлинность фото
- **Монотонные часы**: Android — `SystemClock.elapsedRealtime()` и номер загрузки `BOOT_COUNT` через канал `hey_helpy/clock` (`MainActivity.kt`). При каждой связи — `offline_clock(boot, mono_ms)`: **якорь пишет сервер своим временем** (подделать время сервера нельзя). Доверенное время = якорь + прошедшие миллисекунды. Перезагрузили телефон — якоря этой загрузки нет, остаётся GPS.
- **GPS-время**: последний GPS-фикс (`LocationManager`, время спутников + момент фикса по монотонным часам), не старше 30 минут, пересчитанный к моменту действия.
- Сервер (`offline_time`): монотонные → `monotonic`, иначе GPS → `gps`, ни того ни другого → `device_only`; часы телефона расходятся с доверенным > 5 мин (или GPS спорит с монотонными) → `unverified`. Время действий в базе — доверенное; заявленное телефоном — `attachments.taken_at` / `visits.claimed_at`, расхождение — `time_drift_s`.
- **Отпечаток фото**: SHA-256 снимка **после штампа** считается на телефоне в момент съёмки; Edge Function `offline-sync` скачивает файл под RLS пользователя и пересчитывает по байтам, отпечаток сервера записывает только service_role (`offline_photo_hash_put`). Не совпал — фото отклоняется («Фото повредилось при отправке — снимите заново»).
- **Штамп** (без сети, на телефоне): время по доверенному источнику, «📍 в геозоне / вне геозоны / нет GPS», пометка «без сети».
- `attachments.source` — ⚠️ решение: **остаётся `camera` + признак `offline`**, нового значения нет (меньше правок в акте и проверках).
- Обычная вставка из приложения **не может** поставить себе `offline` / `time_trust = gps` — их ставит только `offline_sync` (триггеры `trg_attachments_offline`, `trg_visits_offline`; тест).
- ⚠️ `Location.getTime()` на Android для GPS-провайдера — время спутников на большинстве устройств, но стандарт этого строго не гарантирует. Подделать монотонные часы и GPS можно только изменённым APK — от этого защиты нет (как и от подделки `source` в шаге 26).

### Блок 4. Акт и карточка — сомнительное решает менеджер
- **Три группы**: «К оплате» / «Требует решения менеджера» (жёлтая) / «Без доказательства». В жёлтую: время снимка не подтверждено («часы телефона расходились на 2 ч»), только часы телефона, фото «из файла» (раньше — сразу «без доказательства»), прислано после закрытия, отпечаток не сверен, время визита без сети не подтверждено.
- «Подтвердить к оплате» (комментарий обязателен) / «Не принимать» (комментарий по желанию) → строка уходит в «К оплате» с «✋ решение менеджера: Администратор Демо, 14 окт. 19:20 — …» или в «Без доказательства». «Изменить решение» — пока заявка не в действующем акте.
- ⚠️ Хранение: `act_proof_decisions` — **строки только добавляются**, последняя по заявке — действующая, прежние — журнал (отдельной таблицы журнала нет). Решать — менеджер с правом на заявку (зона 0016) или администратор, **не исполнитель и не тот, кто сдавал** — проверяет база (`act_proof_decide`).
- «Сформировать акт» при нерешённых — «2 заявки ждут вашего решения — они не попадут в акт · Решить сейчас / Сформировать без них». PDF и Excel: «подтверждено менеджером: <комментарий>», блок «Ожидают решения (без сумм)», в итогах «из них подтверждено вручную: N».
- Карточка заявки (менеджер), блок «Доказательства»: «Снято без сети в 14:19 · время подтверждено ✓ · отправлено в 14:25» / «⚠️ время не подтверждено (часы телефона расходились на 2 ч) · решение при формировании акта» и решение менеджера.
- Главная менеджера — плашка «Ждут вашего решения по оплате: N» (текущий месяц) → акты. «Отчёты» → «Акты подрядчикам»: «Сдано без сети: N · подтверждено вручную: M».
- Демо (блок 6c, нужна 0024): у «КлиматСервис» — 112 («время не подтверждено, 2 ч») и 109 («фото из файла») в жёлтой группе.
- ⚠️ Плашка на главной считает только сомнения по фото (без «времени визита») — так дешевле запрос.
- ⚠️ Если `offline-sync` не выложена, у фото без сети «отпечаток не сверен» → они все попадут в «Требует решения». Для показа **нужен Deploy functions**.

### Блок 5. Проверки и документация
- `test/offline_logic_test.dart` (14), `test/act_logic_test.dart` (+3), `test/live_shot_test.dart` (штамп «нет GPS», «без сети»).
- `tools/db_test/offline_sync.sql` — 54 проверки: порядок действий, время действий = заявленное (не время отправки), повтор без дублей, чужой подрядчик / менеджер / заявитель, отменённая заявка (фото сохранено с пометкой), неверный отпечаток, часы +2 ч → `unverified`, только GPS → `gps`, ни того ни другого → `device_only`, перезагрузка телефона, решения менеджера (исполнитель, автор, без комментария, после акта — нельзя), обычная вставка не притворяется офлайн-действием, Н-1…Н-3.
- **Сквозной сценарий 17** (браузер в тестовом режиме `OFFLINE_TEST` + `?offline=1`, переключатель «Сеть (тест)»): без сети — начать, 2 пункта, живой снимок, сдать → в очереди 6 действий, сервер не менялся → сеть → «на проверке», фото `offline, monotonic, sha256_ok, camera`, визит `monotonic, в геозоне`, 6 записей журнала; второй прогон с часами +2 ч → `unverified, 7200` → исполнитель решать не может (база) → менеджер в акте «Требует решения» → «Подтвердить к оплате» с комментарием → строка в «К оплате» с «решение менеджера». ✅
- `CLAUDE.md` (офлайн, только APK, хранилище, очередь, доверенное время, акт, 0024, `offline-sync`, следующий номер **0025**), `docs/DEMO_SCRIPT.md` — сцена «Режим полёта» 30 с и ответ на «а если в подвале нет связи?».
- Кадры **25** `25-offline-queue-phone.png`, **26** `26-offline-proof-phone.png`, **27** `27-act-decision-desktop.png` — из сценария 17 (локальная база).

### Блок 6. Оборудование точно на плане (помощник, проверено и слито)
- Строка «Место на плане» в форме и карточке оборудования: «Не указано · Указать на плане» или миниатюра плана с точкой «3 этаж · 301 · Переговорная · Изменить». Экран выбора точки: план этажа помещения, приближен к контуру помещения (иначе к точке), маркер тянется или ставится нажатием, **лупа ×2,2** над пальцем, «Готово» / «Отмена» / «Убрать с плана». Для новой единицы точка сохраняется вместе с ней.
- Точка в контуре другого помещения — «Точка в помещении 302 · Кабинет — сменить помещение?» (молча не меняется). Нет плана — «Загрузите план этажа в карточке объекта» и кнопка (менеджеру).
- «Где именно» (`assets.meta.mount` / `height_m` / `landmark`, без миграции): «потолок · 2,8 м · над дверью, слева» — в карточке оборудования, «Камере-помощнике», карточке заявки (через «Показать на плане»), подпись у маркера на плане.
- ⚠️ **Фото места** хранится в закрытом хранилище `floor-plans` в папке этажа (`<компания>/<объект>/<этаж>/asset-place-….jpg`, путь — `meta.place_photo`): по политикам 0013/0014 туда пишет менеджер без новой миграции, видят те, кто видит этаж. Поэтому фото места — только если у точки или помещения есть этаж. При удалении этажа файл не удаляется.
- ⚠️ На экране выбора точки у плана выключена «семантика нажатия» (иначе щелчок диктора ставил точку в центр); диктору точка двигается маркером.
- Тесты: `test/asset_place_test.dart`, `test/plan_point_picker_test.dart`; **сквозной сценарий 18** ✅ (нажатие + перетаскивание → этаж 602, точка внутри переговорной, `ceiling`, 2,8 м → маркер на плане 564,333 = расчёт 564,333).

### Блок 7. Хвосты
- Отчёт шага 26 не трогал (шаг слит). Итог `/screens` этого шага — ниже, в «Проверках».
- `docs/screens/pitch/README.md` — таблица кадров 1–27 с фразой для слайда к каждому.
- `docs/DEMO_SETUP.md` — как пригласить второго менеджера «Москва · Климат» и переснять кадр 17. ⚠️ Помощник заметил: сейчас кадр 17 в `screens.mjs` снимает зону **бригады «Пекин»**, и `--only=17` переснимет её же; чтобы на кадре была зона второго менеджера, нужно поменять сценарий кадра после того, как менеджер появится. Ещё: приглашение в приложении привязано к подрядчику — пригласив через «КлиматСервис», второй менеджер станет и его исполнителем; в инструкции предложено завести служебного подрядчика без закреплений.
- ⚠️ **Кадры 18 и 21 на рабочей базе не переснимал**: 0023 в рабочей базе ещё не применена, а `photo-identify` шага 26 не выложена — кадр снялся бы со старым поведением. Команды для пересъёмки после применения 0023/0024 и Deploy functions: `cd tools/screens && node screens.mjs --pitch --only=18,21`.

### Блок 8. Надёжность перед заморозкой
- **Проверка прав глазами** — `docs/security/review-2026-10.md` (для не программиста: таблицы, роли, функции `security definer`, service_role, автотесты, ограничения). Найдено и **исправлено в 0024** с тестами:
  - ⚠️ **Н-1** `set_member_role`: менеджер с зоной мог сделать коллегу (или свой второй аккаунт) менеджером всей компании → теперь менеджер с зоной ролей не меняет.
  - ⚠️ **Н-2** `attachments_insert`: путь фото не проверялся — исполнитель мог «приложить» демо-картинку `demo/ac_after.jpg` или фото другой заявки с `source = camera` и сдать работу → теперь только файл из папки своей заявки и только свой загруженный.
  - ⚠️ **Н-3** `report_links_select`: менеджер с зоной видел токены всех ссылок Telegram, включая ссылку компании → теперь только своих объектов.
  - Мелочи (не исправлял): строку истории `work_logs` может добавить любой, кто видит заявку (приложение её не читает); телефоны сотрудников видны всей компании.
- **Первая загрузка сайта и ошибки** — см. раздел «Блок 8: загрузка и ошибки» ниже.

### Блок 8: загрузка и ошибки
⚠️ Ветки помощника по этой части не нашлось (в рабочих копиях помощников её нет) — сделал сам после продолжения сессии.

**Замер** — новый скрипт `tools/e2e/first_load.mjs`: сборка раздаётся локально со сжатием gzip (как GitHub Pages), Playwright, холодный кэш, «медленный 4G» (1,6 Мбит/с, задержка 150 мс, как в Lighthouse), время до первого кадра Flutter (экран входа), по 3 прогона, медиана.

| | До | После |
|---|---|---|
| Время до первого экрана | **21,5 с** | **17,0 с** (−21 %) |
| Скачано до первого экрана | 4 236 КБ | 3 286 КБ (−22 %) |
| `main.dart.js` (сжатый) | 1 481 КБ | 1 382 КБ |
| `main.dart.js` (без сжатия) | 5,27 МБ | 4,94 МБ |

Что дало выигрыш:
- ⚠️ **Шрифты значков (главное, −850 КБ).** Пакет `lucide_icons_flutter` объявляет 7 шрифтов; из 4 весов (100, 200, 400, 500) не используется ни один значок, и Flutter их **не обрезает, а грузит целиком до первого кадра** (~870 КБ сжатыми). Теперь три нужных шрифта лежат в `assets/fonts/lucide/` (лицензии ISC/MIT рядом), значки в `AppIcons` — своими кодами с именем в комментарии, пакет удалён. Внешне ничего не меняется (те же файлы шрифтов).
- **Отложенные разделы (−100 КБ сжатыми, пакеты `flutter_map` и `package_info_plus` ушли из первой загрузки)**: «История», «Отчёты», «Моя компания», «Настройки», «Уведомления», карта «Локаций», «Акты подрядчикам», отчёт из карточки подрядчика — через новый `DeferredView` (индикатор, при ошибке — «Не получилось…» и «Повторить»). На Android ничего не меняется.
- Оставшиеся 3,3 МБ: движок Flutter CanvasKit 1,6 МБ (с gstatic.com, это сам Flutter) и `main.dart.js` 1,4 МБ (из него ~1,8 МБ несжатых — Flutter и Dart).
- ⚠️ Не делал (выигрыш мал, риск перед заморозкой): переводы Material/Cupertino на ~80 языков (268 КБ несжатых, ~50 КБ сжатых) — на них же держатся наши даты `intl`; откладывание ещё 7 мест (камера, план этажа, «Узнать по фото» — ещё ~45 КБ); шрифт Roboto 63 КБ подгружает сам движок Flutter.
- Повторный вход на сайт берёт всё из кэша браузера — это замер худшего случая (первый визит).

**Ошибки и «вечная загрузка»:**
- ⚠️ У клиента Supabase не было предела ожидания: при «зависшей» сети (слабый Wi-Fi, подвал) любой запрос мог ждать бесконечно. Теперь **общий предел** `TimeoutHttpClient` (`lib/core/timeout_http_client.dart`): 25 с на обычный запрос, 120 с на загрузку файла, 40 с на Edge Functions (у ИИ свои 16 с). Истёк — это «ошибка сети»: включается режим без сети или показывается «Не получилось… / Повторить». Тест `test/timeout_http_client_test.dart`.
- Прошёл все экраны с загрузкой: «Повторить» уже было везде, кроме вкладок «Локации» (список и карта) и «Подрядчики» — добавил. RPC и вызовы функций — все в `try/catch` с понятным сообщением (`showAppMessage`), кнопки действий на время запроса блокируются.

### Блок 9. Экспорт реестра оборудования в Excel (помощник, проверено и слито)
- «Выгрузить в Excel» в разделе оборудования объекта и в карточке системы: колонки шаблона импорта + «Где именно», «Высота, м», «Ориентир», «Точка на плане» (только чтение), «Объект», «ID». Пакет `excel` — отложенно. Веб — скачать, Android — «Поделиться» (`saveOrShareBytes`).
- ⚠️ Обратная загрузка: строка с «ID» оборудования этого объекта **обновляет** его, без ID — добавляет; строки другого объекта не загружаются; точку на плане импорт не меняет; обновления идут по одной (не одной транзакцией). Все ячейки выгрузки — текст (номера «0012» не превращаются в числа).
- Тест `test/equipment_export_test.dart`: выгрузка → импорт → те же данные (RU и EN, xlsx туда и обратно, старый файл без новых колонок).

### Блок 10. Чек-лист утра показа
- `docs/DEMO_DAY_CHECKLIST.md`: накануне (миграции, Deploy functions, webhook `info`, APK, распечатки), утром (Refresh demo, какие строки должны быть в логах функций), входы на трёх устройствах, проверки за 10 минут, сцена «без сети», запасной план на каждый сбой, что сказать, если ИИ медленный (откат на словарь через 16 с).

## Журнал
- 14.10 22:05 UTC · ветка `step-27`, отчёт создан · первый коммит
- 14.10 23:00 · миграция 0024 + `tools/db_test/offline_sync.sql`, все тесты базы зелёные · «Шаг 27 (блоки 2–4, база)»
- 15.10 · исправления прав Н-1…Н-3 в 0024 · «Шаг 27 (блок 8)»
- 15.10 · хранилище на телефоне, очередь, часы Android, штамп «без сети» · «Шаг 27 (блоки 1–3)»
- 15.10 · карточка и список без сети, чек-лист, плашка, `offline-sync` · «Шаг 27 (блоки 1–2)»
- 15.10 · акт: три группы, решения, PDF/Excel, карточка, плашка, отчёты, демо 109/112 · «Шаг 27 (блок 4)»
- 15.10 · сквозной сценарий 17, тестовый режим, `CLAUDE.md`, `DEMO_SCRIPT.md` · «Шаг 27 (блок 5)»
- 15.10 · слиты ветки помощников: документы (блоки 7/8/10), оборудование на плане и выгрузка (блоки 6/9) · «Шаг 27: слияние…»
- 15.10 · сценарии 17 и 18 ✅, кадры 25–27 · «Шаг 27 (блок 5): кадры питча 25–27»

- 15.10 · блок 8: предел ожидания ответа сервера, «Повторить» в «Локациях» и «Подрядчиках» · «Шаг 27 (блок 8): предел ожидания…»
- 15.10 · блок 8: первая загрузка 21,5 → 17,0 с (шрифты Lucide, отложенные разделы) · «Шаг 27 (блок 8): первая загрузка сайта…»
- 15.10 · тесты базы 1 276 / 0, итоговые разделы отчёта

## Где остановился
Полная регрессия `tools/e2e` (идёт), затем `/check`, `/screens`, итог в «Проверках», PR из черновика — в готовый.

## Новые и изменённые файлы
**База и функции**
- `supabase/migrations/0024_offline_sync.sql` — новая миграция (полный текст ниже).
- `supabase/functions/offline-sync/{index,verify,verify_test}.ts` — сверка SHA-256; `supabase/config.toml`, `.github/workflows/deploy-functions.yml` — новая функция в списке.
- `supabase/seed/demo_history.sql` — блок 6c (109, 112 «требует решения»).
- `tools/db_test/offline_sync.sql` (новый), `10_fixture.sql` (строки 0024), `order_roles.sql` (файлы загружаются до вставки фото — правило Н-2).

**Приложение — без сети**
- `lib/features/offline/offline_logic.dart`, `device_clock.dart`, `offline_store.dart` (+ `_io`, `_stub`), `offline_service.dart`, `offline_banner.dart`, `proof_text.dart` — новые.
- `android/.../MainActivity.kt` — канал часов.
- `lib/core/session_controller.dart`, `lib/features/auth/auth_repository.dart` — вход без сети, очистка при выходе.
- `lib/features/requests/requests.dart` — действия через очередь, «ждёт отправки», чек-лист, снимки в очереди, блок «Доказательства»; `requests_tab.dart` — список из телефона, плашка, плашка решений; `order_checklist.dart` — новый.
- `lib/features/directory/directory.dart` — справочники с запасом на телефоне.
- `lib/features/photos/photo_stamp.dart`, `live_shot_screen.dart`, `photo_repository.dart`; `lib/features/visits/visit_repository.dart` — поля 0024.
- `lib/core/l10n_ext.dart` (`time()`), `lib/core/design/icons.dart` (флажки, «ждёт отправки»).

**Приложение — акт**
- `lib/features/acts/act_logic.dart`, `act_doc.dart`, `act_pdf.dart`, `act_xlsx.dart`, `acts_repository.dart`, `contractor_acts_screen.dart`, `proof_decisions.dart` (новый); `lib/features/reports/reports_screen.dart`.

**Приложение — оборудование (блоки 6, 9)**
- Новые: `lib/features/equipment/asset_place.dart`, `asset_place_widgets.dart`, `equipment_export.dart`, `equipment_export_action.dart`, `lib/features/floors/plan_point_picker.dart`, `point_picker_logic.dart`.
- Изменённые: `equipment_models.dart`, `equipment_form.dart`, `asset_card.dart`, `equipment_repository.dart`, `equipment_import.dart`, `equipment_import_screen.dart`, `equipment_xlsx.dart`, `equipment_section.dart`, `lib/features/systems/system_card.dart`, `floor_models.dart`, `plan_canvas.dart`, `order_plan_link.dart`, `lib/features/camera/camera_screen.dart`, `lib/core/file_share.dart`.

**Переводы**: `lib/l10n/app_ru.arb`, `app_en.arb` (+ сгенерированные).
**Тесты**: `test/offline_logic_test.dart`, `asset_place_test.dart`, `plan_point_picker_test.dart`, `equipment_export_test.dart` — новые; `act_logic_test.dart`, `live_shot_test.dart`.
**Сквозные**: `tools/e2e/scenarios.mjs` (17, 18), `build.sh` (`OFFLINE_TEST`), `tools/screens/local_backend.mjs` (`offline-sync`).
**Документы**: `CLAUDE.md`, `docs/DEMO_SCRIPT.md`, `docs/DEMO_SETUP.md`, `docs/DEMO_DAY_CHECKLIST.md` (новый), `docs/security/review-2026-10.md` (новый), `docs/screens/pitch/README.md` + кадры 25–27.

## Проверки
<!-- PROVERKI -->

## Что сделать вам (по порядку)
1. Проверить и слить PR (кнопка Merge в GitHub).
2. Если ещё не применена — **0023** (шаг 26): Actions → «Apply migration» → `file` = `0023_order_roles_photo_proof.sql` → Run → прочитать текст → Review deployments → `production-db` → Approve and deploy. Написать мне «применена 0023».
3. Затем **0024**: так же, `file` = `0024_offline_sync.sql`. Написать «применена 0024».
4. **Deploy functions** (Actions → Deploy functions → Run workflow, ветка `main` → Approve): выкладывает новую `offline-sync` и `photo-identify` шага 26. Без неё фото, снятые без сети, попадут в «Требует решения».
5. **Refresh demo** (после 0024): демо-заявки 109 и 112 появятся в акте как «Требует решения менеджера».
6. Скачать свежий APK по постоянной ссылке (часы для работы без сети есть только в новом APK).
7. Накануне и утром показа — по `docs/DEMO_DAY_CHECKLIST.md`.
8. После 0023/0024 и Deploy functions — переснять кадры 18 и 21: `cd tools/screens && node screens.mjs --pitch --only=18,21` (или попросить меня).

## Как проверить руками
- **Без сети (телефон, APK)**: войти исполнителем «КлиматСервис» при сети → открыть «Заявки» → включить режим полёта → сверху «Нет сети · данные на ЧЧ:ММ» → открыть назначенную заявку → «Начать работу», отметить пункты чек-листа, снять фото «после» (на штампе — «без сети»), «На проверку» → у заявки «ждёт отправки» → выключить режим полёта → через несколько секунд «Отправлено», заявка «На проверке».
- **Акт**: менеджером на ПК → «Отчёты» → «Акты подрядчикам» → «КлиматСервис» → три группы «К оплате / Требует решения / Не к оплате» → у 109 или 112 «Подтвердить к оплате» с комментарием → строка переходит в «К оплате» с пометкой «решение менеджера».
- **Оборудование на плане**: карточка объекта «БЦ «Демо»» → «Оборудование» → «Кондиционер КД-301» → «Место на плане · Изменить» → поставить точку, «Где именно» — потолок, 2,8 м → «Готово» → «Показать на плане».
- **Выгрузка в Excel**: раздел «Оборудование» объекта → «Выгрузить в Excel» → поправить модель в файле → «Импорт» этого же файла → модель обновилась.
- **Первая загрузка сайта**: открыть сайт в новом окне инкогнито на телефоне — экран входа появляется заметно быстрее; «Отчёты», «История», карта «Локаций» на первом открытии на долю секунды показывают индикатор (догружаются).
- **Ошибки**: на ПК открыть «Локации», в DevTools включить Offline → «Обновить» → «Не получилось загрузить объекты» и «Повторить»; выключить Offline → «Повторить» → список.

## Ограничения и что не сделано
- Работа без сети — **только в APK**; в браузере данные на телефоне не хранятся (кроме тестового режима `OFFLINE_TEST` для сквозных сценариев).
- Кадры 17, 18, 21 на рабочей базе не переснимал (0023/0024 и Deploy functions ещё не выполнены; для кадра 17 нужен второй менеджер — инструкция в `docs/DEMO_SETUP.md`).
- Первая загрузка: не урезал переводы Material на ~80 языков, не откладывал камеру и план этажа (см. «Блок 8: загрузка и ошибки»); 1,6 МБ движка CanvasKit — свойство Flutter.
- Мелочи из проверки прав не исправлял: строку истории `work_logs` может добавить любой, кто видит заявку; телефоны сотрудников видны всей компании (`docs/security/review-2026-10.md`).
- Фото места оборудования хранится в папке этажа `floor-plans` — только если у помещения или точки есть этаж; при удалении этажа файл не удаляется.
- Импорт выгрузки обновляет единицы по одной, не одной транзакцией.

## Полный текст миграции 0024
**Зачем**: работа исполнителя без интернета с честными доказательствами (очередь действий, доверенное время, отпечаток фото, конфликты), решения менеджера по сомнительным доказательствам в акте и три исправления прав (Н-1…Н-3). **Повторный запуск безопасен** (`if not exists`, `create or replace`, `drop … if exists`; локально все новые миграции прогоняются дважды). **Требует 0023.**

```sql
-- =====================================================================
-- hey_helpy · Миграция 0024: работа без интернета (шаг 27)
--
-- Исполнитель без сети начинает работу, отмечает визит, чек-лист, снимает
-- фото «после» и сдаёт на проверку — телефон копит действия в очереди и
-- отправляет их, когда появится сеть. Доказательства остаются честными.
--
-- 1) offline_sync(p_actions) — принимает очередь одной транзакцией, по
--    порядку. Права — те же триггеры и функции шага 26 (wo_is_executor,
--    trg_wo_status_flow, trg_wo_guard, trg_checklist_guard): функция лишь
--    подставляет «время действия» вместо now() (hh_now()). Повтор действия
--    с тем же id ничего не дублирует (offline_actions).
-- 2) Честное время: «доверенное» = время сервера при последней связи
--    + монотонные часы телефона (offline_clock_anchors, якорь пишет только
--    сервер), иначе время GPS-фикса. Расхождение с часами телефона > 5 мин —
--    time_trust = 'unverified'; нет ни того, ни другого — 'device_only'.
-- 3) Отпечаток фото: SHA-256 в момент съёмки; Edge Function offline-sync
--    пересчитывает по загруженному файлу (offline_photo_hashes, пишет только
--    service_role). Не совпало — фото отклоняется.
-- 4) Конфликты: заявку отменили / передали другому / уже приняли — действие
--    отклоняется с причиной, но фото «после» всё равно сохраняется в заявке
--    с пометкой sync_note (after_cancel / after_reassign / after_close).
-- 5) act_proof_decisions — решения менеджера по сомнительным
--    доказательствам в акте («Подтвердить к оплате» / «Не принимать»):
--    только через act_proof_decide(), строки не меняются и не удаляются
--    (каждое изменение — новая строка = журнал).
--
-- 6) Исправления проверки прав (docs/security/review-2026-10.md):
--    Н-1 set_member_role — менеджер с зоной ролей не меняет;
--    Н-2 attachments_insert — фото только из папки своей заявки и только
--        файл, уже загруженный этим же человеком;
--    Н-3 report_links_select — менеджер с зоной видит только ссылки своих
--        объектов, ссылку компании — только администратор.
--
-- Требует 0023. Повторный запуск безопасен: if not exists, create or
-- replace, drop … if exists.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. «Сейчас» с учётом офлайн-действия
--    offline_sync ставит hh.offline = 1 и hh.offline_at = время действия
--    на время одного действия (set_config … true). Из приложения эти
--    настройки задать нельзя: PostgREST не выполняет произвольный SQL.
-- ---------------------------------------------------------------------
create or replace function public.hh_now()
returns timestamptz language sql stable set search_path = public as $$
  select coalesce(
    case when coalesce(current_setting('hh.offline', true), '') = '1'
         then nullif(current_setting('hh.offline_at', true), '')::timestamptz end,
    now());
$$;
revoke all on function public.hh_now() from public, anon;
grant execute on function public.hh_now() to authenticated;

create or replace function public.hh_offline()
returns boolean language sql stable set search_path = public as $$
  select coalesce(current_setting('hh.offline', true), '') = '1';
$$;
revoke all on function public.hh_offline() from public, anon;
grant execute on function public.hh_offline() to authenticated;

-- ---------------------------------------------------------------------
-- 2. Новые столбцы: вложения и визиты
-- ---------------------------------------------------------------------
alter table public.attachments
  add column if not exists offline      boolean not null default false,
  add column if not exists time_trust   text not null default 'online',
  add column if not exists trusted_at   timestamptz,
  add column if not exists time_drift_s integer,
  add column if not exists synced_at    timestamptz,
  add column if not exists sha256       text,
  add column if not exists sha256_ok    boolean,
  add column if not exists sync_note    text;

alter table public.attachments drop constraint if exists attachments_time_trust_check;
alter table public.attachments add constraint attachments_time_trust_check
  check (time_trust in ('online', 'gps', 'monotonic', 'device_only', 'unverified'));
alter table public.attachments drop constraint if exists attachments_sha256_check;
alter table public.attachments add constraint attachments_sha256_check
  check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$');
alter table public.attachments drop constraint if exists attachments_sync_note_check;
alter table public.attachments add constraint attachments_sync_note_check
  check (sync_note is null or sync_note in ('after_cancel', 'after_reassign', 'after_close'));

alter table public.visits
  add column if not exists offline      boolean not null default false,
  add column if not exists time_trust   text not null default 'online',
  add column if not exists claimed_at   timestamptz,
  add column if not exists trusted_at   timestamptz,
  add column if not exists time_drift_s integer,
  add column if not exists synced_at    timestamptz;

alter table public.visits drop constraint if exists visits_time_trust_check;
alter table public.visits add constraint visits_time_trust_check
  check (time_trust in ('online', 'gps', 'monotonic', 'device_only', 'unverified'));

-- Офлайн-пометки ставит только offline_sync (или обслуживание). Обычная
-- вставка из приложения — «online», без доверенного времени; потом эти
-- столбцы не меняет никто.
create or replace function public.trg_attachments_offline()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;
  if tg_op = 'UPDATE' then
    new.offline      := old.offline;
    new.time_trust   := old.time_trust;
    new.trusted_at   := old.trusted_at;
    new.time_drift_s := old.time_drift_s;
    new.synced_at    := old.synced_at;
    new.sha256       := old.sha256;
    new.sha256_ok    := old.sha256_ok;
    new.sync_note    := old.sync_note;
    return new;
  end if;
  if not public.hh_offline() then
    new.offline      := false;
    new.time_trust   := 'online';
    new.trusted_at   := null;
    new.time_drift_s := null;
    new.synced_at    := null;
    new.sha256_ok    := null;
    new.sync_note    := null;
  end if;
  return new;
end $$;
revoke all on function public.trg_attachments_offline() from public, anon, authenticated;
drop trigger if exists trg_attachments_offline on public.attachments;
create trigger trg_attachments_offline
  before insert or update on public.attachments
  for each row execute function public.trg_attachments_offline();

create or replace function public.trg_visits_offline()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;
  if tg_op = 'UPDATE' then
    new.offline      := old.offline;
    new.time_trust   := old.time_trust;
    new.claimed_at   := old.claimed_at;
    new.trusted_at   := old.trusted_at;
    new.time_drift_s := old.time_drift_s;
    new.synced_at    := old.synced_at;
    return new;
  end if;
  if not public.hh_offline() then
    new.offline      := false;
    new.time_trust   := 'online';
    new.claimed_at   := null;
    new.trusted_at   := null;
    new.time_drift_s := null;
    new.synced_at    := null;
  end if;
  return new;
end $$;
revoke all on function public.trg_visits_offline() from public, anon, authenticated;
drop trigger if exists trg_visits_offline on public.visits;
create trigger trg_visits_offline
  before insert or update on public.visits
  for each row execute function public.trg_visits_offline();

-- ---------------------------------------------------------------------
-- 3. Время действий: прежние триггеры, но вместо now() — hh_now()
--    (без офлайн-синхронизации hh_now() = now(), поведение не меняется).
-- ---------------------------------------------------------------------

-- 3a. Визит (0009): время начала и окончания.
create or replace function public.trg_visits_fill()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_wo   record;
  v_obj  record;
  v_tol  double precision;
begin
  if tg_op = 'UPDATE' then
    new.id            := old.id;
    new.company_id    := old.company_id;
    new.object_id     := old.object_id;
    new.profile_id    := old.profile_id;
    new.contractor_id := old.contractor_id;
    new.work_order_id := old.work_order_id;
    new.started_at    := old.started_at;
    new.source        := old.source;
    new.lat           := old.lat;
    new.lng           := old.lng;
    new.accuracy_m    := old.accuracy_m;
    new.distance_m    := old.distance_m;
    new.in_geofence   := old.in_geofence;
    new.mock_location := old.mock_location;
    new.created_at    := old.created_at;
    if old.ended_at is not null then
      new.ended_at := old.ended_at;
    elsif new.ended_at is not null then
      new.ended_at := greatest(old.started_at, public.hh_now());
    end if;
    return new;
  end if;

  if new.work_order_id is null then
    raise exception 'visit: work order required';
  end if;
  select w.company_id, w.object_id, w.assigned_contractor_id into v_wo
    from work_orders w where w.id = new.work_order_id;
  if not found then
    raise exception 'visit: work order not found';
  end if;
  if v_wo.object_id is null then
    raise exception 'visit: work order has no object';
  end if;

  new.company_id    := v_wo.company_id;
  new.object_id     := v_wo.object_id;
  new.contractor_id := v_wo.assigned_contractor_id;
  new.started_at    := public.hh_now();
  new.ended_at      := null;
  new.source        := 'geofence';
  new.created_at    := now();
  new.mock_location := coalesce(new.mock_location, false);

  if new.lat is null or new.lng is null
     or new.lat not between -90 and 90 or new.lng not between -180 and 180 then
    new.lat := null; new.lng := null;
  end if;
  if new.accuracy_m is not null and (new.accuracy_m < 0 or new.accuracy_m > 100000) then
    new.accuracy_m := null;
  end if;

  select o.lat, o.lng, o.geofence_radius_m into v_obj from objects o where o.id = new.object_id;
  if new.lat is null or v_obj.lat is null or v_obj.lng is null then
    new.distance_m  := null;
    new.in_geofence := null;
  else
    new.distance_m := 2 * 6371000 * asin(sqrt(
        power(sin(radians(new.lat - v_obj.lat) / 2), 2)
      + cos(radians(v_obj.lat)) * cos(radians(new.lat))
      * power(sin(radians(new.lng - v_obj.lng) / 2), 2)));
    v_tol := least(coalesce(new.accuracy_m, 0), 50);
    new.in_geofence := new.distance_m <= v_obj.geofence_radius_m + v_tol;
  end if;
  return new;
end $$;
revoke all on function public.trg_visits_fill() from public, anon, authenticated;

-- 3b. Визит закрывается, когда заявка выходит из «в работе» (0009).
create or replace function public.trg_wo_close_visits()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update visits set ended_at = public.hh_now()
   where work_order_id = new.id and ended_at is null;
  return null;
end $$;
revoke all on function public.trg_wo_close_visits() from public, anon, authenticated;

-- 3c. Смена статуса (0023) — те же правила, время — hh_now().
create or replace function public.trg_wo_status_flow()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_mgr    boolean;
  v_author boolean;
  v_exec   boolean;
  v_now    timestamptz := public.hh_now();
  f text;
  t text := new.status;
begin
  if v_uid is null then return new; end if;

  if tg_op = 'INSERT' then
    if new.status not in ('new', 'assigned') then
      raise exception 'status change -> % not allowed', new.status using errcode = '42501';
    end if;
    new.started_at   := null;
    new.submitted_at := null;
    new.submitted_by := null;
    new.accepted_at  := null;
    new.accepted_by  := null;
    return new;
  end if;

  new.submitted_by := old.submitted_by;
  f := old.status;
  if f = t then return new; end if;

  v_mgr    := public.wo_is_manager(old.id);
  v_author := old.created_by = v_uid;
  v_exec   := public.wo_is_executor(old.id);

  if t = 'assigned' and f in ('new', 'returned') and (v_mgr or (v_author and f = 'new')) then
    null;
  elsif t = 'in_progress' and f in ('new', 'assigned', 'returned') and v_exec then
    new.started_at := coalesce(old.started_at, v_now);
  elsif t = 'on_review' and f = 'in_progress' and v_exec then
    if old.requires_photo and not exists (
         select 1 from attachments a
          where a.work_order_id = old.id and a.kind = 'photo'
            and coalesce(a.stage, 'after') = 'after') then
      raise exception 'photo required' using hint = 'Прикрепите фото выполненной работы';
    end if;
    new.submitted_at := greatest(v_now, coalesce(old.started_at, v_now));
    new.submitted_by := v_uid;
    if old.started_at is not null then
      new.time_spent_minutes := greatest(1, ceil(extract(epoch from new.submitted_at - old.started_at) / 60))::int;
    end if;
  elsif t in ('done', 'returned') and f = 'on_review' and v_mgr
        and old.submitted_by is not distinct from v_uid then
    raise exception 'status change % -> % not allowed: same person submitted', f, t
      using errcode = '42501', hint = 'Принять должен другой менеджер';
  elsif t = 'done' and f = 'on_review' and v_mgr then
    new.accepted_at := now();
    new.accepted_by := v_uid;
  elsif t = 'returned' and f = 'on_review' and v_mgr then
    if coalesce(trim(new.return_reason), '') = '' then
      raise exception 'return reason required' using hint = 'Укажите, что не так';
    end if;
  elsif t = 'cancelled' and f not in ('done', 'cancelled')
        and (v_mgr or (v_author and f in ('new', 'assigned'))) then
    null;
  else
    raise exception 'status change % -> % not allowed', f, t using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.trg_wo_status_flow() from public, anon, authenticated;

-- 3d. Отметка чек-листа (0023) — время отметки hh_now().
create or replace function public.trg_checklist_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_exec boolean;
begin
  if v_uid is null then return new; end if;
  if tg_op = 'INSERT' then
    new.is_done := false;
    new.done_at := null;
    new.done_by := null;
    return new;
  end if;
  v_exec := public.wo_is_executor(old.work_order_id);
  if new.is_done is distinct from old.is_done then
    if not v_exec then
      raise exception 'checklist is checked by contractor executor only' using errcode = '42501';
    end if;
    new.done_by := case when new.is_done then v_uid end;
    new.done_at := case when new.is_done then public.hh_now() end;
  else
    new.done_by := old.done_by;
    new.done_at := old.done_at;
  end if;
  if not public.is_manager()
     and (new.text is distinct from old.text or new.work_order_id is distinct from old.work_order_id) then
    raise exception 'forbidden: executor can check items only' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.trg_checklist_guard() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Каким подрядчикам заявка была назначена (для фото «после», которые
--    пришли, когда заявку уже передали другому). Ведёт только база.
-- ---------------------------------------------------------------------
create table if not exists public.wo_contractor_history (
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  contractor_id uuid not null references public.contractors(id) on delete cascade,
  company_id    uuid not null references public.companies(id) on delete cascade,
  first_at      timestamptz not null default now(),
  primary key (work_order_id, contractor_id)
);
alter table public.wo_contractor_history enable row level security;
revoke all on public.wo_contractor_history from anon;
grant select on public.wo_contractor_history to authenticated;

drop policy if exists wo_contractor_history_select on public.wo_contractor_history;
create policy wo_contractor_history_select on public.wo_contractor_history for select using (
  company_id = (select public.my_company_id())
  and ((select public.is_manager()) or contractor_id in (select public.my_contractor_ids())));

create or replace function public.trg_wo_contractor_history()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.assigned_contractor_id is not null
     and (tg_op = 'INSERT' or new.assigned_contractor_id is distinct from old.assigned_contractor_id) then
    insert into wo_contractor_history(work_order_id, contractor_id, company_id)
    values (new.id, new.assigned_contractor_id, new.company_id)
    on conflict do nothing;
  end if;
  return null;
end $$;
revoke all on function public.trg_wo_contractor_history() from public, anon, authenticated;
drop trigger if exists trg_wo_contractor_history on public.work_orders;
create trigger trg_wo_contractor_history
  after insert or update of assigned_contractor_id on public.work_orders
  for each row execute function public.trg_wo_contractor_history();

-- нынешние назначения (повторно — ничего не добавит)
insert into public.wo_contractor_history(work_order_id, contractor_id, company_id, first_at)
select w.id, w.assigned_contractor_id, w.company_id, w.created_at
  from public.work_orders w
 where w.assigned_contractor_id is not null
on conflict do nothing;

-- Был ли пользователь исполнителем подрядчика, которому назначали заявку.
create or replace function public.wo_was_executor(p_order uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from wo_contractor_history h
      join work_orders w on w.id = h.work_order_id
     where h.work_order_id = p_order
       and w.company_id = public.my_company_id()
       and h.contractor_id in (select public.my_contractor_ids()));
$$;
revoke all on function public.wo_was_executor(uuid) from public, anon;
grant execute on function public.wo_was_executor(uuid) to authenticated;

-- Хранилище: фото из очереди (`…/off_<id>.jpg`) можно положить и в
-- заявку, которую уже отменили, приняли или передали другому, — если
-- она была у подрядчика пользователя. Работа не пропадает; доказательством
-- такое фото автоматически не считается (sync_note).
drop policy if exists work_photos_insert_offline on storage.objects;
create policy work_photos_insert_offline on storage.objects for insert to authenticated with check (
  bucket_id = 'work-photos'
  and objects.name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/off_[0-9a-f-]{36}\.jpg$'
  and exists (select 1 from public.work_orders w
               where w.id::text = (storage.foldername(objects.name))[2]
                 and w.company_id::text = (storage.foldername(objects.name))[1]
                 and w.company_id = (select public.my_company_id())
                 and public.wo_was_executor(w.id)));

-- ---------------------------------------------------------------------
-- 5. Якоря часов: «время сервера ↔ монотонные часы телефона»
-- ---------------------------------------------------------------------
create table if not exists public.offline_clock_anchors (
  id         bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  boot_id    text not null check (length(boot_id) between 1 and 80),
  mono_ms    bigint not null check (mono_ms >= 0),
  server_at  timestamptz not null default now()
);
create index if not exists idx_offline_clock_anchors
  on public.offline_clock_anchors (profile_id, boot_id, mono_ms desc);
alter table public.offline_clock_anchors enable row level security;
revoke all on public.offline_clock_anchors from anon;
grant select on public.offline_clock_anchors to authenticated;
drop policy if exists offline_clock_anchors_select on public.offline_clock_anchors;
create policy offline_clock_anchors_select on public.offline_clock_anchors for select using (
  profile_id = (select auth.uid()) and company_id = (select public.my_company_id()));

-- Записать якорь и вернуть время сервера. Не чаще раза в минуту на одну
-- загрузку телефона; старше 30 дней — удаляются.
create or replace function public.offline_clock(p_boot text, p_mono_ms bigint)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_company uuid := public.my_company_id();
begin
  if v_uid is null or v_company is null then
    raise exception 'offline_denied' using errcode = '42501';
  end if;
  if p_boot is null or length(p_boot) not between 1 and 80 or p_mono_ms is null or p_mono_ms < 0 then
    raise exception 'offline_bad_clock' using errcode = '22023';
  end if;
  if not exists (select 1 from offline_clock_anchors a
                  where a.profile_id = v_uid and a.boot_id = p_boot
                    and a.server_at > now() - interval '1 minute') then
    insert into offline_clock_anchors(profile_id, company_id, boot_id, mono_ms)
    values (v_uid, v_company, p_boot, p_mono_ms);
    delete from offline_clock_anchors
     where profile_id = v_uid and server_at < now() - interval '30 days';
  end if;
  return now();
end $$;
revoke all on function public.offline_clock(text, bigint) from public, anon;
grant execute on function public.offline_clock(text, bigint) to authenticated;

-- Доверенное время действия: (trust, trusted_at, drift_s).
--   monotonic — якорь этой загрузки телефона + прошедшие миллисекунды;
--   gps       — время спутников (телефон пересчитал его к моменту действия);
--   оба есть и расходятся > 5 мин, или часы телефона расходятся с
--   доверенным > 5 мин — unverified; нет ни того, ни другого — device_only.
create or replace function public.offline_time(
  p_device timestamptz, p_gps timestamptz, p_boot text, p_mono_ms bigint,
  out trust text, out trusted_at timestamptz, out drift_s integer)
language plpgsql stable security definer set search_path = public as $$
declare
  v_mono timestamptz;
  v_gps  timestamptz;
  v_anchor record;
begin
  if p_boot is not null and p_mono_ms is not null then
    select a.server_at, a.mono_ms into v_anchor
      from offline_clock_anchors a
     where a.profile_id = auth.uid() and a.boot_id = p_boot and a.mono_ms <= p_mono_ms
     order by a.mono_ms desc limit 1;
    if found then
      v_mono := v_anchor.server_at + make_interval(secs => (p_mono_ms - v_anchor.mono_ms) / 1000.0);
      if v_mono > now() + interval '1 minute' then v_mono := null; end if;
    end if;
  end if;
  if p_gps is not null and p_gps <= now() + interval '2 minutes'
     and p_gps > now() - interval '60 days' then
    v_gps := p_gps;
  end if;

  if v_mono is not null then
    trust := 'monotonic'; trusted_at := v_mono;
    if v_gps is not null and abs(extract(epoch from v_gps - v_mono)) > 300 then
      trust := 'unverified';
    end if;
  elsif v_gps is not null then
    trust := 'gps'; trusted_at := v_gps;
  else
    trust := 'device_only';
    trusted_at := least(coalesce(p_device, now()), now());
    drift_s := null;
    return;
  end if;
  if p_device is not null then
    drift_s := round(extract(epoch from p_device - trusted_at))::int;
    if abs(drift_s) > 300 then trust := 'unverified'; end if;
  end if;
  trusted_at := least(trusted_at, now());
end $$;
revoke all on function public.offline_time(timestamptz, timestamptz, text, bigint) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. Отпечатки загруженных фото — пишет только Edge Function offline-sync
--    (service_role), пересчитав SHA-256 по файлу в хранилище.
-- ---------------------------------------------------------------------
create table if not exists public.offline_photo_hashes (
  storage_path text primary key,
  company_id   uuid not null references public.companies(id) on delete cascade,
  sha256       text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  verified_at  timestamptz not null default now()
);
alter table public.offline_photo_hashes enable row level security;
revoke all on public.offline_photo_hashes from anon;
grant select on public.offline_photo_hashes to authenticated;
drop policy if exists offline_photo_hashes_select on public.offline_photo_hashes;
create policy offline_photo_hashes_select on public.offline_photo_hashes for select using (
  company_id = (select public.my_company_id()) and (select public.is_manager()));

create or replace function public.offline_photo_hash_put(p_path text, p_sha256 text)
returns void language plpgsql security definer set search_path = public as $$
declare v_company uuid;
begin
  if p_path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/off_[0-9a-f-]{36}\.jpg$' or p_sha256 !~ '^[0-9a-f]{64}$' then
    raise exception 'offline_bad_hash' using errcode = '22023';
  end if;
  select w.company_id into v_company from work_orders w
   where w.id::text = split_part(p_path, '/', 2) and w.company_id::text = split_part(p_path, '/', 1);
  if v_company is null then
    raise exception 'offline_bad_hash' using errcode = '22023';
  end if;
  insert into offline_photo_hashes(storage_path, company_id, sha256)
  values (p_path, v_company, p_sha256)
  on conflict (storage_path) do update set sha256 = excluded.sha256, verified_at = now();
end $$;
revoke all on function public.offline_photo_hash_put(text, text) from public, anon, authenticated;
grant execute on function public.offline_photo_hash_put(text, text) to service_role;

-- ---------------------------------------------------------------------
-- 7. Журнал принятых офлайн-действий (защита от дублей)
-- ---------------------------------------------------------------------
create table if not exists public.offline_actions (
  id            uuid primary key,
  company_id    uuid not null references public.companies(id) on delete cascade,
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  work_order_id uuid references public.work_orders(id) on delete cascade,
  kind          text not null check (kind in ('start', 'visit', 'check', 'photo', 'submit')),
  device_at     timestamptz,
  trusted_at    timestamptz,
  time_trust    text not null check (time_trust in ('gps', 'monotonic', 'device_only', 'unverified')),
  time_drift_s  integer,
  result        text not null check (result in ('applied', 'rejected', 'saved_late')),
  reason        text,
  synced_at     timestamptz not null default now()
);
create index if not exists idx_offline_actions_order on public.offline_actions (work_order_id, synced_at);
alter table public.offline_actions enable row level security;
revoke all on public.offline_actions from anon;
grant select on public.offline_actions to authenticated;
drop policy if exists offline_actions_select on public.offline_actions;
create policy offline_actions_select on public.offline_actions for select using (
  company_id = (select public.my_company_id())
  and (profile_id = (select auth.uid())
       or ((select public.is_manager()) and public.wo_is_manager(work_order_id))));

-- Почему действие больше не применимо — по нынешнему состоянию заявки.
create or replace function public.offline_conflict(p_order uuid, p_kind text)
returns text language plpgsql stable security definer set search_path = public as $$
declare w record;
begin
  select status, assigned_contractor_id, requires_photo into w
    from work_orders where id = p_order and company_id = public.my_company_id();
  if not found then return 'not_found'; end if;
  if not public.wo_was_executor(p_order) then return 'denied'; end if;
  if w.status = 'cancelled' then return 'cancelled'; end if;
  if w.assigned_contractor_id is null
     or w.assigned_contractor_id not in (select public.my_contractor_ids()) then
    return 'reassigned';
  end if;
  if w.status = 'done' then return 'accepted'; end if;
  if w.status = 'on_review' then return 'on_review'; end if;
  if p_kind = 'submit' and w.requires_photo then return 'photo_required'; end if;
  if not public.wo_is_executor(p_order) then return 'denied'; end if;
  return 'state';
end $$;
revoke all on function public.offline_conflict(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 8. Принять очередь
--    p_actions — массив по порядку:
--    {id, kind, order_id, device_at, gps_at?, boot?, mono_ms?, ...}
--      start  — «Начать работу»
--      visit  — lat, lng, accuracy, mock
--      check  — item_id, done
--      photo  — path (<компания>/<заявка>/off_<id>.jpg), sha256, lat, lng, mock
--      submit — «Выполнено, на проверку»
--    Ответ: [{id, result: applied | rejected | saved_late, reason?, trust}].
--    Каждое действие — в своей подтранзакции: ошибка одного не откатывает
--    остальные. Права проверяют те же триггеры и функции шага 26.
-- ---------------------------------------------------------------------
create or replace function public.offline_sync(p_actions jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_company uuid := public.my_company_id();
  a         jsonb;
  v_id      uuid;
  v_kind    text;
  v_order   uuid;
  v_device  timestamptz;
  v_gps     timestamptz;
  v_time    record;
  v_result  text;
  v_reason  text;
  v_prev    record;
  v_status  text;
  v_path    text;
  v_sha     text;
  v_known   text;
  v_note    text;
  v_n       int;
  v_out     jsonb := '[]'::jsonb;
begin
  if v_uid is null or v_company is null then
    raise exception 'offline_denied' using errcode = '42501';
  end if;
  if jsonb_typeof(p_actions) <> 'array' or jsonb_array_length(p_actions) > 200 then
    raise exception 'offline_bad_payload' using errcode = '22023';
  end if;

  for a in select value from jsonb_array_elements(p_actions) loop
    v_result := null; v_reason := null; v_note := null;
    begin
      v_id     := (a->>'id')::uuid;
      v_kind   := a->>'kind';
      v_order  := (a->>'order_id')::uuid;
      v_device := (a->>'device_at')::timestamptz;
      v_gps    := (a->>'gps_at')::timestamptz;
    exception when others then
      v_out := v_out || jsonb_build_object('id', a->>'id', 'result', 'rejected', 'reason', 'bad_action');
      continue;
    end;
    if v_id is null or v_order is null
       or v_kind not in ('start', 'visit', 'check', 'photo', 'submit') then
      v_out := v_out || jsonb_build_object('id', a->>'id', 'result', 'rejected', 'reason', 'bad_action');
      continue;
    end if;

    -- повтор: тот же ответ, ничего не делаем
    select o.result, o.reason, o.time_trust, o.profile_id into v_prev
      from offline_actions o where o.id = v_id;
    if found then
      if v_prev.profile_id <> v_uid then
        v_out := v_out || jsonb_build_object('id', v_id, 'result', 'rejected', 'reason', 'denied');
      else
        v_out := v_out || jsonb_build_object('id', v_id, 'result', v_prev.result,
                                             'reason', v_prev.reason, 'trust', v_prev.time_trust, 'repeat', true);
      end if;
      continue;
    end if;

    select * into v_time from public.offline_time(
      v_device, v_gps, a->>'boot', nullif(a->>'mono_ms', '')::bigint);
    perform set_config('hh.offline', '1', true);
    perform set_config('hh.offline_at', v_time.trusted_at::text, true);

    begin
      select status into v_status from work_orders
       where id = v_order and company_id = v_company;
      if not found then
        raise exception 'offline:not_found';
      end if;

      if v_kind = 'start' then
        if v_status = 'in_progress' then
          if not public.wo_is_executor(v_order) then
            raise exception 'offline:conflict';
          end if;
          v_result := 'applied';  -- уже в работе
        else
          update work_orders set status = 'in_progress' where id = v_order;
          v_result := 'applied';
        end if;

      elsif v_kind = 'visit' then
        if v_status <> 'in_progress' or not public.wo_is_executor(v_order) then
          raise exception 'offline:conflict';
        end if;
        if exists (select 1 from visits where work_order_id = v_order
                     and profile_id = v_uid and ended_at is null) then
          v_result := 'applied';  -- визит уже открыт
        else
          insert into visits(work_order_id, company_id, profile_id, lat, lng, accuracy_m, mock_location,
                             offline, time_trust, claimed_at, trusted_at, time_drift_s, synced_at)
          values (v_order, v_company, v_uid,
                  (a->>'lat')::double precision, (a->>'lng')::double precision,
                  (a->>'accuracy')::double precision, coalesce((a->>'mock')::boolean, false),
                  true, v_time.trust, v_device, v_time.trusted_at, v_time.drift_s, now());
          v_result := 'applied';
        end if;

      elsif v_kind = 'check' then
        update checklist_items set is_done = coalesce((a->>'done')::boolean, true)
         where id = (a->>'item_id')::uuid and work_order_id = v_order;
        get diagnostics v_n = row_count;
        if v_n = 0 then raise exception 'offline:not_found'; end if;
        v_result := 'applied';

      elsif v_kind = 'photo' then
        v_path := a->>'path';
        v_sha  := lower(a->>'sha256');
        if v_path is null
           or v_path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/off_[0-9a-f-]{36}\.jpg$'
           or split_part(v_path, '/', 1) <> v_company::text
           or split_part(v_path, '/', 2) <> v_order::text
           or v_sha is null or v_sha !~ '^[0-9a-f]{64}$' then
          raise exception 'offline:bad_photo';
        end if;
        if not exists (select 1 from storage.objects so
                        where so.bucket_id = 'work-photos' and so.name = v_path
                          and so.owner_id = v_uid::text) then
          raise exception 'offline:photo_missing';
        end if;
        select h.sha256 into v_known from offline_photo_hashes h where h.storage_path = v_path;
        if v_known is not null and v_known <> v_sha then
          raise exception 'offline:photo_hash_mismatch';
        end if;
        if exists (select 1 from attachments where storage_path = v_path) then
          v_result := 'applied';  -- уже сохранено
        else
          if v_status = 'in_progress' and public.wo_is_executor(v_order) then
            v_result := 'applied';
          elsif public.wo_was_executor(v_order) then
            -- работа не пропадает: фото сохраняется с пометкой
            v_note := case
              when v_status = 'cancelled' then 'after_cancel'
              when not public.wo_is_executor(v_order) then 'after_reassign'
              else 'after_close' end;
            v_result := 'saved_late';
            v_reason := public.offline_conflict(v_order, v_kind);
          else
            raise exception 'offline:conflict';
          end if;
          insert into attachments(work_order_id, kind, stage, storage_path, taken_at, lat, lng,
                                  mock_location, uploaded_by, source, offline, time_trust,
                                  trusted_at, time_drift_s, synced_at, sha256, sha256_ok, sync_note)
          values (v_order, 'photo', 'after', v_path, v_device,
                  (a->>'lat')::double precision, (a->>'lng')::double precision,
                  coalesce((a->>'mock')::boolean, false), v_uid, 'camera', true, v_time.trust,
                  v_time.trusted_at, v_time.drift_s, now(), v_sha,
                  case when v_known is null then null else true end, v_note);
        end if;

      elsif v_kind = 'submit' then
        if v_status = 'on_review' and exists (
             select 1 from work_orders where id = v_order and submitted_by = v_uid) then
          v_result := 'applied';  -- уже сдано этим же исполнителем
        else
          update work_orders set status = 'on_review' where id = v_order;
          v_result := 'applied';
        end if;
      end if;
    exception when others then
      -- подтранзакция откатилась; причину — по нынешнему состоянию заявки
      v_result := 'rejected';
      v_reason := case
        when sqlerrm = 'offline:not_found' then 'not_found'
        when sqlerrm = 'offline:bad_photo' then 'bad_photo'
        when sqlerrm = 'offline:photo_missing' then 'photo_missing'
        when sqlerrm = 'offline:photo_hash_mismatch' then 'photo_hash_mismatch'
        when sqlerrm = 'photo required' then 'photo_required'
        else public.offline_conflict(v_order, v_kind) end;
    end;

    perform set_config('hh.offline', '', true);
    perform set_config('hh.offline_at', '', true);

    insert into offline_actions(id, company_id, profile_id, work_order_id, kind, device_at, trusted_at,
                                time_trust, time_drift_s, result, reason)
    values (v_id, v_company, v_uid,
            case when exists (select 1 from work_orders where id = v_order and company_id = v_company)
                 then v_order end,
            v_kind, v_device, v_time.trusted_at, v_time.trust, v_time.drift_s, v_result, v_reason);
    v_out := v_out || jsonb_build_object('id', v_id, 'result', v_result, 'reason', v_reason,
                                         'trust', v_time.trust, 'drift_s', v_time.drift_s);
  end loop;
  return v_out;
end $$;
revoke all on function public.offline_sync(jsonb) from public, anon;
grant execute on function public.offline_sync(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 9. Решения менеджера по сомнительным доказательствам в акте
--    Строки только добавляются: последнее решение по заявке — действующее,
--    предыдущие — журнал. Решать может менеджер с правом на заявку или
--    администратор, но не исполнитель и не тот, кто сдал работу. Пока
--    заявка входит в действующий (не заменённый) акт — решение не меняется.
-- ---------------------------------------------------------------------
create table if not exists public.act_proof_decisions (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade,
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  decision      text not null check (decision in ('approve', 'reject')),
  reason        text check (reason is null or length(reason) <= 500),
  decided_by    uuid references public.profiles(id) on delete set null,
  decided_at    timestamptz not null default now()
);
create index if not exists idx_act_proof_decisions_order
  on public.act_proof_decisions (work_order_id, decided_at desc);
alter table public.act_proof_decisions enable row level security;
revoke all on public.act_proof_decisions from anon;
grant select on public.act_proof_decisions to authenticated;
drop policy if exists act_proof_decisions_select on public.act_proof_decisions;
create policy act_proof_decisions_select on public.act_proof_decisions for select using (
  company_id = (select public.my_company_id())
  and (select public.is_manager())
  and public.wo_is_manager(work_order_id));

create or replace function public.act_proof_decide(p_order uuid, p_decision text, p_reason text)
returns public.act_proof_decisions
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  w record;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  r public.act_proof_decisions;
begin
  if v_uid is null then
    raise exception 'act_decision_denied' using errcode = '42501';
  end if;
  select id, company_id, status, submitted_by into w
    from work_orders where id = p_order and company_id = public.my_company_id();
  if not found or not public.wo_is_manager(p_order) then
    raise exception 'act_decision_denied' using errcode = '42501';
  end if;
  if public.wo_is_executor(p_order) or w.submitted_by is not distinct from v_uid then
    raise exception 'act_decision_denied: executor or submitter' using errcode = '42501';
  end if;
  if p_decision not in ('approve', 'reject') then
    raise exception 'act_decision_bad' using errcode = '22023';
  end if;
  if p_decision = 'approve' and (v_reason is null or length(v_reason) < 3) then
    raise exception 'act_decision_reason_required' using errcode = '22023';
  end if;
  if w.status <> 'done' then
    raise exception 'act_decision_not_accepted' using errcode = '22023';
  end if;
  if exists (select 1 from contractor_acts a
              where a.company_id = w.company_id and a.status = 'active'
                and a.items @> jsonb_build_array(jsonb_build_object('id', p_order::text))) then
    raise exception 'act_decision_locked' using errcode = '42501';
  end if;
  insert into act_proof_decisions(company_id, work_order_id, decision, reason, decided_by)
  values (w.company_id, p_order, p_decision, left(v_reason, 500), v_uid)
  returning * into r;
  return r;
end $$;
revoke all on function public.act_proof_decide(uuid, text, text) from public, anon;
grant execute on function public.act_proof_decide(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 10. Исправления по проверке прав (docs/security/review-2026-10.md)
-- ---------------------------------------------------------------------

-- Н-1. Менеджер с зоной доступа ролей не меняет: иначе он сделал бы
-- коллегу (или свой второй аккаунт) менеджером всей компании.
create or replace function public.set_member_role(p_profile uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     text := coalesce(public.my_role(), '');
  v_target text;
begin
  if v_me not in ('admin', 'manager') then
    raise exception 'forbidden: admin only';
  end if;
  if v_me = 'manager' and not public.zones_unrestricted() then
    raise exception 'forbidden: admin only';
  end if;
  if p_role not in ('admin', 'manager', 'requester', 'contractor', 'executor') then
    raise exception 'unknown role %', p_role;
  end if;
  if p_profile = auth.uid() then
    raise exception 'cannot change own role';
  end if;

  select role into v_target from profiles
   where id = p_profile and company_id = public.my_company_id()
   for update;
  if not found then
    raise exception 'profile not found in your company';
  end if;

  if v_me = 'manager' and (p_role = 'admin' or v_target = 'admin') then
    raise exception 'forbidden: admin only';
  end if;
  if v_target = 'admin' and p_role <> 'admin' and not exists (
       select 1 from profiles a
        where a.company_id = public.my_company_id() and a.role = 'admin' and a.id <> p_profile) then
    raise exception 'last admin';
  end if;

  update profiles set role = p_role where id = p_profile;
end;
$$;
revoke all on function public.set_member_role(uuid, text) from public, anon;
grant execute on function public.set_member_role(uuid, text) to authenticated;

-- Н-2. Фото — только файл из папки этой заявки, загруженный этим же
-- человеком (раньше путь фото не проверялся: можно было «приложить»
-- демо-картинку или фото другой заявки). Остальное — как в 0023.
drop policy if exists attachments_insert on public.attachments;
create policy attachments_insert on public.attachments for insert with check (
  uploaded_by = (select auth.uid())
  and (
    (kind = 'photo'
     and exists (
       select 1 from public.work_orders w
        where w.id = attachments.work_order_id
          and w.company_id = (select public.my_company_id())
          and attachments.storage_path like w.company_id::text || '/' || w.id::text || '/%'
          and exists (select 1 from storage.objects so
                       where so.bucket_id = 'work-photos'
                         and so.name = attachments.storage_path
                         and so.owner_id = (select auth.uid())::text)
          and (
            (attachments.stage = 'after'
               and w.status = 'in_progress'
               and public.wo_is_executor(w.id))
            or
            (attachments.stage = 'before'
               and w.status not in ('done', 'cancelled')
               and ((select public.is_manager()) or w.created_by = (select auth.uid())))
          )))
    or
    (kind = 'document'
     and exists (
       select 1 from public.work_orders w
        where w.id = attachments.work_order_id
          and w.company_id = (select public.my_company_id())
          and w.status <> 'cancelled'
          and attachments.storage_path like w.company_id::text || '/' || w.id::text || '/%'
          and ((select public.is_manager())
               or w.created_by = (select auth.uid())
               or w.assigned_contractor_id in (select public.my_contractor_ids()))))
  ));

-- Н-3. Токены ссылок Telegram: менеджер с зоной — только объекты своей
-- зоны; ссылку компании видит администратор.
drop policy if exists report_links_select on public.report_links;
create policy report_links_select on public.report_links for select using (
  report_links.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())
       or (report_links.object_id is not null and public.can_manage(report_links.object_id))));
```
