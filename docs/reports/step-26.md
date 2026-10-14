# Шаг 26: кто что может делать с заявкой + фото «после» только живым снимком

Ветка `step-26` от `main` (шаг 25 слит). Открытых задач (issues) нет: `gh issue list --state open` вернул пустой список.

**Новая миграция — 0023** `0023_order_roles_photo_proof.sql` (применяет пользователь, полный текст — ниже). Менялась Edge Function `photo-identify` (общий `_shared/identify.ts`, его же использует `telegram-bot`) — нужен **Deploy functions**. Менялись демо-данные (`demo_history.sql`) — нужен **Refresh demo** после 0023. Новых пакетов и секретов нет.

## Чек-лист
- [x] 1. Роли и действия с заявкой: миграция 0023 (статусы, фото «после», чек-лист, визиты)
- [x] 1. Интерфейс: одна функция `orderActions` + тесты, строка хода работы у менеджера, понятные ошибки
- [x] 1. Тесты базы `tools/db_test/order_roles.sql` (58 проверок), сквозной сценарий 16
- [x] 2. Фото «после» — только живой камерой; «из файла» — только в браузере без камеры
- [x] 2. `attachments.source`, акт: фото «из файла» — не доказательство, метка в галерее
- [x] 2. Штамп на фото «после» (сделан, проверен на картинке)
- [x] 3. «В кадре не видно оборудования» (`photo-identify`)
- [x] 4. Проверки, `CLAUDE.md`, `DEMO_SCRIPT.md`, `/check`, `/screens`
- [ ] 4. Кадр 21 на рабочей базе — см. ниже

## Что сделано

### Блок 1. Роли и действия с заявкой
Последняя версия `trg_wo_status_flow` была в **0006** (0008 и 0010 её не переопределяли). Новая версия в 0023 — по таблице:

| Действие | Кто может (проверяет база) |
|---|---|
| Создать | как раньше; но вошедший пользователь создаёт только «Новая» / «Назначена» (раньше менеджер мог вставить сразу «Выполнена») |
| Назначить / сменить подрядчика | менеджер с правом на заявку (зона 0016), администратор |
| Правка текста | менеджер / админ; автор — пока работа не начата (`new` / `assigned`) |
| Начать, визит, чек-лист, фото «после», «на проверку» | **только исполнитель назначенного подрядчика** (в бригаде — в зоне бригады). Без подрядчика — никто |
| Принять / вернуть | менеджер с правом на заявку, администратор — **не тот, кто отправил на проверку** |
| Отменить | менеджер / админ; автор — пока работа не начата |

- Кто отправил на проверку — новый столбец `work_orders.submitted_by`, ставит только база (подменить нельзя никому, кроме обслуживания).
- Соседние правила закрыты: фото «после» (`attachments_insert`) и визит (`visits_insert`) — только исполнитель (менеджер убран); отметка чек-листа — только исполнитель (`trg_checklist_guard`, «кто и когда» пишет база; менеджер по-прежнему заводит и правит пункты). Фото «до» и документы менеджер прикладывает как раньше.
- Без `auth.uid()` (SQL Editor, Refresh demo, service_role) — без ограничений, как раньше. Бот (`tg_create_order`) создаёт заявки «Новая» — работает (тесты `telegram.sql` 73/73), `telegram-notify` только читает — не затронут (10/10). ППР (`ppr_generate`) создаёт «Новая» — работает (49/49). Акт — 33/33. Демо-данные заливаются дважды без ошибок.
- **Интерфейс:** все кнопки карточки заявки — из одной функции `orderActions(who, status, …)` (`lib/features/requests/order_actions.dart`). Исполнитель определяется по `executors` (приложение один раз читает подрядчиков пользователя), а не по роли. У менеджера:
  - заявка в работе — строка **«Выполняет КлиматСервис · начато 14 окт. 10:15 · фото «после»: нет»** вместо кнопок исполнителя;
  - без подрядчика — «Сначала назначьте подрядчика — работу начинает его исполнитель»;
  - на проверке — «Принять» / «Вернуть»; если отправил он сам — «Работу на проверку отправили вы — принять должен другой менеджер».
