# Шаг 28: VPS-эксперимент Niantic Spatial (отдельный APK) + уведомления исполнителю + офлайн-хвосты + кадры

Ветка `step-28` от свежего `main` (шаг 27 слит — коммит `a0927fd`). Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

Состояние рабочей базы (со слов пользователя, 15.10 12:30): применены 0001–0024, выложены 5 функций, Refresh demo выполнен. 0023 и 0024 дописаны в «Применённые миграции» `CLAUDE.md` первым коммитом.

## Чек-лист
- [x] 1. VPS-эксперимент: отдельный вариант сборки (`-PwithVps=true`, модуль `android/vps`), `VpsActivity`, канал `hey_helpy/vps`, миграция 0025 (`vps_sites`, `vps_marks`), «VPS-скан помещения», документ `docs/research/vps-niantic.md` — **VPS-APK собирается локально**, CI-сборку запускает пользователь
- [x] 2. Telegram: уведомление исполнителю о новой заявке + «Взять в работу» (0025 раздел 2, `telegram-notify` kind `assigned`, кнопка `tk:` в боте)
- [x] 3. Офлайн-хвосты: фото «до» и план этажа без сети (байты при предзагрузке, бюджеты 30 / 20 МБ), `work_logs` — только база, телефоны — `profile_contacts` (0025 раздел 3); ⚠️ новая заявка без сети — не делал
- [x] 4. Кадры 18 / 21 (рабочая база) / 28 (макет), `DEMO_DAY_CHECKLIST.md`, регрессия 18/18, `/check`, `/screens`

## Что сделано

### Блок 1. VPS-эксперимент Niantic Spatial NSDK 4 + VPS2 — отдельный APK
Подробно (источники, лицензия, пошагово для владельца, переход на продакшн, риски) — **`docs/research/vps-niantic.md`**.

- **NSDK получен официальным способом**: для Kotlin Niantic раздаёт AAR публичным Maven-репозиторием на GitHub (`github.com/nianticspatial/nsdk-library-aar`, так же подключают официальные `nsdk-samples-kotlin`). Логин и ключ для скачивания **не нужны** — в CI всё скачается само. Версия `com.nianticspatial:nsdk:4.1.0-26051913`, нативная часть только arm64.
- **Изоляция**: всё VPS — только при `-PwithVps=true`. Без флага: модуль `:vps` не подключается (`settings.gradle.kts`), репозиторий NSDK не добавляется, в `MainActivity` — пустая заглушка `VpsHook` (`src/novps`), канала `hey_helpy/vps` нет, кнопок нет. **Проверено**: обычный APK собирается как раньше (`flutter build apk`), PR check зелёный.
- **VPS-APK собирается локально**: `flutter build apk --release -PwithVps=true --target-platform android-arm64` → 70,7 МБ, в манифесте `com.example.hey_helpy.vps` (ставится рядом с основным), `VpsActivity`, `libLightshipARDK.so`. ⚠️ CI-сборку («Build APK (VPS experiment)») я запустить не могу — запускает пользователь; шаги те же, что локально.
- `VpsActivity` (Kotlin): «Найти место» → `Vps2Session.trackAnchor(anchor payload)` → индикатор красный «Ищу…» / жёлтый «Примерно» / зелёный «Точно ✓» (зелёный — когда якорь `TRACKED`, как советует документация) → таблички над оборудованием (название, «1 открытая заявка · ТО 31.10», рамка цвета системы) → касание → «Карточка оборудования» (возврат во Flutter) или «Удалить метку». Менеджер: «Поставить метку» → касание по стене / полу (hit-test ARCore, плоскости горизонтальные и вертикальные) → выбор оборудования → метка **относительно якоря**.
- ⚠️ Таблички — Android-View поверх камеры, спроецированные из 3D-точки (не 3D-модели Filament): проще и надёжнее без устройства для отладки; при ходьбе держатся на месте.
- ⚠️ Код примеров Niantic **не копировался** (лицензия — бизнес-условия Niantic, не открытая): экран написан заново по тому же порядку вызовов, источник указан в комментарии.
- Чистые функции с JUnit (12 тестов): `PoseMath` (метка ↔ якорь, перезапуск = другой мир ARCore → метка на месте, проекция на экран), `VpsToken` (срок токена из JWT), `VpsState` (индикатор, когда показывать метки, ошибки VPS → тексты).
- Тексты экрана — **все из `lib/l10n`** (Flutter передаёт их в экран); тест `test/vps_logic_test.dart` сверяет, что каждый ключ из Kotlin передаётся.
- Понятные сообщения: «Токен VPS истёк — обновите в портале Niantic и пересоберите VPS-APK», нет токена, Niantic не принял токен, нет ARCore, нет камеры, нет сети, лимит запросов, «Скан не найден — проверьте anchor payload», «Ведите камерой медленнее», «Сессия истекла», «Не нашёл поверхность».
- **Хранение — 0025 раздел 1**: `vps_sites` (anchor payload помещения), `vps_marks` (позиция + кватернион относительно якоря). Видимость и права — в базе (`tools/db_test/vps.sql`, 25 проверок).
- **Во всех сборках**: план этажа → помещение → **«VPS-скан помещения»** (менеджер): вставить payload, название, сохранить, удалить. Без 0025 — «Нужна миграция 0025».
- Кнопка **«Метки VPS (эксперимент)»** — «Камера-помощник» (помещение из «Где я»; камера Flutter выключается до запуска ARCore) и шторка помещения на плане; **только в VPS-сборке**.
- ⚠️ Токен внутри APK можно извлечь — для демо допустимо (≤ 90 дней, только scope «VPS API», отзывается в портале); для продакшна — выдача короткоживущих токенов Edge Function'ом (описано в документе, не реализовано).
- ⚠️ Отдельной «карточки помещения» в приложении нет — «VPS-скан помещения» живёт в шторке помещения на плане этажа.

