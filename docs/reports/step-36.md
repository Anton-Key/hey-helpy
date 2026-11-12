# Шаг 36: Hey Helpy → Dokazio (переименование)

Ветка `step-36` от свежего `main` (`6c63627`, PR #35 слит). Открытых задач (issues) нет.
⚠️ Сессия Claude Code закреплена за веткой `claude/admiring-darwin-o17vck`: те же коммиты пушатся и туда, PR — из `step-36`, как просили.

## Чек-лист
- [x] 1. Приложение: appName, подпись под иконкой, web, wakePhrase, .arb, PDF, terminology_test
- [x] 2. Что НЕ меняем — список ниже
- [x] 3. Telegram-бот: тексты, описание бота, тесты
- [x] 4. Сайт: имя, главная, легенда, честные формулировки про распознавание, check.mjs
- [x] 5. Картинки и видео: /screens, питч, сайт, ролик, OCR — см. блок 5 (что снято, что нет)
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

## Журнал
- 12.11 · отчёт создан · `fad9492`
- 12.11 · блоки 1, 3, 4: приложение, бот, сайт; deno 135 ✅, сайт ✅, ROI 17 ✅ · `dd717ad`
- 12.11 · блок 6: документы, CLAUDE.md, /check, инструменты демо, ролики переименованы · `72bef1d`
- 12.11 · блок 5: макеты чата 22, 28; OCR ищет «Helpy»; локальная база `run.sh` ✅ · `0fe709f`

## Где остановился
Блок 5: полная съёмка `/screens --local` в фоне. Дальше: кадры питча, сценарий 17, ролик, `images.mjs`, `og.mjs`, `build.mjs`, OCR, полный `flutter test`, итог.
