# Шаг 24: доработки по живой проверке, «Оплата по доказательству», уведомления в Telegram, сквозные тесты

Ветка `step-24` от `main` (шаг 23 слит). Миграции 0017 и 0018 применены пользователем (сообщение в задании шага) — номера дописаны в «Применённые миграции» `CLAUDE.md`. Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

## Чек-лист
- [x] 2. Фото в карточке заявки: причина найдена, исправлено; «Фото · N», «До» / «После», просмотр на весь экран
- [x] 1. Форма новой заявки: без данных прошлой заявки (контекст → GPS ≤ 200 м → пусто + «Недавние»)
- [x] 4. Системы (слои): список, карточка, правка администратором, архив; права в базе (0020)
- [x] 3. Документы в заявке (PDF и другие), миграция 0019, хранилище `order-files`
- [x] 5. Проверки и документация (analyze, test, deno, db_test, /check, снимки, `CLAUDE.md`, `DEMO_SCRIPT.md`)
- [x] 6. «Оплата по доказательству» — акты подрядчикам (PDF, Excel), миграция 0021
- [x] 7. Уведомления автору в Telegram (`telegram-notify`), миграция 0022
- [x] 8. Мелочи для показа (EN «Maintenance», плашки на главной, вёрстка)
- [x] 9. Сквозные тесты `tools/e2e` + 5 новых сценариев
- [x] 10. Исследование AR `docs/research/ar-options.md`

**4 новые миграции, все не применены: 0019 → 0020 → 0021 → 0022** (применять по порядку, 0022 требует 0018). **Новая Edge Function `telegram-notify`** (не выложена), изменена `telegram-bot` (команда /stop, кнопка «Не присылать») и общий `_shared/registry.ts`. **Seed изменён** (блоки 5h и 6b) — нужен Refresh demo. **Новый пакет** `share_plus` («Поделиться» на Android). Новых секретов нет.

## Что сделано

### Блок 2. Фото в карточке заявки
**Причина.** Заявки «Кондиционер КД-301: проверить» в базе уже нет — её удалил Refresh demo (блок 0 удаляет все недемо-заявки «Демо БЦ», файлы остаются в Storage: два снимка `before_….jpg` 13.10 там и лежат). Поэтому смотрел журнал запросов Supabase за 13.10: в 21:16 карточка этой заявки **получила** запись о фото, подписанную ссылку и **сам файл (ответ 200)** — то есть данные дошли до браузера, права в порядке, раздел «Фото» на экране был. Браузер — **Яндекс Браузер** (Windows). Локально (Chrome, тот же код) фото видно — проверено сквозным сценарием 10. Вывод: Flutter-веб не смог сам раскодировать картинку в этом браузере, а старая миниатюра в таком случае показывала серый значок «картинка недоступна» без нажатия — выглядело как «фото нет».
- ⚠️ Решил: на вебе картинка, которую Flutter не раскодировал, теперь показывается обычным элементом `<img>` браузера (`WebHtmlElementStrategy.fallback`) — и в миниатюре, и на весь экран. Права (видит все, кто видит заявку) уже были верные (`attachments_select` из 0006: «кто видит заявку»), их не трогал. Окончательно подтвердить можно только в Яндекс Браузере на рабочей базе — см. «Как проверить руками».
- Раздел «Фото · N»: группы «До · N» и «После · N», первая миниатюра крупно, остальные сеткой по 3; кнопка «Добавить» — у тех, кому разрешено, как раньше.
- Просмотр на весь экран: листание свайпом, стрелками по бокам (ПК) и клавишами ←/→, Esc — закрыть, увеличение пальцами, колёсиком и двойным касанием (при увеличении фото двигается, а не листается), счётчик «2 из 5», подпись «До · Менеджер Демо · 14 окт. 2026 г. 00:04 · в геозоне / вне геозоны · 320 м / Без геометки», «Скачать» (веб: файл с именем) / «Поделиться» (Android: файл байтами, пакет `share_plus`).
- ⚠️ Миниатюры: трансформация картинок Storage в проекте не подключена (платная функция), поэтому миниатюра — тот же файл, раскодированный уменьшенным (`cacheWidth`), файл кэширует браузер.
- Фото из «Узнать по фото» и из Telegram — обычные вложения `attachments` (`stage = before`), видны сразу после создания (сценарий 10).

### Блок 1. Форма новой заявки: без данных прошлой заявки
- **Откуда «прошлое место»**: «+ Заявка» во вкладке «Заявки» подставляла объект из **фильтра списка** (фильтр запоминается на устройстве и в адресе), а «Узнать по фото» — запомненное «Где я». ⚠️ Решил: фильтр списка — не контекст. Объект подставляется, только если человек пришёл из карточки объекта (кнопка «Заявки» в карточке на карте).
- Порядок (`order_form_place.dart`, чистые функции с тестами): 1) **контекст** — карточка объекта / карта, план этажа, карточка оборудования, «Узнать по фото» — объект и помещение, мелкая подпись «из карточки объекта» / «с плана этажа» / «из карточки оборудования» / «из «Узнать по фото»»; 2) **GPS** — ближайший видимый объект с координатами не дальше 200 м, **без помещения**, «📍 Рядом с вами · 40 м» и кнопка «Другой объект»; 3) **пусто** + кнопки «Недавние: …» (до 3 объектов своих последних заявок, сами не подставляются).
- Геопозиция — только при открытии формы, не дольше 3 с (`quickPosition()`): последняя известная, если свежее 2 минут (Android), иначе текущая (на вебе — геолокация браузера). Отказ, нет сигнала, не успели — тихо пусто. Пакет и разрешения те же, что у визитов.
- Голосовая заявка: место из того, что сказали (ИИ / словарь) → иначе GPS («Рядом с вами · 40 м» под «Где») → иначе пусто.
- После «Создать» / «Отмена» форма каждый раз создаётся заново — всё пустое (так было и раньше; проблема была только в подстановке объекта).
- Тесты: `test/order_form_place_test.dart` (8): прошлое место не подставляется, контекст важнее GPS, GPS дальше 200 м — нет, отказ геопозиции — пусто, объекты без координат не участвуют, «Недавние». Сквозной сценарий 11.

### Блок 4. Системы (слои)
- «Профиль → Моя компания → **Системы**» (администратор и менеджер; у исполнителя и заявителя пункта нет). На ПК — тот же раздел «Моя компания».
- Список: значок цветом системы, название, «Оборудование: N · открытых заявок: N · подрядчиков: N» (в пределах того, что пользователю видно по RLS и зоне). Архивные — свёрнутым блоком «Архив · N».
- Карточка системы: оборудование по объектам (→ карточка оборудования), подрядчики («на всех объектах» / «N объектов»), «Открытые заявки» → список заявок этой системы.
- Администратор: «+ Система», правка (название RU и EN, значок из 12, цвет из 8), порядок стрелками ↑/↓, «Архивировать» / «Вернуть из архива», «Удалить» (только если ничего не ссылается — иначе «Системой уже пользуются — её можно только архивировать»).
- Архивные системы не предлагаются: в форме новой заявки, голосовой заявке, форме оборудования, зоне доступа, плане ТО (`Layer.active`; уже выбранная остаётся). ИИ-разбор (`_shared/registry.ts`) тоже их не предлагает. Старые заявки и оборудование с ними видны как раньше.
- **Права в базе (миграция 0020)**: было — менять системы мог **любой менеджер**, а политика «for all» заодно давала ему чтение всех систем. Стало: создать / изменить / удалить — только администратор; менеджер с зонами видит только системы своих зон (зона «все системы» — все); менеджер без зон, администратор, исполнитель, заявитель — все системы компании (названия нужны в заявках). ⚠️ Отдельная миграция 0020, а не в 0019: так её можно применить и откатить независимо от документов.
- В списке оборудования объекта группировка по системам уже была (шаг 16); в форме оборудования — только доступные и не архивные.
- Демо: значки и цвета 7 систем «Демо БЦ» (блок 5h, если применена 0020).