- Ошибки базы — по-человечески: «Это действие выполняет исполнитель подрядчика», «Принять или вернуть работу может только менеджер», «Работу отправили вы — принять должен другой менеджер».

⚠️ **Решения:**
- **Заявитель больше не принимает и не возвращает работу** (раньше мог автор). Так требует таблица задания: принимает менеджер. Кнопки «Принять» у заявителя больше нет.
- **Автор правит и отменяет заявку, пока работа не начата — `new` или `assigned`**, а не только «Новая»: правило слоя назначает подрядчика сразу при создании, и заявка почти никогда не бывает «Новой» — иначе заявитель вообще не смог бы поправить опечатку.
- **Исполнитель без бригады у подрядчика с бригадами** — по-прежнему видит и делает всё своего подрядчика (как решено в 0016). Задание говорит «как в 0016» — так и оставил.
- **Собственная служба эксплуатации** (менеджер сам делает работу): в рабочей базе таких нет (проверено запросом: менеджеров-исполнителей 0). Правильный путь — завести «Свою службу» подрядчиком и добавить менеджера туда исполнителем. Тогда он начинает и сдаёт как исполнитель, а принимает **другой** менеджер / администратор. Описано в `CLAUDE.md`, переключателя нет. Тест в базе это проверяет.
- В хранилище `work-photos` по пути файла не видно, «до» это или «после», поэтому менеджер технически может положить туда файл. Но доказательством считается только строка `attachments` со стадией «после», а её вставить может только исполнитель — этого достаточно.

### Блок 2. Фото «после» — только живым снимком
- «Сфотографировать результат» открывает **живую камеру** (`lib/features/photos/live_shot_screen.dart`, тот же `LiveCamera` шага 25: CameraX на Android, `getUserMedia` в браузере): кадр на весь экран, затвор, стоп-кадр, **«Переснять» / «Готово»**. Галереи нет.
- Камеры нет (ПК без веб-камеры, отказ в доступе) — **только в браузере** можно «Выбрать файл» с предупреждением: «фото будет помечено «из файла» и не засчитается в акте». На телефоне — только «Попробовать снова».
- Фото «до» — как раньше (в браузере выбор файла помечается «из файла», на Android камера — `camera`; «Камера-помощник» — `camera`; бот — `telegram`).
- **Штамп** вжигается полупрозрачной полосой внизу: «14.10.2026 14:19 · БЦ «Демо» · 301 Переговорная · в геозоне» (геозона — если есть геопозиция снимка и координаты объекта). Рисует Flutter (шрифт Onest с кириллицей), JPEG кодирует пакет `image` **отложенно**. Не получилось — загружается снимок без штампа. Проверено на картинке с настоящим шрифтом.
- `attachments.source` (`camera | file | telegram | demo`). ⚠️ **Как защищено «задним числом»**: источник ставит приложение **только при вставке**; триггер `trg_attachments_source` не даёт его изменить потом никому, кроме обслуживания, «demo» от пользователя превращается в «file», «telegram» — только из бота. Подделать `camera` при вставке изменённым клиентом теоретически можно — базе не узнать, откуда байты; для MVP достаточно. ⚠️ Отдельного `captured_at` не добавлял: время снимка уже хранится в `attachments.taken_at` (его пишет приложение с устройства), второй столбец дублировал бы его.
- Старые строки: `demo/…` → `demo`, фото бота → `telegram`, остальные → `file` (как сказано в задании). ⚠️ Значит, **старые реальные фото «после» в рабочей базе (если были) в акте станут «без доказательства»**. В рабочей базе сейчас 9 фото, 8 из них — демо.
- **Акт:** фото «после» только «из файла» → «Без доказательства» с причиной «фото «после» загружено из файла, не снято на месте». В галерее у такого фото — метка **«из файла»** (на миниатюре и в подписи при просмотре).
- Демо (`demo_history.sql`): фото `demo/…` получают `source = demo` (только если 0023 применена) — считаются доказательством, как раньше.
- Приложение работает и на базе без 0023 (`SchemaCompat`): `source` просто не пишется и не читается.

