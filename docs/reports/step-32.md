# Шаг 32: доделать этап 0 — сайт, единая терминология, новая заявка без сети, уборка хвостов

Ветка `step-32` от свежего `main` (`584c098`, шаг 31 слит 23.10.2026). Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.
Миграции 0001–0026 применены. Следующий свободный номер — 0027.

## Чек-лист
- [x] 1. Сайт: постер видео, подзаголовок «Для кого», ровные кадры «Главное», 360/412 px, QR в «Контактах», терминология, раздел «AR-метки», политика (ARCore), проверки
- [x] 2. Терминология в приложении, боте и документах + тест-«сторож»
- [x] 3. Новая заявка без сети (APK)
- [x] 4. Уборка хвостов: `ar_anchors`, устойчивый снимок «Выбор подрядчика», CLAUDE.md
- [x] 5. Проверки и итоговый отчёт

## Что сделано

### 1. Сайт
- **Постер видео** — кадр 32 с ролика `hey-helpy-demo-v2.mp4`: готовая карточка «Разобрано ИИ», без индикатора загрузки и служебных надписей; WebP 1280 × 720, 22 КБ (`tools/site/images.mjs`).
- **Подзаголовок главной = «Для кого»**: бизнес-центры и ТЦ, сети и ритейл, управляющие и FM-компании, госзаказчики (RU / EN) — и в `meta description` (он же Open Graph и Twitter), `llms.txt`, `llms-full.txt`, JSON-LD.
- **«Главное»**: кадр Telegram теперь целиком (без обрезки) — у всех трёх карточек одинаковые пропорции 480 × 1066; плюс `aspect-ratio` и `object-fit` в CSS. CLS = 0.
- **360 и 412 px**: новый `tools/site/shots.mjs` проверяет все 14 страниц: нет горизонтальной прокрутки, «Меню» видно и открывается, элементы шапки не налезают. «Запросить демо» и «Войти» на узком экране переносятся на отдельные строки, не налезают. Снимки — `docs/screens/site/` (главная, меню, «Контакты» — RU и EN).
- **«Контакты»**: QR-код ссылки `https://t.me/HeyHelpy_bot?start=demo` — SVG встроен в страницу, подпись «Наведите камеру телефона…». Код считается локально (`tools/site/qr.mjs`, пакет `qrcode` только для этого скрипта), сборка сайта по-прежнему без зависимостей. QR адреса сайта — `docs/site/qr-site.svg` и `docs/screens/site/qr-site.png` (1024 px). Оба кода проверены распознавателем (jsQR) — читаются.
- **Слова**: «прибор» → «оборудование», «число заявок» → «количество заявок»; заявка — «текстом, камерой или голосом»; подрядчик получает и ведёт заявку в приложении, Telegram для него — только уведомления (убраны обещания «Взять в работу» в Telegram); заявитель — в Telegram без приложения; вместо «автоматический тест перебирает все таблицы…» — «Компании и менеджеры разных объектов изолированы — каждый видит только свою информацию». «962 автопроверки» на сайте не было.
- **«Возможности» → «AR-метки»** (RU / EN, факты шага 31; честно: метки пока не сохраняются между запусками, нужен интернет).
- **Политика конфиденциальности** (редакция 23.10.2026): абзац о «Сервисах Google Play для AR» (ARCore на телефоне, наш код к сервисам Google не обращается, облачные якоря и Geospatial выключены, снимок не сохраняется).
- **Проверки**: `check.mjs` ✓; `html-validate@9` — 0 ошибок на 15 страницах (`<!DOCTYPE html>` заглавными — правило больше не нужно отключать); Lighthouse мобильный — RU и EN 100 / 100 / 100 / 100 (LCP 1,7 с, CLS 0, TBT 0); без JS — новые тексты на месте. Новая оценка — `docs/site/ai-readiness-2026-10-23.md`. Дата сайта `UPDATED` — 2026-10-23.
- ⚠️ **Картинки в `docs/screens/site/`, а не в `docs/site/screens/`**: хук `block_secrets` пропускает PNG только из `docs/screens/`, `docs/design/`, `assets/`… Хук не трогал; `qr-site.svg` (не картинка для хука) — в `docs/site/`, как просили, PNG — рядом со снимками.
- ⚠️ **В самом ролике** (`hey-helpy-demo-v2.mp4`) вшита подпись «Исполнитель у прибора…» — ролик не перезаписывал (нужна полная пересъёмка `tools/e2e/record_demo.sh`); подпись в сценарии исправлена в блоке 2, при следующей записи уйдёт.

