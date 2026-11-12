# Шаг 36: Hey Helpy → Dokazio (переименование)

Ветка `step-36` от свежего `main` (`6c63627`, PR #35 слит). Открытых задач (issues) нет.
⚠️ Сессия Claude Code закреплена за веткой `claude/admiring-darwin-o17vck`: те же коммиты пушатся и туда, PR — из `step-36`, как просили.

## Чек-лист
- [x] 1. Приложение: appName, подпись под иконкой, web, wakePhrase, .arb, PDF, terminology_test
- [x] 2. Что НЕ меняем — список ниже
- [x] 3. Telegram-бот: тексты, описание бота, тесты
- [x] 4. Сайт: имя, главная, легенда, честные формулировки про распознавание, check.mjs
- [x] 5. Картинки и видео: /screens, питч, сайт, ролик, OCR — снято на локальной базе; 08 (карта) не переснят
- [x] 6. Документы: README, DEMO_SCRIPT, docs/site, pitch README, CLAUDE.md, /check
- [x] Проверки, итог, «Что сделать вам», PR

## Коротко
- Продукт везде, что видят люди, называется **Dokazio** (полное имя «Dokazio — Contractor Control»): приложение (шапка, кнопка голоса, вход, «О приложении», PDF отчёта / акта / теста распознавания, плакат с QR), подпись под иконкой Android, вкладка браузера, бот, сайт RU / EN, документы для показа.
- Фраза голоса — «Hey, Dokazio» / «Эй, Доказио». Старое «Эй, Хелпи» разбор тоже убирает (люди будут говорить по привычке).
- Главная сайта: «Send the job. See it done.», кнопки «Apply for a pilot» и «See how it works», строка-легенда имени.
- Про узнавание оборудования на сайте и в сценарии показа теперь честно: сервис **предлагает** оборудование из реестра объекта, **человек подтверждает**; AR-метки в первой версии ставит человек. Цифр точности нет.
- Технические имена (`hey_helpy`, `/hey-helpy/`, `@HeyHelpy_bot`, `hey-helpy.apk`, миграции) **не менялись** — иначе сломаются установки и ссылки.
- Сторожа: `test/terminology_test.dart` (строки .arb, подпись под иконкой, web, тексты бота, исходники и сборка сайта), `tools/site/check.mjs` (собранный сайт), `tools/site/ocr_check.mjs` (картинки и ролик).

## Блок 1. Приложение
| Что | Было | Стало |
|---|---|---|
| `appName` (RU, EN) | Hey Helpy | **Dokazio** |
| `wakePhrase` | «Эй, Хелпи» / «Hey, Helpy» | **«Эй, Доказио» / «Hey, Dokazio»** |
| `helpTip1` | «Hey Helpy» — скажите… | «Dokazio» — скажите… (кнопка голоса подписана `appName`) |
| Имена файлов | `HeyHelpy_Report_…pdf`, `HeyHelpy_Equipment_template`, `hey-helpy-qr.pdf`, `hey-helpy-recognition-test-….pdf/csv` | `Dokazio_Report_…pdf`, `Dokazio_Equipment_template`, `dokazio-qr.pdf`, `dokazio-recognition-test-…` |
| Подпись под иконкой (`values*/strings.xml`) | Hey Helpy | Dokazio |
| `web/index.html` | `<title>hey_helpy</title>`, «A new Flutter project.» | «Dokazio — Contractor Control», описание со слоганом |
| `web/manifest.json` | name / short_name `hey_helpy` | «Dokazio — Contractor Control» / «Dokazio» |
| Класс приложения | `HeyHelpyApp` | `DokazioApp` |
| Проверочная фраза «Готовности к показу», заглушка речи `VOICE_MOCK` | «Hey Helpy, …» | «Hey Dokazio, …» |
| User-Agent плиток карты | `app.heyhelpy.cmms` | `app.dokazio.cmms` |
| `pubspec.yaml` description, `.devcontainer` name, комментарии | Hey Helpy | Dokazio |

PDF отчёта, акта, теста распознавания и плакат Telegram берут имя только из `appName` — проверено поиском (`l.appName` в `report_pdf.dart`, `act_pdf.dart`, `eval_pdf.dart`, `telegram_poster.dart`).

**Фраза активации (`TextIntake.stripWakePhrase` и `_shared/intake.ts` — одинаково):**
- приветствие («эй», «хей», «hey», «ok»…) + имя: `доказио`, `доказиа`, `доказия`, `докацио`, `дуказио`, `dokazio`, `docazio`, `dokazzio`, `dokasio`, `dokazia`, `doka zio`, `doca zio` — так системный распознаватель может записать незнакомое слово;
- одно имя без приветствия: `доказио`, `докацио`, `dokazio`, `docazio`, `dokazzio` — их не спутать с обычными словами;
- старые варианты «хелпи / helpy» оставлены.
- ⚠️ **Решение:** старое имя из разбора **не убрал** — люди и демо-пользователи ещё месяц будут говорить «Эй, Хелпи»; если не убрать, оно попадёт в заголовок заявки. Вреда нет: это только удаление фразы в начале текста. Слово «Доказательство» в начале не трогается (тест).
- ⚠️ Голосовой активации «на устройстве» (Porcupine) по-прежнему нет — кнопка «Нажми и говори»; новую фразу распознаватель Android / Chrome пишет по-разному, поэтому вариантов несколько. Проверить на телефоне — см. «Как проверить руками».

**`test/terminology_test.dart` (сторож имени):**
- нет «Hey Helpy», «Helpy», «хелпи», «CtrlSite» в значениях `.arb`, в `strings.xml`, `web/index.html`, `web/manifest.json`, `telegram-bot/texts.ts`, `tools/site/content.*.mjs`, `config.mjs` и в собранном `site/` (HTML, txt, xml, json, webmanifest); разрешены только адрес `hey-helpy` / `hey_helpy` и `HeyHelpy_bot`;
- «Dokazio» написано правильно: любое «doka…zio», кроме «Dokazio» / «dokazio» (в адресах), — ошибка («DokaZio», «Doka zio», «DOKAZIO»);
- прежняя проверка «нигде нет «Эй, Helpy»» сохранена.

## Блок 2. Что НЕ меняли — и почему
| Что | Где | Почему оставлено |
|---|---|---|
| Репозиторий `Anton-Key/hey-helpy`, пакет Dart `hey_helpy` (`package:hey_helpy/…` во всех импортах) | `pubspec.yaml`, `lib/`, `test/` | переименование пакета = правка сотен импортов без пользы для людей; репозиторий — ссылки, Pages, секреты, Actions |
| `applicationId` / `namespace` `com.example.hey_helpy` (и `.vps`, `.arlabel`, `.arcommon`) | `android/` | другой id = другое приложение: телефоны не обновятся, а установят второе рядом |
| Каналы `hey_helpy/clock`, `hey_helpy/vps`, `hey_helpy/arlabel` | Kotlin + Dart | внутренние имена, должны совпадать на обеих сторонах |
| Проект Supabase, `supabase/config.toml` `project_id = "hey-helpy"`, миграции 0001–0028 | `supabase/` | миграции применены, хук запрещает их менять; id проекта — служебный |
| Бот `@HeyHelpy_bot`, `BOT_USERNAME`, `kTelegramBot`, ссылки `t.me/HeyHelpy_bot?start=…` | бот, приложение, сайт, QR-плакаты | имя пользователя бота в Telegram поменять нельзя; QR уже напечатаны. Видимое **имя** бота меняется в @BotFather (см. «Что сделать вам») |
| Адрес `https://anton-key.github.io/hey-helpy/` и `/hey-helpy/site/` | сайт, приложение, бот (`APP_URL`), `--base-href` | решение владельца: адрес прежний до покупки dokazio.com |
| Релиз `latest-apk`, файл `hey-helpy.apk`, `latest-vps-apk` / `hey-helpy-vps.apk`, артефакт `hey-helpy-apk` | `.github/workflows/`, README, CLAUDE.md | постоянные ссылки на APK уже розданы |
| Старые отчёты `docs/reports/step-*.md`, оценки `docs/site/ai-readiness-2026-10-*.md` | `docs/` | история, не для показа |
| Имена служебных npm-пакетов `hey-helpy-screens`, `hey-helpy-site-tools`, секрет локального бэкенда | `tools/` | внутренние, нигде не видны |
| Пример имени токена `hey-helpy-demo` в инструкции Niantic | `docs/research/vps-niantic.md` | так называется уже созданный токен |
| Значок приложения (буква «H» в зелёном квадрате) и цвета дизайн-системы | `android/…/res`, `web/icons`, логотип сайта | ⚠️ решение владельца — ждём бренд-бук. **Буква «H» рядом с «Dokazio» выглядит странно** — заменить вместе с бренд-буком |

## Блок 3. Telegram-бот
- `texts.ts` (RU / EN): «Это бот Dokazio…», «This is the Dokazio bot…», ответ на «Подать заявку на пилот»: «Здравствуйте! Это Dokazio — Contractor Control. Чтобы подать заявку на пилот, расскажите в одном сообщении…» / «Hello! This is Dokazio — Contractor Control. To apply for a pilot, tell us in one message…»; ошибка сохранения ссылается на кнопку «Подать заявку на пилот» / «Apply for a pilot».
- Описание бота (`setMyDescription` в workflow «Telegram webhook»): «Dokazio — Contractor Control. Report a problem…» (RU и EN). Workflow я **не запускал**.
- `/help`, меню команд — имени продукта в них не было, не менялись.
- Тесты `bot_test.ts`, `voice-intake/schema_test.ts` (новая и старая фраза активации, «doka zio»).

## Блок 4. Сайт
Источники — `tools/site/content.en.mjs`, `content.ru.mjs`, `config.mjs` (`BRAND`), `build.mjs` (llms, JSON-LD, призыв), `og.mjs`; `site/` пересобран `node tools/site/build.mjs`.
- Имя везде → **Dokazio**: title, description, OG, JSON-LD (`Organization`, `SoftwareApplication`, `VideoObject`), `llms.txt`, `llms-full.txt`, `robots.txt`, `humans.txt`, `site.webmanifest`, sitemap, 404, политика, FAQ, калькулятор.
- **Главная (EN):** H1 «Send the job. See it done.»; подзаголовок «Dispatch work to any contractor in one tap. Dokazio shows proof the work was done at the exact equipment, so you pay only for verified work.»; кнопки «Apply for a pilot» (бот `?start=demo`) и «See how it works» (`#how`); строка-легенда «Dokazio (doh-KAH-zee-oh) — from “dokaz”, Serbian for “proof”.» под кнопками; ссылки «Estimate your ROI →» и на ролик — строкой ниже.
- **Главная (RU):** «Отправьте задачу — увидите, что она сделана»; «Отправьте работу любому подрядчику одним касанием. Dokazio показывает доказательство, что работа сделана именно на этом оборудовании, — и вы платите только за подтверждённую работу.»; «Подать заявку на пилот», «Как это работает»; «Dokazio (доКАзио) — от сербского «dokaz», «доказательство».»
- ⚠️ **Кнопка «Request a demo» / «Запросить демо» везде стала «Apply for a pilot» / «Подать заявку на пилот»** (шапка, призыв внизу страниц, «Контакты», калькулятор, FAQ, политика) — чтобы на одной странице не было двух разных призывов. Ссылка та же (`?start=demo`, `?start=roi` у калькулятора); страница «Контакты» — «Apply for a pilot» / «Заявка на пилот».
- **Честно про распознавание** (EN и RU): «Intake → AI parses it», «Any unit, same flow», карточка «Camera assistant», раздел «Photo and the camera assistant», «AR labels», FAQ «How does the AI know…», `featureList` JSON-LD, описание ролика — вместо «сервис узнаёт / находит конкретную единицу» теперь «предлагает подходящее оборудование из реестра объекта, человек подтверждает»; в «AR-метках» — «В первой версии метки ставит человек», «после закрытия экрана метки нужно поставить заново». Подпись «Demo frame — not measured accuracy» оставлена. «Works on any phone» на сайте не было и нет (написано «на телефонах с ARCore»).
- Цены, калькулятор, формулы `roi.mjs` — не трогал (только комментарий и слово «Hey Helpy price» → «Dokazio price»).
- `check.mjs`: в любом текстовом файле собранного сайта (HTML, txt, xml, json, webmanifest, css, js) — ошибка на «helpy», «хелпи», «CtrlSite» (кроме `hey-helpy` в адресе и `HeyHelpy_bot`) и на неправильное написание «Dokazio».
- Ролик на сайте теперь `media/dokazio-demo.mp4` (файл в репозитории — `docs/demo/dokazio-demo-v2.mp4`).
- ⚠️ Логотип в шапке сайта — прежний значок «H» (см. блок 2).

## Блок 6. Документы
- `README.md` — заголовок «Dokazio — Contractor Control», слоган, легенда, абзац «Старое имя в технических местах».
- `docs/DEMO_SCRIPT.md` — имя, фраза голоса, произношение и слоган в начале; реплики «система узнала, какой именно…» → «предложила… исполнитель подтвердил»; про цифры точности до замера — ⚠️ не называть (вместо «цифры к питчу из «Отчётов»»).
- `docs/DEMO_DAY_CHECKLIST.md`, `docs/DEMO_SETUP.md`, `docs/design/DESIGN.md`, `docs/screens/pitch/README.md` (тезисы 18 и 21 — «предлагает… человек подтверждает»), `docs/site/README.md`, `docs/site/roi-calculator-brief.md`, `LAUNCH_FIREBASE_STUDIO.md` — Dokazio.
- `CLAUDE.md` — заголовок, первая строка, фраза голоса, новый абзац «Шаг 36 — имя Dokazio» (решения владельца, что не меняется, чего не писать до замеров), «Дизайн» про `appName`, `/check`.
- `.claude/commands/check.md` — правило названия «Dokazio» вместо «Hey Helpy».
- Инструменты: `tools/e2e/record_demo.mjs` (подписи ролика, кнопка `^Dokazio`, имена файлов `dokazio-demo*.mp4`), `scenarios.mjs` (фразы `?voice=`), `tools/screens/local_backend.mjs` (заглушка ИИ убирает и новую фразу), макеты чата бота (имя «Dokazio», аватар «D», ник `@HeyHelpy_bot` — как будет после /setname), `web/ar/` (демо WebXR).
- Демо-сид: только комментарии в первой строке (`demo.sql`, `demo_history.sql`) — Refresh demo из-за этого запускать не нужно.

## Блок 5. Картинки и видео
⚠️ **Рабочая база недоступна**: в контейнере нет `.env.demo` (логины демо-пользователей) и `env.json`, поэтому всё снято на **локальной базе** (`tools/db_test/run.sh`: все миграции 0001–0028 + английские демо-данные; ответы ИИ — заглушка). Данные те же, что даёт Refresh demo.
Окружение: Flutter 3.50.0 (stable, 09.11.2026), PostgreSQL 16, PostgREST 12.2.3, Playwright 1.64 (браузер — предустановленный Chromium 1243 под именем 1248), tesseract 5 (rus + eng).
⚠️ Веб-сборки для съёмки — с `--no-web-resources-cdn`: движок CanvasKit с `gstatic.com` из контейнера не грузится. На рабочие сборки это не влияет (скрипты не менял).

| Что | Чем | Итог |
|---|---|---|
| `/screens` → `docs/screens/latest/` | `screens.mjs --local` | **242 ✅, 33 ❌** (README там же). ❌: карта — 30 снимков «Плитки карты не загрузились» (сервер плиток недоступен из контейнера), «Журнал изменений доступа» — 3 (у локального менеджера нет прав администратора). Сайдбар, шапка телефона, кнопка голоса — «Dokazio». ⚠️ 5 снимков камеры > 300 КБ (как раньше) |
| Кадры питча 01–07, 10–18, 20, 21, 23, 24 | `screens.mjs --local --pitch` (сборка с заглушкой ИИ, `HH_MOCK_AI=1`) | 20 из 22 ✅. **08 и 09 (карта) не пересняты** — плитки; на 08 в меню старое имя (OCR ловит), на 09 имени не видно |
| 19 — плакат A4 с QR | `local_pitch.mjs --only=19` | ✅ «Dokazio», внизу «Telegram bot @HeyHelpy_bot» (ник не меняется) |
| 22, 28 — макеты чата бота | `tg_notify_mock.mjs`, `tg_assign_mock.mjs` | ✅ имя «Dokazio», аватар «D», `@HeyHelpy_bot` |
| 25, 26, 27 — без сети и акт | сценарий 17 (`E2E_LANG=en … e2e.mjs --only=17 --shots`) | ✅ (сценарий прошёл, 93 с). ⚠️ на 27 группа «Needs manager’s decision» ниже края кадра (как и раньше — видна только шапка группы) |
| Ролик `docs/demo/dokazio-demo-v2.mp4` | `record_demo.sh --v2-only` | ✅ **1:37** (было 2:17 — сценарий тот же, вся история на месте: голос → камера → заявка → доказательство → акт → Telegram). Подписи — «Dokazio — Contractor Control. Send the job. See it done.», «The camera suggests “Air conditioner AC-301” from the register — confirm it…» (было «Equipment recognition by camera…»), «Dokazio: intake → dispatch → execution → control». На сайте длительность → `PT1M37S`, «1 min 37 s» |
| ⚠️ Старые ролики `hey-helpy-demo.mp4` (ПК, RU), `hey-helpy-demo-phone.mp4` (телефон, RU) | `record_demo.sh` без флага | **удалены**: их сценарий устарел с шага 33 (данные английские) — запись обрывается на 41–48 с; в старых файлах было старое имя. Запасной ролик теперь один — английский v2 (DEMO_SCRIPT, DEMO_DAY_CHECKLIST, CLAUDE.md поправлены) |
| Картинки сайта `assets/site/*.webp`, постер | `images.mjs` | ✅ из новых кадров питча; постер — 21-я секунда ролика (карточка «Parsed by AI»; на 34-й теперь камера с «91 %») |
| OG `og-en.png`, `og-ru.png` | `og.mjs` | ✅ «Dokazio», «Send the job. See it done.», «Pay only for verified work» |
| Значок приложения, логотип «H» | — | не меняли (решение владельца) |

**`tools/site/ocr_check.mjs`** — теперь ищет и старое имя: отдельный проход tesseract **только с английским** (с русским он читает «Hey Helpy» как «Hey Неру» и пропускал имя), слова «helpy», «hey …hepy», «CtrlSite»; можно только `hey-helpy` в адресе и `HeyHelpy_bot`. Исключение для кадра 08 (местные названия на карте OSM) прощает только кириллицу, **старое имя — никогда**. Проверка «до»: на старых кадрах нашла «Helpy» как минимум в 13 файлах сайта и питча (OG, voice, telegram, plan, постер, 01, 03, 04, 06, 16, 17, 19…). Новый шум OCR (английский текст, прочитанный «по-русски»: «баню» = кнопка «Dokazio», «ОМЕВОЧЕ» = «OVERDUE», «падег» = «manager»…) — проверен глазами по вырезкам кадров и добавлен в `KNOWN_NOISE` с объяснением.

Итог OCR (`node tools/site/ocr_check.mjs`, 48 файлов: картинки сайта, кадры питча, ролик по кадру в секунду) — **1 файл с ошибкой: 08 (старое имя, не переснят)**:

| Файл | Кириллица / «Helpy» | Примеры |
|---|---|---|
| `assets/site/act.webp` | нет |  |
| `assets/site/camera.webp` | нет |  |
| `assets/site/ill-cctv.webp` | нет |  |
| `assets/site/ill-faucet.webp` | нет |  |
| `assets/site/ill-fridge.webp` | нет |  |
| `assets/site/ill-hotel_ac.webp` | нет |  |
| `assets/site/ill-iso.webp` | нет |  |
| `assets/site/ill-led.webp` | нет |  |
| `assets/site/ill-phone.webp` | нет |  |
| `assets/site/ill-pipe.webp` | нет |  |
| `assets/site/og-en.png` | нет |  |
| `assets/site/og-ru.png` | нет |  |
| `assets/site/photos.webp` | нет |  |
| `assets/site/plan.webp` | нет |  |
| `assets/site/ppr.webp` | нет |  |
| `assets/site/reports.webp` | нет |  |
| `assets/site/telegram.webp` | нет |  |
| `assets/site/video-poster.webp` | нет |  |
| `assets/site/voice.webp` | нет |  |
| `docs/screens/pitch/01-requests-phone.png` | нет |  |
| `docs/screens/pitch/02-filters-phone.png` | нет |  |
| `docs/screens/pitch/03-voice-listening-phone.png` | нет |  |
| `docs/screens/pitch/04-voice-ai-check-phone.png` | нет |  |
| `docs/screens/pitch/05-order-show-on-plan-phone.png` | нет |  |
| `docs/screens/pitch/06-floor-plan-desktop.png` | нет |  |
| `docs/screens/pitch/07-floor-plan-marker-phone.png` | нет |  |
| `docs/screens/pitch/08-world-map-desktop.png` | исключение (7) · **старое имя (1)** | Hey Helpy, Петербург, Беларусь, Сългария, Вагсеюпа (исключение: подложка карты OSM: местные названия городов) |
| `docs/screens/pitch/09-moscow-map-phone.png` | нет |  |
| `docs/screens/pitch/10-reports-desktop.png` | нет |  |
| `docs/screens/pitch/11-contractor-card-desktop.png` | нет |  |
| `docs/screens/pitch/12-home-desktop.png` | нет |  |
| `docs/screens/pitch/13-ppr-desktop.png` | нет |  |
| `docs/screens/pitch/14-locations-regions-desktop.png` | нет |  |
| `docs/screens/pitch/15-report-pdf-page1.png` | нет |  |
| `docs/screens/pitch/16-equipment-card-desktop.png` | нет |  |
| `docs/screens/pitch/17-crew-zone-desktop.png` | нет |  |
| `docs/screens/pitch/18-photo-identify-phone.png` | нет |  |
| `docs/screens/pitch/19-telegram-qr-poster.png` | нет |  |
| `docs/screens/pitch/20-act-proven-desktop.png` | нет |  |
| `docs/screens/pitch/21-camera-card-phone.png` | нет |  |
| `docs/screens/pitch/22-telegram-done-phone.png` | нет |  |
| `docs/screens/pitch/23-systems-desktop.png` | нет |  |
| `docs/screens/pitch/24-order-photos-phone.png` | нет |  |
| `docs/screens/pitch/25-offline-queue-phone.png` | нет |  |
| `docs/screens/pitch/26-offline-proof-phone.png` | нет |  |
| `docs/screens/pitch/27-act-decision-desktop.png` | нет |  |
| `docs/screens/pitch/28-telegram-assign-phone.png` | нет |  |
| `docs/demo/dokazio-demo-v2.mp4 (97 кадров)` | нет |  |

## Новые и изменённые файлы
- `lib/l10n/app_ru.arb`, `app_en.arb` (+ сгенерированные `app_localizations*.dart`) — `appName`, `wakePhrase`, `helpTip1`, имена файлов PDF и шаблона.
- `android/app/src/main/res/values*/strings.xml` — подпись под иконкой.
- `web/index.html`, `web/manifest.json` — заголовок вкладки, описание, имя PWA; `web/ar/*` — демо WebXR.
- `lib/features/voice/text_intake.dart`, `supabase/functions/_shared/intake.ts` — разбор новой и старой фразы активации.
- `lib/app.dart`, `lib/main.dart` — `DokazioApp`; `lib/features/recognition_eval/eval_models.dart`, `lib/features/telegram/telegram_poster.dart` — имена файлов; `lib/features/readiness/readiness_repository.dart`, `lib/features/voice/speech_input.dart` — проверочная фраза; `lib/features/map/map_config.dart` — User-Agent плиток; комментарии — `lib/core/design/*`, `home_*.dart`, `report_pdf.dart`, `speech_session.dart`, `wake_word_service.dart`, `user_role.dart`.
- `test/terminology_test.dart` — сторож имени; `l10n_test`, `text_intake_test`, `report_pdf_test`, `recognition_eval_test`, `design_test`, `content_navigator_test` — новое имя.
- `supabase/functions/telegram-bot/texts.ts`, `bot_test.ts`, `voice-intake/schema_test.ts` — бот и тесты; `.github/workflows/telegram-webhook.yml` — описание бота.
- `tools/site/content.en.mjs`, `content.ru.mjs`, `config.mjs`, `build.mjs`, `og.mjs`, `site.css`, `roi.mjs` (комментарий), `images.mjs`, `check.mjs`, `ocr_check.mjs`, `package.json`; `site/*` — пересобран.
- `assets/site/*` — картинки, постер, OG; `docs/screens/latest/*`, `docs/screens/pitch/*` (+ README) — снимки.
- `docs/demo/dokazio-demo-v2.mp4` (новый ролик; `hey-helpy-demo*.mp4` удалены).
- `tools/e2e/record_demo.mjs`, `record_demo.sh`, `scenarios.mjs`, `tools/screens/screens.mjs`, `local_backend.mjs`, `tg_*_mock.mjs` — инструменты.
- `README.md`, `CLAUDE.md`, `.claude/commands/check.md`, `docs/DEMO_SCRIPT.md`, `DEMO_DAY_CHECKLIST.md`, `DEMO_SETUP.md`, `docs/design/DESIGN.md`, `docs/site/README.md`, `roi-calculator-brief.md`, `LAUNCH_FIREBASE_STUDIO.md`, `.devcontainer/devcontainer.json`, `pubspec.yaml` (описание), `supabase/seed/demo*.sql` (комментарий).
- Миграций нет.

## Проверки (12.11.2026, локально — GitHub Actions могут быть заблокированы биллингом)
| Проверка | Итог |
|---|---|
| `flutter analyze lib` (Flutter 3.50.0) | ✅ 0 ошибок и предупреждений; 101 «info» — устаревшие API в новой версии Flutter (`GlobalCupertinoLocalizations` и т. п.), столько же на `main` |
| `flutter test` | **546 ✅, 7 ❌** — ⚠️ те же 7 падают и на чистом `main` (проверено в отдельной копии): `design_test` «‹ Моя компания» в шапке», `object_place_line_test` (2), `ppr_row_test` (4). Причина — Flutter 3.50 (вышел 09.11) теперь ругается «An animation is still running even after the widget tree was disposed». К переименованию не относится; «PR check» с `channel: stable` тоже их увидит. Нужен отдельный шаг (предложение задачи из сессии не создалось — тайм-аут) |
| `flutter test` затронутых тестов (`terminology`, `l10n`, `text_intake`, `report_pdf`, `recognition_eval`) | ✅ 58 |
| `deno check supabase/functions/*/*.ts` | ✅ без ошибок (Deno 2.5.6) |
| `deno test supabase/functions` | ✅ 135 |
| `node tools/site/build.mjs` + `node tools/site/check.mjs build/site` | ✅ 17 страниц, 16 адресов в sitemap, 14 ботов, 148 адресов медиа с версией; новая проверка старого имени — чисто |
| `node --test tools/site/roi.test.mjs` | ✅ 17 |
| `bash tools/db_test/run.sh` (все миграции, права, демо дважды, даты сида) | ✅ «Все проверки пройдены» |
| `/screens --local` | 242 ✅ / 33 ❌ (карта, журнал доступа — см. блок 5) |
| `node tools/site/ocr_check.mjs` | 47 ✅ / 1 ❌ (кадр 08 — старое имя) |
| `git grep -i -n "helpy"` | см. ниже |

### Что осталось после `git grep -i "helpy"` (кроме `docs/reports/`) — и почему
- **~490 строк `anton-key.github.io/hey-helpy/…`** — адрес сайта и приложения (блок 2), в основном в собранном `site/`.
- **~190 `package:hey_helpy/…`** — импорты пакета Dart; **~20 `hey_helpy/clock|vps|arlabel`** — каналы Android ↔ Flutter; `com.example.hey_helpy*` — `applicationId` и пакеты Kotlin.
- **~110 `HeyHelpy_bot` / `t.me/HeyHelpy_bot…`** — ник бота (поменять нельзя), тесты бота с упоминанием `@HeyHelpy_bot`.
- `hey-helpy.apk`, `hey-helpy-vps.apk`, `latest-apk`, артефакт `hey-helpy-apk` — постоянные ссылки на APK.
- `supabase/migrations/` (18 файлов), `supabase/config.toml` `project_id` — применённые миграции и служебный id.
- `tools/screens/package.json`, `tools/site/package.json` (имена npm-пакетов), секрет локального бэкенда, пример имени токена Niantic, `LAUNCH_FIREBASE_STUDIO.md` (имя архива `hey_helpy.zip` и репозитория).
- Разбор фразы активации: `text_intake.dart`, `_shared/intake.ts`, `local_backend.mjs`, тест «Эй, Helpy, не горит свет» — **старая фраза намеренно убирается** (блок 1).
- Сторожа и правила с запрещёнными словами: `test/terminology_test.dart`, `tools/site/check.mjs` (строка собрана из частей), `ocr_check.mjs`, `.claude/commands/check.md`, `CLAUDE.md` (историческая справка «до шага 36 — Hey Helpy»).
- `docs/site/ai-readiness-2026-10-16.md`, `…-10-23.md` — датированные оценки сайта (история).

## Что сделать вам
1. **Проверить и слить PR** (кнопка Merge). После слияния сами обновятся веб-версия и сайт («Deploy web») и APK по постоянной ссылке («Build APK») — если Actions не заблокированы биллингом.
2. **Имя бота в Telegram** — @BotFather → `/mybots` → `@HeyHelpy_bot` → **Edit Bot** → **Edit Name** → `Dokazio` (или команда `/setname` → выбрать бота → `Dokazio`). Ник `@HeyHelpy_bot` остаётся. По желанию там же **Edit About** (короткое описание): `Dokazio — Contractor Control. Send the job. See it done.`
3. **Выложить функции** (новые тексты бота и разбор фразы «Hey, Dokazio»): GitHub → Actions → **Deploy functions** → Run workflow (ветка `main`) → Review deployments → `production-db` → **Approve and deploy**.
4. **Обновить описание бота**: Actions → **Telegram webhook** → Run workflow (ветка `main`, `action` = `set`) → Review deployments → `production-db` → Approve and deploy. Повторный запуск безопасен.
5. **Письма входа Supabase**: Supabase → Authentication → **Email Templates** — открыть каждый шаблон (Confirm signup, Invite user, Magic Link, Change Email, Reset Password) и заменить «Hey Helpy», если он там есть, на «Dokazio». Там же Authentication → **SMTP Settings** → «Sender name», если задано.
6. **Кадр питча 08 (карта мира)** — переснять на рабочей базе, где есть ключ карты: `cd tools/screens && node screens.mjs --pitch --only=08,09` (нужны `.env.demo` и `env.json` с `MAP_TILE_KEY`). Заодно можно переснять весь питч на рабочей базе (`--pitch`), чтобы кадр 04 был с настоящим ИИ.
7. По желанию — `/screens` на рабочей базе (карта и «Журнал изменений доступа» тогда снимутся).
8. Значок приложения и логотип сайта — буква «H»; заменить, когда будет бренд-бук (сейчас не трогали, по вашему решению).
9. Миграций в шаге нет, Refresh demo не нужен (в сиде поменялись только комментарии).

## Как проверить руками
- Сайт приложения (после слияния): вкладка браузера — «Dokazio — Contractor Control»; слева вверху и на зелёной кнопке — «Dokazio»; «Профиль → Настройки → О приложении Dokazio».
- Голос (Chrome / Edge / Android): нажать «Dokazio» и сказать «Hey Dokazio, the air conditioner in the meeting room is not working» — в заголовке заявки не должно быть «Hey Dokazio». То же по-русски: «Эй, Доказио, в переговорной не работает кондиционер». И по привычке «Эй, Хелпи, …» — тоже убирается.
- «Отчёты» → «PDF»: в шапке «Dokazio», файл `Dokazio_Report_….pdf`.
- APK: подпись под иконкой — «Dokazio» (после установки свежего APK).
- Бот: `/start` без ссылки → «This is the Dokazio bot…»; `https://t.me/HeyHelpy_bot?start=demo` → «Hello! This is Dokazio — Contractor Control. To apply for a pilot…» (после «Deploy functions»).
- Сайт `…/hey-helpy/site/`: главная «Send the job. See it done.», кнопки «Apply for a pilot» и «See how it works» (прокручивает к «How it works»), строка «Dokazio (doh-KAH-zee-oh) — from “dokaz”, Serbian for “proof”.»; `/ru/` — то же по-русски.

## ⚠️ Решения (что решил сам и почему)
- **Старая фраза «Эй, Хелпи» по-прежнему убирается** из начала голосовой заявки — люди будут говорить по привычке.
- **Варианты новой фразы** («доказио / докацио / doka zio / docazio…») — догадка, как распознаватель запишет незнакомое слово; проверить на живом телефоне.
- **«Request a demo» → «Apply for a pilot» везде на сайте** (не только на главной), «Контакты» → «Apply for a pilot» / «Заявка на пилот»; ссылка та же (`?start=demo`). Ответ бота на `?start=demo` тоже про пилот.
- **Подзаголовок главной**: «Для кого» (шаг 32) остался строкой-киккером над H1 («Dokazio — Contractor Control for business and shopping centres…»), а описание страницы (`description`) — прежнее, про сегменты.
- **Ссылки на калькулятор и ролик** с главной — строкой текста под кнопками (кнопок ровно две, как просили).
- **Удалены старые русские ролики** ПК и телефона (сценарий устарел, в них старое имя); остался английский v2.
- **Постер ролика** — 21-я секунда (карточка «Parsed by AI»), чтобы не показывать «91 %» без подписи.
- **Снято на локальной базе**, а не на рабочей — нет логинов в контейнере.
- **Значок «H» оставлен** (ждём бренд-бук), хотя рядом с «Dokazio» он смотрится странно.
- **Ветка**: работа в `step-36` (как просили) и зеркально в `claude/admiring-darwin-o17vck` (ветка этой сессии).
- Слоган по-русски на сайте: «Отправьте задачу — увидите, что она сделана» (английский оригинал — в OG-картинке и в `llms`).

## Ограничения и что не сделано
- Кадр питча **08** со старым именем (карта); `/screens` — карта и журнал доступа не сняты (см. блок 5).
- 7 тестов Flutter падают на новой версии Flutter 3.50 — **и на `main`**; нужен отдельный шаг.
- Шаблоны писем Supabase и имя бота — меняете вы (у Claude нет доступа).
- Адрес сайта прежний (`/hey-helpy/`); при переезде на dokazio.com поменять `SITE_URL` в `tools/site/config.mjs`, `webAppUrl` в `lib/core/app_links.dart`, `APP_URL` в функциях бота, `--base-href` в workflow.
- PR check в GitHub мог не запуститься (биллинг) — все проверки выше сделаны локально.

## Журнал
- 12.11 · отчёт создан · `fad9492`
- 12.11 · блоки 1, 3, 4: приложение, бот, сайт; deno 135 ✅, сайт ✅, ROI 17 ✅ · `dd717ad`
- 12.11 · блок 6: документы, CLAUDE.md, /check, инструменты демо, ролики переименованы · `72bef1d`
- 12.11 · блок 5: макеты чата 22, 28; OCR ищет «Helpy»; локальная база `run.sh` ✅ · `0fe709f`
- 12.11 · отчёт: блоки 1–4, 6 · `1047722`
- 12.11 · `/screens --local` 242 ✅ / 33 ❌ (карта, журнал) · `47ae097`
- 12.11 · кадры питча (локальная база), 19, 25–27 · `b107e57`
- 12.11 · ролик v2 1:37, картинки и OG сайта, OCR · `651d5e9`
- 12.11 · итоговые проверки и отчёт · (последний коммит)

## Где остановился
Шаг закончен: всё сделано и запушено, PR открыт. Не сделано — см. «Ограничения».