### Блок 3. «Не оборудование» в кадре
- `_shared/identify.ts`: модель отвечает полем `equipment` (в схеме ответа обязательное). `false` (человек, лицо, пейзаж, документ, пустая стена) — вида, системы, шильдика нет, **кандидаты не подбираются**, в ответе `no_equipment: true`. Старый ответ без поля — как раньше.
- «Камера-помощник» и «Узнать по фото» пишут **«В кадре не видно оборудования — наведите камеру на прибор»** вместо «Не узнал» (в «Камере» список оборудования помещения остаётся ниже — можно выбрать вручную).
- Нужен **Deploy functions** (и `photo-identify`, и `telegram-bot` используют общий код).

### Блок 4. Кадры и проверки
- `CLAUDE.md`: таблица ролей, «собственная служба», правило «фото «после» — живой снимок», `attachments.source`, 0023, следующий номер **0024**. 0023 в «Применённые» **не** дописана (дописывается после «применена 0023»).
- `docs/DEMO_SCRIPT.md`: исполнитель «КлиматСервис» — отдельный вход на телефоне, менеджер только назначает и принимает; фраза «Менеджер не может закрыть работу за подрядчика — это проверяет база»; строка 1:00 в таблице показа.
- Кадр 21 — см. «Проверки».

## Журнал
- 14.10 · отчёт создан · первый коммит
- 14.10 · миграция 0023 + `tools/db_test/order_roles.sql` (58 проверок), все тесты базы и демо-данные — без ошибок · «Шаг 26 (блок 1): миграция 0023»

- 14.10 · интерфейс: `orderActions` + тесты, строка хода работы у менеджера, понятные ошибки · «Шаг 26 (блок 1): кнопки карточки…»
- 14.10 · живой снимок для фото «после» (`live_shot_screen.dart`), штамп, `source` в загрузке, акт «из файла», метка в галерее, демо `source = demo` · «Шаг 26 (блок 2)»

- 14.10 · `photo-identify`: признак «нет оборудования», приложение — «В кадре не видно оборудования…» · «Шаг 26 (блок 3)»
- 14.10 · сквозной сценарий 16, сценарии 1–2 — живая камера, `CLAUDE.md`, `DEMO_SCRIPT.md`, `/check` ✅ · «Шаг 26 (блок 4)»
- 14.10 · отчёт дописан (что сделано, файлы, проверки, текст 0023); `/screens` прерван по просьбе пользователя на середине · «Шаг 26: отчёт, пауза»

## Где остановился
- Работа **на паузе по просьбе пользователя** (14.10, ~17:30 UTC).
- `/screens` был запущен и остановлен на середине (снимал manager-412). Папка `docs/screens/latest/` в рабочей копии — наполовину новая, **не закоммичена**. Следующим: заново `cd tools/screens && PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node screens.mjs` (≈ 40+ мин), прочитать README, заменить `SCREENS_PLACEHOLDER` в «Проверки».
- Refresh demo в рабочей базе уже выполнен (заявки 277, 279 и план 809 есть) → переснять кадр 21: `node screens.mjs --pitch --only=21`, обновить `docs/screens/pitch/README.md` (убрать «ПРЕДПРОСМОТР» у 21), отметить пункт чек-листа.
- Затем: коммит экранов → push `step-26` → `gh pr create` «Шаг 26: …» со ссылкой на отчёт и миграцией 0023.