### 2. Терминология в приложении, боте и документах
- `.arb`: «прибор» был в одной строке — `cameraNoEquipment` → «В кадре не видно оборудования — наведите на него камеру» (EN: «…point the camera at the equipment», было «at a device»). «Число заявок» в строках интерфейса не было. `app_localizations*.dart` пересобраны (`flutter gen-l10n`). Строка стала короче — обрезаться нечему.
- EN «device» / «unit»: «device» осталось только в `infoFilters3` («remembered on this device» — про телефон, не оборудование); «indoor / outdoor unit», «fan coil unit» — названия видов оборудования (по-русски «блок»), не «прибор» — оставлены.
- Тест-«сторож» `test/terminology_test.dart`: в значениях `app_ru.arb` нет «прибор» (любая форма — проверка по основе) и «число заявок»; в `app_en.arb` нет «device / appliance» (кроме `infoFilters3`, ⚠️ там это телефон).
- Бот (`telegram-bot/texts.ts`): «прибор» и «число заявок» нет. Строки нативных экранов VPS и AR-меток идут из `.arb`, ключи не менялись — тесты сверки (`arlabel_logic_test`, `vps_logic_test`) зелёные.
- Документы для показа: `docs/DEMO_SCRIPT.md` (в т. ч. устаревшая фраза «следующий шаг — AR-метки» → «на телефонах с ARCore есть AR-метки», шаг 31), `docs/screens/pitch/README.md` («прибор», «число заявок»); подпись ролика в `tools/e2e/record_demo.mjs` («Исполнитель у оборудования…» — при следующей записи); комментарии `tools/e2e/scenarios.mjs`. В `docs/DEMO_DAY_CHECKLIST.md` замен не понадобилось. `docs/reports/` и исследование `docs/research/ar-options.md` (история) не трогал.
- Комментарии кода: `camera_logic.dart`, `camera_screen.dart`.
- ⚠️ **Кнопка «Взять в работу» в Telegram у исполнителя (шаг 28) оставлена.** Решение «Telegram для подрядчика — только уведомления» выполнено в текстах (сайт больше не обещает работу в Telegram), но убрать уже работающую кнопку — изменение бота с выкладкой функций; без явного «убрать» не стал. Если нужно — это одна правка в `telegram-bot/assign.ts` + Deploy functions.

### 3. Новая заявка без сети (APK)
Раньше без сети исполнитель мог начать работу, отметить визит и чек-лист, снять фото «после» и сдать (шаг 27), а создать новую заявку — нет. Теперь может любой вошедший (заявитель, исполнитель, менеджер).

**Как работает на телефоне**
- Форма «Новая заявка» без сети: вверху пометка «Нет сети: заявка сохранится на телефоне… ИИ без сети не работает — вид работ выберите сами»; объект, помещение и вид работ — из справочников, сохранённых на телефоне; GPS «Рядом с вами» работает и без сети. Вместо «Узнать по фото» (нужен сервер) — **«Снять фото «до»»** живой камерой (штамп «без сети», время по доверенному источнику). «Прикрепить файл» без сети скрыт.
- Голос: без сети разбор сразу **по словарю** (`TextIntake`), не ждём 16 с отказа ИИ. Распознавание речи без сети — как умеет телефон; не получилось — прежняя кнопка «Ввести текстом» → тот же разбор словарём.
- «Создать заявку» → действие очереди `create` с id из приложения (как `RequestsRepo.create` после шага 28) + фото «до» следом. Связь оборвалась прямо при отправке — заявка тоже уходит в очередь (повтор того же id база не задвоит).
- Заявка сразу видна в списке «Заявки» на телефоне (сверху) и открывается: «Создано без сети · ждёт отправки», снимок «Фото «до» · ждёт отправки». Плашка — «Нет сети — сохранено на телефоне: N».
- Сеть вернулась → сначала все `create`, потом остальное (снимок «до» кладётся в папку уже созданной заявки) → Edge Function `offline-sync` сверяет SHA-256 → `offline_sync`. В карточке у автора и менеджера: **«Создано без сети · отправлено в 14:25»**.
- Предзагрузка (шаг 27) дополнена **для всех ролей**: объекты (до 300), системы, этажи, помещения и оборудование своих объектов (по RLS), помещения для голосового разбора, свои открытые заявки. Ключи кэша — те же, что у `DirectoryRepo` / `FloorRepo` (`objects`, `layers`, `floors_of:<объект>`, `items_of:<объект>`, `all_places`), поэтому форма работает без изменений.
- Отказ сервера (нет прав на объект, неверные поля) — в «Не отправлено» с причиной («Новая заявка · … · Нет прав на это действие»), очередь не застревает. Попутно: если хранилище отказало в загрузке снимка (403 / 400), очередь больше не повторяет его бесконечно — база отвечает «файл не дошёл», действие уходит в «Не отправлено».

