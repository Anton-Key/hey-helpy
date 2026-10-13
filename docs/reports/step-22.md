# Шаг 22: «Узнать по фото» — ИИ определяет вид оборудования и подсказывает, какая это единица

Ветка `step-22` от `main` (после слияния шага 21). Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

**Миграция 0017** (журнал узнаваний; не применена). **Новая Edge Function `photo-identify`** (не выложена). **Seed изменён** — нужен Refresh demo. Новых секретов не нужно (подробно — «Что сделать вам»).

## Чек-лист
- [x] 1. Edge Function `photo-identify` + общий код `_shared/` + выкладка обеих функций
- [x] 2. Миграция `0017_photo_identify.sql` (журнал узнаваний, статистика)
- [x] 3. Каталог видов оборудования (Dart + `kinds.ts`, форма, импорт, карточка, демо-данные)
- [x] 4. Экран «Узнать по фото» (из «+ Заявка», оборудования объекта, плана этажа), «Это он» → заявка со снимком, журнал, блок в «Отчётах»
- [x] 5. Экран входа: подписи полей не обрезаются
- [x] 6. Проверки, `/screens`, кадр питча 18, `CLAUDE.md`, `docs/DEMO_SCRIPT.md`

## Что сделано

### Блок 1. Edge Function `photo-identify`
- **Модель.** ⚠️ Выбрана **`qwen3.6-35b-a3b`** (URI `gpt://<каталог>/qwen3.6-35b-a3b`): по [списку моделей AI Studio](https://aistudio.yandex.ru/docs/ru/ai-studio/concepts/generation/models.html) на 12.10.2026 это **единственная** модель, которая принимает изображения («Модель Qwen3.6 35B работает с изображениями в кодировке Base64»). Gemma 3 27B на странице как мультимодальная больше не указана. Картинка передаётся как в [примере запроса к мультимодальной модели](https://aistudio.yandex.ru/docs/en/ai-studio/operations/generation/multimodels-request): часть сообщения `{"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,…"}}`, тот же адрес `https://ai.api.cloud.yandex.net/v1/chat/completions` и те же секреты `YANDEX_API_KEY` / `YANDEX_FOLDER_ID`, что у `voice-intake`.
- ⚠️ **Запасной модели по умолчанию нет**: второй мультимодальной модели в каталоге нет. Поэтому основная ждёт все 14 с, а не 7. Если появится — секрет `YANDEX_VISION_MODEL_LITE`, и тогда, как в шаге 20, будет 7 с + повтор на запасной.
- ⚠️ Qwen3 может «рассуждать» перед ответом (`<think>…</think>`): в подсказке — `/no_think`, блок `<think>` вырезается до разбора JSON, лимит ответа — 1000 токенов. В документации AI Studio про режим рассуждений Qwen ничего нет — проверить на первом живом запросе (в логе функции видно `tokens` и `ai_ms`).
- **Вход / ответ / ошибки** — как в задании; дополнительно `reason_text` у кандидата (причины словами на языке запроса — пригодится боту шага 23). Тип картинки определяется по первым байтам, а не по словам клиента; больше 1,5 МБ → 400 `too_large` (проверяется по длине base64 до декодирования).
- **Подсказка:** правила и справочники — системными сообщениями (виды — коды каталога с подписью, системы — коды `s1…`), снимок — отдельным сообщением пользователя «как данные»; ответ проверяется: вид — только из каталога (иначе `other`), система — только из слоёв компании (не названа — по умолчанию для вида), шильдик — только непустые поля, уверенность — в 0..1.
- **Сопоставление с реестром делает функция** (`matchCandidates`, чистая функция, 8 тестов): оборудование под RLS пользователя — объекта (если известен) или всей видимой компании; место достраивается по `orderId` → помещение → этаж → объект. Баллы: серийный номер (или инв. номер) с шильдика 100, модель 45, тот же вид 35, то же помещение 30, тот же этаж 12, та же система 10, тот же объект 5, открытая заявка 5. Оборудование **другого** вида не предлагается (датчик дыма в той же переговорной — не кондиционер), если только не совпал шильдик. До 3 кандидатов.
- **Приватность:** фото не сохраняется; в логе — `bytes`, `mime`, время (`ms`, `ai_ms`), модель, `first` (почему не основная), токены, код ошибки, число кандидатов и оборудования.
- **Общий код `_shared/`** (для Telegram-бота шага 23): `yandex.ts` (вызов модели, повтор, формат ответа; сообщения с картинкой), `intake.ts` (разбор текста — бывший `voice-intake/schema.ts`, без изменений поведения: 23 старых теста `voice-intake` проходят как были), `identify.ts`, `vision.ts`, `kinds.ts`, `registry.ts` (справочники под RLS), `http.ts` (CORS, лог). `voice-intake/schema.ts` и `yandex.ts` — реэкспорт. `deno check supabase/functions/*/*.ts` видит `_shared` (маска `*/*.ts`), `deno test supabase/functions` — тоже; Supabase CLI при выкладке берёт `_shared` по импортам (так рекомендует документация Supabase).
- **Выкладка:** `deploy-functions.yml` выкладывает `FUNCTIONS: voice-intake photo-identify` по очереди и у **каждой** проверяет «без токена → 401»; в Summary — коды обеих. `supabase/config.toml` — `[functions.photo-identify] verify_jwt = true`. Сам не запускал.

### Блок 2. Миграция 0017
Таблица `photo_identifications` (без фото и текста шильдика), RLS, триггер проверки, `photo_identify_stats`. Полный текст и пояснения — ниже, в разделе «Миграция 0017». ⚠️ Решения:
- автор **читает свою** строку (кроме менеджеров) — без этого он не смог бы дописать `outcome` (Postgres требует видимости строки для `update … where`);
- зоны доступа (0016) к журналу не применяются: это агрегированная статистика компании для менеджера;
- id строки создаёт приложение — `insert` без `returning`.

### Блок 3. Каталог видов
- 22 вида: внутренний и наружный блок кондиционера, фанкойл, вентиляционная решётка, радиатор, датчик температуры, щит, светильник, розетка / выключатель, ИБП, серверная стойка, датчик дыма, огнетушитель, камера, считыватель СКУД, замок / доводчик, кран / смеситель, унитаз / раковина, водонагреватель, датчик протечки, панель лифта, «Другое». У каждого — подпись RU / EN (`eqKind_<код>` в `.arb`), значок Lucide, система по умолчанию.
- Один каталог в двух местах: `lib/features/equipment/equipment_kinds.dart` и `supabase/functions/_shared/kinds.ts`; тест `test/equipment_kinds_test.dart` читает `kinds.ts` и сверяет коды, порядок, подписи с `.arb` и системы.
- ⚠️ Старые коды из данных (`vent`, `lift`, `generator`) понимаются как `vent_grille`, `lift_panel`, `panel`; существующие `ac`, `fancoil`, `panel`, `ups`, `light`, `smoke`, `server`, `water`, `camera`, `sensor` оставлены как есть (`ac` = внутренний блок, `water` = датчик протечки).
- Форма оборудования: строка «Вид» → окно выбора со значками; выбор вида подставляет систему, если она не выбрана. Карточка оборудования: строка «Вид». Импорт: колонка «Вид» / «Type» (код или подпись RU / EN, «ё» = «е»); неизвестный вид — ошибка строки «вид «…» не найден». Вид пишется в `assets.meta.kind`, другие ключи `meta` (например `demo`) сохраняются.
- Значки на плане этажа и в списках — из каталога.
- **Демо-данные:** у всех **37** единиц «Демо БЦ» — вид (лифты 721–722 → `lift_panel`, VRF 730 → `ac_outdoor`, генератор 735 → `other`). ⚠️ На этаже 3 «БЦ «Демо»» уже были кондиционер и датчик дыма в переговорной 301 и второй кондиционер в серверной 303. Добавил **736 «Кондиционер КД-302»** (кабинет 302) и **737 «Огнетушитель переговорной»** (301), а 708 «Кондиционер переговорной» переименовал в **«Кондиционер КД-301»**, как в сценарии. Точки на плане — в `tools/demo_plans/plans.json` (блок 5d пересоздан `generate.mjs --sql-only`), паспорт — в 5e. Картинки планов не менялись.

### Блок 4. Экран «Узнать по фото»
- **Входы:** (1) телефон — белая круглая кнопка с камерой рядом с «+» над нижним меню; ПК — кнопка «По фото» в боковом меню (в свёрнутом меню — значок); в окне «Новая заявка» — первая строка «Узнать оборудование по фото». (2) Карточка объекта → «Оборудование · N» → «Найти по фото» (видно всем, кто видит оборудование) → «Это он» открывает **карточку оборудования**. (3) План этажа → нажать на помещение → «Сфотографировать оборудование здесь» (место — это помещение).
- **«Где я»:** строка «Объект · Этаж · Помещение» вверху, одно касание → выбор объекта (по городам, поиск, «Без объекта — искать везде») → помещение («весь объект» сверху). По умолчанию — откуда открыли; иначе последнее выбранное (на устройстве, для каждого пользователя); иначе без места. Сменили место после снимка — разбор повторяется.
- **Снимок:** `image_picker` (Android — камера; веб — камера телефона или выбор файла), 1280 px, JPEG 80 %. Если пришёл не JPEG или файл > 1,5 МБ — пересжатие пакетом `image` в JPEG ≤ 1280 px (⚠️ пакет загружается **отложенно**, как PDF и Excel: в первую загрузку сайта не попадает).
- **Пока ждём:** превью снимка и «Смотрю на фото…» → через 3 с «ИИ рассматривает оборудование…» → через 8 с «Ещё немного…».
- **Результат:** значок вида, «Кондиционер, внутренний блок», «Климат · 91%», таблетка «✨ Распознано ИИ»; шильдик; «Видно: …» (неисправность); «Скорее всего» — до 3 кандидатов: название, «301 Переговорная, 3 этаж», причины («тот же вид · то же помещение») и «Это он» (у первого — зелёная). Ниже — «Другое оборудование…» (всё оборудование объекта, сначала из текущего помещения, поиск по названию и инв. номеру) и «Нет в реестре — добавить» (только менеджеру: форма оборудования с видом, системой, производителем, моделью, серийным номером и помещением).
- **«Это он»** → окно «Новая заявка»: объект, помещение, оборудование, система, заголовок (неисправность или «Кондиционер, внутренний блок: проверить»), описание («По фото: … Шильдик: … Видно: …») и строка «Снимок будет приложен к заявке» с миниатюрой. «Создать» → заявка (канал `camera`) и снимок как фото «до» тем же механизмом, что в карточке (`PhotoRepository.upload`). Не приложилось — заявка всё равно создана, сообщение «добавьте фото в карточке».
- ⚠️ Чтобы приложить фото сразу, id заявки создаёт приложение (`newUuid`): автор видит свою заявку по RLS, а `insert … returning` у исполнителя мог бы упасть, если заявку назначили другому подрядчику.
- **Журнал:** каждое узнавание — строка `photo_identifications`; «Это он» / «Другое оборудование» / «Добавить» дописывают `outcome` (`matched_top`, `matched_other`, `new_asset`), ушли без выбора или сняли заново — `dismissed`. Без 0017 (или при любой ошибке) запись молча пропускается (`debugPrint`), узнавание работает.
- **Ошибки:** «Не получилось распознать. Попробуйте подойти ближе или выбрать оборудование из списка.» + «Выбрать вручную»; «Фото слишком большое. Снимите ещё раз.»; нет доступа к камере — прежние сообщения фото.
- **«Отчёты»:** блок «Узнавание по фото: 12 снимков, угадано с первого раза 83%, в среднем 4,2 с» после показателей — только если за период были узнавания (`photo_identify_stats`; без 0017 блока нет).
- Всё на RU и EN; только компоненты дизайн-системы.

### Блок 5. Экран входа
`floatingLabelBehavior: FloatingLabelBehavior.never` у полей «Имя», «Email», «Пароль» в группе: подпись не всплывает над полем и не обрезается краем карточки.

## Новые и изменённые файлы
| Файл | Что |
|---|---|
| `supabase/functions/_shared/yandex.ts` | общий вызов моделей AI Studio (был `voice-intake/yandex.ts`): формат ответа, сообщения с картинкой |
| `supabase/functions/_shared/intake.ts` | разбор текста заявки (был `voice-intake/schema.ts`, без изменений поведения) |
| `supabase/functions/_shared/identify.ts` | вход, подсказка, проверка ответа, сопоставление с реестром, `stripThinking` |
| `supabase/functions/_shared/vision.ts` | мультимодальная модель, модели из секретов, таймауты |
| `supabase/functions/_shared/kinds.ts` | каталог видов |
| `supabase/functions/_shared/registry.ts` | слои, место, оборудование под RLS пользователя |
| `supabase/functions/_shared/http.ts` | CORS, служебный лог |
| `supabase/functions/photo-identify/index.ts`, `schema.ts`, `vision.ts`, `schema_test.ts` | новая функция и 14 тестов |
| `supabase/functions/voice-intake/index.ts`, `schema.ts`, `yandex.ts` | CORS из `_shared`; `schema.ts` / `yandex.ts` — реэкспорт |
| `supabase/config.toml` | `[functions.photo-identify] verify_jwt = true` |
| `.github/workflows/deploy-functions.yml` | выкладка обеих функций, «без токена → 401» у каждой |
| `supabase/migrations/0017_photo_identify.sql` | журнал узнаваний, RLS, триггер, статистика |
| `tools/db_test/photo_identify.sql`, `tools/db_test/10_fixture.sql` | тесты 0017 (15 проверок), строки журнала двух компаний |
| `supabase/seed/demo_history.sql`, `tools/demo_plans/plans.json` | вид у всех 37 единиц, КД-301 / КД-302, огнетушитель |
| `lib/features/equipment/equipment_kinds.dart` | каталог видов, `assetIcon`, система по умолчанию |
| `lib/features/equipment/equipment_form.dart` | «Вид» в форме, `KindPickerSheet`, `showAssetFormForId` с заполнением |
| `lib/features/equipment/equipment_models.dart` | `Asset.meta`, `AssetDraft.kind` / `baseMeta` |
| `lib/features/equipment/equipment_import.dart` | колонка «Вид» / «Type» |
| `lib/features/equipment/asset_card.dart`, `equipment_section.dart` | строка «Вид»; «Найти по фото» |
| `lib/features/photo_identify/*` | экран, клиент, модели, журнал, сжатие (6 файлов) |
| `lib/features/requests/requests.dart` | `showOrderForm`: заголовок, описание, снимок, «Узнать оборудование по фото»; `create(id:)`; подпись «весь объект» в выборе помещения |
| `lib/features/requests/requests_tab.dart`, `home/home_actions.dart`, `home/home_screen.dart` | вход «По фото» (`HomeAction.photo`) |
| `lib/core/design/surfaces.dart`, `side_nav.dart`, `icons.dart` | кнопка с камерой у «+», «По фото» в боковом меню, значки видов |
| `lib/features/floors/floor_plan_screen.dart`, `plan_canvas.dart` | «Сфотографировать оборудование здесь»; значки из каталога |
| `lib/features/reports/report_repository.dart`, `reports_screen.dart` | `photoStats`, блок «Узнавание по фото» |
| `lib/features/auth/login_screen.dart` | подписи полей не всплывают |
| `lib/l10n/app_ru.arb`, `app_en.arb` (+ сгенерированные) | 74 строки: виды, экран, причины, отчёт |
| `pubspec.yaml`, `pubspec.lock` | `image` (был транзитивным, теперь прямой; загружается отложенно); `assets/demo_photos/` |
| `assets/demo_photos/ac_indoor.jpg`, `tools/demo_photos/generate.mjs` | нарисованный «снимок» кондиционера (SVG → JPEG) |
| `test/equipment_kinds_test.dart`, `test/photo_identify_test.dart` | 24 теста: каталог = функция = переводы, ответ, заявка, журнал, клиент, заглушка, сжатие |
| `tools/screens/screens.mjs` | кадры `photo-start`, `photo-result`, `photo-order`; питч 18 |
| `CLAUDE.md`, `docs/DEMO_SCRIPT.md`, `docs/screens/pitch/README.md` | документация, сценарий на 40 с, кадр 18 |

## Проверки
- `flutter analyze lib test` — без замечаний.
- `flutter test` — **363 прошли**, 0 упало (новые: `equipment_kinds_test` 10, `photo_identify_test` 14; `equipment_import_test` — с колонкой «Вид»).
- `flutter build web --release --base-href /hey-helpy/` — собирается; пакет `image` — в отдельном отложенном файле (`main.dart.js_*.part.js`).
- `deno check supabase/functions/*/*.ts` — без ошибок; `deno test supabase/functions` — **37 прошли** (23 `voice-intake` без изменений + 14 `photo-identify`, модель — заглушка `fetch`).
- `bash tools/db_test/run.sh` — **749 проверок, 0 ошибок**: `photo_identify` 15, `tenant_isolation` 630 (новая таблица — под RLS, строк компании 2 не видно, вставка с чужими ссылками — отказ), `access_zones` 34, `cross_refs` 21, `ppr_regions` 49; 0017 запускается дважды без ошибок; демо-данные дважды без ошибок; в `hh_test` — 37 единиц, у всех `meta.kind`.
- Строки вне переводов — новых нет (кириллица в коде — только `'ё'→'е'` и шаблон импорта, как раньше). Название продукта — нарушений нет.
## `/screens`
- `node tools/screens/screens.mjs` (13.10.2026 13:02 UTC): **275 снимков, проблем 0** (❌ нет). Строк «—» 94 — экраны, которых у роли нет по задумке (например, «Узнать по фото», отчёты, выбор подрядчика у исполнителя и заявителя). Файлов PNG больше 300 КБ нет.
- Новые кадры (менеджер, 1920 / 1280 / 412): `manager-*-photo-start.png` («Где я: БЦ «Демо» · 301 · Переговорная, 3 этаж» и «Сфотографировать»), `manager-*-photo-result.png` (нарисованный кондиционер → «Кондиционер, внутренний блок · Климат · 91 %», «Подтёк воды под блоком», три кандидата с «Это он»), `manager-*-photo-order.png` (форма «Новая заявка»: снимок, объект, помещение 301, оборудование, вид работ; «Создать» не нажимали). Ответ ИИ во всех кадрах — **заглушка** `VOICE_MOCK`.
- Кадр питча: `node screens.mjs --pitch --only=18` → `docs/screens/pitch/18-photo-identify-phone.png` ✅.
- Просмотрены глазами: `manager-1280-photo-result`, `manager-412-photo-order`, `manager-1280-reports`, `executor-412-requests`, кадр 18 — пустых экранов, ошибок и обрезанного текста нет.
- ⚠️ В кадрах первый кандидат называется «Кондиционер переговорной», а не «Кондиционер КД-301»: рабочая база ещё со старыми демо-данными. После Refresh demo название станет новым. Блока «Узнавание по фото» в «Отчётах» нет, потому что 0017 не применена и журнал пуст. Так и задумано.

## Миграция 0017 — полный текст
**Зачем:** измеримые цифры к питчу — сколько узнаваний, как часто первый кандидат верный, сколько секунд. **Что меняет:** новая таблица `photo_identifications` (только служебные поля, без фото и шильдика), её RLS и триггер, функция `photo_identify_stats`; существующие таблицы не трогает. **Повторный запуск безопасен:** `create table if not exists`, `drop constraint / policy / trigger if exists` → `create`, `create or replace function`, `create index if not exists` (проверено: `tools/db_test/run.sh` выполняет её дважды). Без неё приложение работает (журнал молча пропускается, блока в «Отчётах» нет).

```sql
-- 0017 — «Узнать по фото» (шаг 22): журнал узнаваний для цифр к питчу.
--
-- 1) Таблица photo_identifications: одно узнавание — одна строка. БЕЗ фото и
--    без текста шильдика: вид, уверенность, место, лучший кандидат функции,
--    что выбрал человек и чем кончилось (outcome), модель и время.
-- 2) Доступ: вставляет и дописывает выбор (chosen_asset_id, outcome) только
--    автор, в своей компании; читают автор (свою строку — чтобы дописать) и
--    менеджеры / администратор компании. Удалять нельзя никому (кроме каскада
--    при удалении компании или пользователя).
-- 3) Триггер: ссылки на объект, этаж, помещение и оборудование — только своей
--    компании (при изменении проверяются только изменённые ссылки: при
--    удалении оборудования вторая ссылка на него ещё не обнулена); после вставки меняются только chosen_asset_id и outcome
--    (обнуление ссылок при удалении объекта / оборудования разрешено).
-- 4) photo_identify_stats(компания, с, по): всего узнаваний, с решением,
--    «угадал с первого раза» (matched_top), доля, среднее время. Под RLS
--    вызывающего (security invoker): менеджер видит свою компанию.
--
-- Повторный запуск безопасен: if not exists, create or replace, drop … if exists.

-- ---------------------------------------------------------------------
-- 1. Таблица
-- ---------------------------------------------------------------------
create table if not exists public.photo_identifications (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies(id) on delete cascade,
  user_id         uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  object_id       uuid references public.objects(id) on delete set null,
  floor_id        uuid references public.floors(id) on delete set null,
  location_id     uuid references public.locations(id) on delete set null,
  kind            text,
  confidence      real,
  top_asset_id    uuid references public.assets(id) on delete set null,
  chosen_asset_id uuid references public.assets(id) on delete set null,
  outcome         text,
  model           text,
  ms              integer,
  created_at      timestamptz not null default now()
);

alter table public.photo_identifications drop constraint if exists photo_ident_kind_chk;
alter table public.photo_identifications add constraint photo_ident_kind_chk
  check (kind is null or kind ~ '^[a-z_]{1,32}$');
alter table public.photo_identifications drop constraint if exists photo_ident_confidence_chk;
alter table public.photo_identifications add constraint photo_ident_confidence_chk
  check (confidence is null or (confidence >= 0 and confidence <= 1));
alter table public.photo_identifications drop constraint if exists photo_ident_outcome_chk;
alter table public.photo_identifications add constraint photo_ident_outcome_chk
  check (outcome is null or outcome in ('matched_top', 'matched_other', 'new_asset', 'dismissed'));
alter table public.photo_identifications drop constraint if exists photo_ident_dismissed_chk;
alter table public.photo_identifications add constraint photo_ident_dismissed_chk
  check (outcome is distinct from 'dismissed' or chosen_asset_id is null);
alter table public.photo_identifications drop constraint if exists photo_ident_model_chk;
alter table public.photo_identifications add constraint photo_ident_model_chk
  check (model is null or model in ('main', 'lite'));
alter table public.photo_identifications drop constraint if exists photo_ident_ms_chk;
alter table public.photo_identifications add constraint photo_ident_ms_chk
  check (ms is null or (ms >= 0 and ms <= 600000));

create index if not exists idx_photo_ident_company_created
  on public.photo_identifications (company_id, created_at desc);
create index if not exists idx_photo_ident_user on public.photo_identifications (user_id);
create index if not exists idx_photo_ident_object on public.photo_identifications (object_id);
create index if not exists idx_photo_ident_floor on public.photo_identifications (floor_id);
create index if not exists idx_photo_ident_location on public.photo_identifications (location_id);
create index if not exists idx_photo_ident_top on public.photo_identifications (top_asset_id);
create index if not exists idx_photo_ident_chosen on public.photo_identifications (chosen_asset_id);

-- ---------------------------------------------------------------------
-- 2. Проверка ссылок и неизменяемых полей
-- ---------------------------------------------------------------------
create or replace function public.photo_ident_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    -- Меняются только выбор человека и итог; ссылки можно только обнулить
    -- (так делает on delete set null при удалении объекта или оборудования).
    if new.id is distinct from old.id
       or new.company_id is distinct from old.company_id
       or new.user_id is distinct from old.user_id
       or new.kind is distinct from old.kind
       or new.confidence is distinct from old.confidence
       or new.model is distinct from old.model
       or new.ms is distinct from old.ms
       or new.created_at is distinct from old.created_at
       or (new.object_id is not null and new.object_id is distinct from old.object_id)
       or (new.floor_id is not null and new.floor_id is distinct from old.floor_id)
       or (new.location_id is not null and new.location_id is distinct from old.location_id)
       or (new.top_asset_id is not null and new.top_asset_id is distinct from old.top_asset_id)
    then
      raise exception 'photo_identifications: можно изменить только chosen_asset_id и outcome'
        using errcode = '42501';
    end if;
  end if;

  if new.object_id is not null and (tg_op = 'INSERT' or new.object_id is distinct from old.object_id) and not exists (
       select 1 from objects o where o.id = new.object_id and o.company_id = new.company_id) then
    raise exception 'photo_identifications: объект другой компании' using errcode = '42501';
  end if;
  if new.floor_id is not null and (tg_op = 'INSERT' or new.floor_id is distinct from old.floor_id) and not exists (
       select 1 from floors f where f.id = new.floor_id and f.company_id = new.company_id) then
    raise exception 'photo_identifications: этаж другой компании' using errcode = '42501';
  end if;
  if new.location_id is not null and (tg_op = 'INSERT' or new.location_id is distinct from old.location_id) and not exists (
       select 1 from locations l join objects o on o.id = l.object_id
        where l.id = new.location_id and o.company_id = new.company_id) then
    raise exception 'photo_identifications: помещение другой компании' using errcode = '42501';
  end if;
  if new.top_asset_id is not null and (tg_op = 'INSERT' or new.top_asset_id is distinct from old.top_asset_id) and not exists (
       select 1 from assets a join locations l on l.id = a.location_id join objects o on o.id = l.object_id
        where a.id = new.top_asset_id and o.company_id = new.company_id) then
    raise exception 'photo_identifications: оборудование другой компании' using errcode = '42501';
  end if;
  if new.chosen_asset_id is not null and (tg_op = 'INSERT' or new.chosen_asset_id is distinct from old.chosen_asset_id) and not exists (
       select 1 from assets a join locations l on l.id = a.location_id join objects o on o.id = l.object_id
        where a.id = new.chosen_asset_id and o.company_id = new.company_id) then
    raise exception 'photo_identifications: оборудование другой компании' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.photo_ident_check() from public, anon, authenticated;

drop trigger if exists trg_photo_ident_check on public.photo_identifications;
create trigger trg_photo_ident_check
  before insert or update on public.photo_identifications
  for each row execute function public.photo_ident_check();

-- ---------------------------------------------------------------------
-- 3. RLS
-- ---------------------------------------------------------------------
alter table public.photo_identifications enable row level security;

drop policy if exists photo_ident_select on public.photo_identifications;
create policy photo_ident_select on public.photo_identifications for select using (
  company_id = public.my_company_id()
  and (user_id = auth.uid() or public.is_manager())
);

drop policy if exists photo_ident_insert on public.photo_identifications;
create policy photo_ident_insert on public.photo_identifications for insert with check (
  company_id = public.my_company_id() and user_id = auth.uid()
);

drop policy if exists photo_ident_update on public.photo_identifications;
create policy photo_ident_update on public.photo_identifications for update
  using (company_id = public.my_company_id() and user_id = auth.uid())
  with check (company_id = public.my_company_id() and user_id = auth.uid());

revoke all on public.photo_identifications from anon;
grant select, insert, update on public.photo_identifications to authenticated;

-- ---------------------------------------------------------------------
-- 4. Статистика для «Отчётов»
-- ---------------------------------------------------------------------
create or replace function public.photo_identify_stats(
  p_company uuid default null, p_from timestamptz default null, p_to timestamptz default null)
returns table (
  total         bigint,   -- всего узнаваний
  decided       bigint,   -- человек выбрал что-то (outcome задан)
  matched_top   bigint,   -- угадал с первого раза
  top_rate      numeric,  -- matched_top / decided, 0..1; null — решений нет
  avg_ms        numeric   -- среднее время узнавания, мс
)
language sql stable security invoker set search_path = public as $$
  select count(*),
         count(*) filter (where p.outcome is not null),
         count(*) filter (where p.outcome = 'matched_top'),
         round((count(*) filter (where p.outcome = 'matched_top'))::numeric
               / nullif(count(*) filter (where p.outcome is not null), 0), 3),
         round(avg(p.ms)::numeric, 0)
    from photo_identifications p
   where p.company_id = coalesce(p_company, public.my_company_id())
     and (p_from is null or p.created_at >= p_from)
     and (p_to is null or p.created_at < p_to);
$$;
revoke all on function public.photo_identify_stats(uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.photo_identify_stats(uuid, timestamptz, timestamptz) to authenticated;
```

## Что сделать вам
1. **Слить PR** этого шага (GitHub → Pull requests → «Шаг 22» → Merge).
2. **Миграция 0017:** GitHub → **Actions** → **Apply migration** → Run workflow → поле `file`: `0017_photo_identify.sql` → Run workflow → прочитать текст в задаче «Проверка и текст миграции» → **Review deployments** → `production-db` → **Approve and deploy**. Потом напишите мне «применена 0017».
3. **Refresh demo:** Actions → **Refresh demo** → Run workflow (ветка `main`) → Review deployments → `production-db` → Approve and deploy. После этого у кондиционера переговорной имя «Кондиционер КД-301», появятся «КД-302» и огнетушитель, у всего оборудования — вид. ⚠️ Как всегда, удалятся тестовые заявки «Демо БЦ».
4. **Deploy functions:** Actions → **Deploy functions** → Run workflow (ветка `main`) → Review deployments → `production-db` → Approve and deploy. В Summary должно быть `voice-intake=401 photo-identify=401`.
5. **Новый секрет не нужен:** функция берёт те же `YANDEX_API_KEY` и `YANDEX_FOLDER_ID`. Если первое узнавание отвечает «Не получилось распознать», а в логе (Supabase → Edge Functions → **photo-identify** → Logs) — `code: "http_403"` или `http_401`, значит, у сервисного аккаунта нет доступа к модели Qwen: Yandex Cloud → каталог (тот же, что в `YANDEX_FOLDER_ID`) → **Права доступа** → сервисный аккаунт ключа → **Изменить роли** → добавить роль **`ai.languageModels.user`** → Сохранить. Ключ менять не нужно. Если в логе `http_404` / `http_400` — модель переименовали: Supabase → Edge Functions → **Secrets** → добавить `YANDEX_VISION_MODEL` с новым именем из списка моделей AI Studio (значение — только имя модели, например `qwen3.6-35b-a3b`).
6. **Проверить сайт** в Chrome с **Ctrl+Shift+R** и **Android** (свежий APK по ссылке из `CLAUDE.md`, после «Build APK»).

## Как проверить руками
- **Телефон (APK), исполнитель:** «Главная» → круглая кнопка с камерой рядом с «+» → «Где я» → «Белград · БЦ «Демо»» → «301 · Переговорная, 3 этаж» → «Сфотографировать» → снять кондиционер (или распечатанную картинку `assets/demo_photos/ac_indoor.jpg` с экрана) → через несколько секунд «Кондиционер, внутренний блок · Климат · NN%» и «Скорее всего: Кондиционер КД-301» → «Это он» → в окне «Новая заявка» заполнены объект, помещение, оборудование, «Климат», заголовок, «Снимок будет приложен к заявке» → «Создать» → в карточке заявки — фото «до».
- То же с другим местом («весь объект» или «Без объекта») — кандидатов больше, у второго — «тот же этаж».
- **ПК, менеджер:** «По фото» в меню слева → выбрать файл с картинкой → «Нет в реестре — добавить» → форма оборудования с видом и системой.
- Карточка «БЦ «Демо»» → «Оборудование · 16» → «Найти по фото» → «Это он» открывает карточку оборудования (строка «Вид»).
- План этажа 3 → нажать на «301 · Переговорная» → «Сфотографировать оборудование здесь» — «Где я» уже стоит на 301.
- Форма оборудования → «Вид» → список со значками; импорт — колонка «Вид» в шаблоне.
- «Отчёты» → после нескольких узнаваний — блок «Узнавание по фото: N снимков, угадано с первого раза X%, в среднем Y с».
- Экран входа: подписи «Email» и «Пароль» внутри полей, сверху ничего не обрезано.
- Английский: «By photo», «Identify by photo», «This one», виды по-английски.

## Ограничения и что не сделано
- ⚠️ **Настоящая модель не проверена**: функция не выложена, а у Claude Code нет ключей (и не должно быть). Проверено на заглушке и тестах. Первый живой запрос покажет время и токены (лог функции). Если Qwen отвечает дольше 14 с, приложение покажет «Не получилось распознать» и «Выбрать вручную».
- ⚠️ Цель «≤ 10 секунд от снимка до подсказки» зависит от модели: снимок сжимается до ~150–300 КБ, справочники читаются, пока модель смотрит на фото; остальное — время Qwen.
- ⚠️ Запасной мультимодальной модели в AI Studio нет — повтора нет (см. блок 1).
- ⚠️ На вебе «Сфотографировать» на ПК открывает выбор файла (камеры у браузера ПК через `image_picker` нет); на телефоне в браузере — камера.
- Выбора «только этаж, без помещения» в «Где я» нет: этаж берётся из помещения или из плана, откуда открыли.
- Кадр питча 18 и снимки `/screens` — с **заглушкой** ответа (без модели), снимок — нарисованный. Лицензия рисунка — та же, что у репозитория (нарисован скриптом `tools/demo_photos/generate.mjs`, сторонних изображений нет).
- Зоны доступа (0016) к журналу узнаваний не применяются (статистика — по всей компании, видит менеджер).
- Сквозные тесты `tools/e2e` не дополнял и не запускал (время до заморозки).

## Журнал
| Время | Что сделано | Коммит |
|---|---|---|
| 12.10 | Ветка, отчёт | 8a27109 |
| 12.10 | Блок 1: `photo-identify`, общий код `_shared/`, выкладка двух функций; `deno test` 36 ✅ | 75ed014 |
| 12.10 | Блок 2: миграция 0017, тесты базы `photo_identify.sql` (15 ✅), все 749 ✅ | 32f9b4f |
| 12.10 | Блоки 3–4: каталог видов, вид в форме, клиент, журнал, форма заявки со снимком | d96d330 |
| 12.10 | Блок 4: экран «Узнать по фото», точки входа | 9a3c875 |
| 12.10 | Блоки 3–5: вид в карточке и импорте, блок в «Отчётах», вход, рисунок для заглушки | 3ce35c1 |
| 12.10 | Блок 3: демо-данные (37 единиц с видом, КД-301/КД-302, огнетушитель) | 73af1d4 |
| 12.10 | Блок 6: тесты каталога, ответа, журнала, сжатия | ea3daa6 |
| 12.10 | Блок 6: кадры «Узнать по фото» в /screens и питче 18 | 1a9907b |
| 12.10 | Блок 6: CLAUDE.md, сценарий показа | e787819 |
| 12.10 | Блок 1: подсказка без рассуждений, `<think>` вырезается | bf83bb0 |
| 12.10 | Итоговый отчёт (черновик) | ec29f05 |
| 13.10 | Блок 4: выбор дописывается в журнал и при быстром «Это он» | 3d415a0 |
| 13.10 | `/screens` (275 ✅, 0 ❌), кадр питча 18, `/check`, отчёт | (этот коммит) |

## Где остановился
Шаг закончен: `/screens` и кадр 18 сняты, `/check` пройден, PR создан. Ждёт проверки и слияния пользователем, затем — применить 0017, выложить функции, Refresh demo (см. «Что сделать вам»). Следующее — шаг 23 (Telegram-бот: тот же разбор через `supabase/functions/_shared/identify.ts` и `intake.ts`).