## Новые и изменённые файлы
- `supabase/migrations/0023_order_roles_photo_proof.sql` — новая миграция (роли, `submitted_by`, `source`, фото «после», чек-лист, визит).
- `tools/db_test/order_roles.sql` — 58 проверок прав по ролям и переходам.
- `lib/features/requests/order_actions.dart` — одна функция «что можно этому пользователю с этой заявкой».
- `lib/features/requests/requests.dart` — кнопки карточки по `orderActions`, строка хода работы, подсказки, `myContractorIds`, живой снимок для «после».
- `lib/core/l10n_ext.dart` — понятные ошибки смены статуса по целевому статусу.
- `lib/features/photos/live_shot_screen.dart` — экран живого снимка (новый).
- `lib/features/photos/photo_stamp.dart`, `photo_stamp_encode.dart` — штамп (кодирование отложенно).
- `lib/features/photos/photo_repository.dart` — `source` у снимка и фото, загрузка/чтение с откатом без 0023.
- `lib/features/photos/photo_capture.dart` — источник фото «до» (браузер — `file`).
- `lib/features/photos/photo_section.dart` — метка «из файла».
- `lib/features/acts/act_logic.dart`, `acts_repository.dart`, `act_doc.dart` — причина «фото из файла».
- `lib/features/camera/camera_logic.dart`, `camera_screen.dart` — карточка «нет оборудования», снимок камеры — `camera`.
- `lib/features/photo_identify/identify_models.dart`, `photo_identify_screen.dart` — `no_equipment`.
- `lib/l10n/app_ru.arb`, `app_en.arb` (+ сгенерированные) — новые строки RU / EN.
- `supabase/functions/_shared/identify.ts`, `photo-identify/schema_test.ts` — признак «нет оборудования» и тест.
- `supabase/seed/demo_history.sql` — `source = demo` у демо-фото.
- `test/order_actions_test.dart`, `test/live_shot_test.dart` (новые), `test/act_logic_test.dart`, `test/camera_logic_test.dart`.
- `tools/e2e/scenarios.mjs` — сценарий 16; в 1–2 фото «после» живой камерой; в 14 — фото «из файла» не доказательство.
- `CLAUDE.md`, `docs/DEMO_SCRIPT.md`, `docs/reports/step-26.md`, `docs/screens/latest/`.

## Проверки
- `flutter analyze lib test` — без замечаний.
- `flutter test` — **443 прошли**, 0 упало.
- `deno check` + `deno test supabase/functions` — **85 прошли**.
- `bash tools/db_test/run.sh` — все наборы зелёные: order_roles 58, access_zones 34, contractor_acts 33, cross_refs 21, documents_systems 39, photo_identify 15, ppr_regions 49, telegram 73, telegram_notify 10, tenant_isolation 770; миграции 0015+ (и 0023) — повторный запуск без ошибок; демо-данные дважды — без ошибок.
- Сквозные `tools/e2e/run.sh` — **16 из 16 ✅** (9 — на старой базе без новых миграций). Сценарий 16: менеджер не видит «Начать работу» → исполнитель начинает (визит в геозоне), живой снимок «после» (источник `camera`), сдаёт (`submitted_by` = исполнитель) → менеджер принимает → в акте «К оплате» на экране 7 = по базе 7, заявка среди них.
- `/check` — ✅ анализ, ✅ тесты, ✅ веб-сборка, ✅ строки вне переводов, ✅ название продукта.
- `/screens` — SCREENS_PLACEHOLDER

## Полный текст миграции 0023
**Зачем:** база сама не даёт менеджеру выполнить заявку за подрядчика и принять собственную работу; фото «после» и отметки — только от исполнителя; у фото — источник.
**Что меняет:** см. шапку файла. Данные меняет только в `attachments.source` (заполнение по пути файла). Права обычных действий исполнителя и менеджера (назначение, приёмка) — как раньше.
**Повторный запуск:** безопасен — `add column if not exists`, `create or replace`, `drop … if exists` перед `create policy / trigger`; обновления `source` трогают только строки `file`. Проверено `tools/db_test/run.sh` (миграция выполняется дважды).