**База — миграция 0027** (полный текст ниже). ⚠️ **Решил: миграция нужна.** Без неё можно было бы при появлении сети просто вставить заявку обычным insert с id из приложения, но тогда (1) время создания было бы временем отправки, а не временем на объекте, (2) фото «до» не получило бы офлайн-пометок, доверенного времени и сверки SHA-256 — их ставит только `offline_sync` (шаг 27), (3) не было бы записи, по которой карточка показывает «Создано без сети». Поэтому `offline_sync` дописан:
- `create` — права ровно как у политики `wo_insert` (своя компания, автор = вошедший, зона доступа 0016 — функция `wo_insert_allowed`), статус «Новая» и автоназначение подрядчика — те же триггеры, что при обычной вставке (`trg_wo_status_flow` пускает только new / assigned; статус из телефона не принимается), ссылки на чужую компанию отсекают триггеры 0015; `created_at` — доверенное время (`hh_now()` / `offline_time`); повтор id — без дубля; чужой id — отказ.
- `photo` с `stage = before` — автор заявки или менеджер с правом на неё, пока заявка не принята и не отменена (как `attachments_insert` 0023); пометки `offline`, `time_trust`, `sha256` — как у фото «после».
- Файл снимка кладётся по **обычной** политике `work_photos_insert` (0006: автор пишет в папку своей заявки) — новая политика хранилища не понадобилась. Новых таблиц нет (grant не нужен).
- Проверено локально: `tools/db_test/run.sh` — `offline_sync` 74 ✓ (новых 18: поля и автор, статус из телефона не принят, `created_at` = доверенное время, повтор действия и повтор id без дублей, чужой id — отказ, запись видят автор и менеджер, фото «до» с пометками, зона менеджера (чужой объект — отказ, свой — можно), неверная срочность, объект другой компании, фото «до» в отменённую заявку — отказ с причиной, `ar_anchors` нет), все 16 наборов зелёные, повторный запуск миграции — без ошибок.

**Тесты Dart** — `test/offline_logic_test.dart` (+6): строка заявки из очереди, порядок «новые первыми», отправка «сначала create», фото «до» не считается фото «после», create переживает перезапуск, причина `bad_action` и пометка «до».

### 4. Уборка хвостов
- **`ar_anchors` удалена** в 0027 (`drop table if exists public.ar_anchors cascade`). Обращений в коде приложения, функциях и Kotlin нет (только старые миграции, снимок `schema.sql` 23.09 и исследования). В рабочей базе таблица пуста — проверил запросом только на чтение (Supabase MCP) 23.10.2026. Поправлены `tools/db_test/10_fixture.sql` (строка ar_anchors убрана); `grants.sql` и `tenant_isolation.sql` перебирают таблицы сами — правки не понадобились (`grants` теперь 166 проверок вместо 171 — минус права удалённой таблицы). Заготовка `docs/security/grants-0001-0026.md` — без `ar_anchors` (иначе на базе «с нуля» после 0027 grant упал бы).
- **`/screens`, «Менеджер 360 — Выбор подрядчика»**: список открывается сразу по ссылке с фильтром «Статус: Новая, Назначена, Возвращена» (`#/?st=assigned,new,returned`) — подходящая заявка наверху на любой ширине; прокрутка осталась только запасным путём; после снимка фильтр сбрасывается.
- **CLAUDE.md**: 0026 уже была «применена»; добавлены 0027 (не применена), «следующий номер — 0028», раздел **«Слова в интерфейсе»** (решения владельца), сайт — новые пункты блока 1, работа без сети — новая заявка.

