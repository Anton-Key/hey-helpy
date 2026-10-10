# Шаг 16: ППР, регионы и страны, PDF-отчёты, реестр оборудования, номера и области помещений

Ветка `step-16` от `main` (после слияния шага 15). Миграция `0015_ppr_regions_equipment.sql` — **ждёт применения**.
Отчёт обновлялся по ходу работы (журнал внизу).

## Чек-лист
- [x] 0. Обязательный порядок работы в `CLAUDE.md`; 0014 — в «Применённые миграции»
- [x] A. Миграция 0015 + локальный PostgreSQL + SQL-тесты (изоляция компаний)
- [x] B. Демо-данные (регионы, оборудование, планы ППР, задачи периодов)
- [x] C. ППР в приложении
- [x] E. Печать отчётов в PDF
- [x] D. Регионы и страны
- [x] F. Реестр оборудования
- [x] G. Номера и области помещений на плане
- [x] H. Проверки, снимки, отчёт, PR

## Коротко
- **ППР** — новый раздел: планы регулярных работ (месяц / квартал / полгода / год / каждые N дней), задача текущего периода создаётся сама (при входе менеджера и по «Обновить», не чаще раза в 10 минут), история периодов, статус периода цветом, сводка «Октябрь: выполнено 5 из 8», фильтры, тип «ППР» в заявках, строка «ППР · октябрь 2026 · до 31 окт.» в заявке.
- **Регионы и страны** без дублей: общий список регионов компании, проверка похожих названий («Европпа» → «Похоже, такой регион уже есть: «Европа»»), объединение регионов, страна — только из справочника ISO (с флагом), город — с подсказками. «Локации» — регион → страна → город, окно выбора объектов — «Весь регион / Вся страна / Весь город».
- **PDF-отчёт**: кнопка с принтером в «Отчётах» → PDF по текущим фильтрам (A4, шапка, показатели, «По регионам», «По подрядчикам», список заявок, «стр. 2 из 5»), на английском — английский PDF.
- **Реестр оборудования**: раздел «Оборудование · N» в карточке объекта, карточка оборудования (паспорт, «Показать на плане», планы ППР, заявки, «Создать заявку»), импорт из Excel / CSV с проверкой строк.
- **Номера и области помещений**: номер «305» у помещения (в списках, поиске, голосовом разборе «в 305-й»), область помещения на плане (обвести по углам или прямоугольником), заливка цветом статуса.
- **Разделение компаний** проверено на настоящем PostgreSQL: 556 автоматических проверок, все зелёные (подробно ниже).
- Приложение **работает и без 0015**: новые разделы показывают «Нужна миграция 0015», остальное — как раньше (проверено снимками на рабочей базе).