### Блок 2. Исполнителю в Telegram: «Новая заявка» и «Взять в работу»
- Когда заявку назначили подрядчику (создание с автоназначением или «Назначить подрядчика» менеджером), исполнителям этого подрядчика с привязанным Telegram приходит: **«🆕 Новая заявка № 3F2A1C: Капает вода с кондиционера / 📍 БЦ «Демо» · 301 Переговорная · срочность высокая»** + кнопки «▶️ Взять в работу», «Открыть», «🔕 Не присылать заявки» (кадр 28).
- Кому — решает база (`tg_notify_assign_claim`, только service_role): исполнители назначенного подрядчика; если выбран конкретный исполнитель — только он; **в бригаде — только если заявка в зоне бригады** (та же `wo_is_executor` шага 26 «от его имени»); тот, кто назначил, себе не получает. Повтор (заявка × подрядчик × человек) второго сообщения не шлёт; передали другому подрядчику — придёт его людям.
- **«Взять в работу»** в Telegram → `tg_take_order`: статус «в работе» обычным update **от имени исполнителя** — права проверяют те же триггеры шага 26 (не исполнитель → «Эту заявку берёт исполнитель назначенного подрядчика»). Сообщение заменяется на «вы взяли её в работу» с кнопкой «Открыть»; автору заявки из Telegram уходит «взята в работу 🔧».
- ⚠️ Механизм: **та же функция `telegram-notify`** (вход `{orderId, kind: "assigned"}`), новой функции нет — в Deploy functions по-прежнему **5** функций. Приложение зовёт её после `RequestsRepo.create` (id заявки теперь всегда из приложения) и `assign`; бот — сам, после создания заявки, которую база сразу назначила.
- ⚠️ Отписка — **тот же переключатель чата**, что у уведомлений о статусе: `/stop` или кнопка «🔕 Не присылать заявки», `/start` — снова. Отдельной настройки в приложении нет; в «Настройки → Telegram» добавлено пояснение.
- Без 0025 «Новая заявка» молча не уходит, «Взять в работу» отвечает «недоступна»; до Deploy functions старая `telegram-notify` получит `kind: "assigned"`, поймёт его как обычное уведомление о статусе и ничего не отправит (статус «назначена» не уведомляемый).
- Тесты: `deno test` — 95 (новые: кнопка ≤ 64 байт, текст и кнопки RU / EN, экранирование, частичная ошибка рассылки, «Взять» с правами и без, рассылка после создания); база — `tools/db_test/tg_take.sql` (17).

### Блок 3. Офлайн-хвосты шага 27
- **Фото «до» без сети**: при предзагрузке исполнителя (вход, открытие списка, раз в 15 мин) — строки вложений и **байты** снимков «до» своих заявок (⚠️ всего ≤ 30 МБ, один ≤ 4 МБ; новые заявки первыми; демо-картинки не качаются — они в сборке). Без сети карточка показывает их с телефона (миниатюры и просмотр на весь экран). Закрыли / передали заявку — файлы удаляются при следующей предзагрузке.
- **План этажа без сети**: байты планов этажей помещений и оборудования своих заявок (⚠️ всего ≤ 20 МБ, один ≤ 8 МБ — реальные PNG-планы бывают 5–10 МБ; ⚠️ имя файла включает имя файла на сервере — заменили план, старый удалится). Без сети «Показать на плане» в карточке открывает простой экран плана с точкой места (`OfflinePlanScreen`, масштаб пальцами); полный план с заявками — когда есть сеть. `PlanPicture` сама берёт сохранённую картинку, если сети нет.
- ⚠️ **Новая заявка без сети** — **не делал** (по желанию задания; риск для стабильности перед заморозкой).
- **`work_logs`** — пишет только база (политика вставки удалена, права отозваны). Приложение таблицу не читает и не пишет — экраны не затронуты.
- **Телефоны сотрудников** — видят сам человек и менеджеры / админ своей компании. ⚠️ Решение: отдельная таблица `profile_contacts`, а не запрет столбца: приложение (и уже установленные APK) читает свой профиль через `select *` — запрет столбца сломал бы вход. `profiles.phone` всегда пустое: запись в него («Настройки» — и в старых версиях) триггер переносит в `profile_contacts`. Приложение читает телефон вложением `profile_contacts(phone)` («Моя компания», карточка подрядчика, бригады, свои «Настройки»), без 0025 — по-старому. Старые версии приложения просто не увидят чужих телефонов. Тесты — `tools/db_test/privacy.sql` (13); изоляция компаний — новая таблица в `tenant_isolation` (962 проверки).