### Блок 3. Документы в заявке
- Карточка заявки → раздел **«Документы · N»**: «Прикрепить файл» (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, TXT, до 20 МБ — проверка в приложении и в хранилище), строка: значок типа, имя файла как есть, «180 КБ · Исполнитель Демо · 12 окт. 2026 г. 00:39». Нажатие → «Открыть» (новая вкладка / системное приложение по подписанной ссылке на час), «Скачать» (веб) / «Поделиться» (Android), «Удалить» (загрузивший или менеджер, с подтверждением).
- ⚠️ PDF открывается в новой вкладке браузера (встроенный просмотрщик браузера), а не внутри приложения: просмотр из пакета `printing` на вебе грузит pdf.js со стороннего сервера — для показа это лишний риск.
- В форме новой заявки — строка «Прикрепить файл»: файлы загружаются сразу после создания заявки (id заявки задаётся в приложении).
- В путь хранилища попадает только безопасная часть имени (латиница, цифры, `-_.`, остальное «_», до 80 знаков): `<company_id>/<work_order_id>/<uuid>-Act_5.pdf`. Имя для людей хранится отдельно, как есть.
- Удаление заявки менеджером теперь удаляет файлы из обоих хранилищ (`work-photos` и `order-files`).
- **Миграция 0019** (полный текст ниже). Тесты базы: `tools/db_test/documents_systems.sql`.

### Блок 6. «Оплата по доказательству» — акты подрядчикам
- «Отчёты» → **«Акты подрядчикам»** (менеджер в пределах зоны, администратор): подрядчик (по умолчанию «КлиматСервис» или выбранный в фильтре отчёта), месяц стрелками ‹ ›, ставки.
- **«К оплате · N»** — заявки, **принятые менеджером** и доказанные: 📷 фото «после» (если фото требовалось), 📍 визит в геозоне (если у объекта есть координаты), ✓ все пункты чек-листа (если чек-лист был). Значки доказательств у строки, нажатие → карточка заявки.
- **«Без доказательства — к оплате не принимается · N»** — с причинами словами: «нет фото «после»», «визит вне геозоны», «нет отметки визита», «чек-лист не выполнен», «не принята менеджером», «возвращена на доработку».
- Итоги плитками: к оплате (и сумма), без доказательства, доля доказанных, просрочено.
- ⚠️ «Визиты включены» = у объекта есть координаты (геозона, шаг 9). Отдельного переключателя «визиты обязательны» в продукте нет; норма визитов `visits_per_month` — про количество визитов в месяц, не про конкретную заявку.
- ⚠️ Ставки — отдельная таблица `contractor_rates` (за заявку, за визит планового ТО, валюта), а не столбцы `contractors`: исполнитель подрядчика видит свою строку `contractors`, а ставки ему показывать не нужно. Ставки по системам не делал — одна ставка на подрядчика (проще для акта и бухгалтерии). Нет ставок — акт без сумм, только количество.
- **«Сформировать акт»** → номер `АКТ-<год>-<NNN>` (сквозной по компании за год, выдаёт база), PDF A4 тем же механизмом и шрифтом Onest, что отчёты: шапка (заказчик, исполнитель, период, номер и дата, кто сформировал), итоги, таблица «К оплате» (№, дата, объект, помещение, работа, доказательства, сумма), итог, отдельный блок «Не принято к оплате» с причинами, подписи сторон. PDF сохраняется в закрытом хранилище `contractor-acts`; в браузере — окно печати, на Android — «Поделиться».
- **Excel для бухгалтерии** (кнопка рядом): листы «К оплате» и «Не принято», тот же состав; пакет `excel` загружается отложенно, как импорт оборудования.
- «Сформированные акты» — список: номер, период, «к оплате N, без доказательства M», сумма, когда и кто; акт за тот же период можно переформировать — новый номер, прежний помечается «заменён». Нажатие — открыть PDF.
- ⚠️ Состав акта считает приложение по данным под RLS и сохраняет в базе снимком (строки и итоги на момент формирования). Подделать его может только сам менеджер-заказчик — он и платит; номер, период, автор и время ставит база.
- Подрядчики (исполнители) актов и ставок не видят — проверено тестами базы.
- Демо (блок 6b): у «КлиматСервис» в текущем месяце к оплате 5 заявок (111 — фото + геозона + чек-лист, 112, 113 — сдана позже срока, 214, 220), без доказательства 4 (109 — нет фото, 110 — визит вне геозоны, 225 — нет отметки визита, 114 — не принята). Фото «после» в демо-истории — **нарисованная картинка из сборки** (`assets/demo_photos/ac_after.jpg`, путь вложения `demo/ac_after.jpg`), не файл в Storage и не фото реального объекта. Ставки: «КлиматСервис» 4 500 / 2 500 ₽, «ЭлектроПро» 3 800 / 2 000 ₽, «МосКлимат» 5 200 / 3 000 ₽.
- ⚠️ Числа «5 и 4» верны, если Refresh demo запущен в октябре после ~10-го: даты демо-истории считаются от дня запуска, а акт — за календарный месяц. В начале месяца в текущем месяце заявок меньше — листните на прошлый месяц.
- Кадр питча 20 «Акт: к оплате только доказанное» — `tools/screens/screens.mjs --pitch` (рабочая база, после 0021 и Refresh demo); предпросмотр на локальной базе — `docs/screens/preview24/admin-1280-acts.png`.

### Блок 7. Уведомления автору в Telegram
- Новая Edge Function **`telegram-notify`** (`verify_jwt = true`). После смены статуса («Начать работу», «Принять», «Вернуть», «Отменить») приложение вызывает её со своим JWT — только для заявок канала `telegram`, без ожидания и тихо при ошибке: статус уже сохранён.
- Функция: под JWT пользователя читает заявку (не видна — 404) и **её текущий статус в базе**; уведомляет о `in_progress` («взята в работу 🔧»), `done` («выполнена ✅»), `returned` («возвращена исполнителю на доработку» + причина), `cancelled` («отклонена»). Затем service_role-функция `tg_notify_claim` (только service_role) берёт чат автора из `telegram.orders` и ставит отметку «по этому статусу отправлено» — повторный вызов ничего не шлёт. Ошибка Telegram — отметка снимается (`tg_notify_release`), можно повторить.
- «Выполнена» — с фото «после»: файл скачивается под правами пользователя и отправляется **как фото Telegram** (`sendPhoto`, байтами), а не ссылкой на хранилище.
- Кнопки: привязанному пользователю — «Открыть в приложении»; гостю — «🔕 Не присылать уведомления» → то же, что команда **/stop**; **/start** или новая заявка — снова присылать (`tg_notify_optout`). Группе — без кнопок. /stop добавлена в меню команд бота (RU / EN) — применится при следующем запуске «Telegram webhook» (`set`).
- ⚠️ Без pg_net и pg_cron (их нет в базе): если менеджер сменил статус не из приложения (например, SQL Editor), уведомления не будет.
- Тексты RU / EN — `telegram-bot/texts.ts`; функция добавлена в `FUNCTIONS` «Deploy functions» (проверка «без токена → 401») и в `supabase/config.toml`. Тесты без сети: `telegram-notify/notify_test.ts` (7), `telegram-bot/bot_test.ts` (+1: /stop, кнопка, /start).
- **Миграция 0022** (полный текст ниже), тесты базы `tools/db_test/tg_notify.sql`. ⚠️ Отдельная миграция: требует 0018 и не нужна, если бот не подключён.