```sql
-- =====================================================================
-- hey_helpy · Миграция 0023: кто что может делать с заявкой (шаг 26)
--
-- Разделение обязанностей: работу делает и сдаёт ТОЛЬКО исполнитель
-- назначенного подрядчика, принимает — менеджер (не тот, кто сдал).
-- Раньше (0006) менеджер мог сам начать, сам сдать и сам принять.
--
-- 1) work_orders.submitted_by — кто отправил на проверку (ставит только
--    база). Принять / вернуть этот же человек не может.
-- 2) trg_wo_status_flow — новая версия (теперь и на insert):
--      назначить (→ assigned)        менеджер с правом на заявку, автор — пока «Новая»;
--      начать (→ in_progress)        только исполнитель назначенного подрядчика
--                                    (в бригаде — только в зоне бригады, как 0016);
--      на проверку (→ on_review)     только он же, с фото «после», если нужно;
--      принять / вернуть             менеджер с правом на заявку или администратор,
--                                    но не тот, кто отправил на проверку;
--      отменить                      менеджер с правом на заявку; автор — пока
--                                    работа не начата (new / assigned).
--    Новая заявка от вошедшего пользователя — только «Новая» или
--    «Назначена» (раньше менеджер мог вставить сразу «Выполнена»).
--    Без auth.uid() (SQL Editor, Refresh demo, service_role) — как раньше,
--    без ограничений. Функции бота tg_* создают заявки «Новая» — не меняется.
-- 3) trg_wo_guard — автор меняет содержание своей заявки, только пока
--    работа не начата (new / assigned); submitted_by — только база.
-- 4) Соседние правила: фото «после» (attachments_insert), отметка
--    чек-листа (trg_checklist_guard), визит (visits_insert) — только
--    исполнитель назначенного подрядчика. Фото «до» и документы менеджер
--    прикладывает по-прежнему.
-- 5) attachments.source: camera | file | telegram | demo. Ставит
--    приложение при вставке; изменить потом нельзя никому, кроме
--    обслуживания (trg_attachments_source). Время снимка — уже
--    существующий столбец taken_at. Старые строки: demo/… — demo,
--    …/tg_… — telegram, остальные — file.
--
-- Повторный запуск безопасен: add column if not exists, create or replace,
-- drop … if exists.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Кто отправил на проверку
-- ---------------------------------------------------------------------
alter table public.work_orders
  add column if not exists submitted_by uuid references public.profiles(id) on delete set null;

-- ---------------------------------------------------------------------
-- 2. Исполнитель назначенного подрядчика (с зоной бригады) — одна функция
--    для триггеров и политик.
-- ---------------------------------------------------------------------
create or replace function public.wo_is_executor(p_order uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select w.assigned_contractor_id is not null
       and w.assigned_contractor_id in (select public.my_contractor_ids())
       and (public.zones_unrestricted()
            or public.can_see(w.object_id, w.layer_id, w.asset_id, w.location_id))
      from work_orders w where w.id = p_order), false);
$$;
revoke all on function public.wo_is_executor(uuid) from public, anon;
grant execute on function public.wo_is_executor(uuid) to authenticated;

-- Менеджер (админ) с правом на заявку: администратор — вся компания,
-- менеджер — своя зона (0016).
create or replace function public.wo_is_manager(p_order uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_manager() and coalesce((
    select w.company_id = public.my_company_id()
       and (public.is_admin()
            or public.can_manage(w.object_id, w.layer_id, w.asset_id, w.location_id))
      from work_orders w where w.id = p_order), false);
$$;
revoke all on function public.wo_is_manager(uuid) from public, anon;
grant execute on function public.wo_is_manager(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Смена статуса
-- ---------------------------------------------------------------------
create or replace function public.trg_wo_status_flow()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_mgr    boolean;
  v_author boolean;
  v_exec   boolean;
  f text;
  t text := new.status;
begin
  -- обслуживание из SQL Editor / сервисным ключом — без ограничений
  if v_uid is null then return new; end if;

  if tg_op = 'INSERT' then
    -- новая заявка начинается с «Новой» (или «Назначена» правилом слоя)
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

  -- кто сдал работу, пишет только база
  new.submitted_by := old.submitted_by;
  f := old.status;
  if f = t then return new; end if;

  v_mgr    := public.wo_is_manager(old.id);
  v_author := old.created_by = v_uid;
  v_exec   := public.wo_is_executor(old.id);

  if t = 'assigned' and f in ('new', 'returned') and (v_mgr or (v_author and f = 'new')) then
    null;
  elsif t = 'in_progress' and f in ('new', 'assigned', 'returned') and v_exec then
    new.started_at := coalesce(old.started_at, now());
  elsif t = 'on_review' and f = 'in_progress' and v_exec then
    if old.requires_photo and not exists (
         select 1 from attachments a
          where a.work_order_id = old.id and a.kind = 'photo'
            and coalesce(a.stage, 'after') = 'after') then
      raise exception 'photo required' using hint = 'Прикрепите фото выполненной работы';
    end if;
    new.submitted_at := now();
    new.submitted_by := v_uid;
    if old.started_at is not null then
      new.time_spent_minutes := greatest(1, ceil(extract(epoch from now() - old.started_at) / 60))::int;
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

-- Теперь и на insert, и на любое изменение (submitted_by защищён всегда).
drop trigger if exists trg_wo_status_flow on public.work_orders;
create trigger trg_wo_status_flow
  before insert or update on public.work_orders
  for each row execute function public.trg_wo_status_flow();

-- ---------------------------------------------------------------------
-- 4. Кто какие поля меняет (0008 + submitted_by, автор — до начала работы)
-- ---------------------------------------------------------------------
create or replace function public.trg_wo_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  -- поля, которые заявитель у своей заявки менять не может
  v_locked text[] := array[
    'company_id', 'created_by', 'created_at',
    'assigned_contractor_id', 'assigned_executor_id', 'assigned_by',
    'requires_photo', 'requires_scan', 'input_channel',
    'started_at', 'submitted_at', 'submitted_by', 'accepted_at', 'accepted_by',
    'time_spent_minutes'];
  -- всё, что исполнитель может менять у заявки своего подрядчика
  v_exec_allowed text[] := array['status', 'updated_at'];
  k text;
begin
  -- обслуживание из SQL Editor / сервисным ключом — без ограничений
  if v_uid is null then return new; end if;
  if public.is_manager() then return new; end if;

  if tg_op = 'INSERT' then
    new.requires_photo         := false;
    new.requires_scan          := false;
    new.status                 := 'new';
    new.assigned_contractor_id := null;
    new.assigned_executor_id   := null;
    new.assigned_by            := null;
    new.started_at             := null;
    new.submitted_at           := null;
    new.submitted_by           := null;
    new.accepted_at            := null;
    new.accepted_by            := null;
    new.time_spent_minutes     := null;
    new.return_reason          := null;
    return new;
  end if;

  if old.created_by = v_uid then
    foreach k in array v_locked loop
      if (to_jsonb(new) -> k) is distinct from (to_jsonb(old) -> k) then
        raise exception 'forbidden: % is changed by manager only', k using errcode = '42501';
      end if;
    end loop;
    -- содержание — только пока работа не начата; статус проверяет trg_wo_status_flow
    if old.status not in ('new', 'assigned')
       and (to_jsonb(new) - v_exec_allowed) is distinct from (to_jsonb(old) - v_exec_allowed) then
      raise exception 'forbidden: author edits only before work starts' using errcode = '42501';
    end if;
    return new;
  end if;

  -- сюда доходит только исполнитель: политика wo_update пропускает
  -- менеджера, автора или исполнителя назначенного подрядчика
  if (to_jsonb(new) - v_exec_allowed) is distinct from (to_jsonb(old) - v_exec_allowed) then
    raise exception 'forbidden: executor can change status only' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.trg_wo_guard() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. Вложения: источник фото
-- ---------------------------------------------------------------------
alter table public.attachments
  add column if not exists source text not null default 'file';

alter table public.attachments drop constraint if exists attachments_source_check;
alter table public.attachments add constraint attachments_source_check
  check (source in ('camera', 'file', 'telegram', 'demo'));

-- старые строки: демо-картинки и фото из бота (повторно — ничего не меняет)
update public.attachments set source = 'demo'
 where source = 'file' and storage_path like 'demo/%';
update public.attachments set source = 'telegram'
 where source = 'file' and kind = 'photo' and storage_path like '%/tg\_%';

-- Источник ставится один раз при вставке; потом его не меняет никто, кроме
-- обслуживания. «demo» — только обслуживание, «telegram» — только бот
-- (tg_create_order ставит hh.telegram = 1), «camera» — только фото.
create or replace function public.trg_attachments_source()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;
  if tg_op = 'UPDATE' then
    new.source   := old.source;
    new.taken_at := old.taken_at;
    return new;
  end if;
  if coalesce(current_setting('hh.telegram', true), '') = '1' and new.kind = 'photo' then
    new.source := 'telegram';
  elsif new.source not in ('camera', 'file') or new.kind <> 'photo' then
    new.source := 'file';
  end if;
  return new;
end $$;
revoke all on function public.trg_attachments_source() from public, anon, authenticated;

drop trigger if exists trg_attachments_source on public.attachments;
create trigger trg_attachments_source
  before insert or update on public.attachments
  for each row execute function public.trg_attachments_source();

-- Фото «после» — только исполнитель назначенного подрядчика (был ещё
-- менеджер, 0006 / 0019). Фото «до» и документы — без изменений.
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

-- ---------------------------------------------------------------------
-- 6. Чек-лист: пункты заводит менеджер (0008), отмечает — только
--    исполнитель назначенного подрядчика; кто и когда — пишет база.
-- ---------------------------------------------------------------------
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
    new.done_at := case when new.is_done then now() end;
  else
    new.done_by := old.done_by;
    new.done_at := old.done_at;
  end if;
  -- исполнитель меняет только отметку
  if not public.is_manager()
     and (new.text is distinct from old.text or new.work_order_id is distinct from old.work_order_id) then
    raise exception 'forbidden: executor can check items only' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function public.trg_checklist_guard() from public, anon, authenticated;

drop trigger if exists trg_checklist_guard on public.checklist_items;
create trigger trg_checklist_guard
  before insert or update on public.checklist_items
  for each row execute function public.trg_checklist_guard();

-- ---------------------------------------------------------------------
-- 7. Визит — только исполнитель назначенного подрядчика (был ещё менеджер, 0009)
-- ---------------------------------------------------------------------
drop policy if exists visits_insert on public.visits;
create policy visits_insert on public.visits for insert with check (
  company_id = (select public.my_company_id())
  and profile_id = (select auth.uid())
  and exists (
    select 1 from public.work_orders w
     where w.id = visits.work_order_id
       and w.company_id = (select public.my_company_id())
       and w.status = 'in_progress'
       and public.wo_is_executor(w.id)));
```