### Блок 4. Кадры и подготовка к заморозке
- **18** и **21** пересняты на рабочей базе (`node screens.mjs --pitch --only=18,21`), проверены глазами: в 18 нет «В кадре не видно оборудования», есть «Кондиционер, внутренний блок · Климат · 91 %» и «Скорее всего — Кондиционер КД-301»; в 21 — рабочие данные КД-301 (заявка «Капает вода с кондиционера», ТО до 31 окт., последняя работа 5 окт. · КлиматСервис). Камера и ответ ИИ в Playwright — заглушки.
- **28** «Telegram: новая заявка исполнителю» — HTML-макет `tools/screens/tg_assign_mock.mjs` (тексты — из `texts.ts`).
- **29** (VPS) — не снимался (нет устройства): место в README «снимает владелец с телефона».
- `docs/screens/pitch/README.md`, `docs/DEMO_DAY_CHECKLIST.md` (0025, **5** функций, исполнитель привязывает Telegram, логи `assigned` / `take` / `offline-sync`, раздел VPS-APK), `docs/DEMO_SCRIPT.md` (уведомление исполнителю и фото / план без сети в сцене «Режим полёта»).

## Проверки
| Что | Итог |
|---|---|
| `flutter analyze lib test` | ✅ без замечаний |
| `flutter test` | ✅ 508 из 508 (новые: `vps_logic_test.dart` — 8, `offline_media_test.dart` — 4) |
| Веб-сборка `flutter build web --release --base-href /hey-helpy/` | ✅ собирается |
| Строки вне переводов, название продукта (`/check`, шаги 4–5) | ✅ нарушений нет в изменённых файлах |
| `deno check` + `deno test supabase/functions` | ✅ 95 из 95 |
| Тесты базы `bash tools/db_test/run.sh` | ✅ все наборы: vps 25, tg_assign 17, privacy 13, tenant_isolation 962 (была 938 — новые таблицы под проверкой), остальные как в шаге 27; повторный запуск 0025 — без ошибок; демо-данные — без ошибок |
| JUnit VPS `./gradlew -PwithVps=true :vps:testDebugUnitTest` | ✅ 12 из 12 |
| Обычный APK `flutter build apk --release` | ✅ 77,1 МБ, `com.example.hey_helpy`, **без** `VpsActivity` и NSDK (проверено по манифесту) |
| VPS-APK `flutter build apk --release -PwithVps=true --target-platform android-arm64` | ✅ 72,1 МБ, `com.example.hey_helpy.vps`, `VpsActivity`, NSDK 4.1.0 |
| Сквозные тесты `tools/e2e/run.sh` (все) | ✅ **18 из 18** (`tools/e2e/out/results.md`) |
| «PR check» на GitHub | ✅ зелёный на каждом пуше |
| Кадры 18, 21 (рабочая база), 28 (макет) | ✅ проверены глазами |
| `/screens` | см. ниже |

⚠️ На этой машине 7 ГБ памяти, а проект просит у Gradle 8 ГБ (`android/gradle.properties`) — локально демон падал; помог `~/.gradle/gradle.properties` с `-Xmx3g` (только на машине, не в репозитории). У раннеров GitHub 16 ГБ — там это не мешает.

## Что сделать вам (по порядку)

**Основное (до заморозки 18.10):**
1. **Слить PR** (GitHub → Pull requests → «Шаг 28…» → Merge).
2. **Apply migration**: Actions → «Apply migration» → Run workflow → `file`: `0025_vps_anchors.sql` → прочитать текст в первой задаче → Review deployments → `production-db` → Approve and deploy. Затем написать мне «применена 0025».
3. **Deploy functions**: Actions → «Deploy functions» → Run workflow (ветка `main`) → Review deployments → `production-db` → Approve. Обновляются `telegram-bot` и `telegram-notify` (остальные три — без изменений). В Summary у всех пяти — «401 ✅».
4. **Refresh demo** — не обязателен (демо-данные не менялись). Если запускаете для свежих дат — как обычно.
5. **Обычный APK**: соберётся сам после слияния (релиз `latest-apk`) → поставить на телефон исполнителя.
6. Чтобы показать «Новая заявка» исполнителю: на телефоне исполнителя «Настройки → Telegram → Подключить Telegram» (в Telegram этого телефона, не «гостя»).

**VPS-эксперимент (отдельно, по желанию; подробно — `docs/research/vps-niantic.md`, п. 3):**
1. Регистрация: https://scaniverse.nianticspatial.com → бизнес-аккаунт, план **Free** (20 000 кредитов/мес: ≈ 10 мин съёмки **или** ≈ 1 600 запросов VPS; коммерческих прав на Free нет).
2. **Developer token**: Scaniverse web → Credentials → Developer Tokens → New developer token → срок 90 дней → scope **VPS API** → Create → сразу скопировать. GitHub → Settings → Secrets and variables → Actions → New repository secret → `NIANTIC_DEV_TOKEN`.
3. **Скан переговорной** на iPhone в Scaniverse (Sign in with Business Account): новый Site → свет как на показе → телефон вертикально на уровне глаз, медленно, кондиционер с 2–3 углов → 2 перекрывающихся прохода по 2–3 минуты → «Localize» прямо в приложении.
4. **Обработка**: Upload All → Generate Assets → Assets → «⋯» → **Set as Production** → скопировать anchor payload (если в портале не видно — пример `nsdk-samples-kotlin`, раздел Sites, строка «VPS Anchor: …») → в приложении менеджером: план этажа 3 → «301 Переговорная» → **«VPS-скан помещения»** → вставить → Сохранить.
5. **Сборка**: Actions → **«Build APK (VPS experiment)»** → Run workflow (ветка `main`) → артефакт `hey-helpy-vps-apk` или ссылка https://github.com/Anton-Key/hey-helpy/releases/download/latest-vps-apk/hey-helpy-vps.apk → установить на Android **с ARCore**.
6. **Проверка**: «Метки VPS (эксперимент)» → «Найти место» → «Точно ✓» → «Поставить метку» → кондиционер → «Кондиционер КД-301» → отойти, вернуться → закрыть приложение, открыть заново → «Найти место» → табличка на месте → коснуться → карточка КД-301.
7. **Прислать мне**: запись экрана пунктов 6 или текст сообщения на экране и модель телефона. **Токен не присылать.**