### 5. Проверки
| Проверка | Итог |
|---|---|
| `flutter analyze lib test` | ✅ без замечаний |
| `flutter test` | ✅ 532 прошли (новые: `terminology_test` 2, `offline_logic_test` +7) |
| Веб-сборка | ✅ собирается (`/screens` и сквозные тесты собирают её сами; «PR check» — тоже) |
| Строки вне переводов, название продукта (`/check`, п. 4–5) | ✅ в новых строках кода кириллицы и подписей вне `.arb` нет, «Helpy» без «Эй, / Hey» нет |
| `deno check` + `deno test supabase/functions` | ✅ 112 прошли (функции в шаге не менялись) |
| JUnit `:arcommon`, `:arlabel`, VPS (`-PwithVps=true :vps`) | ✅ все прошли |
| `bash tools/db_test/run.sh` (с `grants.sql`) | ✅ 16 наборов, 0 ошибок: `offline_sync` 74, `grants` 166, `tenant_isolation` 942…; 0027 запущена дважды без ошибок; демо-данные дважды без ошибок |
| Сквозные `tools/e2e` 19 (новый) и 17 (без сети, шаг 27) | ✅ оба прошли: 19 — «в очереди 2 действия; на сервере new, button, Сантехника, автор — заявитель; create applied, monotonic; фото «до» offline, monotonic, camera; у менеджера «Создано без сети · отправлено в 01:58»»; 17 — как раньше (6 действий, monotonic; часы +2 ч → unverified 7200 с) |
| Сайт: `build.mjs` + `check.mjs`, `html-validate`, Lighthouse, без JS, 360 / 412 px | ✅ см. блок 1 |
| `/screens` | SCREENS_RESULT |

Найдено и исправлено по ходу проверок:
- ⚠️ **`isNetworkError` в веб-сборке не узнавал `TimeoutException`** (имена типов в вебе сжаты, а по тексту проверки не было): список без сети падал с «Не удалось загрузить заявки». Теперь узнаёт и по тексту; тест добавлен. Касается и обычных таймаутов в браузере (`TimeoutHttpClient`) — теперь это «нет сети», как задумано в шаге 27.
- Без сети после формы появлялись два сообщения («сохранена на телефоне» и «Заявка создана») — второе убрано во вкладке «Заявки».
- В сквозные тесты добавлена запись консоли приложения (`tools/e2e/out/console-<N>.log`) — для разбора падений.
- ⚠️ `dart format lib` по ходу работы переформатировал 11 чужих файлов — вернул их как в `main` отдельным коммитом, чтобы PR не смешивал правки.
- ⚠️ **«PR check» упал на b3028c2** (на 5cdf32f он не падал, а был отменён: его сменил следующий пуш). Причина — шаг `flutter analyze`: в новом тесте `test/offline_logic_test.dart:166` не хватало `const` (`isNetworkError(_Minified(…))`, подсказка `prefer_const_constructors`), а в CI анализатор падает даже на подсказках. Локально я запускал `flutter analyze lib test`, но не на итоговой версии теста. Исправлено: `const _Minified(…)` (коммит `6758636`). Перед пушем прогнал локально те же шаги, что «PR check»: `flutter analyze` по всему проекту — без замечаний, `flutter test` — 532 ✓, сборка сайта + `git diff site/` + `check.mjs` ✓, проверка имён миграций ✓; deno — 112 ✓ (функции не менялись). «PR check» на `6758636` — ✅ зелёный (3 мин 19 с).
- ⚠️ Сессия оборвалась во время `/screens` (23.10); продолжено 30.10 по «Где остановился»: снимки пересняты заново.