### Блок 8. Мелочи для показа
- Английский интерфейс: «PM» убран — меню и сегмент «Maintenance», заголовок раздела «Preventive maintenance», метка задачи «Maintenance · October 2026 · due Oct 31», фильтр «Maintenance». В `CLAUDE.md` — термин «Maintenance».
- Главная менеджера: плашки «📷 Узнано по фото: 5 (угадано 60 %)» и «✈️ Из Telegram за 7 дней: 2» (за 7 дней; нажатие — список с фильтром «Источник» и «7 дней»; без данных не показываются).
- Вёрстка 412 / 1280 по снимкам — см. раздел «Проверки → снимки».

### Блок 9. Сквозные тесты
См. «Проверки → Сквозные тесты». Базовый прогон на коде `main` до изменений — 9 из 9.

### Блок 10. Исследование AR
`docs/research/ar-options.md` — см. раздел «AR» ниже.

## Новые и изменённые файлы
**Новые**
- `lib/features/requests/order_form_place.dart` — правила места новой заявки (контекст → GPS → пусто, «Недавние»)
- `lib/core/file_share.dart` — «Скачать» (веб) / «Поделиться» (Android), открыть по подписанной ссылке
- `lib/core/design/system_style.dart` — цвета и значки систем
- `lib/features/documents/document_logic.dart`, `document_repository.dart`, `documents_section.dart` — документы заявки
- `lib/features/systems/systems_repository.dart`, `systems_screen.dart`, `system_card.dart`, `system_form.dart` — раздел «Системы»
- `lib/features/acts/act_logic.dart`, `act_doc.dart`, `act_pdf.dart`, `act_xlsx.dart`, `acts_repository.dart`, `contractor_acts_screen.dart` — акты подрядчикам
- `supabase/functions/telegram-notify/index.ts`, `notify.ts`, `notify_test.ts` — уведомления автору в Telegram
- `supabase/migrations/0019_order_documents.sql`, `0020_systems.sql`, `0021_contractor_acts.sql`, `0022_telegram_notify.sql`
- `test/order_form_place_test.dart`, `document_logic_test.dart`, `systems_test.dart`, `act_logic_test.dart`, `act_pdf_test.dart`
- `tools/db_test/documents_systems.sql`, `contractor_acts.sql`, `tg_notify.sql` — тесты прав
- `assets/demo_photos/ac_after.jpg` — нарисованное фото «после» для демо-истории (из `tools/demo_photos/generate.mjs`)
- `docs/research/ar-options.md` — исследование AR; `docs/screens/preview24/` — предпросмотр экранов шага 24

**Изменённые**
- `lib/features/photos/photo_section.dart`, `photo_repository.dart` — «Фото · N», просмотр с листанием, кто снял, геозона, `<img>`-запасной показ, демо-картинки
- `lib/features/requests/requests.dart` — форма (место, «Недавние», «Прикрепить файл»), документы в карточке, геозона для фото, вызов `telegram-notify`, удаление файлов обоих хранилищ, `listBy(layerId, openOnly)`, `countChannel`
- `lib/features/requests/requests_tab.dart` — плашки главной, без подстановки объекта из фильтра; `order_list.dart` — список заявок системы
- `lib/features/voice/voice_confirm_screen.dart` — GPS, если место не названо
- `lib/core/location.dart` — `quickPosition()` (≤ 3 с)
- `lib/features/map/objects_map_view.dart`, `floors/floor_plan_screen.dart`, `equipment/asset_card.dart`, `photo_identify/photo_identify_screen.dart` — откуда открыта форма (подпись)
- `lib/features/directory/directory.dart` — `Layer`: цвет, значок, порядок, архив; системы по порядку (раньше шли в обратном)
- `lib/features/equipment/equipment_form.dart`, `access/zone_editor.dart`, `access/zone_repository.dart`, `ppr/ppr_form.dart` — архивные системы не предлагаются; этажи по порядку
- `lib/features/profile/company_screen.dart` — пункт «Системы»; `reports/reports_screen.dart` — вход «Акты подрядчикам»
- `lib/core/design/icons.dart`, `design.dart` — новые значки, экспорт `system_style`
- `lib/l10n/app_ru.arb`, `app_en.arb` — строки шага 24 (RU / EN), «Maintenance» вместо «PM»
- `pubspec.yaml`, `pubspec.lock` — пакет `share_plus`
- `supabase/functions/telegram-bot/bot.ts`, `index.ts`, `telegram.ts`, `texts.ts`, `bot_test.ts` — /stop, «Не присылать», снова включать на /start и новой заявке, отправка фото байтами
- `supabase/functions/_shared/registry.ts` — архивные системы не предлагаются модели
- `supabase/config.toml`, `.github/workflows/deploy-functions.yml` — функция `telegram-notify`
- `supabase/seed/demo_history.sql` — блоки 5h (значки систем) и 6b (доказательства и ставки)
- `tools/db_test/10_fixture.sql` — строки новых таблиц для обеих компаний
- `tools/e2e/scenarios.mjs` — сценарии 10–14; `tools/screens/local_backend.mjs` — хранилища `order-files`, `contractor-acts`; `local_screens.mjs` — `--step=24`; `screens.mjs` — кадр питча 20
- `tools/demo_photos/generate.mjs` — вторая картинка «после»
- `test/ppr_logic_test.dart` — «Maintenance»
- `CLAUDE.md`, `docs/DEMO_SCRIPT.md` — документация шага; 0017 и 0018 — в «Применённых миграциях»

## Проверки
- `flutter analyze lib test` — **0 замечаний**.
- `flutter test` — **400 прошли, 0 упали** (новые: 8 + 5 + 5 + 7 + 3).
- `deno check` и `deno test supabase/functions` — **84 прошли, 0 упали** (новые: 7 в `telegram-notify`, 1 в боте).
- `tools/db_test/run.sh` — **все 9 наборов прошли**: access_zones 34, contractor_acts 33 (новый), cross_refs 21, documents_systems 39 (новый), photo_identify 15, ppr_regions 49, telegram 73, telegram_notify 10 (новый), tenant_isolation 770 (было 722 — новые таблицы и хранилища тоже проверяются на изоляцию компаний). Демо-данные дважды — без ошибок.
- `/check` — ✅ анализ, ✅ тесты, ✅ веб-сборка, ✅ строки вне переводов (3 места «проверить» — не текст интерфейса: части названий систем для выбора значка, «АКТ» → «AKT» в имени файла, «КлиматСервис» — подрядчик по умолчанию для демо), ✅ название продукта.
- **`/screens` на рабочей базе** (миграции шага ещё не применены): `docs/screens/latest/` — **274 ✅, 1 ❌**. ❌ «Выбор подрядчика» на 360 px: в видимой части списка нет демо-заявки в статусе «Новая» / «Назначена» / «Возвращена» (зависит от данных рабочей базы; на 412 и 1280 тот же экран снят ✅). Два снимка «EN — Maintenance» сначала падали: скрипт искал в английском меню «PM» — скрипт поправлен, сняты заново ✅. Найдено и исправлено по снимкам: на телефоне заголовок «Preventive maintenance» обрезался — на узком экране теперь короткое «Maintenance» («Плановое ТО» по-русски); на телефоне в акте значки и сумма теснили название — перенесены под строку; суммы без «,00»; системы и кнопки «Вид работ» шли в обратном порядке.
- **Предпросмотр шага 24** (локальная база с 0001–0022): `docs/screens/preview24/` — **26 из 26** снимков ✅ (README там же), включая PDF акта.