## Как проверить руками (основное приложение, после 0025 и Deploy functions)
1. **Новая заявка исполнителю**: исполнитель «КлиматСервис» привязал Telegram → менеджер создаёт заявку «Климат» на «БЦ «Демо»» (или гость пишет боту по QR) → у исполнителя в Telegram «🆕 Новая заявка …» с кнопками. Создать ещё раз ту же — второго сообщения о той же заявке нет.
2. **«Взять в работу»** в Telegram → сообщение меняется на «вы взяли её в работу» → в приложении заявка «В работе»; у гостя (если заявка из Telegram) — «взята в работу 🔧». Нажать ещё раз — «уже в работе».
3. Исполнитель **ЭлектроПро** не получает заявки «КлиматСервис»; `/stop` у исполнителя — новые заявки не приходят; `/start` — снова приходят.
4. **Без сети** (APK исполнителя): при сети открыть список заявок → подождать ~10 с → режим полёта → открыть заявку с фото «до» (например, из Telegram гостя с фото) → фото видно; «Показать на плане» → план этажа с точкой.
5. **Телефоны**: менеджер — «Моя компания» → у сотрудников телефоны видны; исполнитель — карточек с чужими телефонами нет; свой телефон в «Настройках» сохраняется и показывается.
6. **VPS-скан помещения** (любая сборка): менеджер → план этажа → помещение → «VPS-скан помещения» → вставить любую строку из 8+ латинских символов → Сохранить → «Скан: есть · меток нет»; исполнитель этой строки не видит.

## Ограничения и что не сделано
- **VPS на устройстве не проверялся** (у Claude Code нет телефона): возможны сюрпризы инициализации NSDK, долгая первая локализация (до минуты). Показывать на питче — только после «Проверки» владельцем.
- CI-сборку VPS-APK я не запускал (запускает пользователь); локально — зелёная. Если в CI упадёт — прислать лог, вероятная причина — память раннера (`org.gradle.jvmargs=-Xmx8G` в проекте; у раннера GitHub 16 ГБ — должно хватить).
- **Новая заявка без сети** — не делал (по желанию, решил не рисковать перед заморозкой).
- «Взять в работу» из Telegram не отмечает визит по геозоне (Telegram не знает координат телефона) — визит отметится, когда исполнитель откроет заявку в приложении.
- Фото «до» без сети — только в карточке и просмотре; «Скачать / Поделиться» без сети не работает.
- Старая таблица `ar_anchors` не удалена (не используется) — удалить отдельной миграцией после эксперимента.

## Новые и изменённые файлы
**Android / VPS (блок 1)**
- `android/settings.gradle.kts`, `android/build.gradle.kts`, `android/app/build.gradle.kts` — флаг `-PwithVps=true`: модуль, репозиторий NSDK, `.vps`-id, источники `src/vps` / `src/novps`.
- `android/app/src/main/kotlin/…/MainActivity.kt` — `VpsHook.register`, результат экрана VPS.
- `android/app/src/novps/…/VpsHook.kt` — пустая заглушка (обычная сборка); `android/app/src/vps/…/VpsHook.kt` — канал `hey_helpy/vps`.
- `android/vps/build.gradle.kts`, `consumer-rules.pro`, `src/main/AndroidManifest.xml` — модуль VPS.
- `android/vps/src/main/kotlin/…/VpsActivity.kt` — экран; `VpsApi.kt` — REST Supabase; `VpsContract.kt` — аргументы и статус; `PoseMath.kt`, `VpsToken.kt`, `VpsState.kt` — чистые функции.
- `android/vps/src/test/kotlin/…/PoseMathTest.kt`, `VpsTokenTest.kt`, `VpsStateTest.kt` — JUnit (12).
- `.github/workflows/build-apk-vps.yml` — «Build APK (VPS experiment)».
- `docs/research/vps-niantic.md` — документ эксперимента.

**Flutter**
- `lib/features/vps/vps_logic.dart`, `vps_channel.dart`, `vps_launch.dart`, `vps_repository.dart`, `vps_site_screen.dart` — новое.
- `lib/features/camera/camera_screen.dart` — кнопка «Метки VPS», `_openAssetById`.
- `lib/features/floors/floor_plan_screen.dart` — кнопка VPS и «VPS-скан помещения» в шторке помещения, карточка оборудования по метке.
- `lib/features/requests/requests.dart` — `notifyAssigned` после создания и назначения, фото «до» с телефона без сети.
- `lib/features/telegram/telegram_screens.dart` — пояснение для исполнителя.
- `lib/features/offline/offline_logic.dart` (бюджеты, имена, чистые функции), `offline_service.dart` (`_prefetchMedia`, `offlineBeforePhotos`, `planBytes`, `cachedPlace`).
- `lib/features/photos/photo_repository.dart` (`WorkPhoto.bytes`, `WorkPhoto.offline`), `photo_section.dart` (`Image.memory`).
- `lib/features/floors/plan_image.dart` (план с телефона), `order_plan_link.dart` (без сети), `offline_plan_screen.dart` — новое.
- `lib/models/profile.dart` (`phoneFromRow`), `lib/features/auth/auth_repository.dart`, `lib/features/profile/profile_repository.dart`, `lib/features/directory/directory.dart` — телефоны из `profile_contacts`.
- `lib/l10n/app_ru.arb`, `app_en.arb` (+52 ключа) и сгенерированные `app_localizations*.dart`.
- `test/vps_logic_test.dart`, `test/offline_media_test.dart` — новые тесты.

