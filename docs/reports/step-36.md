# Шаг 36: Hey Helpy → Dokazio (переименование)

Ветка `step-36` от свежего `main` (`6c63627`, PR #35 слит). Открытых задач нет.
⚠️ Сессия Claude Code закреплена за веткой `claude/admiring-darwin-o17vck`: те же коммиты пушатся и туда, PR — из `step-36`.

## Чек-лист
- [ ] 1. Приложение: appName, подпись под иконкой, web, wakePhrase, .arb, PDF, terminology_test
- [ ] 2. Что НЕ меняем — список
- [ ] 3. Telegram-бот: тексты, тесты
- [ ] 4. Сайт: имя, главная, легенда, честные формулировки про распознавание, check.mjs
- [ ] 5. Картинки и видео: /screens, питч, сайт, ролик, OCR
- [ ] 6. Документы: README, DEMO_SCRIPT, docs/site, pitch README, CLAUDE.md
- [ ] Проверки, итог, «Что сделать вам», PR

## Журнал
- 12.11 · отчёт создан · `fad9492`
- 12.11 · блоки 1, 3, 4: приложение, бот, сайт; deno 135 ✅, сайт ✅, ROI 17 ✅ · `dd717ad`
- 12.11 · блок 6: документы, CLAUDE.md, /check, инструменты демо, ролики переименованы · `72bef1d`
- 12.11 · блок 5: макеты чата 22, 28; локальная база `run.sh` ✅; съёмка `/screens --local` идёт

## Где остановился
Блок 5: `/screens --local` (сборка `build/web_local` с `--no-web-resources-cdn`, CanvasKit с gstatic.com недоступен).
Дальше: кадры питча `screens.mjs --local --pitch`, `local_pitch.mjs`, сценарий 17 (25–27), ролик `record_demo.sh --v2-only`,
`images.mjs`, `og.mjs`, `build.mjs`, OCR.