### Сквозные тесты (`tools/e2e`, локальная база)
Базовый прогон на коде `main` до изменений — 9 из 9. После шага:

| № | Сценарий | Итог | Примечание |
|---|---|---|---|
| 1 | Голос → ИИ → автоназначение → исполнитель (геозона, фото) → приёмка | ✅ | без изменений |
| 2 | ППР: генерация → исполнитель → принятие | ✅ | |
| 3 | План этажа | ✅ | |
| 4 | Регионы | ✅ | |
| 5 | PDF отчёта | ✅ | |
| 6 | Импорт оборудования | ✅ | |
| 7 | Зоны доступа и бригады | ✅ | |
| 8 | Изоляция компаний | ✅ | |
| 9 | Старая база (0001–0014) — приложение работает | ✅ | новые разделы без миграций не ломают экраны |
| 10 | **Новый.** «Узнать по фото» → «Это он» → заявка → фото «до» в карточке и на весь экран | ✅ | |
| 11 | **Новый.** Форма не подставляет прошлое место; GPS в 40 м → «Рядом с вами · 40 м» | ✅ | |
| 12 | **Новый.** Прикрепить PDF → «Документы · 1» → «Открыть» | ✅ | файл открыт по подписанной ссылке |
| 13 | **Новый.** «Системы»: администратор создаёт, менеджер с зоной не видит | ✅ | |
| 14 | **Новый.** Акт «КлиматСервис»: «К оплате» = доказанные по базе → номер и PDF | ✅ | к оплате 6 = 6 по базе, АКТ-2026-002, PDF сохранён |

Упавших из-за приложения не было. Сценарии 12 и 14 сначала падали из-за самих тестов (адрес вкладки с `noopener` Playwright не показывает; заголовок группы на экране заглавными; PDF сохраняется чуть позже номера) — тесты поправлены, повторный прогон ✅.

## Полный текст новых миграций
Все четыре — **не применены**. Применять **по порядку**: 0019 → 0020 → 0021 → 0022.

### 0019_order_documents.sql
Документы в заявке: вид вложения `document`, поля файла, хранилище `order-files` и права (видит тот, кто видит заявку; загружают автор, менеджер, исполнитель назначенного подрядчика; удаляют загрузивший и менеджер). Политики фото пересозданы с тем же условием, что в 0006.

**Повторный запуск безопасен**: `if not exists`, `create or replace`, `drop … if exists`, `on conflict`. Проверено: `tools/db_test/run.sh` запускает каждую новую миграцию дважды.

```sql
-- 0019 — документы в заявке (шаг 24): PDF, Word, Excel, картинки, текст.
--
-- 1) attachments: новый вид 'document' и поля файла — имя (как его назвал
--    человек, 1–200 символов), тип (mime) и размер (≤ 20 МБ). У документа нет
--    стадии «до / после». Фото (kind = 'photo') — как раньше, правила 0006 не
--    меняются.
-- 2) Закрытое хранилище order-files: 20 МБ, только разрешённые типы.
--    Путь: <company_id>/<work_order_id>/<uuid>-<безопасное имя>; в путь
--    приложение кладёт только латиницу, цифры и -_. (остальное — «_»).
-- 3) Права — как у фото:
--    • видит документ тот, кто видит заявку (подзапрос к work_orders проходит
--      через wo_select с зонами доступа 0016);
--    • загружают автор заявки, менеджер (администратор) с правом на заявку и
--      исполнитель назначенного подрядчика; в отменённую заявку — нельзя;
--    • удаляют загрузивший и менеджер (администратор) с правом на заявку;
--    • чужая компания — никогда: компания пути = компания заявки = своя.
--
-- Повторный запуск безопасен: add column if not exists, drop … if exists,
-- on conflict do update.

-- ---------------------------------------------------------------------
-- 1. Вложения: вид 'document' и поля файла
-- ---------------------------------------------------------------------
alter table public.attachments
  add column if not exists file_name  text,
  add column if not exists mime       text,
  add column if not exists size_bytes bigint;

alter table public.attachments drop constraint if exists attachments_kind_check;
alter table public.attachments add constraint attachments_kind_check
  check (kind = any (array['photo', 'audio', 'video', 'model', 'document']));

alter table public.attachments drop constraint if exists attachments_document_check;
alter table public.attachments add constraint attachments_document_check
  check (kind <> 'document' or (
    stage is null
    and file_name is not null and char_length(btrim(file_name)) between 1 and 200
    and mime is not null and char_length(mime) between 3 and 120
    and size_bytes is not null and size_bytes between 1 and 20971520));

alter table public.attachments drop constraint if exists attachments_file_name_len;
alter table public.attachments add constraint attachments_file_name_len
  check (file_name is null or char_length(file_name) <= 200);

create index if not exists idx_attachments_wo_kind on public.attachments (work_order_id, kind);

-- Видят — как раньше (0006): те, кто видит заявку.
-- Добавляют: фото — без изменений (0006); документ — автор, менеджер,
-- исполнитель назначенного подрядчика; путь — папка этой заявки.
drop policy if exists attachments_insert on public.attachments;
create policy attachments_insert on public.attachments for insert with check (
  uploaded_by = (select auth.uid())
  and (
    (kind = 'photo'
     and exists (
       select 1 from public.work_orders w
        where w.id = attachments.work_order_id
          and w.company_id = (select public.my_company_id())
          and (
            (attachments.stage = 'after'
               and w.status = 'in_progress'
               and ((select public.is_manager())
                    or w.assigned_contractor_id in (select public.my_contractor_ids())))
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

-- Удаляют: фото — своё, пока работу не отправили на проверку (0006);
-- документ — загрузивший или менеджер с правом на заявку, в любом статусе.
drop policy if exists attachments_delete on public.attachments;
create policy attachments_delete on public.attachments for delete using (
  (kind <> 'document'
   and uploaded_by = (select auth.uid())
   and exists (select 1 from public.work_orders w
                where w.id = attachments.work_order_id
                  and w.status not in ('on_review', 'done', 'cancelled')))
  or
  (kind = 'document'
   and (uploaded_by = (select auth.uid()) or (select public.is_manager()))
   and exists (select 1 from public.work_orders w
                where w.id = attachments.work_order_id
                  and w.company_id = (select public.my_company_id()))));

-- ---------------------------------------------------------------------
-- 2. Хранилище документов
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('order-files', 'order-files', false, 20971520, array[
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'image/jpeg',
  'image/png',
  'text/plain'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists order_files_select on storage.objects;
drop policy if exists order_files_insert on storage.objects;
drop policy if exists order_files_delete on storage.objects;

-- Папки пути: [1] — компания, [2] — заявка. Сравнение текстом: кривой путь —
-- «нет доступа», а не ошибка приведения. Урок 0014: только objects.name.
create policy order_files_select on storage.objects for select to authenticated using (
  bucket_id = 'order-files'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and exists (select 1 from public.work_orders w
               where w.id::text = (storage.foldername(objects.name))[2]
                 and w.company_id::text = (storage.foldername(objects.name))[1]));

create policy order_files_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'order-files'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and exists (select 1 from public.work_orders w
               where w.id::text = (storage.foldername(objects.name))[2]
                 and w.company_id::text = (storage.foldername(objects.name))[1]
                 and w.status <> 'cancelled'
                 and ((select public.is_manager())
                      or w.created_by = (select auth.uid())
                      or w.assigned_contractor_id in (select public.my_contractor_ids()))));

-- Удаляет файл загрузивший или менеджер компании с правом на заявку.
create policy order_files_delete on storage.objects for delete to authenticated using (
  bucket_id = 'order-files'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and (objects.owner_id = (select auth.uid())::text
       or ((select public.is_manager())
           and exists (select 1 from public.work_orders w
                        where w.id::text = (storage.foldername(objects.name))[2]
                          and w.company_id::text = (storage.foldername(objects.name))[1]))));
```