**База и функции**
- `supabase/migrations/0025_vps_anchors.sql` — новая миграция (текст — в конце отчёта).
- `supabase/functions/telegram-bot/assign.ts` (новое), `bot.ts`, `index.ts`, `texts.ts`, `bot_test.ts`; `supabase/functions/telegram-notify/index.ts`, `notify.ts`.
- `tools/db_test/vps.sql`, `tg_take.sql`, `privacy.sql` (новые), `10_fixture.sql`.

**Документы и кадры**
- `docs/screens/pitch/21-camera-card-phone.png` (переснят), `28-telegram-assign-phone.png` (новый), `README.md`; `tools/screens/tg_assign_mock.mjs`.
- `docs/DEMO_DAY_CHECKLIST.md`, `docs/DEMO_SCRIPT.md`, `docs/security/review-2026-10.md` (Н-4 закрыто), `CLAUDE.md`.

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

## Миграция 0025 — полный текст

**Зачем**: (1) хранение VPS-сканов помещений и меток оборудования относительно якоря; (2) уведомление исполнителю в Telegram о новой заявке и «Взять в работу» из бота с правами шага 26; (3) история заявки пишет только база, телефоны сотрудников видят только сам человек и менеджеры.
**Что меняет**: новые таблицы `vps_sites`, `vps_marks`, `telegram.assign_notified`, `profile_contacts`; функции `vps_site_visible`, `tg_notify_assign_claim`, `tg_notify_assign_release`, `tg_take_order`, триггеры `trg_vps_sites_fill`, `trg_vps_marks_fill`, `trg_profiles_phone`; удаляет политику вставки `work_logs` и права на запись в неё; переносит телефоны из `profiles.phone` в `profile_contacts` (`profiles.phone` становится пустым).
**Повторный запуск**: безопасен (`if not exists`, `create or replace`, `drop … if exists`, `on conflict`); проверено — `run.sh` запускает её дважды. Требует 0022 (проверяет и останавливается с понятной ошибкой).
**Откат телефонов** (если вдруг нужно): `update profiles p set phone = c.phone from profile_contacts c where c.profile_id = p.id;` после `drop trigger trg_profiles_phone on profiles;`.