## Новые и изменённые файлы
**Сайт:** `tools/site/content.ru.mjs`, `content.en.mjs` (тексты: «Для кого», слова, AR-метки, политика, заявка без сети), `build.mjs` (QR в «Контактах», `<!DOCTYPE html>`), `site.css` (рамка кадров, QR), `config.mjs` (дата 2026-10-23), `images.mjs` (постер 32 с, кадр Telegram целиком), `qr.mjs` (новый, QR-коды), `shots.mjs` (новый, 360 / 412 px), `package.json` / `package-lock.json` (`qrcode` — только для `qr.mjs`); `site/**` (пересобран); `assets/site/video-poster.webp`, `telegram.webp`, `sizes.json`, `qr-demo.svg` (новый); `docs/site/README.md`, `ai-readiness-2026-10-23.md` (новый), `qr-site.svg` (новый); `docs/screens/site/*` (новые снимки и `qr-site.png`).
**Слова:** `lib/l10n/app_ru.arb`, `app_en.arb` (+ сгенерированные `app_localizations*.dart`), `lib/features/camera/camera_logic.dart`, `camera_screen.dart` (комментарии), `test/terminology_test.dart` (новый), `docs/DEMO_SCRIPT.md`, `docs/screens/pitch/README.md`, `tools/e2e/record_demo.mjs` (подпись ролика).
**Без сети:** `supabase/migrations/0027_offline_create.sql` (новая), `tools/db_test/offline_sync.sql`, `tools/db_test/10_fixture.sql`; `lib/features/offline/offline_logic.dart` (`create`, `pendingOrderRow`, `pendingCreates`, `splitForSync`, фото «до», `isNetworkError`), `offline_service.dart` (`createOrder`, `pendingRow`, предзагрузка справочников, отправка «сначала create»), `offline_banner.dart`; `lib/features/requests/requests.dart` (`create` с очередью, форма без сети, «Снять фото «до»», пометка в карточке), `requests_tab.dart` (список без сети), `order_checklist.dart` (фото «до» ждёт отправки); `lib/features/floors/floor_repository.dart`, `lib/features/directory/directory.dart` (справочники из кэша); `lib/features/voice/voice_intake_client.dart`, `voice_confirm_screen.dart`; `test/offline_logic_test.dart`; `tools/e2e/scenarios.mjs` (сценарий 19), `tools/e2e/e2e.mjs` (консоль).
**Хвосты:** `tools/screens/screens.mjs` («Выбор подрядчика» по фильтру), `docs/security/grants-0001-0026.md` (без `ar_anchors`), `CLAUDE.md`.
**Отчёт и снимки:** `docs/reports/step-32.md`, `docs/screens/latest/*`.

## Миграция 0027 — полный текст
Зачем: новая заявка без сети должна попадать на сервер с **доверенным временем** и теми же правами, что обычная, а её фото «до» — с офлайн-пометками и сверкой SHA-256 (ставит только `offline_sync`); заодно удалить неиспользуемую `ar_anchors`.
Что меняет: ограничение `offline_actions.kind` (+ `create`), новая закрытая функция `wo_insert_allowed` (вызывается только из `offline_sync`, приложению недоступна), новая версия `offline_sync` (то же, что в 0024, + `create` и фото `stage = before`), удаление таблицы `ar_anchors`. Новых таблиц нет — grant не нужен.
Повторный запуск безопасен: `drop constraint if exists` + `add`, `create or replace function`, `drop table if exists`; локально запущена дважды подряд без ошибок.
Требует 0024 (применена). Пока 0027 не применена, всё остальное работает как раньше, но заявка, созданная **без сети**, при отправке получит отказ (старая `offline_sync` не знает `create` → «Заявка заполнена с ошибкой — создайте её заново» в «Не отправлено») и на сервер не попадёт. Поэтому **применить 0027 сразу после слияния**, до того как ставить свежий APK на телефоны. Заявки, созданные при сети, от 0027 не зависят.