### 0020_systems.sql
Системы: значок и архив у `layers`; менять — только администратор (было — любой менеджер); менеджер с зонами видит только системы своих зон; удалить можно только неиспользуемую систему.

**Повторный запуск безопасен**: `if not exists`, `create or replace`, `drop … if exists`, `on conflict`. Проверено: `tools/db_test/run.sh` запускает каждую новую миграцию дважды.

```sql
-- 0020 — системы (слои `layers`) в приложении (шаг 24).
--
-- 1) layers: значок (`icon` — код из набора приложения), архив
--    (`archived_at`): архивная система не предлагается в новых заявках,
--    оборудовании и зонах, но старые данные с ней остаются и видны.
--    Цвет — только #RRGGBB.
-- 2) Права. Было (0004): видит вся компания, меняет любой менеджер
--    («for all» — заодно и чтение всего). Стало:
--    • создаёт, меняет, удаляет — только администратор своей компании;
--    • менеджер с зонами доступа (0016) видит только системы своих зон;
--      зона «все системы» — все. Менеджер без зон — все, как раньше;
--    • администратор, исполнитель и заявитель видят все системы компании
--      (названия нужны в заявках) — раздела «Системы» у последних двух нет.
-- 3) Удалить можно только систему, на которую ничего не ссылается: заявки,
--    оборудование, закрепления подрядчиков, планы ППР, зоны менеджеров и
--    бригад. Иначе — ошибка «system_in_use» (в приложении — «Архивировать»).
--    Проверка — только для действий пользователя (auth.uid() не null):
--    удаление компании целиком и обслуживание из SQL Editor не мешает.
--
-- Повторный запуск безопасен: add column if not exists, drop … if exists,
-- create or replace.

alter table public.layers
  add column if not exists icon        text,
  add column if not exists archived_at timestamptz;

alter table public.layers drop constraint if exists layers_icon_code;
alter table public.layers add constraint layers_icon_code
  check (icon is null or icon ~ '^[a-z][a-z0-9_]{0,23}$');

alter table public.layers drop constraint if exists layers_color_hex;
alter table public.layers add constraint layers_color_hex
  check (color ~ '^#[0-9A-Fa-f]{6}$');

alter table public.layers drop constraint if exists layers_name_len;
alter table public.layers add constraint layers_name_len
  check (char_length(btrim(name)) between 1 and 60);

-- ---------------------------------------------------------------------
-- 1. Видимость систем по зоне доступа менеджера
-- ---------------------------------------------------------------------
-- true — систему видно: не менеджер с зонами, или у него есть зона «все
-- системы», или зона с этой системой. Одна проверка на строку (систем мало).
create or replace function public.layer_in_my_zone(p_layer uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when coalesce((select p.role from profiles p where p.id = auth.uid()), '') <> 'manager' then true
    when not exists (select 1 from access_zones z where z.profile_id = auth.uid()) then true
    else exists (select 1 from access_zones z
                  where z.profile_id = auth.uid()
                    and (cardinality(z.layer_ids) = 0 or p_layer = any (z.layer_ids)))
  end;
$$;
revoke all on function public.layer_in_my_zone(uuid) from public, anon;
grant execute on function public.layer_in_my_zone(uuid) to authenticated;

drop policy if exists layers_select on public.layers;
drop policy if exists layers_manage on public.layers;
drop policy if exists layers_insert on public.layers;
drop policy if exists layers_update on public.layers;
drop policy if exists layers_delete on public.layers;

create policy layers_select on public.layers for select using (
  layers.company_id = (select public.my_company_id())
  and ((select public.zones_unrestricted()) or public.layer_in_my_zone(layers.id)));

create policy layers_insert on public.layers for insert with check (
  layers.company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy layers_update on public.layers for update
  using (layers.company_id = (select public.my_company_id()) and (select public.is_admin()))
  with check (layers.company_id = (select public.my_company_id()) and (select public.is_admin()));
create policy layers_delete on public.layers for delete using (
  layers.company_id = (select public.my_company_id()) and (select public.is_admin()));

-- ---------------------------------------------------------------------
-- 2. Удалить можно только неиспользуемую систему
-- ---------------------------------------------------------------------
create or replace function public.trg_layers_delete_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return old; end if;
  if exists (select 1 from work_orders w where w.layer_id = old.id)
     or exists (select 1 from assets a where a.layer_id = old.id)
     or exists (select 1 from contractor_layers cl where cl.layer_id = old.id)
     or exists (select 1 from maintenance_plans mp where mp.layer_id = old.id)
     or exists (select 1 from access_zones z where old.id = any (z.layer_ids))
     or exists (select 1 from crew_zones cz where old.id = any (cz.layer_ids)) then
    raise exception 'system_in_use' using errcode = 'P0001',
      hint = 'Систему используют заявки, оборудование, подрядчики, ППР или зоны — её можно только архивировать.';
  end if;
  return old;
end $$;
revoke all on function public.trg_layers_delete_guard() from public, anon, authenticated;

drop trigger if exists trg_layers_delete_guard on public.layers;
create trigger trg_layers_delete_guard before delete on public.layers
  for each row execute function public.trg_layers_delete_guard();
```

### 0021_contractor_acts.sql
Ставки и акты подрядчикам: таблицы `contractor_rates`, `contractor_acts`, функции выдачи номера и записи PDF, хранилище `contractor-acts`. Подрядчики не видят ни ставок, ни актов.

**Повторный запуск безопасен**: `if not exists`, `create or replace`, `drop … if exists`, `on conflict`. Проверено: `tools/db_test/run.sh` запускает каждую новую миграцию дважды.