## ⚠️ Решения
- ⚠️ Открытых задач (GitHub Issues) в начале шага нет — `gh issue list --state open` пуст.
- ⚠️ План 802 «Чистка фильтров кондиционеров» — на **Дубай · Офис 2**, а не «Офис 1», и план 803 «ТО лифтов» — на **Москва · Офис 5**, а не «Офис 1»: старые заявки 241 и 234, которые становятся задачами этих планов, стоят именно там (241 — Dubai Marina, 234 — атриум Сколково). Иначе у задачи и её плана были бы разные объекты.
- ⚠️ План 808 «Поверка датчиков дыма» (слой «Системы безопасности») — без подрядчика: в демо нет подрядчика по этому слою. Задачи висят «Новая» — так видно состояние «не назначено»; прошлое полугодие (270) — просрочено.
- ⚠️ В 0015 добавлены триггеры проверки ссылок и для **старых** таблиц: заявки (объект, помещение, оборудование, слой, подрядчик, исполнитель, план), закрепления подрядчиков, подрядчик ↔ объект, исполнители, метки. Раньше политики проверяли только `company_id` самой строки, и менеджер мог вписать id чужой компании (например, свой подрядчик + слой чужой компании → заявки чужой компании назначались бы его подрядчику). В рабочей базе нарушений нет (проверено запросом только на чтение 10.10), поэтому триггеры ничего не ломают.
- ⚠️ `ppr_generate()` создаёт задачи только у менеджера / администратора; у остальных возвращает 0 без ошибки. Название задачи — на языке профиля того, кто вызвал (ru / en); приложение показывает период по `period_start` / `period_end` на языке интерфейса.
- ⚠️ Задачи генерирует приложение (при входе менеджера). Если месяц никто из менеджеров не заходил — задачи появятся при первом входе. Ночной запуск без приложения — следующий шаг (см. «Ограничения»).
- ⚠️ На телефоне «ППР» — второй сегмент «Заявки | ППР | Подрядчики | Локации» (на 360 помещается, снимок `manager-360-ppr-list.png`); на ПК — отдельный пункт бокового меню, а сегменты остаются «Заявки | Подрядчики | Локации».
- ⚠️ Состояние периода: «Просрочено» — период закончился, а задача не принята; в последний день периода — ещё «Не начато» / «В работе». Сводка «Октябрь: выполнено N из M» считает все активные планы по их текущему периоду (квартальный план, выполненный в октябре, — «выполнено»).
- ⚠️ Тип заявки «ППР» в фильтре — по `recurrence.kind = 'ppr'` (работает и на базе без 0015: просто 0 заявок). «Повторяющаяся» теперь — повторяющиеся, кроме ППР. Правка задачи ППР в форме заявки не превращает её в обычную повторяющуюся.
- ⚠️ Номер заявки в PDF — последние 6 знаков id («#000101»): отдельного номера у заявок нет. Сквозной номер — отдельная доработка базы.
- ⚠️ Импорт: шаблон и русские / английские названия колонок — в коде (это формат файла, а не надписи на экране: шаблон, скачанный по-русски, должен импортироваться и в английском интерфейсе). `/check` видит там кириллицу — так задумано. Недостающие помещения импорт создаёт по одному, затем всё оборудование — одним запросом; если этот запрос упадёт, созданные помещения останутся.
- ⚠️ Номер помещения задаётся на плане в режиме «Редактировать» (шторка маркера → «Номер помещения»), потому что отдельной формы помещения в приложении нет.
- ⚠️ В режиме «Редактировать» нажатие внутри области помещения — «поставить здесь», а не «открыть помещение»: иначе внутри комнаты нельзя было бы разместить оборудование.
- ⚠️ При переименовании региона «Использовать «Европа»» оставляет старое название (объединить — отдельной командой «Объединить с…»).
- ⚠️ Пакеты: `pdf 3.12` и `printing 5.14` (не самые новые): самые новые требуют `xml 7`, а `excel` (импорт) — `xml 6`. Версии подобраны автоматически.
- ⚠️ Блоки C–G сделаны параллельно в отдельных ветках (`step-16-d/e/f/g`) и слиты в `step-16`; конфликты были только в файлах переводов — объединены, переводы сгенерированы заново.
- ⚠️ Локальная база — PostgreSQL 16 (в Supabase — 15/17); заглушки `auth` и `storage` повторяют только то, что используют миграции. Поле `work_orders.assigned_contractor_id`, которого нет в миграциях, добавляется в тестовой базе между 0003 и 0004 (`tools/db_test/05_shim_after_0003.sql`) — как в рабочей.
- ⚠️ Снимки новых экранов (`docs/screens/preview/`) — с **локальной** базы (все миграции + демо-данные, PostgREST), а не подстановкой ответов: так экраны показывают настоящую работу 0015 и её прав. Помечены «ПРЕДПРОСМОТР». Обычный `/screens` (`docs/screens/latest/`) снят на рабочей базе без 0015 — видно, что приложение там не падает.

## Что сделано по блокам

### 0. Правила работы
- В `CLAUDE.md` — раздел «Обязательный порядок работы над каждым шагом» (без вопросов, отчёт первым коммитом, сохранение прогресса, продолжение после обрыва, «3 раза — обойти», итоговый отчёт всегда).
- 0014 — в строке «Применённые миграции»; правило: миграция, применённая вручную до слияния, вносится в «Применённые» следующим PR.

### A. Миграция 0015 (полный текст — в конце отчёта)
- Регионы (`regions`, уникальность по нормализованному имени внутри компании), у объекта — страна (ISO, проверка в базе), город (заполнен из адреса), регион.
- Номер помещения (`locations.code`, уникален в объекте без учёта регистра).
- Паспорт оборудования (`assets.layer_id`, производитель, модель, серийный номер, дата ввода).
- ППР: `maintenance_plans`, у заявки — `plan_id`, `period_start`, `period_end` (одна задача на план и период), функции `period_bounds`, `period_label`, `ppr_generate()`, канал `ppr`.
- Индексы под новые фильтры, проверочные запросы в конце файла.
- **Локальная проверка**: `bash tools/db_test/run.sh` (PostgreSQL 16, все миграции 0001–0015 по порядку, 0015 — дважды).

### B. Демо-данные (`supabase/seed/demo_history.sql`, блок 5e; блок 5d — из `plans.json`)
- Регионы 901–905, у всех 20 объектов — страна, город, регион.
- Оборудование 701–720 — паспорт; 721–735 — ещё 15 единиц (Москва · Офис 1, Дубай · Офис 1, Абиджан) для реестра.
- Номера помещений на схемах (101–104, 301–304, 1501–1504, «305» — Open space) и области помещений этажей 601–603.
- Планы ППР 801–808 с чек-листами (3–5 пунктов), задачи периодов 258–276; 234 и 241 — задачи текущего месяца планов 803 и 802.
- Без 0015 скрипт останавливается: «Сначала примените миграцию 0015».
- Проверено на локальной базе: скрипт дважды подряд без ошибок, итог **91 заявка (21 задача ППР), 35 единиц оборудования, 5 регионов, 8 планов, 20 объектов с страной / городом / регионом, 13 помещений с номером, 12 областей**.

### C. ППР в приложении — `lib/features/ppr/`
- Раздел «ППР»: телефон — сегмент, ПК — пункт бокового меню.
- Список: название, «Москва · Офис 1 · Климат», «каждый месяц · октябрь 2026 · МосКлимат», статус периода цветом; группы «Просрочено / Не начато / В работе / Выполнено / Приостановлен»; сводка «Октябрь: выполнено N из M»; «Фильтры · N» (статус периода, объект, система, подрядчик) с «×» и «Сбросить всё».
- Карточка плана: описание, объект, помещение, оборудование, система, периодичность, подрядчик (по системе и объекту), текущий период, чек-лист, история 12 периодов (период, статус, подрядчик, «Принято … · кто») с переходом в задачу. Менеджер: изменить, приостановить / возобновить, удалить (только без задач, иначе «можно только приостановить»).
- Форма плана: название, описание, объект, помещение, оборудование, система, периодичность (+ число дней), начало, фото «после», срочность, чек-лист.
- Задача периода в списке заявок и в карточке: «ППР · октябрь 2026 · до 31 окт.», исполнителю — «Выполнить в течение периода», вид — «ППР (регламент по плану)».
- Генерация — при входе менеджера и по «Обновить» (не чаще раза в 10 минут; без 0015 — молча).
- Фильтр «Тип»: «Разовая / Повторяющаяся / ППР».

### D. Регионы и страны — `lib/features/regions/` и др.
- «Моя компания» → «Регионы компании»: добавить, переименовать, порядок, удалить, «Объединить с…» (с подтверждением «7 объектов перейдут в «Европа»»).
- Проверка похожих: нормализация + Левенштейн ≤ 2 (короче 5 букв — ≤ 1); точный дубль база не пропустит — понятное сообщение.
- Страна — из справочника ISO (≈ 245 стран, поиск по-русски, по-английски и по коду, флаг); город — с подсказками и той же проверкой похожих.
- Карточка объекта → «Адрес и геозона»: «Страна», «Город», «Регион».
- «Локации»: регион → страна → город; без регионов — по городам; чипы над картой — регионы.
- Окно выбора объектов: «Весь регион», «Вся страна», «Весь город» с галочкой / минусом; подпись «Европа (7)», «Россия · Москва (5)».

### E. PDF-отчёт — `lib/features/reports/report_pdf.dart`
- Кнопка с принтером (ПК — в служебных кнопках страницы, телефон — в шапке) и ⓘ «Печать отчёта».
- A4, шапка «Эй, Helpy», компания, название, фильтры словами, «Сформирован: дата, время, имя»; показатели (заявок, в срок, приняты с первого раза, визиты в геозоне, ППР выполнено N из M); «По регионам»; «По подрядчикам»; список заявок; «стр. N из M», повтор шапки таблицы.
- Шрифт Onest вшит; веб — окно печати браузера («Сохранить как PDF»), Android — «Поделиться»; имя `HeyHelpy_Отчёт_<период>.pdf`.
- В «Отчётах» — фильтры «Регион» и «Тип», плитка «ППР выполнено», блок «По регионам» (или «По городам», если регионов нет).

### F. Реестр оборудования — `lib/features/equipment/`
- Карточка объекта → «Оборудование · N» по системам, поиск; менеджер — «Добавить оборудование» и «Импорт из Excel / CSV».
- Карточка оборудования: паспорт, где стоит (помещение с номером, этаж, «Показать на плане»), планы ППР (переход в карточку плана), история заявок, «Создать заявку» (объект, помещение, оборудование и система подставлены).
- Импорт: шаблон `.xlsx` / `.csv` → выбор файла → предпросмотр с ошибками по строкам (нет помещения, неизвестная система, дубль инвентарного номера, неверная дата) → «Импортировать N строк»; недостающие помещения — по переключателю «Создать».

### G. Номера и области помещений — `lib/features/floors/`, `text_intake.dart`
- Номер помещения: в шторке маркера (режим «Редактировать»), в списках («305 · Переговорная»), в поиске, в разборе заявки по словарю («в 305-й», «кабинет 305», «room 305»).
- Область: «Обвести область» → по углам («Готово» / «Отменить точку») или прямоугольником; перетаскивание вершин, «Удалить область»; заливка цветом статуса, нажатие в области = нажатие на маркер, подпись по центру при приближении.
- ИИ-разметку не делали — как её подключить, см. «Ограничения».

## Проверки
- `flutter analyze lib test` — без замечаний.
- `flutter test` — **295 тестов, все прошли** (новые: `ppr_logic_test` 14, `report_pdf_test` 10, `room_area_test` 18, `equipment_import_test` 13, `region_name_match_test`, `region_grouping_test`, `country_list_test`, дополнение `order_filter_test`).
- Строки вне переводов: только словарь разбора заявки (`text_intake.dart`, было и раньше), шаблон импорта (`equipment_import.dart`, ⚠️ выше), служебная нормализация `'ё' → 'е'` и пример фразы голоса — как раньше.
- Название продукта — нарушений нет.
- Веб-сборка — собирается (её делает `/screens`).
- **SQL-тесты на локальном PostgreSQL 16** (`bash tools/db_test/run.sh`):

| Набор | Проверок | Упало | Что проверяет |
|---|---|---|---|
| `tenant_isolation` | 486 | 0 | все 21 таблица `public` + `storage.objects`: менеджер, администратор, исполнитель, заявитель компании 1 — 0 строк компании 2 при чтении, 0 изменённых / удалённых, отказ при вставке копии строки компании 2 и при вставке своей строки со ссылками на компанию 2; аноним — ничего; `ppr_generate()` компании 1 ничего не создал в компании 2; RLS и хотя бы одна политика у каждой таблицы |
| `cross_refs` | 21 | 0 | ссылки на чужую компанию: регион объекта, родитель помещения, система оборудования, объект / слой / помещение / оборудование плана, объект / помещение / оборудование / слой / подрядчик / план заявки, закрепления, исполнитель, метка |
| `ppr_regions` | 49 | 0 | границы периодов (конец года, високосный февраль, N дней), подписи, нормализация, дубли регионов, страна ISO, номера помещений, `ppr_generate` (идемпотентность, чек-лист, подрядчик, срок, пауза, N дней), права исполнителя и заявителя |
| демо-данные | — | — | `demo.sql` + `demo_history.sql` дважды — без ошибок, итоговые числа выше |

- Контрольная проверка тестов: если убрать RLS у `regions` или триггер проверки ссылок у заявок, тесты падают (проверено вручную).
- **Существующий риск — таблицы `public` без RLS: нет.** Политики без прямого условия по компании (через заявку или «свою строку» — безопасно, тест изоляции это подтверждает): `attachments_select`, `attachments_delete`, `checklist_select`, `checklist_check`, `work_logs_select`, `work_logs_insert`, `profiles_select_self`, `profiles_update_self`. Найденные пробелы (ссылки на чужую компанию в заявках, закреплениях, исполнителях, метках) закрыты триггерами 0015.

## Снимки
- `/screens` на **рабочей базе** (без 0015): `docs/screens/latest/` — итоги в `docs/screens/latest/README.md` (раздел заполняется после съёмки, см. ниже).
- **ПРЕДПРОСМОТР** новых экранов на локальной базе с 0015: `docs/screens/preview/` — итоги в `docs/screens/preview/README.md`.

**`/screens` на рабочей базе (без 0015)** — `docs/screens/latest/`, **218 снимков, проблем нет** (итоги — `docs/screens/latest/README.md`). Видно, что на старой базе приложение не падает: в меню есть «ППР», остальные экраны — как в шаге 15. Ширина 1920 переснята отдельным запуском: в общем прогоне страница браузера упала на 1920 из-за нехватки памяти (параллельно шла сборка шага 17). В скрипте исправлены две хрупкие проверки: незавершённое ожидание выбора файла роняло весь прогон, а перенос маркера на плане теперь может попасть и на оборудование внутри области помещения.

**ПРЕДПРОСМОТР новых экранов на локальной базе с 0015** — `docs/screens/preview/`, **37 снимков, проблем нет** (итоги — `docs/screens/preview/README.md`): ППР (список на 1280 / 412 / 360, «Фильтры», карточка плана и история, задача периода, заявки «Тип: ППР»), «Локации» регион → страна → город, окно объектов с «Весь регион / Весь город», карточка объекта со страной / городом / регионом, «Оборудование · N», карточка оборудования, импорт с ошибками по строкам, план с областями и номерами, отчёт «По регионам», «Регионы», «Похоже, такой регион уже есть», **первая страница PDF** (файл, который веб-версия отдаёт в окно печати; 4 страницы).

Просмотрено глазами и исправлено по снимкам: на 360 обрезалась подпись «Подрядчики» в сегментах (шрифт на пункт меньше при 4 сегментах) и статус сжимал строки ППР (статус перенесён под название, как в заявках); «Дата ввода» оборудования показывалась без года; подпись вида «ППР (регламент по плану)» переносилась — сокращена до «ППР».

## Новые и изменённые файлы
- `CLAUDE.md` — правила работы над шагом, 0014 в «Применённых», 0015, ППР, регионы, оборудование, локальные SQL-тесты, предпросмотр снимков
- `docs/DEMO_SETUP.md` — миграции до 0015, итоги Refresh demo (91 заявка, 8 планов ППР, 5 регионов, 35 единиц оборудования)
- `docs/design/DESIGN.md` — экраны шага 16 из компонентов дизайн-системы, новые значки, подсказки
- `docs/reports/step-16.md` — этот отчёт
- `lib/core/design/icons.dart` — значки печати, скачивания, таблицы
- `lib/core/l10n_ext.dart` — `l.date()` — дата без времени
- `lib/core/schema_compat.dart` — новый: работа на базе без новой миграции, «Нужна миграция NNNN»
- `lib/features/directory/city.dart` — город объекта из поля `city`, группировка регион → страна → город
- `lib/features/directory/directory.dart` — страна / город / регион объекта, номер помещения, «Локации» по регионам
- `lib/features/directory/object_card.dart` — «Страна / Город / Регион», раздел «Оборудование», номер помещения
- `lib/features/directory/object_picker.dart` — «Весь регион / Вся страна / Весь город», подписи «Европа (7)»
- `lib/features/equipment/asset_card.dart` — новый: карточка оборудования
- `lib/features/equipment/equipment_form.dart` — новый: форма оборудования, значок по виду
- `lib/features/equipment/equipment_import.dart` — новый: разбор CSV / Excel и проверка строк (чистые функции)
- `lib/features/equipment/equipment_import_screen.dart` — новый: импорт — шаблон, предпросмотр с ошибками
- `lib/features/equipment/equipment_models.dart` — новый: модель оборудования
- `lib/features/equipment/equipment_repository.dart` — новый: запросы реестра
- `lib/features/equipment/equipment_section.dart` — новый: раздел «Оборудование · N»
- `lib/features/floors/floor_models.dart` — номер и область помещения
- `lib/features/floors/floor_plan_screen.dart` — «Номер помещения», «Обвести область»
- `lib/features/floors/floor_repository.dart` — сохранение номера и области
- `lib/features/floors/plan_canvas.dart` — области помещений, подписи, рисование
- `lib/features/floors/plan_logic.dart` — точка в многоугольнике, разбор `plan_shape`
- `lib/features/floors/plan_sheets.dart` — поле с подсказкой и ограничением длины
- `lib/features/home/home_chrome.dart` — сегмент «ППР» на телефоне
- `lib/features/home/home_screen.dart` — раздел «ППР» на ПК, генерация при входе менеджера
- `lib/features/map/map_logic.dart` — чипы регионов
- `lib/features/map/objects_map_view.dart` — чипы регионов над картой
- `lib/features/ppr/ppr_card.dart` — новый: карточка плана ППР
- `lib/features/ppr/ppr_form.dart` — новый: форма плана ППР
- `lib/features/ppr/ppr_logic.dart` — новый: периоды, состояние, порог генерации (чистые функции)
- `lib/features/ppr/ppr_repository.dart` — новый: планы, задачи, генерация
- `lib/features/ppr/ppr_tab.dart` — новый: раздел «ППР»
- `lib/features/ppr/ppr_text.dart` — новый: подписи периодов
- `lib/features/ppr/ppr_view.dart` — новый: строка списка, подрядчик плана, фильтр
- `lib/features/profile/company_screen.dart` — «Регионы компании»
- `lib/features/regions/countries.dart` — новый: справочник стран ISO
- `lib/features/regions/geo_pickers.dart` — новый: выбор страны, города, региона
- `lib/features/regions/name_match.dart` — новый: похожие названия
- `lib/features/regions/region.dart` — новый: регионы, объединение
- `lib/features/regions/region_flows.dart` — новый: «Похоже, такой регион уже есть»
- `lib/features/regions/regions_screen.dart` — новый: экран «Регионы»
- `lib/features/reports/report_pdf.dart` — новый: PDF отчёта
- `lib/features/reports/report_repository.dart` — регионы, ППР, тип задачи
- `lib/features/reports/reports_screen.dart` — печать, «Регион», «Тип», «По регионам», плитка ППР
- `lib/features/requests/order_filter.dart` — тип «ППР»
- `lib/features/requests/order_filter_bar.dart` — подпись «ППР»
- `lib/features/requests/order_filters_panel.dart` — пункт «ППР»
- `lib/features/requests/requests.dart` — строка периода ППР в карточке, номер помещения, правка задачи ППР
- `lib/features/requests/requests_tab.dart` — строка периода ППР в списке, номер помещения
- `lib/features/requests/work_order.dart` — поля ППР и номер помещения
- `lib/features/voice/text_intake.dart` — номер помещения в разборе («в 305-й»)
- `lib/l10n/app_en.arb` — строки шага 16
- `lib/l10n/app_localizations.dart` — сгенерировано
- `lib/l10n/app_localizations_en.dart` — сгенерировано
- `lib/l10n/app_localizations_ru.dart` — сгенерировано
- `lib/l10n/app_ru.arb` — строки шага 16
- `pubspec.lock` — версии пакетов
- `pubspec.yaml` — пакеты `pdf`, `printing`, `excel`, `file_picker`
- `supabase/migrations/0015_ppr_regions_equipment.sql` — новая миграция
- `supabase/seed/demo_history.sql` — блок 5e (регионы, оборудование, ППР), номера и области (5d), проверка 0015
- `test/country_list_test.dart` — новый
- `test/equipment_import_test.dart` — новый
- `test/order_filter_test.dart` — тип «ППР»
- `test/ppr_logic_test.dart` — новый
- `test/region_grouping_test.dart` — новый
- `test/region_name_match_test.dart` — новый
- `test/report_pdf_test.dart` — новый
- `test/room_area_test.dart` — новый
- `tools/db_test/00_supabase_stub.sql` — новый: заглушки Supabase
- `tools/db_test/05_shim_after_0003.sql` — новый: поле, добавленное в рабочей базе вручную
- `tools/db_test/10_fixture.sql` — новый: две компании с одинаковыми названиями
- `tools/db_test/20_demo_seed.sh` — новый: демо-данные дважды
- `tools/db_test/cross_refs.sql` — новый: ссылки на чужую компанию
- `tools/db_test/ppr_regions.sql` — новый: периоды, регионы, ППР
- `tools/db_test/run.sh` — новый: запуск всех проверок
- `tools/db_test/tenant_isolation.sql` — новый: изоляция компаний по всем таблицам
- `tools/demo_plans/generate.mjs` — номера и области помещений в SQL-блоке 5d
- `tools/demo_plans/plans.json` — номера помещений
- `tools/screens/local_backend.mjs` — новый: локальный «Supabase» (PostgREST + вход + картинки планов)
- `tools/screens/local_screens.mjs` — новый: ПРЕДПРОСМОТР новых экранов
- `docs/screens/latest/*`, `docs/screens/preview/*` — снимки

## Что сделать вам
1. Проверить PR шага 16 и **слить** его (Merge).
2. GitHub → Actions → **«Apply migration»** → Run workflow → `file`: `0015_ppr_regions_equipment.sql` → прочитать текст в задаче «Проверка и текст миграции» → Review deployments → `production-db` → **Approve and deploy**.
3. Написать мне «применена 0015» — я внесу номер в «Применённые миграции» (или впишите сами).
4. GitHub → Actions → **«Refresh demo»** → Run workflow → одобрить. Ожидаемо в Summary: **«Демо БЦ»: заявок 91, визитов 15 или 16**.
5. В приложении на ПК в «Демо БЦ» загрузить картинки этажей, если ещё не загружены (картинки Refresh demo не трогает).

## Как проверить руками (менеджер «Демо БЦ», после шагов 2–4)
1. **ППР**: телефон — сегмент «ППР», ПК — пункт меню «ППР». Сверху «Октябрь: выполнено …», ниже группы по статусу текущего периода. Карточка «Проверка генератора» → в истории сентябрь — «Просрочено».
2. Открыть «ТО кондиционеров» → история периодов (июнь–октябрь) → нажать октябрь → карточка заявки «ППР · октябрь 2026 · до 31 окт.».
3. «+» в «ППР» → новый план «Обход крыши», каждые 7 дней → «Обновить» → в «Заявках» с «Тип: ППР» появилась задача.
4. «Заявки» → «Все фильтры» → «Тип» → «ППР»: только задачи ППР.
5. «Профиль» → «Моя компания» → «Регионы компании» → «+» → «Европпа» → должно спросить «Похоже, такой регион уже есть: «Европа»».
6. «Локации» (список): «ЕВРОПА» → «🇷🇸 Сербия» → «Белград».
7. Карточка «БЦ «Демо»» → «Оборудование · …» → «ИБП серверной 10 кВА» → паспорт, «Показать на плане», план «Проверка ИБП серверной».
8. «Импорт из Excel / CSV» → «Скачать шаблон» → открыть, испортить одну строку (несуществующее помещение) → выбрать файл → строка помечена ошибкой.
9. План «3 этаж» БЦ «Демо» → приблизить: области комнат с подписями «301 · Переговорная…».
10. «Отчёты» → кнопка с принтером → окно печати браузера (на телефоне — «Поделиться») → PDF с таблицами и «стр. 1 из N».
11. Голосом / текстом: «в 305-й не работает свет» → помещение — Open space (305).

## Ограничения и что не сделано
- **Ночная генерация ППР** без приложения — следующий шаг: в Supabase включить расширение `pg_cron` и функцию `ppr_generate_all()` (security definer, без `auth.uid()`, по всем компаниям, вызывается только ролью `postgres`), расписание `select cron.schedule('ppr-nightly', '5 0 * * *', 'select public.ppr_generate_all()')`. Сейчас не включено: нужно решение владельца (расширение и расписание в рабочей базе).
- **ИИ-разметка плана** не сделана (нужны ключи и сервис). Как подключить: Edge Function `plan-markup` берёт картинку этажа из бакета `floor-plans` под входом пользователя, отправляет её модели распознавания изображений, получает помещения многоугольниками (доли 0..1), номерами и названиями, проверяет каждый многоугольник так же, как приложение (`parsePlanShape`: ≥ 3 точки в пределах 0..1) и возвращает **черновик**, ничего не записывая. Приложение показывает черновик в режиме «Обвести область»: менеджер правит вершины и подтверждает каждую комнату — сохраняется теми же `setShape` / `setCode` (права — только менеджер). Ключи модели — только в секретах Edge Function, выкладка — workflow «Deploy functions».
- Печать PDF в окне браузера и «Поделиться» на Android проверены только снимком PDF из веб-версии (Blob → картинка первой страницы); на телефоне — проверить руками (п. 10).
- Скачивание шаблона и выбор файла импорта на Android — через `file_picker` (окно сохранения / выбора); на устройстве не проверялось.
- Картинки ДЕМО-СХЕМ не перерисованы с номерами: номера и области рисует приложение поверх.
- Отдельного сквозного номера заявки нет (в PDF — последние 6 знаков id).

## Журнал
| Время (UTC) | Что сделано | Коммит |
|---|---|---|
| 10.10 21:35 | Раздел «Обязательный порядок работы» в `CLAUDE.md` | 83bc8bb |
| 10.10 21:37 | 0014 — в «Применённые миграции», правило о ручном применении | 129e098 |
| 10.10 21:45 | A: миграция 0015, локальный PostgreSQL 16, SQL-тесты (изоляция, ссылки, ППР) — 556 проверок зелёные | 029b897 |
| 10.10 21:50 | B: демо-данные — регионы, страны, паспорт оборудования, планы ППР 801–808, задачи 258–276; проверено на локальной базе дважды | b30a393 |
| 10.10 21:55 | Основа для приложения: `SchemaCompat` (работа без 0015), страна / город / регион объекта, номер помещения | 1ed0bc4 |
| 10.10 22:00 | C: ППР — вкладка (телефон) и пункт меню (ПК), список с фильтрами и сводкой, карточка плана, форма, генерация, тип «ППР» в заявках | 82a6381 |
| 10.10 22:05 | E, G, D, F (делались параллельно в отдельных ветках) — слиты в step-16: PDF-отчёт, номера и области помещений, регионы и страны, реестр оборудования | b053638 |
| 10.10 22:10 | Связки между блоками: номер помещения в заявках, планы ППР из карточки оборудования, страны в отчётах из общего справочника | 1cd6dbd |
| 10.10 22:15 | Документы (CLAUDE.md, DESIGN.md, DEMO_SETUP.md), локальный бэкенд для снимков новых экранов | 6d2e6ba |
| 10.10 22:45 | Исправления по снимкам (360, дата ввода, подписи) | 944abfb |
| 11.10 00:05 | Снимки: `/screens` на рабочей базе (218), ПРЕДПРОСМОТР на локальной (37, включая PDF); итоговый отчёт | (этот) |

## Где остановился
Шаг 16 закончен, PR — на проверке. Дальше — шаг 17 (ветка `step-17` от `step-16`).

## Полный текст миграции 0015

**Зачем:** ППР (регламентные работы по периодам), регионы и страны без дублей, паспорт и реестр оборудования, номера помещений; плюс жёсткая проверка, что все ссылки в строках — из той же компании.
**Что меняет:** добавляет 2 таблицы (`regions`, `maintenance_plans`), столбцы у `objects`, `locations`, `assets`, `work_orders`, функции, триггеры, индексы, политики новых таблиц; пересоздаёт ограничение `work_orders.input_channel` с новым значением `ppr` (старые значения те же); заполняет `objects.city` из адреса там, где город пуст. Ничего не удаляет и не переименовывает.
**Повторный запуск:** безопасен — проверено (`run.sh` выполняет 0015 дважды).

```sql
-- =====================================================================
-- hey_helpy · Миграция 0015: ППР, регионы и страны, реестр оборудования,
-- номера помещений (шаг 16)
-- 1) Регионы компании (regions): один общий список, без дублей —
--    «Европа», «европа », «ЕВРОПА» база считает одним регионом.
-- 2) Объект: страна (код ISO из двух заглавных латинских букв, не текст),
--    город, регион. Город у существующих объектов — из адреса (до запятой).
-- 3) Помещение: номер (locations.code), уникален внутри объекта.
-- 4) Оборудование: система (слой), производитель, модель, серийный номер,
--    дата ввода.
-- 5) ППР — регулярные работы по периодам (maintenance_plans). Задача
--    периода — обычная заявка с plan_id и границами периода. Функция
--    ppr_generate() создаёт задачи текущего периода, повторный вызов
--    ничего не дублирует.
-- 6) Жёсткое разделение компаний: у новых таблиц company_id и RLS по
--    компании; все ссылки (регион, план, слой, объект, помещение,
--    оборудование, подрядчик) проверяются триггерами на ту же компанию —
--    и у новых, и у старых таблиц (заявки, закрепления подрядчиков,
--    исполнители, метки), где раньше политика проверяла не все ссылки.
--
-- Зависит от: 0008 (политики, функции закрыты по умолчанию), 0013 (этажи).
-- Применяет пользователь: GitHub Actions «Apply migration» (с одобрением)
-- или Supabase → SQL Editor. Без begin/commit: workflow сам выполняет файл
-- одной транзакцией. Только добавления (таблицы, столбцы, функции,
-- триггеры, индексы, политики); ничего не удаляет и не переименовывает.
-- Ограничение work_orders.input_channel пересоздаётся с новым значением
-- 'ppr' (старые значения те же). Безопасно запускать повторно.
-- Проверено локально на PostgreSQL 16: tools/db_test/run.sh.
-- =====================================================================

do $$
begin
  if to_regclass('public.floors') is null then
    raise exception '0015: сначала примените миграцию 0013 (планы этажей)';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 0. Нормализация названий: регистр, пробелы по краям и внутри, «ё» → «е».
--    Используется в уникальных индексах (регионы, планы ППР).
-- ---------------------------------------------------------------------
create or replace function public.norm_name(p text)
returns text language sql immutable parallel safe
set search_path = pg_catalog
as $$
  select regexp_replace(btrim(replace(lower(coalesce(p, '')), 'ё', 'е')), '\s+', ' ', 'g');
$$;
revoke all on function public.norm_name(text) from public, anon;
grant execute on function public.norm_name(text) to authenticated;

-- ---------------------------------------------------------------------
-- 1. Регионы
-- ---------------------------------------------------------------------
create table if not exists public.regions (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name       text not null,
  sort       int  not null default 0,
  created_at timestamptz not null default now()
);

alter table public.regions drop constraint if exists regions_name_check;
alter table public.regions add constraint regions_name_check
  check (char_length(btrim(name)) between 1 and 60);

-- Уникальность — только внутри компании: у разных компаний могут быть
-- одинаковые «Европа».
create unique index if not exists regions_company_norm_key
  on public.regions (company_id, public.norm_name(name));
create index if not exists idx_regions_company on public.regions (company_id, sort);

alter table public.regions enable row level security;
revoke all on public.regions from anon;
grant select, insert, update, delete on public.regions to authenticated;

drop policy if exists regions_select on public.regions;
drop policy if exists regions_manage on public.regions;
create policy regions_select on public.regions for select
  using (regions.company_id = (select public.my_company_id()));
create policy regions_manage on public.regions for all
  using (regions.company_id = (select public.my_company_id()) and (select public.is_manager()))
  with check (regions.company_id = (select public.my_company_id()) and (select public.is_manager()));

-- ---------------------------------------------------------------------
-- 2. Объект: страна, город, регион
-- ---------------------------------------------------------------------
alter table public.objects
  add column if not exists country_code char(2),
  add column if not exists city         text,
  add column if not exists region_id    uuid references public.regions(id) on delete set null;

-- Страна — только код ISO 3166-1 (две заглавные латинские буквы), не текст.
alter table public.objects drop constraint if exists objects_country_code_check;
alter table public.objects add constraint objects_country_code_check
  check (country_code is null or country_code ~ '^[A-Z]{2}$');

alter table public.objects drop constraint if exists objects_city_check;
alter table public.objects add constraint objects_city_check
  check (city is null or char_length(btrim(city)) between 1 and 100);

-- Город у существующих объектов — часть адреса до первой запятой
-- (так же считает приложение: cityOf в lib/features/directory/city.dart).
update public.objects
   set city = btrim(split_part(address, ',', 1))
 where city is null
   and position(',' in coalesce(address, '')) > 1
   and char_length(btrim(split_part(address, ',', 1))) between 1 and 100;

create index if not exists idx_objects_region       on public.objects (region_id);
create index if not exists idx_objects_country      on public.objects (company_id, country_code);
create index if not exists idx_objects_city         on public.objects (company_id, lower(city));

-- Регион объекта — из той же компании.
create or replace function public.trg_objects_refs_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.region_id is not null
     and (tg_op = 'INSERT' or new.region_id is distinct from old.region_id
          or new.company_id is distinct from old.company_id)
     and not exists (select 1 from regions r
                      where r.id = new.region_id and r.company_id = new.company_id) then
    raise exception 'region must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_objects_refs_check on public.objects;
create trigger trg_objects_refs_check
  before insert or update on public.objects
  for each row execute function public.trg_objects_refs_check();

-- ---------------------------------------------------------------------
-- 3. Помещение: номер (код), уникален внутри объекта без учёта регистра
-- ---------------------------------------------------------------------
alter table public.locations add column if not exists code text;

alter table public.locations drop constraint if exists locations_code_check;
alter table public.locations add constraint locations_code_check
  check (code is null or char_length(btrim(code)) between 1 and 20);

create unique index if not exists locations_object_code_key
  on public.locations (object_id, lower(btrim(code))) where code is not null;

-- Родительское помещение — из той же компании (раньше не проверялось).
create or replace function public.trg_locations_refs_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.parent_id is not null
     and (tg_op = 'INSERT' or new.parent_id is distinct from old.parent_id
          or new.object_id is distinct from old.object_id)
     and not exists (select 1 from locations p
                       join objects po on po.id = p.object_id
                       join objects o  on o.id = new.object_id
                      where p.id = new.parent_id and po.company_id = o.company_id) then
    raise exception 'parent location must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_locations_refs_check on public.locations;
create trigger trg_locations_refs_check
  before insert or update on public.locations
  for each row execute function public.trg_locations_refs_check();

-- ---------------------------------------------------------------------
-- 4. Оборудование: система, производитель, модель, серийный номер, дата ввода.
--    Политики assets не меняются (0008: читает компания, меняет менеджер).
-- ---------------------------------------------------------------------
alter table public.assets
  add column if not exists layer_id     uuid references public.layers(id) on delete set null,
  add column if not exists manufacturer text,
  add column if not exists model        text,
  add column if not exists serial_no    text,
  add column if not exists installed_at date;

alter table public.assets drop constraint if exists assets_registry_text_check;
alter table public.assets add constraint assets_registry_text_check
  check (coalesce(char_length(manufacturer), 0) <= 120
     and coalesce(char_length(model), 0) <= 120
     and coalesce(char_length(serial_no), 0) <= 120);

create index if not exists idx_assets_layer on public.assets (layer_id);

-- Система оборудования — слой той же компании, что и объект помещения.
create or replace function public.trg_assets_refs_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.layer_id is not null
     and (tg_op = 'INSERT' or new.layer_id is distinct from old.layer_id
          or new.location_id is distinct from old.location_id)
     and not exists (select 1 from layers y
                       join objects o on o.company_id = y.company_id
                       join locations l on l.object_id = o.id
                      where y.id = new.layer_id and l.id = new.location_id) then
    raise exception 'layer must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_assets_refs_check on public.assets;
create trigger trg_assets_refs_check
  before insert or update on public.assets
  for each row execute function public.trg_assets_refs_check();

-- ---------------------------------------------------------------------
-- 5. Планы ППР
-- ---------------------------------------------------------------------
create table if not exists public.maintenance_plans (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  object_id      uuid not null references public.objects(id) on delete cascade,
  location_id    uuid references public.locations(id) on delete set null,
  asset_id       uuid references public.assets(id) on delete set null,
  layer_id       uuid not null references public.layers(id),
  title          text not null,
  description    text,
  period_kind    text not null default 'month',
  period_days    int,
  starts_on      date not null default current_date,
  checklist      jsonb not null default '[]'::jsonb,
  requires_photo boolean not null default true,
  priority       text not null default 'normal',
  active         boolean not null default true,
  created_by     uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.maintenance_plans drop constraint if exists maintenance_plans_title_check;
alter table public.maintenance_plans add constraint maintenance_plans_title_check
  check (char_length(btrim(title)) between 1 and 120);
alter table public.maintenance_plans drop constraint if exists maintenance_plans_period_check;
alter table public.maintenance_plans add constraint maintenance_plans_period_check
  check (period_kind in ('month', 'quarter', 'half_year', 'year', 'days')
         and ((period_kind = 'days') = (period_days is not null))
         and (period_days is null or period_days between 1 and 3660));
alter table public.maintenance_plans drop constraint if exists maintenance_plans_checklist_check;
alter table public.maintenance_plans add constraint maintenance_plans_checklist_check
  check (jsonb_typeof(checklist) = 'array' and jsonb_array_length(checklist) <= 50);
alter table public.maintenance_plans drop constraint if exists maintenance_plans_priority_check;
alter table public.maintenance_plans add constraint maintenance_plans_priority_check
  check (priority in ('low', 'normal', 'high', 'critical'));

-- Название плана уникально внутри объекта (то есть внутри компании).
create unique index if not exists maintenance_plans_object_title_key
  on public.maintenance_plans (company_id, object_id, public.norm_name(title));
create index if not exists idx_mplans_company on public.maintenance_plans (company_id, active);
create index if not exists idx_mplans_object  on public.maintenance_plans (object_id);
create index if not exists idx_mplans_layer   on public.maintenance_plans (layer_id);
create index if not exists idx_mplans_asset   on public.maintenance_plans (asset_id);

drop trigger if exists trg_mplans_updated_at on public.maintenance_plans;
create trigger trg_mplans_updated_at
  before update on public.maintenance_plans
  for each row execute function public.touch_updated_at();

-- Объект, помещение, оборудование, слой — одной компании и согласованы:
-- помещение — из объекта плана, оборудование — из этого объекта (и из
-- помещения плана, если оно задано).
create or replace function public.trg_mplans_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from objects o
                  where o.id = new.object_id and o.company_id = new.company_id) then
    raise exception 'plan object must belong to the same company' using errcode = '42501';
  end if;
  if not exists (select 1 from layers y
                  where y.id = new.layer_id and y.company_id = new.company_id) then
    raise exception 'plan layer must belong to the same company' using errcode = '42501';
  end if;
  if new.location_id is not null and not exists (
       select 1 from locations l
        where l.id = new.location_id and l.object_id = new.object_id) then
    raise exception 'plan location must belong to the plan object' using errcode = '42501';
  end if;
  if new.asset_id is not null and not exists (
       select 1 from assets a join locations l on l.id = a.location_id
        where a.id = new.asset_id and l.object_id = new.object_id
          and (new.location_id is null or a.location_id = new.location_id)) then
    raise exception 'plan asset must belong to the plan object' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_mplans_check on public.maintenance_plans;
create trigger trg_mplans_check
  before insert or update on public.maintenance_plans
  for each row execute function public.trg_mplans_check();

alter table public.maintenance_plans enable row level security;
revoke all on public.maintenance_plans from anon;
grant select, insert, update, delete on public.maintenance_plans to authenticated;

drop policy if exists mplans_select on public.maintenance_plans;
drop policy if exists mplans_manage on public.maintenance_plans;
create policy mplans_select on public.maintenance_plans for select
  using (maintenance_plans.company_id = (select public.my_company_id()));
create policy mplans_manage on public.maintenance_plans for all
  using (maintenance_plans.company_id = (select public.my_company_id()) and (select public.is_manager()))
  with check (maintenance_plans.company_id = (select public.my_company_id()) and (select public.is_manager()));

-- ---------------------------------------------------------------------
-- 6. Заявка: задача периода ППР
-- ---------------------------------------------------------------------
alter table public.work_orders
  add column if not exists plan_id      uuid references public.maintenance_plans(id) on delete set null,
  add column if not exists period_start date,
  add column if not exists period_end   date;

alter table public.work_orders drop constraint if exists work_orders_period_check;
alter table public.work_orders add constraint work_orders_period_check
  check ((period_start is null) = (period_end is null)
         and (period_start is null or period_end >= period_start));

-- Одна задача на план и период: повторная генерация ничего не дублирует.
create unique index if not exists work_orders_plan_period_key
  on public.work_orders (plan_id, period_start) where plan_id is not null;
create index if not exists idx_wo_plan       on public.work_orders (plan_id);
create index if not exists idx_wo_period_end on public.work_orders (company_id, period_end);

-- Канал «ppr» — задачу создал план ППР (остальные значения как в 0004).
alter table public.work_orders drop constraint if exists work_orders_input_channel_check;
alter table public.work_orders add constraint work_orders_input_channel_check
  check (input_channel = any (array['button','text','voice','camera','wake_word','ppr']));

-- Все ссылки заявки — из компании заявки. Раньше политика wo_insert
-- проверяла только company_id: можно было вписать чужой слой или
-- помещение. Проверяем только изменившиеся ссылки — смена статуса
-- ничего лишнего не читает.
-- BEFORE-триггеры идут по алфавиту: trg_wo_guard → trg_wo_layer_and_route →
-- trg_wo_refs_check → … — проверяется и подрядчик, назначенный правилом слоя.
create or replace function public.trg_wo_refs_check()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  c uuid := new.company_id;
  ins boolean := tg_op = 'INSERT';
begin
  if not ins and new.company_id is distinct from old.company_id then
    raise exception 'work order company cannot be changed' using errcode = '42501';
  end if;
  if new.object_id is not null and (ins or new.object_id is distinct from old.object_id)
     and not exists (select 1 from objects o where o.id = new.object_id and o.company_id = c) then
    raise exception 'object must belong to the same company' using errcode = '42501';
  end if;
  if new.location_id is not null and (ins or new.location_id is distinct from old.location_id)
     and not exists (select 1 from locations l join objects o on o.id = l.object_id
                      where l.id = new.location_id and o.company_id = c) then
    raise exception 'location must belong to the same company' using errcode = '42501';
  end if;
  if new.asset_id is not null and (ins or new.asset_id is distinct from old.asset_id)
     and not exists (select 1 from assets a join locations l on l.id = a.location_id
                       join objects o on o.id = l.object_id
                      where a.id = new.asset_id and o.company_id = c) then
    raise exception 'asset must belong to the same company' using errcode = '42501';
  end if;
  if new.layer_id is not null and (ins or new.layer_id is distinct from old.layer_id)
     and not exists (select 1 from layers y where y.id = new.layer_id and y.company_id = c) then
    raise exception 'layer must belong to the same company' using errcode = '42501';
  end if;
  if new.assigned_contractor_id is not null
     and (ins or new.assigned_contractor_id is distinct from old.assigned_contractor_id)
     and not exists (select 1 from contractors x
                      where x.id = new.assigned_contractor_id and x.company_id = c) then
    raise exception 'contractor must belong to the same company' using errcode = '42501';
  end if;
  if new.assigned_executor_id is not null
     and (ins or new.assigned_executor_id is distinct from old.assigned_executor_id)
     and not exists (select 1 from executors e join contractors x on x.id = e.contractor_id
                      where e.id = new.assigned_executor_id and x.company_id = c) then
    raise exception 'executor must belong to the same company' using errcode = '42501';
  end if;
  if new.plan_id is not null and (ins or new.plan_id is distinct from old.plan_id)
     and not exists (select 1 from maintenance_plans p
                      where p.id = new.plan_id and p.company_id = c) then
    raise exception 'plan must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_wo_refs_check on public.work_orders;
create trigger trg_wo_refs_check
  before insert or update on public.work_orders
  for each row execute function public.trg_wo_refs_check();

-- ---------------------------------------------------------------------
-- 7. Старые связи, где политика проверяла не все ссылки
--    (закрепления подрядчиков, подрядчик ↔ объект, исполнители, метки)
-- ---------------------------------------------------------------------
create or replace function public.trg_contractor_links_check()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_company uuid;
begin
  select x.company_id into v_company from contractors x where x.id = new.contractor_id;
  if tg_table_name = 'contractor_layers' then
    if not exists (select 1 from layers y where y.id = new.layer_id and y.company_id = v_company) then
      raise exception 'layer must belong to the contractor company' using errcode = '42501';
    end if;
  end if;
  if new.object_id is not null and not exists (
       select 1 from objects o where o.id = new.object_id and o.company_id = v_company) then
    raise exception 'object must belong to the contractor company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_contractor_layers_check on public.contractor_layers;
create trigger trg_contractor_layers_check
  before insert or update on public.contractor_layers
  for each row execute function public.trg_contractor_links_check();

drop trigger if exists trg_contractor_objects_check on public.contractor_objects;
create trigger trg_contractor_objects_check
  before insert or update on public.contractor_objects
  for each row execute function public.trg_contractor_links_check();

-- Исполнитель — сотрудник компании подрядчика (accept_invite сначала
-- переводит профиль в компанию, потом добавляет исполнителя).
create or replace function public.trg_executors_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.profile_id is not null and not exists (
       select 1 from profiles p join contractors x on x.company_id = p.company_id
        where p.id = new.profile_id and x.id = new.contractor_id) then
    raise exception 'executor must belong to the contractor company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_executors_check on public.executors;
create trigger trg_executors_check
  before insert or update on public.executors
  for each row execute function public.trg_executors_check();

-- Метка: оборудование и помещение (если заданы оба) — одной компании.
create or replace function public.trg_scan_tags_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.asset_id is not null and new.location_id is not null and not exists (
       select 1 from assets a
         join locations al on al.id = a.location_id join objects ao on ao.id = al.object_id
         join locations l  on l.id = new.location_id join objects lo on lo.id = l.object_id
        where a.id = new.asset_id and ao.company_id = lo.company_id) then
    raise exception 'scan tag asset and location must belong to the same company' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists trg_scan_tags_check on public.scan_tags;
create trigger trg_scan_tags_check
  before insert or update on public.scan_tags
  for each row execute function public.trg_scan_tags_check();

-- ---------------------------------------------------------------------
-- 8. Периоды ППР
--    period_bounds: начало и конец периода, в который попадает дата.
--    Месяц, квартал, полугодие, год — календарные; days — от starts_on
--    шагами по N дней.
-- ---------------------------------------------------------------------
create or replace function public.period_bounds(
  p_kind text, p_days int, p_starts_on date, p_on date,
  out period_start date, out period_end date)
language plpgsql immutable set search_path = pg_catalog as $$
declare
  n int;
begin
  if p_kind = 'month' then
    period_start := date_trunc('month', p_on)::date;
    period_end   := (period_start + interval '1 month' - interval '1 day')::date;
  elsif p_kind = 'quarter' then
    period_start := date_trunc('quarter', p_on)::date;
    period_end   := (period_start + interval '3 months' - interval '1 day')::date;
  elsif p_kind = 'half_year' then
    period_start := (date_trunc('year', p_on)
                     + case when extract(month from p_on) > 6 then interval '6 months'
                            else interval '0' end)::date;
    period_end   := (period_start + interval '6 months' - interval '1 day')::date;
  elsif p_kind = 'year' then
    period_start := date_trunc('year', p_on)::date;
    period_end   := (period_start + interval '1 year' - interval '1 day')::date;
  elsif p_kind = 'days' then
    if p_days is null or p_days < 1 or p_starts_on is null then
      raise exception 'period_days and starts_on are required for days';
    end if;
    n := floor((p_on - p_starts_on)::numeric / p_days)::int;
    period_start := p_starts_on + n * p_days;
    period_end   := period_start + p_days - 1;
  else
    raise exception 'unknown period kind %', p_kind;
  end if;
end $$;
revoke all on function public.period_bounds(text, int, date, date) from public, anon;
grant execute on function public.period_bounds(text, int, date, date) to authenticated;

-- Подпись периода: «октябрь 2026», «IV кв. 2026», «II полугодие 2026»,
-- «2026 год», «10.10–19.10.2026» (en: «October 2026», «Q4 2026», «H2 2026»…).
create or replace function public.period_label(
  p_kind text, p_start date, p_end date, p_locale text default 'ru')
returns text language plpgsql immutable set search_path = pg_catalog as $$
declare
  m int := extract(month from p_start);
  y text := extract(year from p_start)::text;
  en boolean := coalesce(p_locale, 'ru') = 'en';
  ru_months text[] := array['январь','февраль','март','апрель','май','июнь','июль',
                            'август','сентябрь','октябрь','ноябрь','декабрь'];
  en_months text[] := array['January','February','March','April','May','June','July',
                            'August','September','October','November','December'];
  roman text[] := array['I','II','III','IV'];
begin
  if p_kind = 'month' then
    return case when en then en_months[m] else ru_months[m] end || ' ' || y;
  elsif p_kind = 'quarter' then
    return case when en then 'Q' || ((m - 1) / 3 + 1) || ' ' || y
                else roman[(m - 1) / 3 + 1] || ' кв. ' || y end;
  elsif p_kind = 'half_year' then
    return case when en then 'H' || ((m - 1) / 6 + 1) || ' ' || y
                else roman[(m - 1) / 6 + 1] || ' полугодие ' || y end;
  elsif p_kind = 'year' then
    return case when en then y else y || ' год' end;
  else
    return to_char(p_start, 'DD.MM') || '–' || to_char(p_end, 'DD.MM.YYYY');
  end if;
end $$;
revoke all on function public.period_label(text, date, date, text) from public, anon;
grant execute on function public.period_label(text, date, date, text) to authenticated;

-- ---------------------------------------------------------------------
-- 9. Генерация задач ППР текущего периода
--    Только для компании текущего пользователя; вызывает менеджер или
--    администратор (приложение — при входе и по «Обновить»). У остальных
--    ничего не делает и возвращает 0. Подрядчик назначается обычным
--    триггером по слою и объекту (trg_wo_layer_and_route).
--    Ночной запуск без приложения — следующий шаг (pg_cron, см. отчёт шага 16).
-- ---------------------------------------------------------------------
create or replace function public.ppr_generate()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company uuid := public.my_company_id();
  v_locale  text;
  v_today   date := (now() at time zone 'utc')::date;
  v_count   int := 0;
  v_id      uuid;
  p         record;
  b         record;
begin
  if auth.uid() is null or v_company is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not public.is_manager() then
    return 0;
  end if;
  select coalesce(pr.locale, 'ru') into v_locale from profiles pr where pr.id = auth.uid();

  for p in
    select mp.*, l.name as layer_name,
           coalesce(mp.location_id, a.location_id) as loc_id
      from maintenance_plans mp
      join layers l on l.id = mp.layer_id
      left join assets a on a.id = mp.asset_id
     where mp.company_id = v_company and mp.active
  loop
    select * into b from public.period_bounds(p.period_kind, p.period_days, p.starts_on, v_today);
    continue when b.period_end < p.starts_on;

    insert into work_orders (
      company_id, object_id, location_id, asset_id, layer_id, work_type,
      title, description, priority, status, recurrence, requires_photo,
      input_channel, created_by, due_at, plan_id, period_start, period_end)
    values (
      v_company, p.object_id, p.loc_id, p.asset_id, p.layer_id, p.layer_name,
      left(p.title || ' — ' || public.period_label(p.period_kind, b.period_start, b.period_end, v_locale), 200),
      p.description, p.priority, 'new',
      jsonb_build_object('kind', 'ppr', 'period', p.period_kind, 'days', p.period_days),
      p.requires_photo, 'ppr', coalesce(p.created_by, auth.uid()),
      (b.period_end::timestamp + interval '23 hours 59 minutes') at time zone 'utc',
      p.id, b.period_start, b.period_end)
    on conflict (plan_id, period_start) where plan_id is not null do nothing
    returning id into v_id;

    if v_id is not null then
      v_count := v_count + 1;
      insert into checklist_items (work_order_id, text)
      select v_id, btrim(item #>> '{}')
        from jsonb_array_elements(p.checklist) with ordinality as t(item, ord)
       where jsonb_typeof(item) = 'string' and btrim(item #>> '{}') <> ''
       order by ord;
      v_id := null;
    end if;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.ppr_generate() from public, anon;
grant execute on function public.ppr_generate() to authenticated;

-- Триггерные функции вызываются только базой.
revoke all on function public.trg_objects_refs_check()     from public, anon, authenticated;
revoke all on function public.trg_locations_refs_check()   from public, anon, authenticated;
revoke all on function public.trg_assets_refs_check()      from public, anon, authenticated;
revoke all on function public.trg_mplans_check()           from public, anon, authenticated;
revoke all on function public.trg_wo_refs_check()          from public, anon, authenticated;
revoke all on function public.trg_contractor_links_check() from public, anon, authenticated;
revoke all on function public.trg_executors_check()        from public, anon, authenticated;
revoke all on function public.trg_scan_tags_check()        from public, anon, authenticated;

-- =====================================================================
-- Проверка после применения (только чтение; запускать в SQL Editor
-- по одному запросу):
--
-- 1) Новые таблицы и RLS (ожидается regions, maintenance_plans — true):
-- select relname, relrowsecurity from pg_class
--  where oid in ('public.regions'::regclass, 'public.maintenance_plans'::regclass);
--
-- 2) Новые столбцы:
-- select table_name, column_name from information_schema.columns
--  where table_schema = 'public'
--    and ((table_name = 'objects' and column_name in ('country_code', 'city', 'region_id'))
--      or (table_name = 'locations' and column_name = 'code')
--      or (table_name = 'assets' and column_name in ('layer_id', 'manufacturer', 'model', 'serial_no', 'installed_at'))
--      or (table_name = 'work_orders' and column_name in ('plan_id', 'period_start', 'period_end')))
--  order by 1, 2;
--
-- 3) Город заполнен из адреса:
-- select name, address, city from public.objects order by city, name;
--
-- 4) Границы периодов (ожидается 2026-10-01 … 2026-10-31 и 2026-10-01 … 2026-12-31):
-- select * from public.period_bounds('month', null, '2026-01-01', '2026-10-10')
-- union all
-- select * from public.period_bounds('quarter', null, '2026-01-01', '2026-10-10');
--
-- 5) Политики новых таблиц (ожидается regions_select, regions_manage,
--    mplans_select, mplans_manage):
-- select tablename, policyname, cmd from pg_policies
--  where schemaname = 'public' and tablename in ('regions', 'maintenance_plans')
--  order by 1, 2;
--
-- 6) Функции закрыты от анонимов (ожидается false для anon, true для authenticated):
-- select p.proname,
--        has_function_privilege('anon', p.oid, 'execute') as anon,
--        has_function_privilege('authenticated', p.oid, 'execute') as authenticated
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and p.proname in ('ppr_generate', 'period_bounds', 'period_label', 'norm_name');
-- =====================================================================
```