```sql
-- =====================================================================
-- hey_helpy · Миграция 0027: новая заявка без сети; удаление ar_anchors
-- (шаг 32)
--
-- 1) offline_sync(p_actions) принимает ещё два действия очереди:
--      create — новая заявка, созданная без сети: id из приложения, title,
--               description?, priority, input_channel, layer_id?, object_id?,
--               location_id?, asset_id?. Права — как у политики wo_insert
--               (своя компания, автор = пользователь, зона доступа 0016),
--               статус «Новая» и подрядчик — те же триггеры, что при обычной
--               вставке (trg_wo_status_flow: только new / assigned; правило
--               слоя назначает подрядчика). Время создания (created_at) —
--               доверенное (offline_time, как у остальных действий). Повтор
--               того же id — заявка не дублируется.
--      photo  — теперь и stage = 'before' (фото «до» новой заявки): автор
--               заявки или менеджер с правом на неё, пока заявка не принята
--               и не отменена (как attachments_insert 0023); офлайн-пометки,
--               доверенное время и SHA-256 — как у фото «после» (шаг 27).
--    Файл снимка телефон кладёт в work-photos по обычной политике
--    work_photos_insert (0006: автор видит папку своей заявки) — новая
--    политика хранилища не нужна.
--    Пометку «Создано без сети» приложение берёт из offline_actions
--    (kind = 'create'): видят сам автор и менеджеры с правом на заявку.
-- 2) Старая таблица ar_anchors (0002) не используется (заменена vps_sites /
--    vps_marks, 0025), в рабочей базе пуста (проверено 23.10.2026) —
--    удаляется.
--
-- Новых таблиц нет. Требует 0024. Повторный запуск безопасен: drop … if
-- exists, create or replace.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Журнал офлайн-действий: вид create
-- ---------------------------------------------------------------------
alter table public.offline_actions drop constraint if exists offline_actions_kind_check;
alter table public.offline_actions add constraint offline_actions_kind_check
  check (kind in ('create', 'start', 'visit', 'check', 'photo', 'submit'));

-- ---------------------------------------------------------------------
-- 2. Можно ли пользователю создать заявку с такими объектом / системой /
--    оборудованием / помещением — то же условие зоны, что в политике
--    wo_insert (0016). Компанию и автора offline_sync подставляет сам.
-- ---------------------------------------------------------------------
create or replace function public.wo_insert_allowed(
  p_object uuid, p_layer uuid, p_asset uuid, p_location uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.zones_unrestricted()
      or p_object in (select z.object_id from public.zone_obj_layers() z where z.layer_id is null)
      or (p_object, p_layer) in (select z.object_id, z.layer_id from public.zone_obj_layers() z
                                  where z.layer_id is not null)
      or (p_object in (select public.zone_partial_objects())
          and public.can_see(p_object, p_layer, p_asset, p_location));
$$;
revoke all on function public.wo_insert_allowed(uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Принять очередь (0024 + create и фото «до»)
--    p_actions — массив по порядку:
--    {id, kind, order_id, device_at, gps_at?, boot?, mono_ms?, ...}
--      create — title, description?, priority, input_channel, layer_id?,
--               object_id?, location_id?, asset_id?   (шаг 32)
--      start  — «Начать работу»
--      visit  — lat, lng, accuracy, mock
--      check  — item_id, done
--      photo  — path (<компания>/<заявка>/off_<id>.jpg), sha256, lat, lng, mock,
--               stage? (after — по умолчанию, before — шаг 32)
--      submit — «Выполнено, на проверку»
--    Ответ: [{id, result: applied | rejected | saved_late, reason?, trust}].
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
  -- шаг 32: новая заявка и фото «до» без сети
  v_stage   text;
  v_title   text;
  v_prio    text;
  v_channel text;
  v_layer   uuid;
  v_wtype   text;
  v_object  uuid;
  v_loc     uuid;
  v_asset   uuid;
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
       or v_kind not in ('create', 'start', 'visit', 'check', 'photo', 'submit') then
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
      if v_kind = 'create' then
        -- Новая заявка (шаг 32): id — из приложения. Права — как у политики
        -- wo_insert (компания, автор, зона 0016), статус и подрядчик — те же
        -- триггеры, что при обычной вставке; время создания — доверенное.
        if exists (select 1 from work_orders where id = v_order) then
          if not exists (select 1 from work_orders
                          where id = v_order and company_id = v_company and created_by = v_uid) then
            raise exception 'offline:denied';
          end if;
          v_result := 'applied';  -- уже создана (ответ потерялся по дороге)
        else
          v_title   := btrim(coalesce(a->>'title', ''));
          v_prio    := coalesce(nullif(a->>'priority', ''), 'normal');
          v_channel := coalesce(nullif(a->>'input_channel', ''), 'button');
          v_layer   := nullif(a->>'layer_id', '')::uuid;
          v_object  := nullif(a->>'object_id', '')::uuid;
          v_loc     := nullif(a->>'location_id', '')::uuid;
          v_asset   := nullif(a->>'asset_id', '')::uuid;
          if length(v_title) not between 1 and 500
             or length(coalesce(a->>'description', '')) > 5000
             or v_prio not in ('low', 'normal', 'high', 'critical')
             or v_channel not in ('button', 'text', 'voice', 'camera') then
            raise exception 'offline:bad_action';
          end if;
          v_wtype := null;
          if v_layer is not null then
            select l.name into v_wtype from layers l
             where l.id = v_layer and l.company_id = v_company;
            if not found then raise exception 'offline:bad_action'; end if;
          end if;
          if not public.wo_insert_allowed(v_object, v_layer, v_asset, v_loc) then
            raise exception 'offline:denied';
          end if;
          insert into work_orders(id, company_id, title, description, work_type, layer_id, priority,
                                  status, input_channel, object_id, location_id, asset_id,
                                  created_by, created_at)
          values (v_order, v_company, v_title, nullif(btrim(coalesce(a->>'description', '')), ''),
                  v_wtype, v_layer, v_prio, 'new', v_channel, v_object, v_loc, v_asset,
                  v_uid, v_time.trusted_at);
          v_result := 'applied';
        end if;
      else

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
        v_stage := coalesce(nullif(a->>'stage', ''), 'after');
        if v_stage not in ('before', 'after') then
          raise exception 'offline:bad_photo';
        end if;
        if exists (select 1 from attachments where storage_path = v_path) then
          v_result := 'applied';  -- уже сохранено
        elsif v_stage = 'before' then
          -- Фото «до» (шаг 32) — как обычное: автор заявки или менеджер с
          -- правом на неё, пока заявка не принята и не отменена.
          if v_status = 'cancelled' then raise exception 'offline:cancelled'; end if;
          if v_status = 'done' then raise exception 'offline:accepted'; end if;
          if not exists (select 1 from work_orders where id = v_order and created_by = v_uid)
             and not public.wo_is_manager(v_order) then
            raise exception 'offline:denied';
          end if;
          insert into attachments(work_order_id, kind, stage, storage_path, taken_at, lat, lng,
                                  mock_location, uploaded_by, source, offline, time_trust,
                                  trusted_at, time_drift_s, synced_at, sha256, sha256_ok)
          values (v_order, 'photo', 'before', v_path, v_device,
                  (a->>'lat')::double precision, (a->>'lng')::double precision,
                  coalesce((a->>'mock')::boolean, false), v_uid, 'camera', true, v_time.trust,
                  v_time.trusted_at, v_time.drift_s, now(), v_sha,
                  case when v_known is null then null else true end);
          v_result := 'applied';
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
      end if;  -- create / остальные
    exception when others then
      -- подтранзакция откатилась; причину — по нынешнему состоянию заявки
      v_result := 'rejected';
      v_reason := case
        when sqlerrm = 'offline:not_found' then 'not_found'
        when sqlerrm = 'offline:bad_photo' then 'bad_photo'
        when sqlerrm = 'offline:photo_missing' then 'photo_missing'
        when sqlerrm = 'offline:photo_hash_mismatch' then 'photo_hash_mismatch'
        when sqlerrm = 'photo required' then 'photo_required'
        when sqlerrm = 'offline:bad_action' then 'bad_action'
        when sqlerrm = 'offline:denied' then 'denied'
        when sqlerrm = 'offline:cancelled' then 'cancelled'
        when sqlerrm = 'offline:accepted' then 'accepted'
        when v_kind = 'create' then 'denied'
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
-- 4. Старая таблица AR-якорей (0002) — не используется
-- ---------------------------------------------------------------------
drop table if exists public.ar_anchors cascade;
```