```sql
-- =====================================================================
-- hey_helpy · Миграция 0025: VPS-метки, уведомления исполнителю, мелочи
-- безопасности (шаг 28)
--
-- 1) VPS-эксперимент (Niantic Spatial NSDK 4, VPS2):
--    vps_sites — «VPS-скан помещения»: anchor payload из портала Niantic
--      (вводит менеджер в приложении). Не секрет, но видят только менеджеры
--      (своей зоны) и исполнители подрядчиков этого объекта.
--    vps_marks — метки оборудования ОТНОСИТЕЛЬНО VPS-якоря помещения:
--      позиция (м) и поворот (кватернион). Читают те, кто видит оборудование
--      (can_see); ставят и удаляют — менеджер с правом на объект /
--      администратор (can_manage).
--    Старую таблицу ar_anchors (0002) не трогаем: она не используется и
--    заменяется этими двумя (docs/research/vps-niantic.md).
-- 2) Уведомление исполнителю в Telegram о новой заявке (блок 2 шага 28) —
--    см. раздел 2 ниже.
-- 3) Мелочи из docs/security/review-2026-10.md — см. раздел 3 ниже.
--
-- Требует 0024. Повторный запуск безопасен: if not exists, create or
-- replace, drop … if exists.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. VPS: сайты (скан помещения) и метки
-- ---------------------------------------------------------------------
create table if not exists public.vps_sites (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  object_id      uuid not null references public.objects(id) on delete cascade,
  location_id    uuid references public.locations(id) on delete cascade,
  floor_id       uuid references public.floors(id) on delete cascade,
  name           text not null default '',
  anchor_payload text not null,
  created_by     uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint vps_sites_place check (location_id is not null or floor_id is not null),
  constraint vps_sites_name_len check (char_length(name) <= 80),
  constraint vps_sites_payload_len check (char_length(btrim(anchor_payload)) between 8 and 20000)
);
-- Один скан на помещение (новый payload — правка этой строки).
create unique index if not exists uq_vps_sites_location on public.vps_sites (location_id)
  where location_id is not null;
create index if not exists idx_vps_sites_company on public.vps_sites (company_id);
create index if not exists idx_vps_sites_object on public.vps_sites (object_id);
alter table public.vps_sites enable row level security;

create table if not exists public.vps_marks (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  site_id     uuid not null references public.vps_sites(id) on delete cascade,
  asset_id    uuid not null references public.assets(id) on delete cascade,
  pos_x       double precision not null,
  pos_y       double precision not null,
  pos_z       double precision not null,
  rot_x       double precision not null default 0,
  rot_y       double precision not null default 0,
  rot_z       double precision not null default 0,
  rot_w       double precision not null default 1,
  created_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  -- метка — в пределах помещения от якоря (то же проверяет PoseMath.isValidRelative)
  constraint vps_marks_pos check (abs(pos_x) <= 50 and abs(pos_y) <= 50 and abs(pos_z) <= 50),
  constraint vps_marks_rot check (
    abs(sqrt(rot_x * rot_x + rot_y * rot_y + rot_z * rot_z + rot_w * rot_w) - 1) < 0.01)
);
-- Одна метка на оборудование в скане (переставить = удалить и поставить).
create unique index if not exists uq_vps_marks_site_asset on public.vps_marks (site_id, asset_id);
create index if not exists idx_vps_marks_asset on public.vps_marks (asset_id);
create index if not exists idx_vps_marks_company on public.vps_marks (company_id);
alter table public.vps_marks enable row level security;

-- Компания и объект скана — из помещения / этажа (не от приложения);
-- перенести скан в другое место нельзя.
create or replace function public.trg_vps_sites_fill()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_obj uuid;
  v_fl_obj uuid;
begin
  if new.location_id is not null then
    select l.object_id into v_obj from locations l where l.id = new.location_id;
    if v_obj is null then raise exception 'vps_site_bad_place'; end if;
  end if;
  if new.floor_id is not null then
    select f.object_id into v_fl_obj from floors f where f.id = new.floor_id;
    if v_fl_obj is null or (v_obj is not null and v_fl_obj <> v_obj) then
      raise exception 'vps_site_bad_place';
    end if;
    v_obj := coalesce(v_obj, v_fl_obj);
  end if;
  if tg_op = 'UPDATE' and (new.location_id is distinct from old.location_id
                           or new.floor_id is distinct from old.floor_id) then
    raise exception 'vps_site_place_fixed';
  end if;
  new.object_id := v_obj;
  select o.company_id into new.company_id from objects o where o.id = v_obj;
  new.anchor_payload := btrim(new.anchor_payload);
  new.name := btrim(coalesce(new.name, ''));
  if tg_op = 'UPDATE' then
    new.created_by := old.created_by;
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;
  return new;
end $$;
drop trigger if exists trg_vps_sites_fill on public.vps_sites;
create trigger trg_vps_sites_fill before insert or update on public.vps_sites
  for each row execute function public.trg_vps_sites_fill();

-- Метка: компания — из скана; оборудование — того же объекта, что и скан.
create or replace function public.trg_vps_marks_fill()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_site record;
  v_asset_obj uuid;
begin
  select s.company_id, s.object_id into v_site from vps_sites s where s.id = new.site_id;
  if v_site.object_id is null then raise exception 'vps_mark_bad_site'; end if;
  select l.object_id into v_asset_obj
    from assets a join locations l on l.id = a.location_id where a.id = new.asset_id;
  if v_asset_obj is null or v_asset_obj <> v_site.object_id then
    raise exception 'vps_mark_bad_asset';
  end if;
  new.company_id := v_site.company_id;
  if tg_op = 'UPDATE' then
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  return new;
end $$;
drop trigger if exists trg_vps_marks_fill on public.vps_marks;
create trigger trg_vps_marks_fill before insert or update on public.vps_marks
  for each row execute function public.trg_vps_marks_fill();

-- Кто видит скан помещения: менеджер (админ) своей зоны или исполнитель
-- подрядчика, закреплённого за объектом (или с заявкой на этом объекте).
create or replace function public.vps_site_visible(p_object uuid, p_location uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from objects o where o.id = p_object and o.company_id = public.my_company_id())
    and public.can_see(p_object, null, null, p_location)
    and (
      public.is_manager()
      or exists (
        select 1 from contractor_layers cl
         where cl.contractor_id in (select public.my_contractor_ids())
           and (cl.object_id = p_object or cl.object_id is null))
      or exists (
        select 1 from work_orders w
         where w.object_id = p_object
           and w.assigned_contractor_id in (select public.my_contractor_ids()))
    );
$$;
revoke all on function public.vps_site_visible(uuid, uuid) from public, anon;
grant execute on function public.vps_site_visible(uuid, uuid) to authenticated;

drop policy if exists vps_sites_select on public.vps_sites;
create policy vps_sites_select on public.vps_sites for select using (
  vps_sites.company_id = (select public.my_company_id())
  and public.vps_site_visible(vps_sites.object_id, vps_sites.location_id));
drop policy if exists vps_sites_insert on public.vps_sites;
create policy vps_sites_insert on public.vps_sites for insert with check (
  vps_sites.company_id = (select public.my_company_id())
  and public.can_manage(vps_sites.object_id, null, null, vps_sites.location_id));
drop policy if exists vps_sites_update on public.vps_sites;
create policy vps_sites_update on public.vps_sites for update using (
  vps_sites.company_id = (select public.my_company_id())
  and public.can_manage(vps_sites.object_id, null, null, vps_sites.location_id))
  with check (
  vps_sites.company_id = (select public.my_company_id())
  and public.can_manage(vps_sites.object_id, null, null, vps_sites.location_id));
drop policy if exists vps_sites_delete on public.vps_sites;
create policy vps_sites_delete on public.vps_sites for delete using (
  vps_sites.company_id = (select public.my_company_id())
  and public.can_manage(vps_sites.object_id, null, null, vps_sites.location_id));

-- Метку видит тот, кто видит оборудование (и сам скан — иначе нечего
-- показывать, но позы без payload бесполезны, поэтому проверяем только
-- оборудование, как в задании).
drop policy if exists vps_marks_select on public.vps_marks;
create policy vps_marks_select on public.vps_marks for select using (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_see(l.object_id, a.layer_id, a.id, a.location_id)));
drop policy if exists vps_marks_insert on public.vps_marks;
create policy vps_marks_insert on public.vps_marks for insert with check (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_manage(l.object_id, a.layer_id, a.id, a.location_id)));
drop policy if exists vps_marks_update on public.vps_marks;
create policy vps_marks_update on public.vps_marks for update using (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_manage(l.object_id, a.layer_id, a.id, a.location_id)))
  with check (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_manage(l.object_id, a.layer_id, a.id, a.location_id)));
drop policy if exists vps_marks_delete on public.vps_marks;
create policy vps_marks_delete on public.vps_marks for delete using (
  vps_marks.company_id = (select public.my_company_id())
  and exists (select 1 from public.assets a join public.locations l on l.id = a.location_id
               where a.id = vps_marks.asset_id
                 and public.can_manage(l.object_id, a.layer_id, a.id, a.location_id)));

grant select, insert, update, delete on public.vps_sites to authenticated;
grant select, insert, update, delete on public.vps_marks to authenticated;

-- ---------------------------------------------------------------------
-- 2. Telegram: исполнителю — «Новая заявка» и «Взять в работу» (блок 2)
--
-- Как в 0022, без pg_net: после назначения подрядчика приложение вызывает
-- Edge Function telegram-notify ({orderId, kind: "assigned"}) со своим JWT;
-- бот после создания заявки — сам. Функции ниже — только service_role.
--
-- Кому: исполнители назначенного подрядчика с привязанным Telegram
-- (telegram_links). Если в заявке выбран конкретный исполнитель — только
-- ему. Исполнитель в бригаде — только если заявка в зоне его бригады:
-- проверяет та же wo_is_executor() шага 26 «от его имени» (telegram.act_as).
-- Тот, кто назначил, себе не получает. Отписка — тот же переключатель чата,
-- что и у уведомлений о статусе (telegram.optout: /stop и кнопка 🔕;
-- /start — снова присылать).
-- Повтор: (заявка, подрядчик, человек) — один раз; передали другому
-- подрядчику — новым исполнителям придёт.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('telegram.notified') is null then
    raise exception '0025: сначала примените миграцию 0022 (уведомления в Telegram)';
  end if;
end $$;

create table if not exists telegram.assign_notified (
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  contractor_id uuid not null,
  profile_id    uuid not null,
  sent_at       timestamptz not null default now(),
  primary key (work_order_id, contractor_id, profile_id)
);
revoke all on telegram.assign_notified from public, anon, authenticated, service_role;

-- Кому и что отправить: {number, title, object, place, priority, targets:
-- [{chat_id, lang, profile_id}]} или null (нет подрядчика, статус не «новая /
-- назначена», некому).
create or replace function public.tg_notify_assign_claim(p_order uuid, p_actor uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  w record;
  r record;
  prev text[];
  ok boolean;
  inserted int;
  targets jsonb := '[]'::jsonb;
begin
  select wo.id, wo.status, wo.title, wo.priority, wo.company_id, wo.assigned_contractor_id,
         wo.assigned_executor_id, o.name as object_name,
         nullif(btrim(concat_ws(' ', nullif(btrim(coalesce(l.code, '')), ''), l.name)), '') as place
    into w
    from work_orders wo
    left join objects o on o.id = wo.object_id
    left join locations l on l.id = wo.location_id
   where wo.id = p_order;
  if not found or w.assigned_contractor_id is null or w.status not in ('new', 'assigned') then
    return null;
  end if;

  for r in
    select distinct on (e.profile_id) e.profile_id, tl.chat_id, coalesce(tl.language, 'ru') as lang
      from executors e
      join telegram_links tl on tl.profile_id = e.profile_id
      join profiles p on p.id = e.profile_id and p.company_id = w.company_id
     where e.contractor_id = w.assigned_contractor_id
       and e.profile_id is not null
       and (w.assigned_executor_id is null or e.id = w.assigned_executor_id)
       and e.profile_id is distinct from p_actor
       and not exists (select 1 from telegram.optout x where x.chat_id = tl.chat_id)
     order by e.profile_id
  loop
    -- Бригада: заявка должна быть в зоне — проверка «от имени» исполнителя.
    prev := telegram.act_as(r.profile_id);
    begin
      ok := public.wo_is_executor(p_order);
      perform telegram.restore(prev);
    exception when others then
      perform telegram.restore(prev);
      ok := false;
    end;
    continue when not ok;

    insert into telegram.assign_notified(work_order_id, contractor_id, profile_id)
    values (p_order, w.assigned_contractor_id, r.profile_id)
    on conflict do nothing;
    get diagnostics inserted = row_count;
    continue when inserted = 0;
    targets := targets || jsonb_build_object('chat_id', r.chat_id, 'lang', r.lang, 'profile_id', r.profile_id);
  end loop;

  if jsonb_array_length(targets) = 0 then
    return null;
  end if;
  return jsonb_build_object(
    'number', upper(left(p_order::text, 6)), 'title', left(coalesce(w.title, ''), 200),
    'object', w.object_name, 'place', w.place, 'priority', w.priority,
    'contractor_id', w.assigned_contractor_id, 'targets', targets);
end $$;

-- Отправить не удалось — снять отметку (следующий вызов попробует снова).
create or replace function public.tg_notify_assign_release(p_order uuid, p_contractor uuid, p_profile uuid)
returns void language sql volatile security definer set search_path = public as $$
  delete from telegram.assign_notified
   where work_order_id = p_order and contractor_id = p_contractor and profile_id = p_profile;
$$;

-- «Взять в работу» из Telegram: человек — по chat_id из привязки, смена
-- статуса — обычным update «от его имени»: права проверяют те же триггеры
-- шага 26 (trg_wo_status_flow: только исполнитель назначенного подрядчика,
-- в бригаде — в её зоне). Ответ: {ok, number, title} или {error}.
create or replace function public.tg_take_order(p_chat bigint, p_order uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid;
  v_company uuid;
  w record;
  prev text[];
begin
  select l.profile_id, p.company_id into v_uid, v_company
    from telegram_links l join profiles p on p.id = l.profile_id
   where l.chat_id = p_chat;
  if v_uid is null then
    return jsonb_build_object('error', 'not_linked');
  end if;
  select wo.status, wo.title, wo.company_id into w from work_orders wo where wo.id = p_order;
  if not found or w.company_id is distinct from v_company then
    return jsonb_build_object('error', 'not_found');
  end if;
  if w.status = 'in_progress' then
    return jsonb_build_object('error', 'already', 'number', upper(left(p_order::text, 6)), 'title', w.title);
  end if;
  if w.status not in ('new', 'assigned', 'returned') then
    return jsonb_build_object('error', 'bad_status', 'status', w.status);
  end if;

  prev := telegram.act_as(v_uid);
  begin
    if not public.wo_is_executor(p_order) then
      perform telegram.restore(prev);
      return jsonb_build_object('error', 'not_executor');
    end if;
    update work_orders set status = 'in_progress' where id = p_order;
    perform telegram.restore(prev);
  exception when others then
    perform telegram.restore(prev);
    return jsonb_build_object('error', 'not_executor');
  end;
  return jsonb_build_object('ok', true, 'number', upper(left(p_order::text, 6)), 'title', w.title);
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.tg_notify_assign_claim(uuid, uuid)',
    'public.tg_notify_assign_release(uuid, uuid, uuid)',
    'public.tg_take_order(bigint, uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 3. Мелочи из docs/security/review-2026-10.md (Н-4)
-- ---------------------------------------------------------------------

-- 3.1 История заявки (work_logs) пишет только база. Раньше (0008) любой,
-- кто видит заявку, мог добавить строку «on_review → done, принято» от
-- своего имени. Приложение work_logs не пишет и не читает; база сама в
-- неё сейчас тоже не пишет — таблица остаётся для будущей истории.
drop policy if exists work_logs_insert on public.work_logs;
drop policy if exists work_logs_update on public.work_logs;
drop policy if exists work_logs_delete on public.work_logs;
revoke insert, update, delete on public.work_logs from authenticated, anon;

-- 3.2 Телефоны сотрудников видят сам человек и менеджеры (админ) своей
-- компании, а не все в компании (исполнители подрядчиков, заявители).
-- ⚠️ Решение: отдельная таблица profile_contacts, а не запрет столбца
-- (revoke select (phone)): приложение и уже установленные APK читают свой
-- профиль через select * — запрет столбца сломал бы вход. Старое поле
-- profiles.phone остаётся, но всегда пустое: запись в него (экран
-- «Настройки», и в старых версиях) триггер переносит в profile_contacts.
create table if not exists public.profile_contacts (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  company_id uuid references public.companies(id) on delete cascade,
  phone      text not null check (char_length(btrim(phone)) between 1 and 40),
  updated_at timestamptz not null default now()
);
create index if not exists idx_profile_contacts_company on public.profile_contacts (company_id);
alter table public.profile_contacts enable row level security;

drop policy if exists profile_contacts_select on public.profile_contacts;
create policy profile_contacts_select on public.profile_contacts for select using (
  profile_contacts.profile_id = auth.uid()
  or (profile_contacts.company_id = (select public.my_company_id()) and (select public.is_manager())));
-- Писать — только свой телефон и только через profiles (триггер ниже,
-- security definer); прямой записи у приложения нет.
revoke insert, update, delete on public.profile_contacts from authenticated, anon;
grant select on public.profile_contacts to authenticated;

create or replace function public.trg_profiles_phone()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.phone is not null then
    if btrim(new.phone) = '' then
      delete from profile_contacts where profile_id = new.id;
    else
      insert into profile_contacts(profile_id, company_id, phone, updated_at)
      values (new.id, new.company_id, left(btrim(new.phone), 40), now())
      on conflict (profile_id) do update
        set phone = excluded.phone, company_id = excluded.company_id, updated_at = now();
    end if;
    new.phone := null;
  end if;
  -- Человек перешёл в другую компанию (приглашение) — телефон за ним.
  if tg_op = 'UPDATE' and new.company_id is distinct from old.company_id then
    update profile_contacts set company_id = new.company_id where profile_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists trg_profiles_phone on public.profiles;
create trigger trg_profiles_phone before insert or update on public.profiles
  for each row execute function public.trg_profiles_phone();

-- Перенос уже записанных телефонов (повторный запуск — ничего не меняет:
-- в profiles.phone к этому времени пусто).
insert into public.profile_contacts(profile_id, company_id, phone)
select p.id, p.company_id, left(btrim(p.phone), 40)
  from public.profiles p
 where p.phone is not null and btrim(p.phone) <> ''
on conflict (profile_id) do update set phone = excluded.phone, company_id = excluded.company_id;
update public.profiles set phone = null where phone is not null;
```