```sql
-- 0021 — «Оплата по доказательству»: ставки и акты подрядчикам (шаг 24).
-- Без реальных денег и платёжных систем: акт — документ для бухгалтерии.
--
-- 1) contractor_rates — необязательные ставки подрядчика: за заявку и за
--    визит планового ТО (задача ППР), валюта (ISO, по умолчанию RUB).
--    Отдельная таблица, а не столбцы contractors: подрядчик (исполнитель)
--    видит свою строку contractors, а ставки ему не показываются.
--    Читают менеджеры (с зоной — подрядчиков своей зоны) и администратор;
--    меняют администратор и менеджер без зон (как contractors_update, 0016).
-- 2) contractor_acts — сформированные акты: номер АКТ-<год>-<NNN> (сквозной
--    в компании за год), подрядчик, период, итоги и строки (снимок на момент
--    формирования), кто и когда, путь PDF в хранилище. Акт за тот же период
--    можно переформировать: новый номер, прежний — «заменён» (replaced).
--    Создаёт и помечает только функция contractor_act_issue (менеджер
--    с правом на подрядчика); PDF — contractor_act_set_pdf. Читают менеджеры
--    своей зоны и администратор. Подрядчики и исполнители актов не видят.
-- 3) Закрытое хранилище contractor-acts (PDF до 10 МБ):
--    <company_id>/<act_id>/<файл>.pdf.
--
-- Повторный запуск безопасен: if not exists, create or replace, drop … if exists.

-- ---------------------------------------------------------------------
-- 1. Ставки
-- ---------------------------------------------------------------------
create table if not exists public.contractor_rates (
  contractor_id uuid primary key references public.contractors(id) on delete cascade,
  company_id    uuid not null references public.companies(id) on delete cascade,
  rate_order    numeric(12,2) check (rate_order is null or rate_order >= 0),
  rate_visit    numeric(12,2) check (rate_visit is null or rate_visit >= 0),
  currency      text not null default 'RUB' check (currency ~ '^[A-Z]{3}$'),
  updated_by    uuid references public.profiles(id) on delete set null default auth.uid(),
  updated_at    timestamptz not null default now()
);
alter table public.contractor_rates enable row level security;
revoke all on public.contractor_rates from anon;
grant select, insert, update, delete on public.contractor_rates to authenticated;

-- Компания ставки = компания подрядчика.
create or replace function public.trg_contractor_rates_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from contractors c where c.id = new.contractor_id and c.company_id = new.company_id) then
    raise exception 'contractor_rates: подрядчик другой компании' using errcode = '42501';
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke all on function public.trg_contractor_rates_check() from public, anon, authenticated;
drop trigger if exists trg_contractor_rates_check on public.contractor_rates;
create trigger trg_contractor_rates_check before insert or update on public.contractor_rates
  for each row execute function public.trg_contractor_rates_check();

drop policy if exists contractor_rates_select on public.contractor_rates;
drop policy if exists contractor_rates_insert on public.contractor_rates;
drop policy if exists contractor_rates_update on public.contractor_rates;
drop policy if exists contractor_rates_delete on public.contractor_rates;
create policy contractor_rates_select on public.contractor_rates for select using (
  contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())
       or public.can_see_contractor(contractor_rates.contractor_id)));
create policy contractor_rates_insert on public.contractor_rates for insert with check (
  contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())));
create policy contractor_rates_update on public.contractor_rates for update
  using (contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
         and ((select public.is_admin()) or (select public.zones_unrestricted())))
  with check (contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
         and ((select public.is_admin()) or (select public.zones_unrestricted())));
create policy contractor_rates_delete on public.contractor_rates for delete using (
  contractor_rates.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())));

-- ---------------------------------------------------------------------
-- 2. Акты
-- ---------------------------------------------------------------------
create table if not exists public.contractor_acts (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade,
  contractor_id uuid not null references public.contractors(id) on delete cascade,
  year          int  not null check (year between 2000 and 2100),
  seq           int  not null check (seq > 0),
  number        text not null,
  period_start  date not null,
  period_end    date not null check (period_end >= period_start),
  status        text not null default 'active' check (status in ('active', 'replaced')),
  replaced_by   uuid references public.contractor_acts(id) on delete set null,
  totals        jsonb not null default '{}'::jsonb check (jsonb_typeof(totals) = 'object'),
  items         jsonb not null default '[]'::jsonb check (jsonb_typeof(items) = 'array'),
  pdf_path      text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  unique (company_id, year, seq)
);
create index if not exists idx_contractor_acts_contractor
  on public.contractor_acts (contractor_id, period_start, created_at desc);
alter table public.contractor_acts enable row level security;
revoke all on public.contractor_acts from anon;
grant select on public.contractor_acts to authenticated;

drop policy if exists contractor_acts_select on public.contractor_acts;
create policy contractor_acts_select on public.contractor_acts for select using (
  contractor_acts.company_id = (select public.my_company_id()) and (select public.is_manager())
  and ((select public.is_admin()) or (select public.zones_unrestricted())
       or public.can_see_contractor(contractor_acts.contractor_id)));

-- Сформировать акт: номер по компании за год, прежние активные акты этого
-- подрядчика за тот же период — «заменён». Проверки: менеджер (админ) своей
-- компании, подрядчик своей компании и в его зоне доступа, строки ≤ 2000.
create or replace function public.contractor_act_issue(
  p_contractor uuid, p_from date, p_to date, p_totals jsonb, p_items jsonb)
returns table (id uuid, number text)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_company uuid := public.my_company_id();
  v_year int := extract(year from p_to)::int;
  v_seq int;
  v_id uuid;
  v_number text;
begin
  if auth.uid() is null or not public.is_manager() then
    raise exception 'act_denied' using errcode = '42501';
  end if;
  if not exists (select 1 from contractors c where c.id = p_contractor and c.company_id = v_company) then
    raise exception 'act_denied' using errcode = '42501';
  end if;
  if not (public.is_admin() or public.zones_unrestricted() or public.can_see_contractor(p_contractor)) then
    raise exception 'act_denied' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 400 then
    raise exception 'act_bad_period' using errcode = '22023';
  end if;
  if jsonb_typeof(coalesce(p_totals, '{}')) <> 'object' or jsonb_typeof(coalesce(p_items, '[]')) <> 'array'
     or jsonb_array_length(coalesce(p_items, '[]')) > 2000 then
    raise exception 'act_bad_payload' using errcode = '22023';
  end if;

  -- Номер — сквозной по компании за год; блокировка на время транзакции,
  -- чтобы два одновременных акта не получили один номер.
  perform pg_advisory_xact_lock(hashtext('contractor_acts:' || v_company::text || ':' || v_year));
  select coalesce(max(a.seq), 0) + 1 into v_seq
    from contractor_acts a where a.company_id = v_company and a.year = v_year;
  v_number := format('АКТ-%s-%s', v_year, lpad(v_seq::text, 3, '0'));

  insert into contractor_acts(company_id, contractor_id, year, seq, number, period_start, period_end,
                              totals, items, created_by)
  values (v_company, p_contractor, v_year, v_seq, v_number, p_from, p_to,
          coalesce(p_totals, '{}'), coalesce(p_items, '[]'), auth.uid())
  returning contractor_acts.id into v_id;

  update contractor_acts a set status = 'replaced', replaced_by = v_id
   where a.company_id = v_company and a.contractor_id = p_contractor
     and a.period_start = p_from and a.period_end = p_to
     and a.status = 'active' and a.id <> v_id;

  return query select v_id, v_number;
end $$;
revoke all on function public.contractor_act_issue(uuid, date, date, jsonb, jsonb) from public, anon;
grant execute on function public.contractor_act_issue(uuid, date, date, jsonb, jsonb) to authenticated;

-- Путь PDF акта: только свой акт (видимый по RLS) и только папка этого акта.
create or replace function public.contractor_act_set_pdf(p_act uuid, p_path text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_company uuid := public.my_company_id();
begin
  if auth.uid() is null or not public.is_manager() then
    raise exception 'act_denied' using errcode = '42501';
  end if;
  if p_path is null or p_path !~ ('^' || v_company::text || '/' || p_act::text || '/[A-Za-z0-9_.-]{1,80}\.pdf$') then
    raise exception 'act_bad_path' using errcode = '22023';
  end if;
  update contractor_acts a set pdf_path = p_path
   where a.id = p_act and a.company_id = v_company
     and (public.is_admin() or public.zones_unrestricted() or public.can_see_contractor(a.contractor_id));
  if not found then
    raise exception 'act_denied' using errcode = '42501';
  end if;
end $$;
revoke all on function public.contractor_act_set_pdf(uuid, text) from public, anon;
grant execute on function public.contractor_act_set_pdf(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Хранилище PDF актов
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('contractor-acts', 'contractor-acts', false, 10485760, array['application/pdf'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists contractor_acts_files_select on storage.objects;
drop policy if exists contractor_acts_files_insert on storage.objects;

-- Папки: [1] — компания, [2] — акт. Подзапрос к contractor_acts проходит
-- через contractor_acts_select (менеджер своей зоны). Урок 0014: objects.name.
create policy contractor_acts_files_select on storage.objects for select to authenticated using (
  bucket_id = 'contractor-acts'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and exists (select 1 from public.contractor_acts a
               where a.id::text = (storage.foldername(objects.name))[2]));

create policy contractor_acts_files_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'contractor-acts'
  and (storage.foldername(objects.name))[1] = (select public.my_company_id())::text
  and (select public.is_manager())
  and exists (select 1 from public.contractor_acts a
               where a.id::text = (storage.foldername(objects.name))[2]
                 and a.pdf_path is null));
```