## Что сделать вам
1. **Проверить и слить PR** (ссылка — в конце). После слияния «Deploy web» сам выложит приложение **и сайт** (через 3–5 минут; если публикация включена — переменная `WEB_PUBLISH_ENABLED`).
2. **Применить 0027**: GitHub → Actions → **Apply migration** → Run workflow → в поле `file`: `0027_offline_create.sql` → Run → прочитать текст в первой задаче → Review deployments → `production-db` → Approve and deploy. Потом написать мне «применена 0027».
3. **Deploy functions — не нужно**: функции в шаге не менялись. **Telegram webhook — не нужно**: команды бота не менялись.
4. **Свежий APK** — соберётся сам после слияния: https://github.com/Anton-Key/hey-helpy/releases/download/latest-apk/hey-helpy.apk — установить поверх старого.

## Как проверить руками
**Новая заявка без сети (телефон Android, после шагов 2 и 4):**
1. Войти (например, заявителем «Демо БЦ») при включённой сети, открыть «Заявки» и подождать ~10 секунд — телефон сохранит справочники.
2. Включить **режим полёта**.
3. «+» → в форме вверху: «Нет сети: заявка сохранится на телефоне…». Написать «Течёт кран», выбрать объект, вид работ «Сантехника», при желании «Снять фото «до»» → «Создать заявку».
4. Сообщение «Нет сети — заявка сохранена на телефоне…»; заявка — первой в списке, в карточке «Создано без сети · ждёт отправки», плашка «Нет сети — сохранено на телефоне: 2 действия».
5. Выключить режим полёта → через несколько секунд «Отправлено ✓».
6. Войти менеджером (на ПК или другом телефоне) → заявка в списке, в карточке «Создано без сети · отправлено в ЧЧ:ММ», фото «до» на месте.