## Что сделать вам
1. Проверить и **слить PR** (GitHub → Pull requests → «Шаг 26» → Merge).
2. **Apply migration**: GitHub → Actions → [Apply migration](https://github.com/Anton-Key/hey-helpy/actions/workflows/apply-migration.yml) → Run workflow (ветка `main`) → в поле `file`: `0023_order_roles_photo_proof.sql` → Run → прочитать текст → Review deployments → `production-db` → **Approve and deploy**. Написать мне «применена 0023».
3. **Refresh demo**: Actions → [Refresh demo](https://github.com/Anton-Key/hey-helpy/actions/workflows/refresh-demo.yml) → Run workflow → Approve (демо-фото получат `source = demo`; сама 0023 их тоже помечает, так что шаг не обязателен, но данные станут свежими к питчу).
4. **Deploy functions**: Actions → [Deploy functions](https://github.com/Anton-Key/hey-helpy/actions/workflows/deploy-functions.yml) → Run workflow → Approve (новая `photo-identify` и `telegram-bot` с общим кодом).
5. Сайт — обновить с очисткой кэша **Ctrl+Shift+R**; APK — скачать свежий по постоянной ссылке.

## Как проверить руками
1. **Менеджер** (демо-менеджер): открыть заявку «Назначена» — кнопок «Начать работу», «Сфотографировать результат», «Выполнено, на проверку» **нет**. Открыть заявку «В работе» — строка «Выполняет КлиматСервис · начато … · фото «после»: …».
2. **Исполнитель «КлиматСервис»** (`DEMO_EXECUTOR_EMAIL`, пароль у вас): открыть ту же «Назначена» → «Начать работу» → «Сфотографировать результат» → открывается **камера** (галереи нет) → «Снять» → «Готово» → в карточке «После · 1», на фото внизу полоса «дата · БЦ «Демо» · помещение · в геозоне» → «Выполнено, на проверку».
3. Снова **менеджер** → «Принять работу». Затем «Отчёты» → «Акты подрядчикам» → «КлиматСервис»: заявка в «К оплате».
4. «Камера-помощник»: навести на лицо / стену → «Что это?» → «В кадре не видно оборудования — наведите камеру на прибор» (после Deploy functions).

## Ограничения и что не сделано
- Кадр 21 на рабочей базе — см. «Проверки» (`/screens`).
- Источник `camera` ставит приложение; изменённый клиент теоретически может прислать файл как `camera` (база не видит, откуда байты). Защищено только «задним числом».
- «Авто» в «Камере-помощнике» и новый экран снимка «после» — без изменений по платформам шага 25 (в APK кадры через CameraX).
- До применения 0023 приложение уже прячет кнопки исполнителя у менеджера и «Принять» у заявителя, но база ещё пускает по-старому.