### 0022_telegram_notify.sql
Уведомления в Telegram: отметки отправленных уведомлений и отписки, функции только для service_role. Требует 0018.

**Повторный запуск безопасен**: `if not exists`, `create or replace`, `drop … if exists`, `on conflict`. Проверено: `tools/db_test/run.sh` запускает каждую новую миграцию дважды.

```sql
-- 0022 — уведомления автору заявки в Telegram (шаг 24). Требует 0018.
--
-- Без pg_net и pg_cron: после смены статуса приложение (менеджер или
-- исполнитель) вызывает Edge Function telegram-notify со своим JWT. Функция
-- читает заявку под RLS пользователя (видит ли он её, какой статус сейчас
-- В БАЗЕ — не со слов приложения), затем service_role-функцией
-- tg_notify_claim берёт чат автора из telegram.orders и отметку «по этому
-- статусу уже отправлено». Повторный вызов на тот же статус ничего не шлёт.
-- Не получилось отправить — tg_notify_release снимает отметку.
--
-- 1) telegram.notified — (заявка, статус): уже отправлено.
-- 2) telegram.optout — чаты, которые попросили «Не присылать уведомления»
--    (/stop или кнопка). /start или новая заявка — снова присылать.
-- 3) tg_notify_claim(заявка, статус) → кому и что отправить (или null);
--    tg_notify_release(заявка, статус); tg_notify_optout(чат, выкл).
--    Только service_role — как остальные tg_* (0018).
--
-- Статусы с уведомлением: in_progress (взяли в работу), done (выполнена),
-- returned (возвращена на доработку), cancelled (отклонена).
-- Повторный запуск безопасен: if not exists, create or replace.

do $$
begin
  if to_regclass('telegram.orders') is null then
    raise exception '0022: сначала примените миграцию 0018 (Telegram-бот)';
  end if;
end $$;

create table if not exists telegram.notified (
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  status        text not null,
  sent_at       timestamptz not null default now(),
  primary key (work_order_id, status)
);

create table if not exists telegram.optout (
  chat_id    bigint primary key,
  created_at timestamptz not null default now()
);

revoke all on all tables in schema telegram from public, anon, authenticated, service_role;

-- Кому и что отправить. null — не отправлять: заявка не из Telegram, статус
-- без уведомления, по нему уже отправлено, чат отписался или отвязан.
create or replace function public.tg_notify_claim(p_order uuid, p_status text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  o record;
  w record;
  v_kind text;
  v_lang text;
  inserted int;
begin
  if p_status not in ('in_progress', 'done', 'returned', 'cancelled') then
    return null;
  end if;
  select t.chat_id, t.profile_id, t.link_id into o from telegram.orders t where t.work_order_id = p_order;
  if not found then return null; end if;
  select wo.status, wo.title, wo.company_id, wo.return_reason into w from work_orders wo where wo.id = p_order;
  -- Только текущий статус заявки в базе — не то, что прислали.
  if not found or w.status <> p_status then return null; end if;
  if exists (select 1 from telegram.optout x where x.chat_id = o.chat_id) then return null; end if;

  if o.chat_id < 0 then
    if not exists (select 1 from telegram_groups g where g.chat_id = o.chat_id and g.company_id = w.company_id) then
      return null;
    end if;
    v_kind := 'group';
    v_lang := 'ru';
  elsif o.profile_id is not null
        and exists (select 1 from telegram_links l where l.chat_id = o.chat_id and l.profile_id = o.profile_id) then
    v_kind := 'user';
    select l.language into v_lang from telegram_links l where l.chat_id = o.chat_id;
  elsif exists (select 1 from telegram_guests g where g.chat_id = o.chat_id and g.company_id = w.company_id) then
    v_kind := 'guest';
    select g.language into v_lang from telegram_guests g where g.chat_id = o.chat_id;
  else
    return null;
  end if;

  insert into telegram.notified(work_order_id, status) values (p_order, p_status)
  on conflict do nothing;
  get diagnostics inserted = row_count;
  if inserted = 0 then return null; end if;

  return jsonb_build_object(
    'chat_id', o.chat_id, 'kind', v_kind, 'lang', coalesce(v_lang, 'ru'),
    'number', upper(left(p_order::text, 6)), 'title', w.title, 'status', p_status,
    'return_reason', case when p_status = 'returned' then left(coalesce(w.return_reason, ''), 300) end);
end $$;

-- Отправить не удалось — снять отметку, чтобы следующий вызов попробовал снова.
create or replace function public.tg_notify_release(p_order uuid, p_status text)
returns void language sql volatile security definer set search_path = public as $$
  delete from telegram.notified where work_order_id = p_order and status = p_status;
$$;

-- «Не присылать уведомления» (p_off = true) / снова присылать (false).
create or replace function public.tg_notify_optout(p_chat bigint, p_off boolean)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if p_off then
    insert into telegram.optout(chat_id) values (p_chat) on conflict do nothing;
  else
    delete from telegram.optout where chat_id = p_chat;
  end if;
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.tg_notify_claim(uuid, text)',
    'public.tg_notify_release(uuid, text)',
    'public.tg_notify_optout(bigint, boolean)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
```

## AR (блок 10)
`docs/research/ar-options.md` (проверено 14.10.2026, около 40 ссылок). Главное:
- **К 19.10 настоящий AR лучше не делать.** Реально за 2–3 дня — режим «как AR»: живая камера, кнопка «Что это?», уже готовое «Узнать по фото» и карточка поверх кадра (без привязки метки к прибору — так и называть на показе).
- Дополнительно можно отдельную WebXR-страницу (2–3 дня): только Chrome на Android с ARCore, метка ставится рукой и исчезает при закрытии страницы. На iPhone WebXR нет.
- Готовые Flutter-пакеты для ARCore как основу брать не стоит (не обновлялись около 3 лет, форки сомнительные).
- **Для пилота** — свой AR-экран на Kotlin (ARCore + SceneView), который открывается из Flutter: метки к наклейкам-картинкам, потом облачные якоря ARCore. Оценка 3–5 недель.
- Niantic Spatial (Scaniverse + VPS 2.0) — на потом: нет SDK для веба и Flutter, работа внутри помещений не подтверждена, цена приватных локаций — через продажи.
- Таблица `ar_anchors` (0002) не используется и для меток не годится как есть (нет вида якоря, системы координат, этажа, срока жизни, `company_id`, права без зон) — в документе два варианта схемы.