**Сайт (телефон, ширина ~360 px):** https://anton-key.github.io/hey-helpy/site/ — подзаголовок «для бизнес-центров и ТЦ, сетей и ритейла…», кнопка «Меню» открывается, страница не прокручивается вбок; «Контакты» — QR-код (навести камеру другого телефона → открывается бот); «Возможности» → «AR-метки»; кадры в «Главное» одной высоты; постер видео — экран «Проверьте заявку» с «Разобрано ИИ».

## Ограничения и что не сделано
- Без сети нет ИИ: вид работ выбирается вручную (или по словарю в голосовой заявке); «Узнать по фото» и документы без сети недоступны.
- Голос без сети — только если распознавание речи на телефоне работает без интернета; иначе — «Ввести текстом».
- Справочники на телефоне: до 300 объектов и до 5 000 помещений / единиц оборудования; обновляются при входе, открытии списка и раз в 15 минут. Объект, добавленный, пока телефон был без сети, в форме не появится до следующей связи.
- Заявка без сети создаётся со статусом «Новая»; подрядчик назначается базой при отправке (как обычно).
- После «Создать заявку» без сети в некоторых местах (план этажа, карта) кроме «сохранена на телефоне» ещё мелькает «Заявка создана» — убрано только во вкладке «Заявки» (основной вход).
- ⚠️ Кнопка «Взять в работу» в Telegram у исполнителя оставлена (см. блок 2).
- ⚠️ В самом ролике `hey-helpy-demo-v2.mp4` осталась вшитая подпись «Исполнитель у прибора…» — уйдёт при следующей записи (`tools/e2e/record_demo.sh`).
- Веб-версия без сети по-прежнему не работает (тестовый режим `OFFLINE_TEST` — только для сквозных тестов).

## Журнал
| Время (UTC) | Что сделано | Коммит |
|---|---|---|
| 23.10 01:13 | Ветка, отчёт | первый коммит |
| 23.10 01:27 | Блок 1: сайт — постер, «Для кого» в подзаголовке / description / llms, ровные кадры, QR в «Контактах», терминология, «AR-метки», политика (ARCore), 360/412 px, Lighthouse 100, html-validate 0 | блок 1 |
| 23.10 01:30 | Блок 2: терминология — `.arb`, тест-«сторож», DEMO_SCRIPT, pitch README, подпись ролика | блок 2 |
| 23.10 01:35 | Блок 3a: миграция 0027 (create и фото «до» в `offline_sync`, удаление `ar_anchors`), тесты `offline_sync.sql` — 74 ✓ | блок 3a |
| 23.10 01:42 | Блок 3b: приложение — очередь create, форма без сети, фото «до», пометка в карточке, справочники в предзагрузке, тесты Dart | блок 3b |
| 23.10 01:45 | Блок 4: `/screens` «Выбор подрядчика», CLAUDE.md, заготовка прав без `ar_anchors`, сайт — заявка без сети | блок 4 |
| 23.10 02:00 | Сквозной сценарий 19 ✅ (+17 ✅); найдено и исправлено: `isNetworkError` в веб-сборке не узнавал `TimeoutException` (имена типов сжаты) — список без сети падал; лишнее «Заявка создана» без сети | блок 5 |
| 30.10 | Продолжение после обрыва сессии: возврат файлов автоформатирования, анализ и 532 теста ✅, `/screens`, итоговый отчёт | итог |
| 30.10 | «PR check» падал на `flutter analyze` (нет `const` в тесте) — исправлено, проверки повторены локально | `6758636` |

## Где остановился
Все блоки готовы. 30.10: после обрыва сессии — `/screens` переснят, отчёт дописан, PR переведён в «готов к проверке». Дальше — ждать проверки и «применена 0027».