## ⚠️ Решения (что решил и почему)
1. **Фото**: причина — показ картинки в Яндекс Браузере, а не права. Права «видят все, кто видит заявку» уже были верными, их не трогал. Окончательно подтвердить — в Яндекс Браузере на рабочей базе.
2. **Фильтр списка — не контекст формы**: объект подставляется только при переходе из карточки объекта.
3. **GPS-разрешение**: при первом открытии формы браузер / телефон один раз спросит доступ к геопозиции; отказ — форма просто пустая.
4. **Миграции разделены на 4** (0019 документы, 0020 системы, 0021 акты, 0022 Telegram): каждую можно применить и проверить отдельно.
5. **Менеджер без зон видит все системы, исполнитель и заявитель — тоже** (иначе в их заявках пропали бы названия систем); ограничение — только у менеджера с зонами.
6. **«Визит нужен» = у объекта есть координаты**; отдельного флага нет.
7. **Ставки — одна пара на подрядчика** (за заявку и за визит ТО), в отдельной таблице, невидимой исполнителям.
8. **Состав акта считает приложение**, база хранит снимок и выдаёт номер.
9. **PDF документа открывается в новой вкладке** (встроенный просмотрщик браузера), не внутри приложения.
10. **Миниатюры фото — тот же файл**, уменьшенный при показе (трансформация картинок Storage не подключена).
11. **Демо-фото «после» — картинка из сборки** (`demo/ac_after.jpg`), не файл Storage: Refresh demo не умеет загружать файлы, а реальные фото объектов в демо нельзя.
12. **Порядок систем**: исправлена старая ошибка — системы и кнопки «Вид работ» шли в обратном порядке («Другое» первым).
13. **Английский**: «PM» заменён на «Maintenance» везде в интерфейсе.

## Что сделать вам (по шагам)
1. Проверить и слить PR (кнопка **Merge** в PR на GitHub).
2. Применить миграции **по очереди** — для каждой: GitHub → **Actions** → [Apply migration](https://github.com/Anton-Key/hey-helpy/actions/workflows/apply-migration.yml) → **Run workflow** (ветка `main`) → в поле `file` — имя файла → **Run workflow** → прочитать текст в первой задаче → **Review deployments** → `production-db` → **Approve and deploy**. После каждой — написать мне «применена NNNN».
   1. `0019_order_documents.sql`
   2. `0020_systems.sql`
   3. `0021_contractor_acts.sql`
   4. `0022_telegram_notify.sql`
3. **Refresh demo** — [Actions → Refresh demo](https://github.com/Anton-Key/hey-helpy/actions/workflows/refresh-demo.yml) → Run workflow (`main`) → Review deployments → Approve and deploy (значки систем, доказательства для акта, ставки). Запускать **после** 0020 и 0021.
4. **Deploy functions** — [Actions → Deploy functions](https://github.com/Anton-Key/hey-helpy/actions/workflows/deploy-functions.yml) → Run workflow (`main`) → Approve. В Summary должно быть 4 функции, у всех **401**: `voice-intake`, `photo-identify`, `telegram-bot`, `telegram-notify`. Новых секретов не нужно (`TELEGRAM_BOT_TOKEN` уже задан).
5. **Telegram webhook** (`set`) — [Actions → Telegram webhook](https://github.com/Anton-Key/hey-helpy/actions/workflows/telegram-webhook.yml) → Run workflow (`main`, `action` = `set`) → Approve: в меню бота появится команда /stop.
6. Сайт — обновить с **Ctrl+Shift+R**; APK — скачать заново по постоянной ссылке.

## Как проверить руками
- **Фото (блок 2)** — в **Яндекс Браузере**: «По фото» → «Это он» → «Создать» → открыть заявку → «Фото · 1 → До» видно, по нажатию — на весь экран, ←/→ и Esc работают, «Скачать». Заявку «Капает конденсат над рабочим местом» (после Refresh demo) — «После · Исполнитель Демо · … · в геозоне».
- **Форма (блок 1)**: создать заявку на любой объект → снова «+ Заявка» — объект пустой, снизу «Недавние». На телефоне рядом с «БЦ «Демо»» (Белград) — «Рядом с вами · N м». Из карточки оборудования — «из карточки оборудования».
- **Системы (блок 4)**: «Профиль → Моя компания → Системы»: 7 систем по порядку со значками; «+» → «Лифты» / «Lifts» → появилась; «Архивировать» → её нет в «+ Заявка». У «Климат» → «Удалить» — «Системой уже пользуются…».
- **Документы (блок 3)**: карточка любой заявки → «Прикрепить файл» → PDF → «Документы · 1» → «Открыть». Сгенерированный пример, не реальный документ.
- **Акты (блок 6)**: «Отчёты → Акты подрядчикам» → «КлиматСервис», октябрь: к оплате 5 (22 500 ₽), без доказательства 4 с причинами → «Сформировать акт» → PDF; кнопка Excel → файл .xlsx.
- **Telegram (блок 7)**: создать заявку в боте гостем (QR) → в приложении «Начать работу» → в Telegram «взята в работу 🔧» с кнопкой «Не присылать»; «Принять» после фото «после» → «выполнена ✅» с фото. /stop → больше не приходит; /start → снова.
- **Английский**: переключить EN → в меню «Maintenance».

## Ограничения и что не сделано
- Причину «фото не видно» на рабочей базе воспроизвести нельзя (заявку удалил Refresh demo); исправлен вероятный механизм (Яндекс Браузер), проверить — по пункту выше.
- Уведомления в Telegram — только когда статус меняют из приложения (pg_net / pg_cron нет).
- PDF документа — во вкладке браузера, без встроенного просмотра в приложении.
- Числа акта в демо зависят от дня запуска Refresh demo (см. блок 6).
- Кадр питча 20 на рабочей базе снимется только после 0021 и Refresh demo (`node tools/screens/screens.mjs --pitch --only=20`).
- AR — только исследование, кода нет.

## Журнал
- 00:00 · Начало шага, отчёт создан
- 00:20 · Базовый прогон сквозных тестов на коде `main`: 9 из 9 прошли
- 00:45 · Блоки 1–2: форма без прошлого места (контекст → GPS → пусто), фото «До / После» и просмотр · 6ca26f1
- 01:30 · Блок 2: причина в рабочей базе найдена по журналу запросов; блок 3: документы, миграция 0019; блок 4: миграция 0020; тесты базы 7/7 · 2092f6f
- 02:10 · Блок 4: экраны «Системы», архивные системы не предлагаются · eeb04c8
- 03:00 · Блок 6: акты подрядчикам (0021, PDF, Excel, демо-доказательства), тесты базы 8/8 · 4ba4ec8
- 03:30 · Блок 7: `telegram-notify`, 0022, /stop; тесты базы 9/9, deno 84 · 6381c7f
- 03:50 · Блоки 5, 8, 9: EN «Maintenance», плашки главной, документация, сценарии e2e 12–14, снимки шага 24 · 84ce2e7
- 04:30 · Предпросмотр 26/26, AR-исследование, сквозные 14/14, /check, /screens рабочей базы 274/275, правки вёрстки

## Где остановился
Шаг завершён: все блоки сделаны, проверки пройдены, PR переведён в «готов к проверке». Дальше — «Что сделать вам».
